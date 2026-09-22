# zcap: run a command in a login+interactive zsh under a PTY, isolated
# from preen capture's own caller environment, and return its cleaned
# output. Sourced by bin/preen-capture; extracted into its own file (like
# bin/lib/dump-kitty.py and bin/lib/check-floors.sh) so
# tests/test-kitty-harness.sh can exercise the real function directly.
#
# THIRD normalisation source in this capture, after kitty's memory
# addresses/set-hashing and the tmux-continuum epoch: an interactive zsh
# under a PTY whose stdin hits EOF (as it does here — nothing is typing
# into it) prints zle's own EOF-acknowledgement, `^D` followed by two
# backspaces erasing it, before any real output. Confirmed independent of
# the tty's echoctl setting (stty -echoctl before exec'ing zsh has no
# effect — zle renders this itself in raw mode, not via kernel echo) and
# independent of rc-file content (reproduces with `zsh -f`, no .zshrc at
# all). Giving it a live, non-EOF stdin does suppress it, but only by
# introducing its own noise (extra blank lines from each byte zle then
# treats as a keystroke).
#
# col -b is NOT a general "resolve N-characters-then-N-backspaces"
# filter — that undersells what it does and, more importantly, hides
# what it doesn't guarantee. col -b reconstructs each line by column
# position and discards ANY unrecognised control character or escape
# sequence outright, not just backspace-erase runs. Verified:
#   printf 'a\x1b[31mred\x1b[0m text\n' | col -b  ->  a31mred0m text
# The ESC bytes (0x1B) vanish silently and the literal text `[31m`
# survives as ordinary printable characters — not a control byte a
# downstream scan could ever catch (`col -b | grep -c '[[:cntrl:]]'`
# reports 0 on that output).
#
# It is still the right tool for the one artifact it's used for here:
# the only thing it is asked to resolve is a KNOWN, VERIFIED pattern
# (zle's EOF backspace-erase run), and no legitimate output of anything
# zcap runs (setopt, bindkey -L, alias, zstyle -L, print -l on
# $fpath/$path/${(k)widgets}, env|cut) should ever contain an ANSI
# escape sequence — a well-behaved capture has none for col -b to
# discard. But "should never" is not "structurally cannot": a zsh plugin
# hook, a prompt fragment echoed during the forced zle init, or some
# future addition to .zshrc could start emitting one, and col -b would
# then silently swallow it and hand back plausible-looking garbage with
# no signal anything was lost — precisely the failure class this whole
# capture harness exists to prevent, one layer further in. So zcap
# checks the RAW, pre-col-b output for a literal ESC byte first and
# aborts loudly if it finds one, rather than trusting col -b's silence.
# Only output that has already been verified clean of ESC bytes is
# handed to col -b to strip the actual, expected artifact.
#
# ⚠️ The PTY this makes is 0x0 WIDE: `script` copies its own stdout's window
# size, and the caller's stdout is a pipe. `isatty()` is still true, and zsh
# invents COLUMNS=80/LINES=24 inside it. Every consumer here is
# width-insensitive today, so nothing is wrong — but never probe a
# width-derived value through zcap without setting the size first, or you
# measure the fabrication. eza's `auto` modes are the worked example
# (docs/traps.md).
#
# Isolated from preen capture's own caller's environment — otherwise this
# section measures whoever ran the capture, not the shell config. Without
# `env -i`, three sections silently absorbed caller state: env-names
# picked up Claude Code's CLAUDE_* vars (7 names, confirmed to vary
# between an agent run and a plain terminal); PATH picked up 18 entries
# never added by any dotfile (17 Claude plugin bin dirs, kitty's own
# MacOS bin dir — present only because preen capture happened to be run
# from inside a real kitty session, which this harness's `script`-based
# PTY never actually goes through); FPATH picked up one more kitty
# injection plus two entries — .docker/completions and homebrew's
# site-functions — silently DUPLICATED, because the caller's inherited
# FPATH already had what .zshrc/.zprofile also explicitly prepend.
# `env -i` fixes all three at the root: PATH and FPATH end up containing
# only what .zprofile/.zshrc themselves build, with no caller residue to
# duplicate or pad them.
#
# env -i starts genuinely empty; each seeded name below was verified
# necessary, not assumed:
#   HOME, USER   - ~ expansion and .zprofile's Keychain lookups
#                  (`security find-generic-password -a "$USER"`) key on
#                  USER explicitly; unset USER silently breaks the
#                  CONTEXT7_API_KEY/EXA_API_KEY/etc exports.
#   LOGNAME      - zsh derives this from getpwuid if omitted, but it's
#                  pinned rather than relied on implicitly.
#   TERM         - changes real captured content, not just cosmetics:
#                  zsh's built-in terminal-aware bindings (delete/home/
#                  end/arrow keys — 4 lines in ### bindkey) resolve via
#                  $terminfo, keyed on TERM. Pinned to xterm-kitty — what
#                  a real kitty tab actually sets — so those bindings key
#                  the way they do in a kitty tab regardless of the
#                  terminal preen capture is invoked from.
#                  This does NOT make it a shell with kitty's shell
#                  integration loaded — that is injected by kitty's own
#                  ZDOTDIR trampoline at spawn (not by TERM) and armed by a
#                  precmd, which `-c` never fires. So the integration's
#                  additions — OSC 133/7/2 prompt-mark, cwd and title
#                  reporting, the _kitty completion, the sudo terminfo
#                  wrapper, and the alt-arrow fallback binding — are absent
#                  here, and that is the correct scope: the SSOT asserts
#                  what the MANAGED CONFIG resolves, and the integration only
#                  ADDS features that never override a managed preference
#                  (the alt-arrow fallback no-ops because .zshrc binds those
#                  keys first). See traps.md, "The live zsh probe measures
#                  the config, not the kitty-integrated shell."
#   TERMINFO     - required for TERM=xterm-kitty to resolve at all:
#                  kitty's terminfo entry ships inside kitty.app, not in
#                  any system terminfo search path.
# PATH is deliberately NOT seeded — /etc/zprofile's path_helper and
# .zprofile's own `path=(...)` rebuild it fully from system files no
# matter the starting value, and starting it genuinely empty is what
# surfaces caller leakage instead of masking it.
#
# stdin is pinned to /dev/null INSIDE the function (02-09-2026): macOS
# `script` relays its stdin into the PTY, and with a socket there — the
# Claude Code tool-shell shape — it dies with "tcgetattr/ioctl: Operation
# not supported on socket", which the 2>/dev/null below hides, leaving an
# EMPTY capture and exit 0. pref-check.py had pinned it at its own call
# site since 26-08; every other caller was one stdin away from a silent
# blank. Pinned once, here, so no caller has to know.
zcap() {
  local tmp
  tmp="$(mktemp)"
  script -q /dev/null env -i \
    HOME="$HOME" USER="$(id -un)" LOGNAME="$(id -un)" \
    TERM=xterm-kitty TERMINFO=/Applications/kitty.app/Contents/Resources/kitty/terminfo \
    zsh -l -i -c "$1" </dev/null 2>/dev/null | tr -d '\r' >| "$tmp"
  if LC_ALL=C grep -q $'\x1b' "$tmp"; then
    echo "zcap: ERROR: raw output of \`$1\` contains an ESC byte (0x1B)." >&2
    echo "zcap: col -b discards escape sequences silently instead of" >&2
    echo "zcap: reporting them - refusing to hand it plausible-looking" >&2
    echo "zcap: garbage. See the comment above zcap() in bin/lib/zcap.sh." >&2
    rm -f "$tmp"
    return 1
  fi
  col -b < "$tmp"
  rm -f "$tmp"
}
