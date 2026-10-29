#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./gh/install.sh [--dry-run]

Take this gh configuration alone.

Sets each key this config.yml gives a value to in your ~/.config/gh/config.yml
with gh config set, gh's own writer, which rewrites that key's line and keeps
your aliases and every other key, known to gh or not, in gh's own layout: it
drops your blank lines and indentation, and can drop a comment. With no
config.yml, gh first writes its own commented defaults. A key left blank here
is not set, and hosts.yml is never written.

  from a clone:    ./gh/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.4/gh/install.sh | bash

There is nothing to ask, so nothing is asked.

Your config.yml is copied to a timestamped backup beside it before the first
key is set, and a run that finds every key already set writes nothing. If gh
fails part-way, the run stops with gh's words and names the backup. Every
refusal comes before the first write; among them: gh not on PATH, on a real
run; a GH_CONFIG_DIR or XDG_CONFIG_HOME under which gh reads a config.yml
other than ~/.config/gh/config.yml; a symlink at ~/.config or ~/.config/gh,
dangling or not, or at config.yml where a key differs; any of them the run
cannot write where it must; a config.yml or hosts.yml gh itself cannot read,
in gh's words; a source file that is missing, empty, or not this config; and
a value in it that is not plain words.

  --dry-run   print what the run would touch and stop, having written nothing
              — gh need not be installed yet
  -h, --help  print this and exit

  PREEN_SOURCE  piped, a preen tree to fetch from instead of this release,
                as a URL or file://
  GH_SOURCE     piped, this piece's directory in such a tree; the rest
                comes from the tree it is in, unless PREEN_SOURCE names one
EOF
}
set -euo pipefail

# Every argument is answered before the temp directory, the helper's fetch and
# gh, so --help and an argument error write nothing and need no network. The
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
# plan, the backup rule. Beside this script in a clone; otherwise fetched from
# the mirror exactly as the config is — same trust, same mechanism — and
# checked for its marker line before it is sourced.
PIECE="gh"   # this piece's path under the mirror root
PREEN_REF=v2.2.4   # this installer's release: the tag it fetches from, and the helper's marker
# A slash ending an override would double the one joined after it, and leave
# a root taken from it a level too deep.
trim_slash() { printf '%s' "$1" | sed 's#/*$##'; }   # trim_slash <url> → it with any trailing slash dropped
ROOT_URL="$(trim_slash "${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/$PREEN_REF}")"
SOURCE_URL="$(trim_slash "${GH_SOURCE:-$ROOT_URL/$PIECE}")"
# GH_SOURCE names this piece's directory and the helper sits a level above
# it, so an override takes the root with it instead of leaving it on the mirror.
if [ -n "${GH_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*}"; fi

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || SELF_DIR=""; fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The shared library comes from this script's own tree, else from the root
# the config comes from, never the shell's directory. Its marker names its
# release; another release's may not do what this installer asks.
helper_ok() { # helper_ok <file> <where it is from> → true when it is this release's helper, false when it is no helper; stops the run on another release's
  grep -qxF "PREEN_INSTALL_LIB=$PREEN_REF" "$1" && return 0
  grep -q '^PREEN_INSTALL_LIB=' "$1" || return 1
  echo "install.sh: $2 is preen $(sed -n 's/^PREEN_INSTALL_LIB=//p' "$1") but this installer is $PREEN_REF" >&2
  exit 1
}
LIB=""
candidate="$SELF_DIR/../lib/install.sh"
if [ -f "$candidate" ] && helper_ok "$candidate" "$candidate"; then LIB="$candidate"; fi
if [ -z "$LIB" ]; then
  LIB="$WORK/lib.sh"
  curl -fsSL "$ROOT_URL/lib/install.sh" -o "$LIB" 2>/dev/null || { echo "install.sh: could not fetch $ROOT_URL/lib/install.sh" >&2; exit 1; }
  helper_ok "$LIB" "$ROOT_URL/lib/install.sh" || { echo "install.sh: $ROOT_URL/lib/install.sh is not the shared installer helper" >&2; exit 1; }
  # A download cut off past the marker line passes the check above and then
  # fails to parse — and a parse failure inside `source` is masked to exit 0 by
  # the EXIT trap, so `curl … | bash && echo installed` would print installed.
  bash -n "$LIB" 2>/dev/null || { echo "install.sh: $ROOT_URL/lib/install.sh did not arrive whole — try again" >&2; exit 1; }
fi
# shellcheck source=../lib/install.sh
. "$LIB"

CONFIG_HOME="$HOME/.config"
GH_DIR="$CONFIG_HOME/gh"
CONF="$GH_DIR/config.yml"
TAB="$(printf '\t')"

# ── where the config comes from ──────────────────────────────────────────────
locate_sources config.yml
[ -s "$SRC/config.yml" ] || die "$ORIGIN/config.yml is missing or empty"
# curl -f already refuses a 404; this refuses a 200 that is not the file, and
# a foreign file beside a clone. A download cut between two lines still
# parses, and would set fewer keys, so the file must end on its own last line.
whole_with config.yml 'telemetry: disabled' 'git_protocol: ssh' \
  || die "$ORIGIN/config.yml is not this config, or did not arrive whole — it must set git_protocol to ssh and end by turning telemetry off"

# ── the keys ─────────────────────────────────────────────────────────────────
# Each top-level `key: value` line with a value, as `key<TAB>value`. A blank
# value is gh's "refer to the environment", its default, and setting it would
# erase one of yours; version is gh's schema, not a choice; the indented
# aliases under `aliases:` are gh's own default, and are left to gh.
KEYS="$(awk '/^[A-Za-z_][A-Za-z0-9_]*:/ {
  k = $0; sub(/:.*/, "", k)
  v = $0; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
  if (k != "version" && v != "") print k "\t" v
}' "$SRC/config.yml")"
# Each value is set as written, so it must be plain words — a letter or digit,
# then letters, digits, spaces, . _ / and - — which gh reads as written; a
# comment, quotes, an anchor, a tag or a flow form it reads otherwise.
width=0
while IFS="$TAB" read -r key value; do
  case "$value" in
    [!A-Za-z0-9]*|*[!A-Za-z0-9\ ._/-]*) die "$ORIGIN/config.yml gives $key the value $(sq "$value"), and this run sets only plain words: a letter or digit, then letters, digits, spaces, . _ / and -" ;;
  esac
  [ "${#key}" -le "$width" ] || width="${#key}"
done <<< "$KEYS"
key_line() { printf "%-${width}s  %s\n" "$1" "$2"; }   # key_line <key> <what> — one line of the keys section, the keys in a column

# ── dependencies ─────────────────────────────────────────────────────────────
# gh is the writer, so a real run without it stops here; past this nothing up
# to the plan needs it, so a dry run still prints the plan. delta is located,
# never run. Every gh call has telemetry off: with it on, even gh config get
# writes a device id under ~/.local/state, which a dry run must not
# (measured, 2.102).
echo "== dependencies =="
gh_bin="$(command -v gh 2>/dev/null || true)"
gh_q() { GH_TELEMETRY=0 "$gh_bin" "$@" </dev/null; }   # gh_q <gh args…> — gh, sending nothing
if [ -z "$gh_bin" ]; then
  [ "$dry_run" = yes ] || die "gh not found — this config is written by gh's own gh config set. Install gh (brew install gh, or https://cli.github.com), then re-run this. Nothing was changed."
  echo "gh not found — a real run stops here, before any write. Install it first (brew install gh, or https://cli.github.com)"
else
  # A config gh cannot read fails --version too; its words come below.
  gh_version="$(gh_q --version 2>/dev/null | sed -n 1p || true)"
  echo "${gh_version:-gh} at $(short "$gh_bin")"
fi
delta_bin="$(command -v delta 2>/dev/null || true)"
if [ -n "$delta_bin" ]; then
  echo "delta at $(short "$delta_bin")"
else
  echo "delta not on PATH — it is this config's pager, so a paged gh command says it failed to start the pager and prints unpaged (brew install git-delta)"
fi

# ── the refusals that need no gh ─────────────────────────────────────────────
# GH_CONFIG_DIR, else XDG_CONFIG_HOME/gh, else ~/.config/gh, is the directory
# gh reads; empty, each counts as unset (measured). Past these, gh reads and
# writes ~/.config/gh.
if [ -n "${GH_CONFIG_DIR:-}" ] && [ "$(squeeze "$GH_CONFIG_DIR")" != "$(squeeze "$GH_DIR")" ]; then
  die "GH_CONFIG_DIR is '$GH_CONFIG_DIR', not $(squeeze "$GH_DIR"), so gh reads its config there, and this run knows only ~/.config/gh. Nothing was changed."
fi
[ -n "${GH_CONFIG_DIR:-}" ] || refuse_other_xdg "so gh reads its config under it, and this run knows only ~/.config/gh"
refuse_unwritable_dir "$CONFIG_HOME"
refuse_linked_dir "$GH_DIR"
refuse_unwritable_if_there "$GH_DIR"

# ── gh's own read ────────────────────────────────────────────────────────────
# Each key as gh reads it now: from config.yml, else gh's default. A
# config.yml or hosts.yml gh cannot read — bad YAML, a directory, no read
# permission — fails every gh command, rc 1, and gh's first line says why. A
# key this gh does not know is rc 1 too, "could not find key", and gh config
# set writes it all the same, with a warning.
gh_says() { # gh_says <file holding gh's stderr> → its first line, a path in gh's directory written under ~
  local said seen
  said="$(sed -n 1p "$1")"
  seen="$(squeeze "$GH_DIR")/"   # gh prints the path cleaned
  case "$said" in *"$seen"*) said="${said%%"$seen"*}$(short "$GH_DIR")/${said#*"$seen"}" ;; esac
  printf '%s' "${said:-nothing}"
}
# The keys to set, `key<TAB>value`, and the keys section; without gh, every
# key, as nothing can say which are set already.
DIFF=""
SECTION=""
if [ -z "$gh_bin" ]; then
  DIFF="$KEYS"
  while IFS="$TAB" read -r key value; do SECTION="$SECTION$(key_line "$key" "$value")
"; done <<< "$KEYS"
else
  while IFS="$TAB" read -r key value; do
    rc=0
    now="$(gh_q config get "$key" 2> "$WORK/said")" || rc=$?
    if [ "$rc" -eq 0 ] && [ "$now" = "$value" ]; then
      SECTION="$SECTION$(key_line "$key" "$value, already")
"
      continue
    fi
    if [ "$rc" -eq 0 ]; then
      SECTION="$SECTION$(key_line "$key" "${now:-(blank)} -> $value")
"
    else
      grep -q 'could not find key' "$WORK/said" \
        || die "gh cannot read its config as it stands — gh says: $(gh_says "$WORK/said"). Nothing was changed."
      SECTION="$SECTION$(key_line "$key" "(not a key this gh knows) -> $value")
"
    fi
    DIFF="$DIFF$key$TAB$value
"
  done <<< "$KEYS"
fi

# ── what this run will touch, said before the first write ────────────────────
if [ -n "$DIFF" ]; then
  [ -d "$CONFIG_HOME" ] || touching "$CONFIG_HOME" "the directory configs live under, created by gh"
  [ -d "$GH_DIR" ] || touching "$GH_DIR" "gh's config directory, created by gh"
  if there "$CONF"; then
    touching "$CONF" "backed up, then each differing key below set"
  else
    touching "$CONF" "gh's own defaults, then each differing key below set"
  fi
fi
show_plan
echo
if [ -n "$gh_bin" ]; then echo "== the keys, as gh reads them -> as this config sets them =="; else echo "== the keys this config sets =="; fi
printf '%s' "$SECTION"

if [ -z "$DIFF" ]; then
  echo
  echo "Every key already holds this config's value. Nothing was changed."
  exit 0
fi

# ── the last refusals, before the first write ────────────────────────────────
# gh writes config.yml in place, through a symlink into whatever it points at
# — a dangling one creates its target — so a link is refused where a key
# would be written, with what belongs in the file it points at.
if [ -L "$CONF" ]; then
  wanted="$(while IFS="$TAB" read -r key value; do [ -z "$key" ] || printf '%s: %s, ' "$key" "$value"; done <<< "$DIFF")"
  die "$(short "$CONF") is a symlink to $(readlink "$CONF") — gh config set would write into that file, which something else manages. Set these there instead: ${wanted%, }. Nothing was changed."
fi
if there "$CONF" && [ ! -w "$CONF" ]; then die "$(short "$CONF") is not writable. Nothing was changed."; fi

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
bak=""
if there "$CONF"; then
  bak="$(backup_name "$CONF")"
  cp -p "$CONF" "$bak" || die "could not back up $(short "$CONF")"
  record "backed up       $(short "$CONF") -> $(short "$bak")"
fi
# What gh creates on its first write — directories with its own mode, and its
# defaults where there was no file — is said once it is there.
absent=""
for p in "$CONFIG_HOME" "$GH_DIR" "$CONF"; do there "$p" || absent="$absent$p$TAB"; done
if [ -n "$bak" ]; then
  kept="$(short "$bak") is config.yml as it was before this run"
else
  kept="there was no config.yml before this run"
fi
# gh config set prints nothing, and on a terminal gh asks it for its colours
# and waits for the answer.
while IFS="$TAB" read -r key value; do
  [ -n "$key" ] || continue
  gh_q config set "$key" "$value" >/dev/null 2> "$WORK/said" \
    || die "gh config set $key $(sq "$value") failed — gh says: $(gh_says "$WORK/said"). The keys said set above are set; $kept."
  while [ -n "$absent" ]; do
    p="${absent%%"$TAB"*}"; absent="${absent#*"$TAB"}"
    if there "$p"; then record "created         $(short "$p")"; fi
  done
  if [ -s "$WORK/said" ]; then
    record "set             $key: $value — gh says: $(gh_says "$WORK/said")"
  else
    record "set             $key: $value"
  fi
done <<< "$DIFF"

echo
echo "Next: nothing to restart — gh reads config.yml on its next command, and gh config get <key> prints what it reads."
