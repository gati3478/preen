#!/usr/bin/env bash
# Apply the macOS half of the taste — the settings System Settings owns and
# no manifest row can carry. The values are the ones docs/preferences.md
# § macOS names; preen doctor asserts them LIVE through the `defaults` targets
# in the preference spec, so drift between this file and the taste shows
# up there, never here. Idempotent. User-level only: the one root step
# (Touch ID for sudo) is printed, not run. Trackpad, language and region
# changes take effect at the next login; the Dock, Finder and the menu bar
# restart here.
set -euo pipefail

d() { defaults write "$@"; }

# Appearance. The key is what survives; osascript only saves the re-login, and
# it is a TCC Automation request, so it can fail — a grant denied or not yet
# asked for, a session with no GUI — and under `set -e` that would abort the
# script before a single setting was written. Best effort, printed remedy.
# The switching row wants the key not to say 1, and deleting it satisfies that.
d -g AppleInterfaceStyle -string Dark
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' >/dev/null 2>&1 \
  || echo "could not flip dark mode live — grant Automation to the terminal, or re-login for Dark to apply" >&2
defaults delete -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || true

# Dock
d com.apple.dock orientation -string left
d com.apple.dock tilesize -int 40
d com.apple.dock magnification -bool false
d com.apple.dock autohide -bool false
d com.apple.dock mineffect -string scale
d com.apple.dock minimize-to-application -bool false

# Hot corners: 3 = the front app's windows, 1 = nothing
d com.apple.dock wvous-bl-corner -int 3
d com.apple.dock wvous-bl-modifier -int 0
for corner in tl tr br; do
  d com.apple.dock "wvous-$corner-corner" -int 1
  d com.apple.dock "wvous-$corner-modifier" -int 0
done

# Finder
d com.apple.finder AppleShowAllFiles -bool true
d com.apple.finder ShowPathbar -bool true
d com.apple.finder FXPreferredViewStyle -string icnv
d com.apple.finder FXPreferredGroupBy -string Name
d com.apple.finder FXDefaultSearchScope -string SCcf
d com.apple.finder FXRemoveOldTrashItems -bool true

# Trackpad
d com.apple.AppleMultitouchTrackpad Clicking -bool false
d com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
d com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0
d -g com.apple.trackpad.scaling -float 1.5

# Text
d -g NSAutomaticSpellingCorrectionEnabled -bool false

# Language and region. The Georgian-QWERTY layout itself is added in
# System Settings → Keyboard → Input Sources — deliberately not written from
# here, untested either way; the rehearsal is where to try it. The doctor
# asserts it is present.
d -g AppleLanguages -array en-US ka-GE
d -g AppleLocale -string 'en_US@rg=gezzzz'

# Screenshots to the clipboard, recordings to a file
d com.apple.screencapture target -string clipboard
d com.apple.screencapture target-screenrecording -string file

# Menu bar clock
d com.apple.menuextra.clock ShowDate -int 1
d com.apple.menuextra.clock ShowDayOfWeek -bool true

# Stage Manager off; Siri out of the menu bar and off voice
d com.apple.WindowManager GloballyEnabled -bool false
d com.apple.Siri StatusMenuVisible -bool false
d com.apple.Siri VoiceTriggerUserEnabled -bool false

# Default browser (macOS asks once to confirm a change)
if command -v defaultbrowser >/dev/null 2>&1; then
  defaultbrowser firefox
else
  echo "defaultbrowser is not installed (it is in the Brewfile) — set Firefox as the default browser by hand" >&2
fi

killall Dock Finder SystemUIServer 2>/dev/null || true
echo "applied — trackpad, language and region changes take effect at the next login"
echo "root step, once, for Touch ID at sudo:"
echo "  sudo sh -c 'printf \"auth       sufficient     pam_tid.so\\n\" > /etc/pam.d/sudo_local'"
