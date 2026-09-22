#!/usr/bin/env bash
usage() { cat <<'EOF'
Take this kitty configuration alone.

Copies the config and its palette into ~/.config/kitty/preen, copies the three
files kitty insists on reading from ~/.config/kitty itself, and appends ONE
line to your own kitty.conf:

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
everything else. That file is yours too: this installer owns one line of it,
the tab title, and appends that line rather than replacing the file.

open-actions.conf, mime.types and choose-files.conf are read by kitty from
~/.config/kitty itself, under those names and no others, so a file of yours at
one of them is left exactly as it is and said so. Nothing else is overwritten
without a timestamped backup beside it, and a re-run with nothing changed
rewrites nothing. Every refusal comes before the first write.
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
# foreign file beside a clone. Both lines are load-bearing rather than
# decorative: the overlay below rides on the globinclude, and kitty.conf's
# `include current-theme.conf` resolves to a file that has to be a palette.
grep -q '^globinclude local\.conf$' "$SRC/kitty.conf" \
  || die "$ORIGIN/kitty.conf is not this config — it must end with \`globinclude local.conf\`, which is what your own overrides ride on"
grep -q '^background[[:space:]]' "$SRC/current-theme.conf" \
  || die "$ORIGIN/current-theme.conf is not a kitty colour scheme"

# ── dependencies ─────────────────────────────────────────────────────────────
# Each of the three is a warning and never a refusal: the files are worth having
# before the thing that reads them, and an adopter may install kitty, the font
# or bat after this run. Nothing below launches kitty — the binary is located
# and named, not executed.
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
# (bin/bootstrap, 14-09-2026).
echo
echo "== tab title =="
title_line=""
if [ "$HOME" = "$AUTHORED_HOME" ]; then
  echo "this is the home the tab title was authored for — no local.conf needed"
else
  title_line="$(awk -v old="$AUTHORED_HOME" -v new="$HOME" '
    /^tab_title_template / {
      out = ""; rest = $0
      while ((i = index(rest, old)) > 0) {
        out = out substr(rest, 1, i - 1) new
        rest = substr(rest, i + length(old))
      }
      print out rest
      exit
    }' "$SRC/kitty.conf")"
  if [ -n "$title_line" ]; then
    echo "tab titles collapse this home to '~', from $(short "$PREEN_DIR/local.conf")"
  else
    echo "$ORIGIN/kitty.conf has no tab_title_template line — no local.conf needed"
  fi
fi

# ── what this run will touch, said before the first write ────────────────────
[ -d "$KITTY_DIR" ] || touching "$KITTY_DIR" "kitty's config directory, created"
[ -d "$PREEN_DIR" ] || touching "$PREEN_DIR" "this config's own directory, created"
touching "$PREEN_DIR/kitty.conf" "the config"
touching "$PREEN_DIR/current-theme.conf" "the palette it includes"
if [ -n "$title_line" ]; then touching "$PREEN_DIR/local.conf" "your overrides, read last — one line of ours: the tab title for this home"; fi
touching "$KITTY_CONF" "one line appended: $INCLUDE_LINE"
touching "$KITTY_DIR/open-actions.conf" "what a click on a link does — kept if you have one"
touching "$KITTY_DIR/mime.types" "the file types behind it — kept if you have one"
touching "$KITTY_DIR/choose-files.conf" "the fp picker — kept if you have one"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
if [ -L "$CONFIG_HOME" ] && [ ! -e "$CONFIG_HOME" ]; then die "$(short "$CONFIG_HOME") is a symlink to nothing"; fi
if [ -e "$CONFIG_HOME" ]; then
  [ -d "$CONFIG_HOME" ] || die "$(short "$CONFIG_HOME") is not a directory"
  [ -w "$CONFIG_HOME" ] || die "$(short "$CONFIG_HOME") is not writable — nothing was changed"
else
  [ -w "$HOME" ] || die "$(short "$HOME") is not writable, so $(short "$CONFIG_HOME") cannot be created"
fi
# append_line_once refuses a symlink of its own accord, but it refuses at the
# END of this run, with the copies already on disk. Asking here keeps the
# promise that a stopped run has changed nothing.
# The directory, for the same reason as the file below it: a symlinked
# ~/.config/kitty is a directory something else manages, and every copy
# would land in it.
if [ -L "$KITTY_DIR" ]; then
  die "$(short "$KITTY_DIR") is a symlink to $(readlink "$KITTY_DIR") — every file here would land in that directory, which something else manages. Install into it from there, or replace the link. Nothing was changed."
fi
if [ -L "$KITTY_CONF" ]; then
  die "$(short "$KITTY_CONF") is a symlink to $(readlink "$KITTY_CONF") — appending would write into that file, which something else manages. Add \`$INCLUDE_LINE\` there instead, or replace the link. Nothing was changed."
fi
if [ -n "$title_line" ] && [ -L "$PREEN_DIR/local.conf" ]; then
  die "$(short "$PREEN_DIR/local.conf") is a symlink to $(readlink "$PREEN_DIR/local.conf") — the tab-title line would be appended into that file. Add it there yourself, or replace the link. Nothing was changed."
fi
# A kitty.conf or local.conf that cannot be written — root-owned after a sudo
# edit, or a directory — stopped the run at its last write with the copies
# already on disk (the audit of 22-09-2026 watched it). Asked here, beside the
# symlink refusals, so a stopped run has still changed nothing.
if [ -e "$KITTY_CONF" ] && { [ ! -f "$KITTY_CONF" ] || [ ! -w "$KITTY_CONF" ]; }; then
  die "$(short "$KITTY_CONF") is not a file this run can append to. Nothing was changed."
fi
if [ -n "$title_line" ] && [ -e "$PREEN_DIR/local.conf" ] && { [ ! -f "$PREEN_DIR/local.conf" ] || [ ! -w "$PREEN_DIR/local.conf" ]; }; then
  die "$(short "$PREEN_DIR/local.conf") is not a file this run can append to. Nothing was changed."
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
# local.conf is the ADOPTER's file, and this installer owns one line of it
# rather than the file: created holding that line when there is none, appended
# to when they already have their own, left exactly as it is once the line is
# there. The two copies above made preen/, which append_line_once does not do.
if [ -n "$title_line" ]; then append_line_once "$PREEN_DIR/local.conf" "$title_line"; fi
# shellcheck disable=SC2086
for f in $ROOT_FILES; do copy_if_absent "$SRC/$f" "$KITTY_DIR/$f"; done
# Last, so a kitty.conf that includes this config only ever points at files
# already on disk.
append_line_once "$KITTY_CONF" "$INCLUDE_LINE"

show_summary
echo
echo "Next: open a new kitty window, or reload the config with ctrl+cmd+, in the one you have."
