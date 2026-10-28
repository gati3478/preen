# zcap: run a command in a login+interactive zsh under a PTY, isolated from
# the caller's environment, and return its cleaned output. A file of its own
# so every caller, pref-check.py's live zsh probe among them, sources the one
# function.
#
# An interactive zsh under a PTY whose stdin hits EOF (as it does here —
# nothing is typing into it) prints zle's own EOF acknowledgement, `^D` and
# two backspaces erasing it, before any real output. zle draws it itself in
# raw mode, so neither stty -echoctl nor an empty rc file stops it. A stdin
# held open for zsh's whole run suppresses it too, but only something that
# outlives zsh can hold it (closed early, the `^D` comes back), and every
# byte sent is a keystroke to zle.
#
# col -b strips that artifact, but mangles every other escape sequence just
# as silently (`a\x1b[31mred` gives `a31mred`), so the RAW output is refused
# if it holds an ESC byte.
#
# ⚠️ The PTY this makes is 0x0 WIDE: `script` copies its own stdout's window
# size, and the caller's stdout is a pipe. `isatty()` is still true, and zsh
# invents COLUMNS=80/LINES=24 inside it, so set the size before probing any
# width-derived value through zcap, or you measure the fabrication.
#
# `env -i` isolates it from the caller: without it the probe measures whoever
# ran it — their PATH, FPATH and variables — not the shell config.
#
# env -i starts genuinely empty; each seeded name below was verified
# necessary, not assumed:
#   HOME, USER   - ~ expansion, and anything a login shell keys on USER,
#                  such as a Keychain lookup in the ~/.zprofile.local that
#                  .zprofile sources (`security find-generic-password -a
#                  "$USER"`), which breaks silently with USER unset.
#   LOGNAME      - zsh derives this from getpwuid if omitted, but it's
#                  pinned rather than relied on implicitly.
#   TERM         - changes real captured content, not just cosmetics:
#                  zsh's built-in terminal-aware bindings (delete/home/
#                  end/arrow keys) resolve via $terminfo, keyed on TERM.
#                  Pinned to xterm-kitty — what a real kitty tab actually
#                  sets — so those bindings key the way they do in a kitty
#                  tab whatever terminal the caller runs in. It does not
#                  load kitty's shell integration, which kitty injects at
#                  spawn, not by TERM. That is the correct scope: the spec
#                  asserts what the managed config resolves, and the
#                  integration only adds, never overriding a managed
#                  preference.
#   TERMINFO     - required for TERM=xterm-kitty to resolve at all:
#                  kitty's terminfo entry ships inside kitty.app, not in
#                  any system terminfo search path.
#   PATH         - what anything the Dock starts runs on, kitty included:
#                  `getconf PATH`, /usr/bin:/bin:/usr/sbin:/sbin. .zshenv runs
#                  on it before /etc/zprofile and .zprofile add to it. Left
#                  unset, zsh falls back to a compiled default with
#                  /usr/local/bin, which nothing the Dock starts has.
#
# stdin is pinned to /dev/null INSIDE the function: macOS `script` relays its
# stdin into the PTY, and with a socket there (an agent's tool shell, say) it
# dies with "tcgetattr/ioctl: Operation not supported on socket", which the
# 2>/dev/null below hides, leaving an EMPTY capture and exit 0. Pinned here so
# no caller has to know.
zcap() {
  local tmp
  tmp="$(mktemp)"
  script -q /dev/null env -i \
    HOME="$HOME" USER="$(id -un)" LOGNAME="$(id -un)" PATH="$(getconf PATH)" \
    TERM=xterm-kitty TERMINFO=/Applications/kitty.app/Contents/Resources/kitty/terminfo \
    zsh -l -i -c "$1" </dev/null 2>/dev/null | tr -d '\r' >| "$tmp"
  if LC_ALL=C grep -q $'\x1b' "$tmp"; then
    echo "zcap: ERROR: raw output of \`$1\` contains an ESC byte (0x1B)." >&2
    echo "zcap: col -b discards escape sequences silently instead of" >&2
    echo "zcap: reporting them - refusing to hand it plausible-looking" >&2
    echo "zcap: garbage. See the comment above zcap() in zcap.sh." >&2
    rm -f "$tmp"
    return 1
  fi
  col -b < "$tmp"
  rm -f "$tmp"
}
