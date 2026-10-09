#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./editor/sublime/install.sh [--dry-run]

Take this Sublime Text configuration alone.

Copies four files into a package of their own, Packages/preen, in Sublime
Text's data directory:

  macOS  ~/Library/Application Support/Sublime Text/Packages/preen
  Linux  ~/.config/sublime-text/Packages/preen

Nothing else is written. Packages/User, where Sublime, Package Control and
you keep your own settings, is never read or written. Copies, never
symlinks: the files become yours to tune, and nothing here points back at
this repo afterwards.

  from a clone:    ./editor/sublime/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/editor/sublime/install.sh | bash

There is nothing to ask, so nothing is asked.

Sublime reads this package beneath Packages/User: a key you set there wins
over the same key here, and a key whose value is an object is replaced
whole, never merged. No package is installed: the run names the two these
settings need, ayu and Terminus, found or not, and how to get one missing.

Nothing is overwritten without a timestamped backup beside it, and a re-run
with nothing changed rewrites nothing. Every refusal comes before the first
write; among them: a symlinked directory between ~ and Packages/preen, or
one that is not a directory, or that the run can neither write into nor
create; on Linux, an XDG_CONFIG_HOME that names a directory other than
~/.config; a system other than macOS or Linux. A file linked into a clone
of the whole setup already is this config, and the run leaves it as it is
and says so.

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
# otherwise fetched from the mirror exactly as the config is — same trust,
# same mechanism — and checked for its marker line before it is sourced.
PIECE="editor/sublime"   # this piece's path under the mirror root
ROOT_URL="${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/main}"
SOURCE_URL="${SUBLIME_SOURCE:-$ROOT_URL/$PIECE}"
# SUBLIME_SOURCE names this piece's directory and the helper sits at the root
# above it, so an override takes the root with it instead of leaving it on the
# mirror. Two levels are stripped, because PIECE is two deep.
if [ -n "${SUBLIME_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*/*}"; fi

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || SELF_DIR=""; fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Beside this script in either tree — `lib/` in the mirror, `public/lib/` in the
# private one — else fetched from the root the config comes from. Never the
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

# Sublime Text's data directory: on macOS the one build 4215 uses, measured;
# on Linux ~/.config/sublime-text, as Package Control 4.2.8's sys_path.py
# documents it (a comment, line 31). Whether Sublime on Linux follows
# XDG_CONFIG_HOME is not known, so one naming another directory is refused
# there; on macOS the binary's only XDG_CONFIG_HOME sits in its git code.
os="$(uname -s)"
case "$os" in
  Darwin)
    DATA_DIR="$HOME/Library/Application Support/Sublime Text"
    CHAIN=("$HOME/Library" "$HOME/Library/Application Support") ;;
  Linux)
    DATA_DIR="$HOME/.config/sublime-text"
    CHAIN=("$HOME/.config") ;;
  *) die "this run knows where Sublime Text keeps its data on macOS and Linux, and uname -s says '$os'. Nothing was changed." ;;
esac
PACKAGES="$DATA_DIR/Packages"
PREEN_DIR="$PACKAGES/preen"
# Every directory from below ~ down to the package's own, outermost first.
CHAIN+=("$DATA_DIR" "$PACKAGES" "$PREEN_DIR")
FILES=(
  "Preferences.sublime-settings"
  "gruvbox-light-hard.sublime-color-scheme"
  "Terminus.sublime-settings"
  "Terminus View.sublime-settings"
)

# ── a home that took the whole setup ─────────────────────────────────────────
# There each file is a link into the setup's clone, which already carries this
# config; a copy would move the link aside and leave a file nothing updates.
in_clone=0
for f in "${FILES[@]}"; do
  if links_into_clone "$PREEN_DIR/$f"; then in_clone=$((in_clone + 1)); fi
done
if [ "$in_clone" -eq "${#FILES[@]}" ]; then
  echo "$(short "$PREEN_DIR")'s files link into a clone of the whole setup, which already carries this config. Nothing was changed."
  exit 0
fi

# ── where the config comes from ──────────────────────────────────────────────
locate_sources "${FILES[0]}"
if [ "$SRC" = "$WORK/src" ]; then
  for f in "${FILES[@]:1}"; do
    # curl refuses a space in a URL (measured, 8.7.1), so the name is fetched
    # with it encoded, and saved under its own.
    fetch "${f// /%20}"
    if [ "$f" != "${f// /%20}" ]; then mv "$SRC/${f// /%20}" "$SRC/$f"; fi
  done
fi
for f in "${FILES[@]}"; do
  [ -s "$SRC/$f" ] || die "$ORIGIN/$f is missing or empty"
done
# curl -f already refuses a 404; these refuse a 200 that is not the file, and a
# foreign file beside a clone. Each file is one object, closed on the last line
# by a brace at its start, so a download cut between two lines ends elsewhere;
# a whole object proves nothing alone, so each must also hold a line that marks
# it as this config's.
whole_with() { [ "$(tail -n 1 "$SRC/$1")" = "$2" ] && grep -qF -- "$3" "$SRC/$1"; }   # whole_with <file> <its last line> <text it holds> → true when it ends on that line and holds that text
whole_with Preferences.sublime-settings '}' '"color_scheme": "Packages/preen/gruvbox-light-hard.sublime-color-scheme"' \
  || die "$ORIGIN/Preferences.sublime-settings is not this config, or did not arrive whole — it must name the colour scheme in Packages/preen and end on the } that closes it"
whole_with gruvbox-light-hard.sublime-color-scheme '}' '"name": "gruvbox (Light) (Hard)"' \
  || die "$ORIGIN/gruvbox-light-hard.sublime-color-scheme is not this config, or did not arrive whole — it must be the scheme named gruvbox (Light) (Hard) and end on the } that closes it"
whole_with Terminus.sublime-settings '}' '"theme": "user",' \
  || die "$ORIGIN/Terminus.sublime-settings is not this config, or did not arrive whole — it must set theme to user, which draws Terminus's panel from the palette here, and end on the } that closes it"
whole_with "Terminus View.sublime-settings" '}' '"font_face": "FiraCode Nerd Font Mono"' \
  || die "$ORIGIN/Terminus View.sublime-settings is not this config, or did not arrive whole — it must set font_face to FiraCode Nerd Font Mono and end on the } that closes it"

# ── dependencies ─────────────────────────────────────────────────────────────
# Each is a line and never a refusal: the files are worth having before the
# packages that read them. No package is installed here, and Packages/preen
# holds no Package Control list: Package Control takes the names such a list
# holds off the adopter's own list in Packages/User, and deletes those packages
# once the list is gone (Package Control 4.2.8, update_installed_packages and
# remove_orphaned_packages).
pkg_at() { # pkg_at <package> → where it is in the data directory, zipped or loose; nothing when it is not there
  local p
  for p in "$DATA_DIR/Installed Packages/$1.sublime-package" "$PACKAGES/$1"; do
    if [ -e "$p" ]; then printf '%s' "$p"; return 0; fi
  done
}
if [ -n "$(pkg_at "Package Control")" ]; then
  get="Package Control: Install Package"
else
  get="Install Package Control, then Package Control: Install Package"
fi
dep_line() { # dep_line <package> <what of this package's is its> — the package, where it is or how to get it
  local at
  at="$(pkg_at "$1")"
  if [ -n "$at" ]; then
    echo "$1 at $(short "$at")"
  else
    echo "$1 not found in $(short "$DATA_DIR") — $2 (from Sublime's command palette: $get, then $1)"
  fi
}
echo "== dependencies =="
dep_line ayu "the theme these settings name, ayu-light.sublime-theme, is ayu's"
dep_line Terminus "Terminus.sublime-settings and Terminus View.sublime-settings here are its settings"

# ── where it goes ────────────────────────────────────────────────────────────
echo
echo "== where it goes =="
case "$os" in
  Darwin) echo "$(short "$PREEN_DIR"): a package of its own, in Sublime Text's data directory on macOS" ;;
  Linux)  echo "$(short "$PREEN_DIR"): a package of its own, in Sublime Text's data directory on Linux" ;;
esac

# ── what this run will touch, said before the first write ────────────────────
what_dir() { # what_dir <dir> → what it is, for the plan
  case "$1" in
    "$PREEN_DIR") echo "this config's own package" ;;
    "$PACKAGES") echo "Sublime Text's packages directory" ;;
    "$DATA_DIR") echo "Sublime Text's data directory" ;;
    "$HOME/.config") echo "the directory configs live under" ;;
    "$HOME/Library/Application Support") echo "where applications keep their data" ;;
    *) echo "macOS's library directory" ;;
  esac
}
what_file() { # what_file <name> → what it is, for the plan
  case "$1" in
    Preferences.sublime-settings) echo "the editor's settings" ;;
    *.sublime-color-scheme) echo "the colour scheme" ;;
    "Terminus View.sublime-settings") echo "Terminus's view settings" ;;
    *) echo "Terminus's settings" ;;
  esac
}
for d in "${CHAIN[@]}"; do
  [ -d "$d" ] || touching "$d" "$(what_dir "$d"), created"
done
for f in "${FILES[@]}"; do
  if links_into_clone "$PREEN_DIR/$f"; then
    touching "$PREEN_DIR/$f" "links into a clone of the whole setup — left as it is"
  else
    touching "$PREEN_DIR/$f" "$(what_file "$f")"
  fi
done
show_plan

# ── the last refusals, before the first write ────────────────────────────────
if [ "$os" = Linux ]; then
  refuse_other_xdg "and whether Sublime Text reads its data directory under it instead is not known, while this run knows only ~/.config/sublime-text"
fi
for d in "${CHAIN[@]}"; do refuse_linked_dir "$d"; done
for d in "${CHAIN[@]}"; do
  # The first directory not there is made under the last one that is.
  if [ ! -e "$d" ]; then refuse_unwritable_dir "$d"; break; fi
  [ -d "$d" ] || die "$(short "$d") is not a directory. Nothing was changed."
  [ "$d" != "$PREEN_DIR" ] || refuse_unwritable_dir "$d"
done

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
make_dir "$PREEN_DIR"
for f in "${FILES[@]}"; do
  if links_into_clone "$PREEN_DIR/$f"; then
    record "left alone      $(short "$PREEN_DIR/$f")"
  else
    place "$SRC/$f" "$PREEN_DIR/$f"
  fi
done

echo
echo "Sublime reads this package beneath Packages/User: a key set in $(short "$PACKAGES/User") wins over the same key here, and a key whose value is an object is replaced whole, not merged."
echo "Next: start Sublime Text, which reads the package from $(short "$PREEN_DIR")."
