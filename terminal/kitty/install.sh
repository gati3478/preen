#!/usr/bin/env bash
usage() { cat <<'EOF'
Take this kitty configuration alone.

Copies the config, its palette and the tab title for your home into
~/.config/kitty/preen, copies the files kitty insists on reading from
~/.config/kitty itself, and appends ONE line to your own kitty.conf:

  include preen/kitty.conf

That is the whole edit to your file. Nothing in it is rewritten or removed, and
if you have no kitty.conf yet it becomes that line alone. Copies, never
symlinks: the files become yours to tune, and nothing here points back at this
repo afterwards.

  from a clone:    ./terminal/kitty/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/terminal/kitty/install.sh | bash

There is nothing to ask, so nothing is asked. Two flags:
  --dry-run   print what the run would touch and stop, having written nothing
  --help      this

kitty reads includes last-wins, so the appended line beats everything above it
in your kitty.conf. Keep a line of your own by moving it BELOW that line, or
into ~/.config/kitty/preen/local.conf, which this config reads after
everything else. That file is yours: nothing here writes it. A tab title in
it wins over ours; a run names its line, with the path it collapses when that
is not your home. tab-title.conf beside it is this installer's: a run
replaces its one line with no backup, and anything else there is backed up
first.

open-actions.conf, mime.types and choose-files.conf are read by kitty from
~/.config/kitty itself, under those names and no others, so a file of yours at
one of them is left exactly as it is and said so. Nothing else is overwritten
without a timestamped backup beside it, and a re-run with nothing changed
rewrites nothing. Every refusal comes before the first write: a symlinked
~/.config, ~/.config/kitty or preen/ is refused, and so is a symlinked
kitty.conf, whose target should carry the line instead. A kitty.conf linked
into a clone of the whole setup already has this config, and the run says so
and writes nothing.
EOF
}
set -euo pipefail

# --help answers with no network, so it is read before the helper is fetched.
for arg in "$@"; do case "$arg" in -h|--help) usage; exit 0 ;; esac; done

# ── the shared helper ────────────────────────────────────────────────────────
# The generic half of every drop-in installer here: the source resolution, the
# plan and summary lists, the copies and their backup rule. Beside this script
# in a clone; otherwise fetched from the mirror exactly as the configs are —
# same trust, same mechanism — and checked for its marker line before it is
# sourced.
PIECE="terminal/kitty"   # this piece's path under the mirror root
ROOT_URL="${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/main}"
SOURCE_URL="${KITTY_SOURCE:-$ROOT_URL/$PIECE}"
# KITTY_SOURCE names this piece's directory and the helper sits at the root
# above it, so an override takes the root with it instead of leaving it on the
# mirror. Two levels are stripped here where prompt/'s installer strips one,
# because PIECE is two deep.
if [ -n "${KITTY_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*/*}"; fi

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || SELF_DIR=""; fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Beside this script in either tree — `lib/` in the mirror, `public/lib/` in the
# private one — else fetched from the root the configs come from. Never the
# directory the shell happens to be standing in.
LIB=""
candidate="$SELF_DIR/../../lib/install.sh"
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
# shellcheck source=../../lib/install.sh
. "$LIB"

CONFIG_HOME="$HOME/.config"
KITTY_DIR="$CONFIG_HOME/kitty"
PREEN_DIR="$KITTY_DIR/preen"
KITTY_CONF="$KITTY_DIR/kitty.conf"
INCLUDE_LINE="include preen/kitty.conf"
# Read by kitty from the config directory ROOT under these exact names —
# measured for open-actions.conf, a bytecode constant for mime.types, the
# kitten's documented path for choose-files.conf. A drop-in cannot layer under
# a fixed name, so one of yours there wins by staying.
ROOT_FILES="open-actions.conf mime.types choose-files.conf"
KITTY_APP="/Applications/kitty.app/Contents/MacOS/kitty"
FONT_FILE_PREFIX="FiraCodeNerdFontMono"   # how the cask names the files
FONT_NAME="FiraCode Nerd Font Mono"       # how kitty.conf asks for it
FONT_CASK="font-fira-code-nerd-font"
# The home the shipped tab title collapses to '~'. bin/bootstrap carries the
# same constant for the same line; kitty expands no variable in that option.
AUTHORED_HOME="/Users/gati3478"

dry_run=no
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=yes ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done

# ── a home that took the whole setup ─────────────────────────────────────────
# Its kitty.conf is a link into the setup's clone, which already carries this
# config; the include line appended there would dirty that clone.
if links_into_clone "$KITTY_CONF"; then
  echo "$(short "$KITTY_CONF") links into a clone of the whole setup, which already carries this config. Nothing was changed."
  exit 0
fi

# ── where the configs come from ──────────────────────────────────────────────
locate_sources kitty.conf
if [ "$SRC" = "$WORK/src" ]; then
  # shellcheck disable=SC2086  # ROOT_FILES is a list of names, meant to split
  for f in current-theme.conf $ROOT_FILES; do fetch "$f"; done
fi
# shellcheck disable=SC2086
for f in kitty.conf current-theme.conf $ROOT_FILES; do
  [ -s "$SRC/$f" ] || die "$ORIGIN/$f is missing or empty"
done
# curl -f already refuses a 404; these refuse a 200 that is not the file, and a
# foreign file beside a clone. Each line is load-bearing rather than
# decorative: the tab title and the overlay ride on the globincludes, and
# kitty.conf's `include current-theme.conf` resolves to a file that has to be a
# palette.
grep -q '^globinclude tab-title\.conf$' "$SRC/kitty.conf" \
  || die "$ORIGIN/kitty.conf is not this config — it must end with \`globinclude tab-title.conf\`, which is what the tab title for your home rides on"
grep -q '^globinclude local\.conf$' "$SRC/kitty.conf" \
  || die "$ORIGIN/kitty.conf is not this config — it must end with \`globinclude local.conf\`, which is what your own overrides ride on"
grep -q '^background[[:space:]]' "$SRC/current-theme.conf" \
  || die "$ORIGIN/current-theme.conf is not a kitty colour scheme"

# ── dependencies ─────────────────────────────────────────────────────────────
# Each is a warning and never a refusal: the files are worth having before the
# thing that reads them, and an adopter may install kitty, the font, bat or Zed
# after this run. Nothing below launches kitty — the binary is located and
# named, not executed.
echo "== dependencies =="
kitty_bin=""
if [ -x "$KITTY_APP" ]; then
  kitty_bin="$KITTY_APP"
else
  kitty_bin="$(command -v kitty 2>/dev/null || true)"
fi
if [ -n "$kitty_bin" ]; then
  echo "kitty at $(short "$kitty_bin")"
else
  echo "kitty not found, at $KITTY_APP or on PATH — installing anyway; these files are read the first time kitty starts (brew install --cask kitty)"
fi

font_file=""
for dir in "$HOME/Library/Fonts" /Library/Fonts; do
  [ -d "$dir" ] || continue
  for f in "$dir/$FONT_FILE_PREFIX"*; do
    if [ -e "$f" ]; then font_file="$f"; break; fi
  done
  [ -z "$font_file" ] || break
done
if [ -n "$font_file" ]; then
  echo "$FONT_NAME at $(short "$(dirname "$font_file")")"
else
  echo "$FONT_NAME not found in $(short "$HOME/Library/Fonts") or /Library/Fonts — without it kitty falls back to its own monospace face, and the ligatures, the slashed zero and the oldstyle figures this config asks for are not there (brew install --cask $FONT_CASK)"
fi

bat_bin="$(command -v bat 2>/dev/null || true)"
if [ -n "$bat_bin" ]; then
  echo "bat at $(short "$bat_bin")"
else
  echo "bat not on PATH — this config pages the scrollback through it, so until bat is there the scrollback pager opens on nothing (brew install bat)"
fi

zed_bin="$(command -v zed 2>/dev/null || true)"
if [ -n "$zed_bin" ]; then
  echo "zed at $(short "$zed_bin")"
else
  echo "zed not on PATH — open-actions.conf launches it when you click a file path, so a click does nothing until it is there, or until you put your editor's name in that file (brew install --cask zed)"
fi

# ── the tab title ────────────────────────────────────────────────────────────
# kitty.conf's tab_title_template collapses the working directory to '~' with a
# Python .replace() inside kitty's own config language, which expands no
# environment variable in that option — so the home is a literal, authored for
# one machine. The line is read out of kitty.conf rather than repeated here,
# and rewritten with awk's index/substr, which match no pattern at all:
# `sed "s|$AUTHORED_HOME|$HOME|"` built its expression out of $HOME, so a `|`
# in it became a different command and an `&` became the whole match, silently
# (bin/bootstrap, 14-09-2026). HOME is read from ENVIRON: `awk -v` turns a `\t`
# in it into a tab. kitty compiles the title as a Python f-string, where `\t` is
# a tab too, so each backslash is written doubled.
echo
echo "== tab title =="
title_line=""
if [ "$HOME" = "$AUTHORED_HOME" ]; then
  echo "this is the home the tab title was authored for — no tab-title.conf needed"
else
  title_line="$(awk -v old="$AUTHORED_HOME" '
    /^tab_title_template / {
      lit = ""; r = ENVIRON["HOME"]
      while ((k = index(r, "\\")) > 0) {
        lit = lit substr(r, 1, k - 1) "\\\\"
        r = substr(r, k + 1)
      }
      lit = lit r
      out = ""; rest = $0
      while ((i = index(rest, old)) > 0) {
        out = out substr(rest, 1, i - 1) lit
        rest = substr(rest, i + length(old))
      }
      print out rest
      exit
    }' "$SRC/kitty.conf")"
  # local.conf is read after tab-title.conf. Of its tab_title_template lines,
  # awk takes the last with a value and prints its line number and, when it is
  # `active_wd.replace('<path>', '~')` for a path other than this home, that
  # path. Their file: named, never written. bin/bootstrap reads its local.conf
  # by the same rule. A line has a value when kitty's whitespace follows the
  # key — spaces, tabs, \v, \f, \x1c-\x1f; it ends a line at a lone \r — and
  # then a byte that is not whitespace. kitty also counts multibyte spaces as
  # whitespace; a line led or split by one, or with one for its value, is not
  # modelled. LC_ALL=C: under a UTF-8 locale, macOS awk stops at a byte that
  # is not UTF-8.
  local_title="$(LC_ALL=C awk '
    /^[[:space:]\034-\037]*tab_title_template[ \t\v\f\034-\037]+[^[:space:]\034-\037]/ { n = NR; t = $0 }
    END {
      if (!n) exit
      p = ""; i = index(t, "active_wd.replace(")
      if (i) {
        s = substr(t, i + 18); q = substr(s, 1, 1); s = substr(s, 2); j = index(s, q)
        if ((q == "\"" || q == "'\''") && j && substr(s, 1, j - 1) != ENVIRON["HOME"] && substr(s, j + 1) ~ /^, *.~.\)/) p = substr(s, 1, j - 1)
      }
      print n, p
    }' "$PREEN_DIR/local.conf" 2>/dev/null)" || local_title=""
  local_line="${local_title%% *}"; local_path="${local_title#* }"
  # Said before the refusals and the write, so it is what a run writes, never
  # what the file holds.
  if [ -z "$title_line" ]; then
    echo "$ORIGIN/kitty.conf has no tab_title_template line — no tab-title.conf needed"
  elif [ -n "$local_path" ]; then
    echo "$(short "$PREEN_DIR/local.conf") line $local_line, read after tab-title.conf, sets a tab title that collapses $local_path"
  elif [ -n "$local_title" ]; then
    echo "$(short "$PREEN_DIR/local.conf") line $local_line, read after tab-title.conf, sets a tab title"
  else
    home_lit="${HOME//\\/\\\\}"
    case "$title_line" in
      *"'$home_lit'"*|*"\"$home_lit\""*) echo "the tab title a run writes to $(short "$PREEN_DIR/tab-title.conf") collapses this home to '~'" ;;
      *) echo "the tab title a run writes to $(short "$PREEN_DIR/tab-title.conf") does not collapse this home" ;;
    esac
  fi
fi

# ── what this run will touch, said before the first write ────────────────────
[ -d "$KITTY_DIR" ] || touching "$KITTY_DIR" "kitty's config directory, created"
[ -d "$PREEN_DIR" ] || touching "$PREEN_DIR" "this config's own directory, created"
touching "$PREEN_DIR/kitty.conf" "the config"
touching "$PREEN_DIR/current-theme.conf" "the palette it includes"
if [ -n "$title_line" ]; then touching "$PREEN_DIR/tab-title.conf" "the tab title for this home — ours; local.conf stays yours"; fi
touching "$KITTY_CONF" "one line appended: $INCLUDE_LINE"
touching "$KITTY_DIR/open-actions.conf" "what a click on a link does — kept if you have one"
touching "$KITTY_DIR/mime.types" "the file types behind it — kept if you have one"
touching "$KITTY_DIR/choose-files.conf" "the fp picker — kept if you have one"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
for d in "$CONFIG_HOME" "$KITTY_DIR" "$PREEN_DIR"; do refuse_linked_dir "$d"; done
if [ -e "$CONFIG_HOME" ]; then
  [ -d "$CONFIG_HOME" ] || die "$(short "$CONFIG_HOME") is not a directory"
  [ -w "$CONFIG_HOME" ] || die "$(short "$CONFIG_HOME") is not writable — nothing was changed"
else
  [ -w "$HOME" ] || die "$(short "$HOME") is not writable, so $(short "$CONFIG_HOME") cannot be created"
fi
# append_line_once refuses a symlink of its own accord, but it refuses at the
# END of this run, with the copies already on disk. Asking here keeps the
# promise that a stopped run has changed nothing.
if [ -L "$KITTY_CONF" ]; then
  die "$(short "$KITTY_CONF") is a symlink to $(readlink "$KITTY_CONF") — appending would write into that file, which something else manages. Add \`$INCLUDE_LINE\` there instead, or replace the link. Nothing was changed."
fi
# A kitty.conf that cannot be written — root-owned after a sudo edit, or a
# directory — would stop the run at its last write, with the copies already on
# disk. Asked here, beside the symlink refusals, so a stopped run has changed
# nothing.
if [ -e "$KITTY_CONF" ] && { [ ! -f "$KITTY_CONF" ] || [ ! -w "$KITTY_CONF" ]; }; then
  die "$(short "$KITTY_CONF") is not a file this run can append to. Nothing was changed."
fi
for d in "$KITTY_DIR" "$PREEN_DIR"; do
  if [ -e "$d" ] && { [ ! -d "$d" ] || [ ! -w "$d" ]; }; then die "$(short "$d") is not a directory this run can write into. Nothing was changed."; fi
done

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
# copy_if_absent places a file, never a directory, so the config directory is
# made here — and registered in the plan above, because it is a thing this run
# creates.
if [ ! -d "$KITTY_DIR" ]; then
  mkdir -p "$KITTY_DIR" || die "could not create $(short "$KITTY_DIR")"
  record "created         $(short "$KITTY_DIR")"
fi
copy_into "$SRC/kitty.conf" "$PREEN_DIR/kitty.conf"
copy_into "$SRC/current-theme.conf" "$PREEN_DIR/current-theme.conf"
# tab-title.conf is this installer's, written whole, so the line kitty reads
# always names this HOME. local.conf, read after it, is the adopter's, and a
# tab title of theirs there wins. A plain file of one tab_title_template line
# is this installer's own, for another home or an older kitty.conf: replaced
# with no backup, which the doctor would otherwise warn about on every run
# after. Anything else there is backed up by copy_into.
if [ -n "$title_line" ]; then
  printf '%s\n' "$title_line" > "$WORK/tab-title.conf"
  title_conf="$PREEN_DIR/tab-title.conf"
  if [ ! -L "$title_conf" ] && [ -f "$title_conf" ] && ! cmp -s "$WORK/tab-title.conf" "$title_conf" \
    && awk 'NR == 1 { ok = /^tab_title_template / } END { exit !(NR == 1 && ok) }' "$title_conf" 2>/dev/null; then
    rm -f "$title_conf" || die "could not replace $(short "$title_conf")"
  fi
  copy_into "$WORK/tab-title.conf" "$title_conf"
fi
# shellcheck disable=SC2086
for f in $ROOT_FILES; do copy_if_absent "$SRC/$f" "$KITTY_DIR/$f"; done
# Last, so a kitty.conf that includes this config only ever points at files
# already on disk.
append_line_once "$KITTY_CONF" "$INCLUDE_LINE"

show_summary
echo
echo "Next: open a new kitty window, or reload the config with ctrl+cmd+, in the one you have."
