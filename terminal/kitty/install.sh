#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./terminal/kitty/install.sh [--dry-run]

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

There is nothing to ask, so nothing is asked.

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
rewrites nothing. Every refusal comes before the first write; among them, a
symlinked ~/.config, ~/.config/kitty or preen/ is refused, and so is a
symlinked kitty.conf whose target lacks the line, which belongs in the
target. A kitty.conf linked into a clone of the whole setup already has this
config, and the run says so and writes nothing.

  --dry-run   print what the run would touch and stop, having written nothing
  -h, --help  print this and exit
EOF
}
set -euo pipefail

# Every argument is answered before the temp directory and the helper's fetch,
# so --help and an argument error write nothing and need no network. The
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
# otherwise fetched from the mirror exactly as the configs are — same trust,
# same mechanism — and checked for its marker line before it is sourced.
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
  for f in current-theme.conf tab-title.awk $ROOT_FILES; do fetch "$f"; done
fi
# shellcheck disable=SC2086
for f in kitty.conf current-theme.conf tab-title.awk $ROOT_FILES; do
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
# The program that writes the tab title. A download cut off between two rules
# still parses, so it must end on its marker line; one cut mid-block fails to
# parse, and a file that is not this program lacks the rule local.conf is read by.
grep -q '^want == "local"' "$SRC/tab-title.awk" && awk -f "$SRC/tab-title.awk" </dev/null >/dev/null 2>&1 \
  && [ "$(tail -n 1 "$SRC/tab-title.awk")" = '# end of tab-title.awk: install.sh refuses a copy whose last line is not this one' ] \
  || die "$ORIGIN/tab-title.awk is not the program that writes the tab title, or did not arrive whole"

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
# kitty.conf's tab_title_template collapses the working directory to '~' for a
# home that is a literal, authored for one machine. The line is read out of
# kitty.conf rather than repeated here, and rewritten for this HOME by
# tab-title.awk, the program bin/bootstrap runs too; it says why it is awk.
echo
echo "== tab title =="
title_line=""
if [ "$HOME" = "$AUTHORED_HOME" ]; then
  echo "this is the home the tab title was authored for — no tab-title.conf needed"
else
  title_line="$(awk -v want=title -v authored="$AUTHORED_HOME" -f "$SRC/tab-title.awk" "$SRC/kitty.conf")"
  # local.conf, read after tab-title.conf, may set a tab title of its own:
  # tab-title.awk names its line, and the path it collapses when that is not
  # this home. Their file: named, never written.
  local_title="$(LC_ALL=C awk -v want=local -f "$SRC/tab-title.awk" "$PREEN_DIR/local.conf" 2>/dev/null)" || local_title=""
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
[ -d "$CONFIG_HOME" ] || touching "$CONFIG_HOME" "the directory configs live under, created"
[ -d "$KITTY_DIR" ] || touching "$KITTY_DIR" "kitty's config directory, created"
[ -d "$PREEN_DIR" ] || touching "$PREEN_DIR" "this config's own directory, created"
touching "$PREEN_DIR/kitty.conf" "the config"
touching "$PREEN_DIR/current-theme.conf" "the palette it includes"
if [ -n "$title_line" ]; then touching "$PREEN_DIR/tab-title.conf" "the tab title for this home — ours; local.conf stays yours"; fi
touching_line "$KITTY_CONF" "$INCLUDE_LINE"
touching "$KITTY_DIR/open-actions.conf" "what a click on a link does — copied if absent"
touching "$KITTY_DIR/mime.types" "the file types behind it — copied if absent"
touching "$KITTY_DIR/choose-files.conf" "kitty's file picker, kitten choose-files — copied if absent"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
refuse_unwritable_dir "$CONFIG_HOME"
for d in "$KITTY_DIR" "$PREEN_DIR"; do refuse_linked_dir "$d"; done
# Only a kitty.conf the run appends to is checked: one holding the line is
# never written.
if ! holds_line "$KITTY_CONF" "$INCLUDE_LINE"; then
  refuse_linked_rc "$KITTY_CONF" "$INCLUDE_LINE"
  # A kitty.conf that cannot be written — root-owned after a sudo edit, or a
  # directory — would stop the run at its last write, with the copies already
  # on disk. Asked here, beside the symlink refusals, so a stopped run has
  # changed nothing.
  if [ -e "$KITTY_CONF" ] && { [ ! -f "$KITTY_CONF" ] || [ ! -w "$KITTY_CONF" ]; }; then
    die "$(short "$KITTY_CONF") is not a file this run can append to. Nothing was changed."
  fi
fi
for d in "$KITTY_DIR" "$PREEN_DIR"; do refuse_unwritable_if_there "$d"; done

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
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

echo
echo "Next: open a new kitty window, or reload the config with ctrl+cmd+, in the one you have."
