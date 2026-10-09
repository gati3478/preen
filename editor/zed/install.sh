#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./editor/zed/install.sh [--dry-run]

Take this Zed configuration alone.

Copies the settings to ~/.config/zed/global_settings.json, a file Zed reads
under your own ~/.config/zed/settings.json, and copies keymap.json and
tasks.json into ~/.config/zed where none is there. Your settings.json is
never read or written, and it wins: a key you set there wins over ours, an
object there merges with ours key by key, and an array there replaces ours
whole. Copies, never symlinks: the files become yours to tune, and nothing
here points back at this repo afterwards.

  from a clone:    ./editor/zed/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/editor/zed/install.sh | bash

There is nothing to ask, so nothing is asked.

keymap.json and tasks.json are read by Zed from ~/.config/zed under those
names and no others, so a file of yours at one of them is left exactly as it
is and said so. Nothing else is overwritten without a timestamped backup
beside it; a symlink at global_settings.json is moved aside, never written
through; and a re-run with nothing changed rewrites nothing. Every refusal
comes before the first write; among them: a symlinked ~/.config or
~/.config/zed, or one the run can neither write into nor create; and, on
Linux and FreeBSD, an XDG_CONFIG_HOME that names a directory other than
~/.config, where Zed then reads its config. A global_settings.json linked
into a clone of the whole setup already has this config, and the run says so
and writes nothing.

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
PIECE="editor/zed"   # this piece's path under the mirror root
ROOT_URL="${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/main}"
SOURCE_URL="${ZED_SOURCE:-$ROOT_URL/$PIECE}"
# ZED_SOURCE names this piece's directory and the helper sits at the root
# above it, so an override takes the root with it instead of leaving it on the
# mirror. Two levels are stripped, because PIECE is two deep.
if [ -n "${ZED_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*/*}"; fi

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
ZED_DIR="$CONFIG_HOME/zed"
# Zed 1.23.2 reads this file under settings.json, every key of settings.json
# winning (measured; paths.rs and settings_store.rs at tag v1.23.2).
LAYER="$ZED_DIR/global_settings.json"
# Read by Zed from its config directory under these names alone, so a drop-in
# cannot layer under them: one of yours there wins by staying.
FIXED_FILES="keymap.json tasks.json"
ZED_APP="/Applications/Zed.app"
OS="$(uname -s)"

# ── a home that took the whole setup ─────────────────────────────────────────
# Its global_settings.json is a link into the setup's clone, which already
# carries this config; a copy placed there would move the setup's link aside.
if links_into_clone "$LAYER"; then
  echo "$(short "$LAYER") links into a clone of the whole setup, which already carries this config. Nothing was changed."
  exit 0
fi

# ── where the configs come from ──────────────────────────────────────────────
locate_sources settings.json
if [ "$SRC" = "$WORK/src" ]; then
  # shellcheck disable=SC2086  # FIXED_FILES is a list of names, meant to split
  for f in $FIXED_FILES; do fetch "$f"; done
fi
# shellcheck disable=SC2086
for f in settings.json $FIXED_FILES; do
  [ -s "$SRC/$f" ] || die "$ORIGIN/$f is missing or empty"
done
# curl -f already refuses a 404; these refuse a 200 that is not the file, and a
# foreign file beside a clone. A download cut between two lines still parses
# as text, so each file must end on its own closing line, and each must hold
# the line the others lean on: the keymap's bindings are chosen against the
# JetBrains base, and alt-g spawns the task labelled lazygit.
whole_with() { [ "$(tail -n 1 "$SRC/$1")" = "$2" ] && grep -qF -- "$3" "$SRC/$1"; }   # whole_with <file> <its last line> <text it holds> → true when it ends on that line and holds that text
whole_with settings.json '}' '"base_keymap": "JetBrains"' \
  || die "$ORIGIN/settings.json is not this config, or did not arrive whole — it must set base_keymap to JetBrains and end on its closing brace"
whole_with keymap.json ']' '"task_name": "lazygit"' \
  || die "$ORIGIN/keymap.json is not this keymap, or did not arrive whole — it must bind the lazygit task and end on its closing bracket"
whole_with tasks.json ']' '"label": "lazygit"' \
  || die "$ORIGIN/tasks.json is not these tasks, or did not arrive whole — it must hold the lazygit task and end on its closing bracket"

# ── dependencies ─────────────────────────────────────────────────────────────
# Each is a line and never a refusal: the files are worth having before the
# tools that read them. Nothing here runs Zed or lazygit — each is located and
# named, not executed.
echo "== dependencies =="
zed_bin=""
if [ "$OS" = Darwin ] && [ -x "$ZED_APP/Contents/MacOS/zed" ]; then
  zed_bin="$ZED_APP"
else
  zed_bin="$(command -v zed 2>/dev/null || true)"
fi
if [ -n "$zed_bin" ]; then
  echo "Zed at $(short "$zed_bin")"
elif [ "$OS" = Darwin ]; then
  echo "Zed not found, at $ZED_APP or on PATH — installing anyway; Zed reads these files when it starts (brew install --cask zed)"
else
  echo "zed not on PATH — installing anyway; Zed reads these files when it starts (https://zed.dev/download)"
fi
lazygit_bin="$(command -v lazygit 2>/dev/null || true)"
if [ -n "$lazygit_bin" ]; then
  echo "lazygit at $(short "$lazygit_bin")"
else
  echo "lazygit not on PATH — alt-g spawns the lazygit task, which runs it, so the task fails until it is there (brew install lazygit)"
fi

# ── keymap.json and tasks.json, as they stand ────────────────────────────────
# Read before the writes, so the closing says what the copy-if-absent did.
fixed_state() { # fixed_state <name> → absent, ours (the shipped bytes), setup (a link into a clone of the whole setup) or yours
  local dst="$ZED_DIR/$1"
  if ! there "$dst"; then
    echo absent
  elif links_into_clone "$dst"; then
    echo setup
  elif [ ! -L "$dst" ] && cmp -s "$SRC/$1" "$dst"; then
    echo ours
  else
    echo yours
  fi
}
keymap_state="$(fixed_state keymap.json)"
tasks_state="$(fixed_state tasks.json)"

# ── what this run will touch, said before the first write ────────────────────
[ -d "$CONFIG_HOME" ] || touching "$CONFIG_HOME" "the directory configs live under, created"
[ -d "$ZED_DIR" ] || touching "$ZED_DIR" "Zed's config directory, created"
touching "$LAYER" "the settings, read under your settings.json"
touching "$ZED_DIR/keymap.json" "the keymap — copied if absent"
touching "$ZED_DIR/tasks.json" "the tasks — copied if absent"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
# Zed takes its config directory from XDG_CONFIG_HOME on Linux and FreeBSD and
# from ~/.config on macOS whatever XDG_CONFIG_HOME says (paths.rs config_dir()
# at tag v1.23.2), so only the first are refused.
case "$OS" in
  Linux|FreeBSD) refuse_other_xdg "so Zed reads its config files under it, and this run knows only ~/.config/zed" ;;
esac
refuse_unwritable_dir "$CONFIG_HOME"
refuse_linked_dir "$ZED_DIR"
refuse_unwritable_if_there "$ZED_DIR"

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
copy_into "$SRC/settings.json" "$LAYER"
# shellcheck disable=SC2086
for f in $FIXED_FILES; do copy_if_absent "$SRC/$f" "$ZED_DIR/$f"; done

# ── what Zed reads now ───────────────────────────────────────────────────────
echo
echo "Zed reads $(short "$LAYER") under $(short "$ZED_DIR/settings.json"), which this run never reads or writes: a key you set there wins over ours, an object there merges with ours key by key, and an array there replaces ours whole."
case "$keymap_state" in
  absent|ours) echo "keymap.json: alt-g spawns the lazygit task in the centre pane, alt-z toggles soft wrap and alt-i inlay hints." ;;
  setup) echo "keymap.json: a link into a clone of the whole setup, left as it is — the setup's keymap stays in force." ;;
  yours) echo "keymap.json: yours, left as it is, so this keymap's alt-g, alt-z and alt-i are not added — they are in $ORIGIN/keymap.json, to copy into yours." ;;
esac
case "$tasks_state:$keymap_state" in
  absent:*|ours:*) echo "tasks.json: the lazygit task alt-g spawns, and the rust: and node: tasks, in Zed's task picker." ;;
  setup:*) echo "tasks.json: a link into a clone of the whole setup, left as it is — the setup's tasks stay in force." ;;
  yours:yours) echo "tasks.json: yours, left as it is — these tasks are in $ORIGIN/tasks.json, to copy into yours." ;;
  yours:*) echo "tasks.json: yours, left as it is, so alt-g spawns a task only where yours, or a project's .zed/tasks.json, has one labelled lazygit — these tasks are in $ORIGIN/tasks.json, to copy into yours." ;;
esac
echo "Next: open Zed — one already running reads global_settings.json again when it changes."
