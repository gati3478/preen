#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./git/install.sh [--dry-run]

Take this git configuration alone.

Copies the config into ~/.config/git/preen and appends ONE line to the file
git --global writes to — ~/.gitconfig where it is there, else
~/.config/git/config where only that is:

  [include] path = ~/.config/git/preen/gitconfig

That is the whole edit to your file. Nothing in it is rewritten or removed,
and with neither file there, a new ~/.gitconfig holds that line alone. Your
name and email are not asked for, and nothing here writes them. Copies,
never symlinks: the file becomes yours to tune, and nothing here points back
at this repo afterwards. ~/.config/git/ignore, git's global ignore, is copied
only where none is there.

  from a clone:    ./git/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/git/install.sh | bash

There is nothing to ask, so nothing is asked.

The appended line reads a whole config in place, so it wins over every line
above it in your file, and a line below it wins over it. ~/.gitconfig.local,
which the copy includes at its end, wins over it too. That file is yours:
nothing here writes it.

Nothing is overwritten without a timestamped backup beside it, and a re-run
with nothing changed rewrites nothing. Every refusal comes before the first
write; among them: a GIT_CONFIG_GLOBAL set, under which git reads that file
alone, or none; an XDG_CONFIG_HOME that names a directory other than
~/.config; a symlinked ~/.config, ~/.config/git or preen/, or one the run can
neither write into nor create; a symlinked file the line goes in whose target
lacks it, which belongs in the target; that file lacking the line and not one
the run can read and append to, or locked by a git writing it; a
~/.gitconfig.local that is, or links to, that file or the copy, which would
loop, or is not a file; and where git can be asked, a ~/.gitconfig.local
that includes either, or a file git cannot read, or one that would read the
appended line as part of the line above it — where it cannot, a last line
ending in a backslash. A file linked into a clone of the whole setup
already has this config, and the run says so and writes nothing.

  --dry-run   print what the run would touch and stop, having written nothing
  -h, --help  print this and exit
EOF
}
set -euo pipefail

# Every argument is answered before the temp directory, the helper's fetch and
# git, so --help and an argument error write nothing and need no network. The
# helper's die is not loaded yet, and exits 1 where an argument error is 2.
for arg in "$@"; do case "$arg" in -h|--help) usage; exit 0 ;; esac; done
dry_run=no
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=yes ;;
    *) echo "install.sh: unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

# ── the shared helper ────────────────────────────────────────────────────────
# The generic half of every drop-in installer here: the source resolution, the
# plan, the copies and their backup rule. Beside this script in a clone;
# otherwise fetched from the mirror exactly as the config is — same trust,
# same mechanism — and checked for its marker line before it is sourced.
PIECE="git"   # this piece's path under the mirror root
ROOT_URL="${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/main}"
SOURCE_URL="${GIT_SOURCE:-$ROOT_URL/$PIECE}"
# GIT_SOURCE names this piece's directory and the helper sits a level above
# it, so an override takes the root with it instead of leaving it on the mirror.
if [ -n "${GIT_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*}"; fi

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || SELF_DIR=""; fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Beside this script in either tree — `lib/` in the mirror, `public/lib/` in the
# private one — else fetched from the root the config comes from. Never the
# directory the shell happens to be standing in.
LIB=""
candidate="$SELF_DIR/../lib/install.sh"
if [ -f "$candidate" ] && grep -q '^PREEN_INSTALL_LIB=1$' "$candidate"; then LIB="$candidate"; fi
if [ -z "$LIB" ]; then
  LIB="$WORK/lib.sh"
  curl -fsSL "$ROOT_URL/lib/install.sh" -o "$LIB" 2>/dev/null || { echo "install.sh: could not fetch $ROOT_URL/lib/install.sh" >&2; exit 1; }
  grep -q '^PREEN_INSTALL_LIB=1$' "$LIB" || { echo "install.sh: $ROOT_URL/lib/install.sh is not the shared installer helper" >&2; exit 1; }
  # A download cut off past the marker line passes the check above and then
  # fails to parse — and a parse failure inside `source` is masked to exit 0 by
  # the EXIT trap, so `curl … | bash && echo installed` would print installed.
  bash -n "$LIB" 2>/dev/null || { echo "install.sh: $ROOT_URL/lib/install.sh did not arrive whole — try again" >&2; exit 1; }
fi
# shellcheck source=../lib/install.sh
. "$LIB"

CONFIG_HOME="$HOME/.config"
GIT_DIR_XDG="$CONFIG_HOME/git"
PREEN_DIR="$GIT_DIR_XDG/preen"
COPY="$PREEN_DIR/gitconfig"
IGNORE="$GIT_DIR_XDG/ignore"
DOT_CONF="$HOME/.gitconfig"
XDG_CONF="$GIT_DIR_XDG/config"
LOCAL_CONF="$HOME/.gitconfig.local"
# shellcheck disable=SC2088  # a path for git to expand, its ~ git's own
LINE_PATH='~/.config/git/preen/gitconfig'
LINE="[include] path = $LINE_PATH"
# The copy's load-bearing end: the overlay an adopter's own lines go in,
# included last so it wins.
OVERLAY_LAST="$(printf '\tpath = ~/.gitconfig.local')"

# git reads ~/.config/git/config, then ~/.gitconfig, and `git config --global`
# writes to ~/.gitconfig where it is there, else to ~/.config/git/config where
# only that is, else to a new ~/.gitconfig: the file the line goes in is the
# one --global writes, and the last git reads. A link counts as there,
# dangling or not, so the symlink policy below meets it.
if there "$DOT_CONF"; then
  TARGET="$DOT_CONF"
elif there "$XDG_CONF"; then
  TARGET="$XDG_CONF"
else
  TARGET="$DOT_CONF"
fi

# ── a home that took the whole setup ─────────────────────────────────────────
# Its ~/.gitconfig is a link into the setup's clone, which already carries this
# config; the line appended there would dirty that clone.
if links_into_clone "$TARGET"; then
  echo "$(short "$TARGET") links into a clone of the whole setup, which already carries this config. Nothing was changed."
  exit 0
fi

# ── git's own read, nothing in the file run ──────────────────────────────────
# `git config -f <file> --no-includes -z --list` reads one file and prints
# each entry as `key\nvalue\0`; a file git cannot read is rc 128 and git's
# message. Every probe reads with no system and no global config, and from the
# temp directory: a global config that includes itself in a circle stops every
# git command, --version included, and a repository the shell stands in adds
# its own config. macOS's /usr/bin/git without the developer tools is a stub
# that raises an install dialog when run, so it is never run.
git_bin="$(command -v git 2>/dev/null || true)"
probe=none
probe_said=""
if [ -n "$git_bin" ] && bare_shim git; then
  probe=shim
elif [ -n "$git_bin" ]; then
  probe=ok
fi
git_q() { # git_q <git config args…> — git config, deaf to every config but the file named
  (cd "$WORK" && GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "$git_bin" config "$@")
}
git_read() { # git_read <file> → true when git reads it; its entries, -z, in $WORK/list, and its first complaint in GIT_SAID
  local rc=0
  git_q -f "$1" --no-includes -z --list > "$WORK/list" 2> "$WORK/list.err" || rc=$?
  GIT_SAID="$(head -n 1 "$WORK/list.err")"
  return "$rc"
}
git_says() { # git_says <file it read> <name to give it> → git's complaint, the file written as that name
  local said="$GIT_SAID"
  case "$said" in *"$1"*) said="${said%%"$1"*}$2${said#*"$1"}" ;; esac
  printf '%s' "${said:-nothing}"
}
if [ "$probe" = ok ]; then
  git_version="$(cd "$WORK" && GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "$git_bin" --version 2>/dev/null || true)"
  if ! git_read /dev/null; then
    probe=failed; probe_said="git says: $(git_says /dev/null /dev/null)"
  fi
fi

# ── where the config comes from ──────────────────────────────────────────────
locate_sources gitconfig
if [ "$SRC" = "$WORK/src" ]; then fetch ignore; fi
for f in gitconfig ignore; do
  [ -s "$SRC/$f" ] || die "$ORIGIN/$f is missing or empty"
done
# curl -f already refuses a 404; these refuse a 200 that is not the file, and a
# foreign file beside a clone. A download cut between two lines still parses,
# so the config must end on its own last line.
[ "$(tail -n 1 "$SRC/gitconfig")" = "$OVERLAY_LAST" ] && [ "$(tail -n 2 "$SRC/gitconfig" | head -n 1)" = "[include]" ] \
  || die "$ORIGIN/gitconfig is not this config, or did not arrive whole — it must end by including ~/.gitconfig.local, which is what your own overrides ride on"
grep -qxF '.DS_Store' "$SRC/ignore" || die "$ORIGIN/ignore is not this config's global ignore"
if [ "$probe" = ok ]; then
  git_read "$SRC/gitconfig" || die "$ORIGIN/gitconfig is not a file git can read — git says: $(git_says "$SRC/gitconfig" "$ORIGIN/gitconfig")"
fi

# ── dependencies ─────────────────────────────────────────────────────────────
# Each is a line and never a refusal: the file is worth having before the
# tools it names. git alone is run, for its version and its read; delta, less
# and git-lfs are located, never run.
echo "== dependencies =="
case "$probe" in
  ok) echo "${git_version:-git} at $(short "$git_bin")" ;;
  failed)
    echo "${git_version:-git} at $(short "$git_bin")"
    echo "git's own read of your files could not run — $probe_said — so no file is checked but for a last line ending in a backslash, and ~/.gitconfig.local's includes are not read" ;;
  shim) echo "git at /usr/bin/git is macOS's stub, which asks to install the developer tools when run, so it is not run — installing anyway; git reads the file once it is there. git's own read of your files needs git, so no file is checked but for a last line ending in a backslash, and ~/.gitconfig.local's includes are not read (xcode-select --install)" ;;
  none) echo "git not on PATH — installing anyway; git reads the file once it is there. git's own read of your files needs git, so no file is checked but for a last line ending in a backslash, and ~/.gitconfig.local's includes are not read (brew install git)" ;;
esac
tool_line() { # tool_line <tool> <what goes without it> <how to install>
  local bin
  bin="$(command -v "$1" 2>/dev/null || true)"
  if [ -n "$bin" ]; then
    echo "$1 at $(short "$bin")"
  else
    echo "$1 not on PATH — $2 ($3)"
  fi
}
tool_line delta "the pager this config names falls back to less, else cat, and git add -p shows git's own colours" "brew install git-delta"
tool_line less "without delta too, the pager falls back to cat, so long output is not paged" "brew install less"
tool_line git-lfs "this config marks LFS's filter required, so in a repository whose .gitattributes routes files through LFS, git add of those files and a clone's checkout of them fail until it is installed" "brew install git-lfs"

# ── where the line goes ──────────────────────────────────────────────────────
echo
echo "== where the line goes =="
if [ "$TARGET" = "$XDG_CONF" ]; then
  echo "$(short "$XDG_CONF"): it is here and $(short "$DOT_CONF") is not"
elif there "$XDG_CONF"; then
  echo "$(short "$DOT_CONF"): both it and $(short "$XDG_CONF") are here, and git reads it second"
elif there "$DOT_CONF"; then
  echo "$(short "$DOT_CONF"): it is here and $(short "$XDG_CONF") is not"
else
  echo "$(short "$DOT_CONF"), created: neither it nor $(short "$XDG_CONF") is here"
fi
if [ "$TARGET" = "$DOT_CONF" ] && holds_line "$XDG_CONF" "$LINE"; then
  echo "$(short "$XDG_CONF") holds the line too, at line $(grep -nxF -- "$LINE" "$XDG_CONF" | head -n 1 | cut -d: -f1)"
fi

# ── what this run will touch, said before the first write ────────────────────
[ -d "$CONFIG_HOME" ] || touching "$CONFIG_HOME" "the directory configs live under, created"
[ -d "$GIT_DIR_XDG" ] || touching "$GIT_DIR_XDG" "git's config directory, created"
[ -d "$PREEN_DIR" ] || touching "$PREEN_DIR" "this config's own directory, created"
touching "$COPY" "the config"
touching "$IGNORE" "the global ignore — copied if absent"
touching_line "$TARGET" "$LINE"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
# Set at all, GIT_CONFIG_GLOBAL is the one global file git reads and writes —
# none, when empty (measured) — so a line in either of the others is not read.
if [ -n "${GIT_CONFIG_GLOBAL:-}" ]; then
  die "GIT_CONFIG_GLOBAL is '$GIT_CONFIG_GLOBAL', so git reads that file alone in place of ~/.gitconfig and ~/.config/git/config, and a line in either would not be read. Nothing was changed."
elif [ -n "${GIT_CONFIG_GLOBAL+set}" ]; then
  die "GIT_CONFIG_GLOBAL is set and empty, so git reads no global file, and a line in ~/.gitconfig or ~/.config/git/config would not be read. Nothing was changed."
fi
refuse_other_xdg "so git reads its config and ignore files under it, and this run knows only ~/.config/git"
refuse_unwritable_dir "$CONFIG_HOME"
for d in "$GIT_DIR_XDG" "$PREEN_DIR"; do refuse_linked_dir "$d"; done
for d in "$GIT_DIR_XDG" "$PREEN_DIR"; do refuse_unwritable_if_there "$d"; done

# The copy includes ~/.gitconfig.local last. Where that file is the one the
# line goes in or the copy, or includes either, the two include each other in
# a circle once the line is there, and git stops every command on it —
# measured, `exceeded maximum include depth`, rc 128. One hop: what
# ~/.gitconfig.local includes is read, not what those files include in turn.
# An include's path is taken as written but for a leading ~, ~<user> or
# %(prefix)/, which git's own --type=path expands as git does when it includes
# — an includeIf's only where its condition holds, which is not decided here;
# a relative path is read against the including file's directory. A path is the same file by inode; for one not there yet, by its
# spelling, or by its name in the same directory.
same_path() { # same_path <a> <b> → true when they name one file
  [ "$1" -ef "$2" ] || [ "$(squeeze "$1")" = "$(squeeze "$2")" ] \
    || { [ "${1##*/}" = "${2##*/}" ] && [ "$(dirname "$1")" -ef "$(dirname "$2")" ]; }
}
loops_into() { # loops_into <path> → the file of ours it names, the line's or the copy, written under ~; nothing otherwise
  if same_path "$1" "$TARGET"; then short "$TARGET"; elif same_path "$1" "$COPY"; then short "$COPY"; fi
}
refuse_local_loop() { # refuse_local_loop — stop the run when ~/.gitconfig.local is, or includes, the file the line goes in or the copy, or is not a file
  local hit key value path hops=0 rc=0
  there "$LOCAL_CONF" || return 0
  # A link is followed by name, a relative target taken against the link's own
  # directory, for a bounded number of hops: one that dangles may name the
  # file the run is about to create.
  path="$LOCAL_CONF"
  hit="$(loops_into "$path")"
  while [ -z "$hit" ] && [ -L "$path" ] && [ "$hops" -lt 40 ]; do
    value="$(readlink "$path")"
    case "$value" in /*) path="$value" ;; *) path="$(dirname "$path")/$value" ;; esac
    hit="$(loops_into "$path")"
    hops=$((hops + 1))
  done
  [ -z "$hit" ] || die "$(short "$LOCAL_CONF") is $hit, and the copy includes $(short "$LOCAL_CONF"), so with the line in $(short "$TARGET") the two would include each other in a circle, which stops git. Nothing was changed."
  # Measured: a directory there, or a cycle of links — a link still left after
  # the hops — stops every git command, rc 128.
  if [ -L "$path" ] || { [ -e "$LOCAL_CONF" ] && [ ! -f "$LOCAL_CONF" ]; }; then
    die "$(short "$LOCAL_CONF") is not a file, and the copy includes it, so git would stop every command on it. Nothing was changed."
  fi
  [ "$probe" = ok ] && [ -f "$LOCAL_CONF" ] || return 0
  git_q -f "$LOCAL_CONF" --no-includes -z --get-regexp '^include(if\..*)?\.path$' > "$WORK/local" 2> "$WORK/local.err" || rc=$?
  # rc 1 with nothing said is no include there.
  if [ "$rc" -ne 0 ] && { [ "$rc" -ne 1 ] || [ -s "$WORK/local.err" ]; }; then
    GIT_SAID="$(head -n 1 "$WORK/local.err")"
    die "git cannot read $(short "$LOCAL_CONF"), which the copy includes — git says: $(git_says "$LOCAL_CONF" "$(short "$LOCAL_CONF")"). Nothing was changed."
  fi
  while IFS= read -r value; do
    key="${value%%$'\t'*}"; value="${value#*$'\t'}"
    [ -n "$value" ] || continue
    case "$value" in
      "~"*|"%(prefix)/"*)
        if ! value="$(git_q --type=path --default "$value" --get preen.unset 2> "$WORK/local.err")"; then
          [ "$key" = include.path ] || continue
          GIT_SAID="$(head -n 1 "$WORK/local.err")"
          die "git cannot read $(short "$LOCAL_CONF"), which the copy includes — git says: $(git_says "$LOCAL_CONF" "$(short "$LOCAL_CONF")"). Nothing was changed."
        fi ;;
    esac
    case "$value" in /*) path="$value" ;; *) path="$(dirname "$LOCAL_CONF")/$value" ;; esac
    hit="$(loops_into "$path")"
    [ -z "$hit" ] || die "$(short "$LOCAL_CONF") includes $(short "$value"), which is $hit, and the copy includes $(short "$LOCAL_CONF"), so with the line in $(short "$TARGET") the two would include each other in a circle, which stops git. Remove that include from $(short "$LOCAL_CONF"). Nothing was changed."
  done <<< "$(tr '\n\000' '\t\n' < "$WORK/local")"
}
refuse_local_loop

# Without git to ask: a last line ending in an odd run of backslashes, a CR
# that ends it aside, carries the next line into it — measured, git took an
# appended line after one into the value above it. A comment's counts too,
# though git ends a comment at its newline: the text cannot tell a comment
# from a value that holds a # in quotes.
backslash_end() { # backslash_end <file> → the number of its last line when that line, one trailing CR dropped, ends in an odd run of backslashes; nothing otherwise
  awk '{ last = $0 } END { sub(/\r$/, "", last); n = 0; while (n < length(last) && substr(last, length(last) - n, 1) == "\\") n++; if (n % 2) print NR }' "$1"
}
# The line is read as an include of its own exactly when git's last entry for
# the file with it appended is include.path with the line's own path: a
# value it ended up inside of lists as that value, a section it broke stops
# git's read.
own_entry() { [ "$(tr '\n\000' '\t\n' < "$WORK/list" | tail -n 1)" = "include.path	$LINE_PATH" ]; }   # own_entry → true when $WORK/list ends on the line's own include
refuse_unread() { # refuse_unread — stop the run when git, where it can be asked, cannot read TARGET as it stands
  [ "$probe" = ok ] || return 0
  git_read "$TARGET" \
    || die "git cannot read $(short "$TARGET") as it stands — git says: $(git_says "$TARGET" "$(short "$TARGET")"). Nothing was changed."
}
refuse_target() { # refuse_target — stop the run where the line cannot go in TARGET, or git would not read it there as a line of its own
  local pending probe_conf
  # Readable, as holds_line found the line in it: read as it stands.
  if holds_line "$TARGET" "$LINE"; then refuse_unread; return 0; fi
  refuse_linked_rc "$TARGET" "$LINE"
  # git takes this lock while it rewrites the file, then renames it over the
  # file, so a line appended meanwhile would be lost. Inferred from git's
  # lockfile design, not measured: no run caught git mid-write.
  if there "$TARGET.lock"; then
    die "$(short "$TARGET.lock") is there: a git is writing $(short "$TARGET"), or one stopped while it was. Once no git is running, delete it. Nothing was changed."
  fi
  there "$TARGET" || return 0
  # Readable too: git's read and the text test read it.
  { [ -f "$TARGET" ] && [ -r "$TARGET" ] && [ -w "$TARGET" ]; } || die "$(short "$TARGET") is not a file this run can read and append to. Nothing was changed."
  [ -s "$TARGET" ] || return 0
  if [ "$probe" != ok ]; then
    pending="$(backslash_end "$TARGET")"
    [ -z "$pending" ] || die "line $pending of $(short "$TARGET") ends in a backslash, which would carry the appended line into it. Nothing was changed."
    return 0
  fi
  refuse_unread
  probe_conf="$WORK/probe.gitconfig"
  { cat "$TARGET"; [ -z "$(tail -c 1 "$TARGET")" ] || printf '\n'; printf '%s\n' "$LINE"; } > "$probe_conf"
  git_read "$probe_conf" \
    || die "git cannot read $(short "$TARGET") with the line appended — git says: $(git_says "$probe_conf" "$(short "$TARGET")"). Nothing was changed."
  own_entry \
    || die "git would read a line appended to $(short "$TARGET") as part of the line above it, not as a line of its own. Nothing was changed."
}
refuse_target

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
copy_into "$SRC/gitconfig" "$COPY"
copy_if_absent "$SRC/ignore" "$IGNORE"
# Last, so the line only ever points at a copy already on disk.
append_line_once "$TARGET" "$LINE"

echo
echo "Next: nothing to restart — git reads the line on its next command, and git config --show-origin --get pull.rebase names the file a value comes from."
