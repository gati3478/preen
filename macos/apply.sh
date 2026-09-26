#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./macos/apply.sh [--dry-run]

Apply the macOS half of this setup: the settings System Settings owns.

Sets, for the user running it, the appearance, the Dock and its hot corners,
Finder, the trackpad, spelling correction, screenshots, the menu-bar clock,
Stage Manager and Siri. Only a setting that differs is written, and the Dock,
Finder and the menu bar restart only when one of theirs changed. Trackpad
changes take effect at the next login.

Before the first write, the values it replaces are saved as a script,
~/.local/state/preen/macos.unpreened.<time>.sh ($XDG_STATE_HOME/preen when
that is set). `sh` it to put them back. A symlinked directory on the way
there stops the run before it writes anything.

  --dry-run   list each setting that differs, from → to, and stop, having written nothing
  -h, --help  print this and exit

Refuses to run as root, and anywhere but macOS.
EOF
}
set -euo pipefail

for arg in "$@"; do case "$arg" in -h|--help) usage; exit 0 ;; esac; done
dry_run=no
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=yes ;;
    *) echo "macos/apply.sh: unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done
[ "$(uname -s)" = Darwin ] || { echo "macos/apply.sh: macOS only" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "macos/apply.sh: refusing to run as root — these are one user's settings" >&2; exit 1; }

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/preen"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/macos-apply.XXXXXX")"   # a bare `mktemp -d` ignores $TMPDIR on macOS
saved=""
finish() {
  local rc=$?
  rm -rf "$WORK"
  if [ "$rc" -ne 0 ] && [ -n "$saved" ]; then
    echo "macos/apply.sh: stopped part-way — sh $(printf '%q' "$saved") puts back what changed" >&2
  fi
}
trap finish EXIT

# ── reading a setting ────────────────────────────────────────────────────────
# A value is compared and saved as a plist XML fragment, e.g.
# <integer>40</integer>: `defaults write <domain> <key> '<fragment>'` takes it
# back with its exact type, so the restore script is a list of plain writes.
# Whole-domain exports would not do: com.apple.dock also holds the Dock's apps,
# and importing it back would undo every change made to them since.
keypath() { printf '%s' "$1" | sed 's/\./\\./g'; }   # plutil splits a key path on dots: com.apple.trackpad.scaling
fragment() { # fragment <plist file> <key> → the key's value as XML, empty when unset
  local x
  x="$(plutil -extract "$(keypath "$2")" xml1 -o - "$1" 2>/dev/null)" || return 0
  printf '%s\n' "$x" | sed '1,3d;$d'
}
live() { # live <domain> <key> → the fragment the system holds now; each domain is exported once
  local dom="$1" f
  if [ "$dom" = -g ]; then dom=NSGlobalDomain; fi
  f="$WORK/live.$dom.plist"
  [ -f "$f" ] || defaults export "$dom" - >"$f"
  fragment "$f" "$2"
}
show() { # show <fragment> → one short line for display, entities decoded: 40, true, left, a&b; (unset) when empty
  [ -n "$1" ] || { echo '(unset)'; return 0; }
  printf '%s\n' "$1" | tr -d '\t' | tr '\n' ' ' \
    | sed -E 's#^<(string|integer|real|date)>(.*)</[a-z]+> $#\2#; s#^<(true|false)/> $#\1#; s/ $//
              s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&apos;/'\''/g; s/&amp;/\&/g'
}
kind() { # kind <fragment> → its plist type: integer, real, string, boolean…
  printf '%s\n' "$1" | sed -nE '1{s#^<([a-z]+).*#\1#;s#^(true|false)$#boolean#;p;}'
}
quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }   # quote <text> → one sh word

# ── the plan ─────────────────────────────────────────────────────────────────
# The table runs twice. The plan pass records each setting that differs, with
# its plan line and its restore line; the write pass writes only those.
phase=plan
n=0
: >"$WORK/changed"
changed() { grep -qxF -e "$1 $2" "$WORK/changed"; }   # changed <domain> <key>
record() { # record <domain> <key> <old fragment> <new fragment>
  local name="$1" from to
  if [ "$1" = -g ]; then name=NSGlobalDomain; fi
  echo "$1 $2" >>"$WORK/changed"
  from="$(show "$3")" to="$(show "$4")"
  # The fragments differ, so the same text is a change of type.
  if [ "$from" = "$to" ]; then from="$from ($(kind "$3"))" to="$to ($(kind "$4"))"; fi
  echo "  $name $2: $from → $to" >>"$WORK/plan"
  if [ -n "$3" ]; then
    echo "defaults write $1 $2 $(quote "$3")" >>"$WORK/undo"
  else
    echo "defaults delete $1 $2" >>"$WORK/undo"
  fi
}
want() { # want <domain> <key> <type> <value…>, as `defaults write` takes them
  local dom="$1" key="$2" old new
  shift 2
  if [ "$phase" = write ]; then
    if changed "$dom" "$key"; then defaults write "$dom" "$key" "$@"; fi
    return 0
  fi
  n=$((n + 1))
  old="$(live "$dom" "$key")"
  defaults write "$WORK/want.$n.plist" "$key" "$@"
  new="$(fragment "$WORK/want.$n.plist" "$key")"
  if [ "$old" != "$new" ]; then record "$dom" "$key" "$old" "$new"; fi
}
unwant() { # unwant <domain> <key>: the key must not be set
  local dom="$1" key="$2" old
  if [ "$phase" = write ]; then
    if changed "$dom" "$key"; then defaults delete "$dom" "$key"; fi
    return 0
  fi
  old="$(live "$dom" "$key")"
  if [ -n "$old" ]; then record "$dom" "$key" "$old" ""; fi
}

settings() {
  local corner

  # Appearance, dark and never switching: the switching key must not say 1,
  # and unset satisfies that. The flip to dark happens live, after the writes.
  want -g AppleInterfaceStyle -string Dark
  unwant -g AppleInterfaceStyleSwitchesAutomatically

  # Dock
  want com.apple.dock orientation -string left
  want com.apple.dock tilesize -int 40
  want com.apple.dock magnification -bool false
  want com.apple.dock autohide -bool false
  want com.apple.dock mineffect -string scale
  want com.apple.dock minimize-to-application -bool false

  # Hot corners: 3 = the front app's windows, 1 = nothing
  want com.apple.dock wvous-bl-corner -int 3
  want com.apple.dock wvous-bl-modifier -int 0
  for corner in tl tr br; do
    want com.apple.dock "wvous-$corner-corner" -int 1
    want com.apple.dock "wvous-$corner-modifier" -int 0
  done

  # Finder
  want com.apple.finder AppleShowAllFiles -bool true
  want com.apple.finder ShowPathbar -bool true
  want com.apple.finder FXPreferredViewStyle -string icnv
  want com.apple.finder FXPreferredGroupBy -string Name
  want com.apple.finder FXDefaultSearchScope -string SCcf
  want com.apple.finder FXRemoveOldTrashItems -bool true

  # Trackpad
  want com.apple.AppleMultitouchTrackpad Clicking -bool false
  want com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
  want com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0
  want -g com.apple.trackpad.scaling -float 1.5

  # Text
  want -g NSAutomaticSpellingCorrectionEnabled -bool false

  # Screenshots to the clipboard, recordings to a file
  want com.apple.screencapture target -string clipboard
  want com.apple.screencapture target-screenrecording -string file

  # Menu bar clock
  want com.apple.menuextra.clock ShowDate -int 1
  want com.apple.menuextra.clock ShowDayOfWeek -bool true

  # Stage Manager off; Siri out of the menu bar and off voice
  want com.apple.WindowManager GloballyEnabled -bool false
  want com.apple.Siri StatusMenuVisible -bool false
  want com.apple.Siri VoiceTriggerUserEnabled -bool false
}
settings

restarts() { # restarts <domain> → the process to restart so its settings take effect now, if any
  case "$1" in
    com.apple.dock) echo Dock ;;
    com.apple.finder) echo Finder ;;
    com.apple.menuextra.clock|com.apple.Siri|com.apple.screencapture) echo SystemUIServer ;;
  esac
}
procs=""
while read -r dom rest; do
  p="$(restarts "$dom")"
  [ -n "$p" ] || continue
  case " $procs " in *" $p "*) ;; *) procs="${procs:+$procs }$p" ;; esac
done <"$WORK/changed"
appearance=no
if changed -g AppleInterfaceStyle || changed -g AppleInterfaceStyleSwitchesAutomatically; then appearance=yes; fi
trackpad=no
if grep -q -e '^com\.apple\.AppleMultitouchTrackpad ' -e '^-g com\.apple\.trackpad\.' "$WORK/changed"; then trackpad=yes; fi

if [ ! -s "$WORK/changed" ]; then
  echo "nothing to change — every setting already matches"
  exit 0
fi
echo "== will change =="
cat "$WORK/plan"

# ── the restore script, saved before the first write ─────────────────────────
short() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
# The checks below only read, so a dry run runs them too and refuses as the
# run would. A symlinked directory between $HOME and the restore script would
# put it wherever the link points, so the run stops instead. $HOME itself is
# not tested.
link=""
p="$STATE_DIR"
while [ "${p#"$HOME"/}" != "$p" ]; do
  if [ -L "$p" ]; then link="$p"; fi
  p="${p%/*}"
done
if [ -n "$link" ]; then
  echo "macos/apply.sh: $(short "$link") is a symlink to $(readlink "$link"), and the restore script would be written through it — nothing was written" >&2
  exit 1
fi
STAMP="$(date +%Y%m%d-%H%M%S)"
SNAP="$STATE_DIR/macos.unpreened.$STAMP.sh"
k=1
while [ -e "$SNAP" ] || [ -L "$SNAP" ]; do SNAP="$STATE_DIR/macos.unpreened.$STAMP.$k.sh"; k=$((k + 1)); done
cannot_save="macos/apply.sh: could not save the restore script at $(short "$SNAP") — nothing was written"
# The first write, mkdir -p's or the restore script's, lands in the deepest
# path on the way that exists.
p="$STATE_DIR"
while [ ! -e "$p" ] && [ ! -L "$p" ]; do
  case "$p" in */*) p="${p%/*}"; p="${p:-/}" ;; *) p=. ;; esac
done
if [ ! -d "$p" ] || [ ! -w "$p" ] || [ ! -x "$p" ]; then
  echo "$cannot_save" >&2
  exit 1
fi
if [ "$dry_run" = yes ]; then
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi
restore_script() {
  local dark=false
  if [ "$(live -g AppleInterfaceStyle)" = "<string>Dark</string>" ]; then dark=true; fi
  echo '#!/bin/sh'
  echo "# Written by macos/apply.sh on $(date '+%Y-%m-%d %H:%M'): \`sh\` it to put back what that run changed."
  if [ "$trackpad" = yes ]; then echo "# The trackpad takes its values back at the next login."; fi
  cat "$WORK/undo"
  if [ -n "$procs" ]; then echo "killall $procs"; fi
  if changed -g AppleInterfaceStyle; then
    echo "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to $dark' >/dev/null 2>&1"
  fi
}
if ! mkdir -p "$STATE_DIR" 2>/dev/null || ! (set -C; restore_script >"$SNAP") 2>/dev/null; then
  echo "$cannot_save" >&2
  exit 1
fi
saved="$SNAP"

# ── the writes ───────────────────────────────────────────────────────────────
phase="write"
settings
if [ -n "$procs" ]; then
  # shellcheck disable=SC2086  # one word per process name
  killall $procs 2>/dev/null || true
  echo "restarted $procs"
fi
# osascript flips the appearance live; the key alone waits for a login. It is a
# TCC Automation request, so it can fail — a grant denied or not yet asked for,
# a session with no GUI — and that must not stop the run. Best effort, printed
# remedy.
if [ "$appearance" = yes ]; then
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' >/dev/null 2>&1 \
    || echo "could not flip dark mode live — grant Automation to the terminal, or re-login for Dark to apply" >&2
fi
echo "applied — sh $(printf '%q' "$SNAP") puts back what changed"
if [ "$trackpad" = yes ]; then echo "trackpad changes take effect at the next login, and so does putting them back"; fi
