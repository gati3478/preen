#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./shell/install.sh [--dry-run]

Take this zsh and readline configuration alone.

Copies the interactive zshrc, the zshenv every zsh reads and readline's
inputrc into ~/.config/zsh/preen, and appends ONE line to each of your own
files:

  source ~/.config/zsh/preen/zshenv       to the .zshenv zsh reads
  $include ~/.config/zsh/preen/inputrc    to ~/.inputrc
  source ~/.config/zsh/preen/zshrc        to the .zshrc zsh reads

That is the whole edit to your files. Nothing in them is rewritten or removed,
and one you have not got yet becomes that line alone — but a new ~/.inputrc
first includes /etc/inputrc where there is one, because readline stops
reading that file once ~/.inputrc exists. Which .zshenv and .zshrc is zsh's
to say. A ZDOTDIR the system zshenv sets moves both, one your zshenv sets
moves the .zshrc. zsh is asked as a non-login, non-interactive shell, so it
does not see a ZDOTDIR set only in a login file or only for an interactive
shell; and ZDOTDIR is unset for the question, so one exported before zsh
starts is not followed either. Copies, never symlinks: the files become
yours to tune, and nothing here points back at this repo afterwards.
~/.hushlogin and ~/.config/atuin/config.toml are copied only where none
exists. ~/.zprofile is never touched.

  from a clone:    ./shell/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/shell/install.sh | bash

There is nothing to ask, so nothing is asked.

The appended zshrc line is a whole zshrc, read last, so it wins over every
line above it in your file — prompt, keymap, aliases, history file, options.
A line below it wins over it, and so does ~/.zshrc.local, which the copied
zshrc reads at its end. ~/.zshenv.local, read at the end of the copied
zshenv, wins over that file and not over a zshrc, which is read after it.
Those two are yours: nothing here writes them.

Nothing is overwritten without a timestamped backup beside it, and a re-run
with nothing changed rewrites nothing. Every refusal comes before the first
write: a symlinked ~/.config, ~/.config/zsh or preen/, or ~/.config/atuin
when its file would be copied, or a symlinked directory on the way to the
.zshenv or .zshrc zsh reads; a symlinked .zshrc, .zshenv or ~/.inputrc
whose target lacks its line, which belongs in the target; one of them that
lacks its line and cannot be read and appended to; a zsh file that would
carry the appended line into its last command — its last line ends in a
backslash, or its last command in &&, || or a pipe — or ends inside a
here-document, or that zsh cannot parse; and a zsh that gives no answer, or
a ZDOTDIR that is not an absolute path. A .zshrc, .zshenv or ~/.inputrc
linked into a clone of the whole setup already has this config, and the run
says so and writes nothing.

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
PIECE="shell"   # this piece's path under the mirror root
ROOT_URL="${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/main}"
SOURCE_URL="${SHELL_SOURCE:-$ROOT_URL/$PIECE}"
# SHELL_SOURCE names this piece's directory and the helper sits a level above
# it, so an override takes the root with it instead of leaving it on the mirror.
if [ -n "${SHELL_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*}"; fi

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || SELF_DIR=""; fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Beside this script in either tree — `lib/` in the mirror, `public/lib/` in the
# private one — else fetched from the root the configs come from. Never the
# directory the shell happens to be standing in.
LIB=""
candidate="$SELF_DIR/../lib/install.sh"
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
# shellcheck source=../lib/install.sh
. "$LIB"

CONFIG_HOME="$HOME/.config"
ZSH_DIR="$CONFIG_HOME/zsh"
PREEN_DIR="$ZSH_DIR/preen"
ATUIN_DIR="$CONFIG_HOME/atuin"
ATUIN_CONF="$ATUIN_DIR/config.toml"
HUSHLOGIN="$HOME/.hushlogin"
INPUTRC="$HOME/.inputrc"
SYSTEM_INPUTRC="/etc/inputrc"
ZSHENV_LINE='source ~/.config/zsh/preen/zshenv'
# shellcheck disable=SC2016  # a line for readline to read, its $ and ~ its own
INPUTRC_LINE='$include ~/.config/zsh/preen/inputrc'
SYSTEM_INPUTRC_LINE="\$include $SYSTEM_INPUTRC"
ZSHRC_LINE='source ~/.config/zsh/preen/zshrc'
# The load-bearing ends of the two zsh files: the highlighter is sourced last,
# upstream's rule, and each file's overlay is where an adopter's own lines go.
ZSHRC_LAST='unset _zsh_hl_dir'
# shellcheck disable=SC2016  # lines of zsh, matched as written
ZSHRC_OVERLAY='[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'
# shellcheck disable=SC2016
ZSHENV_LAST='[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"'
HL_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"   # the zshrc's own lookup, so a probe here finds what it will
FZF_FLOOR="0.48.0"   # `fzf --zsh` arrived here (fzf's CHANGELOG)
EZA_FLOOR="0.23.5"   # `--hyperlink=auto`, which the aliases pass, arrived here (eza's CHANGELOG)

# ── where zsh reads its zshenv and zshrc ─────────────────────────────────────
# zsh reads its zshenv from $ZDOTDIR once the system zshenv — read first, even
# under -f — sets it, and its zshrc from $ZDOTDIR once any zshenv does. So
# zsh itself is asked, twice: with -f for what the system zshenv alone
# leaves, without it for what every zshenv leaves. ZDOTDIR is unset for the
# question: the shell running this may carry one its own zshenv exported, or
# kitty's integration set. A non-login, non-interactive zsh is asked, so a
# ZDOTDIR set only by a login file, or only for an interactive shell, is not
# seen. Its own startup output is ignored; the marker line is the answer.
HOME_DIR="${HOME%/}"; [ -n "$HOME_DIR" ] || HOME_DIR=/   # a HOME given with a trailing slash names the same directory
zsh_bin="$(command -v zsh 2>/dev/null || true)"
zdotdir_after() { # zdotdir_after [-f] — set ZD to the ZDOTDIR zsh is left with after its zshenv files, or after the system one alone with -f; HOME's directory when none
  local answer
  # shellcheck disable=SC2016  # zsh expands it, not this shell
  answer="$(env -u ZDOTDIR "$zsh_bin" "$@" -c 'print -r -- "PREEN_ZDOTDIR=${ZDOTDIR:-$HOME}"' </dev/null 2>/dev/null || true)"
  answer="$(sed -n 's/^PREEN_ZDOTDIR=//p' <<< "$answer" | tail -n 1)"
  [ -n "$answer" ] || die "zsh, asked where it reads its zshenv and zshrc, printed no answer — something in its startup files stops \`zsh -c\`. Nothing was changed."
  case "$answer" in
    /) ZD="/" ;;
    /*) ZD="${answer%/}" ;;
    *) die "zsh reports ZDOTDIR=$answer, which is not an absolute path, so where it reads its zshenv and zshrc depends on the directory it starts in. Nothing was changed." ;;
  esac
}
env_dir="$HOME_DIR"
rc_dir="$HOME_DIR"
if [ -n "$zsh_bin" ]; then
  zdotdir_after -f; env_dir="$ZD"
  zdotdir_after; rc_dir="$ZD"
fi
ZSHENV="${env_dir%/}/.zshenv"
ZSHRC="${rc_dir%/}/.zshrc"

# ── a home that took the whole setup ─────────────────────────────────────────
# Decided for the run, not per file: the setup links every one of these into
# its clone, which carries this whole config already, and a line appended
# there would dirty that clone.
for f in "$ZSHRC" "$ZSHENV" "$INPUTRC"; do
  if links_into_clone "$f"; then
    echo "$(short "$f") links into a clone of the whole setup, which already carries this config. Nothing was changed."
    exit 0
  fi
done

# ── where the configs come from ──────────────────────────────────────────────
locate_sources zshrc
if [ "$SRC" = "$WORK/src" ]; then
  mkdir -p "$SRC/atuin"
  for f in zshenv inputrc atuin/config.toml; do fetch "$f"; done
fi
for f in zshrc zshenv inputrc atuin/config.toml; do
  [ -s "$SRC/$f" ] || die "$ORIGIN/$f is missing or empty"
done
# The shipped hushlogin is empty — its content is that nothing prints — and
# fetch refuses an empty file, so it is made here rather than fetched.
: > "$WORK/hushlogin"
# curl -f already refuses a 404; these refuse a 200 that is not the file, and a
# foreign file beside a clone. A download cut between two lines still parses,
# so each zsh file must end on its own last line.
{ [ "$(tail -n 1 "$SRC/zshrc")" = "$ZSHRC_LAST" ] && grep -q 'zsh-syntax-highlighting\.zsh' "$SRC/zshrc"; } \
  || die "$ORIGIN/zshrc is not this config, or did not arrive whole — it must end on the zsh-syntax-highlighting block, which has to be read last"
grep -qxF -- "$ZSHRC_OVERLAY" "$SRC/zshrc" \
  || die "$ORIGIN/zshrc is not this config — it must source ~/.zshrc.local, which is what your own overrides ride on"
[ "$(tail -n 1 "$SRC/zshenv")" = "$ZSHENV_LAST" ] \
  || die "$ORIGIN/zshenv is not this config, or did not arrive whole — it must end by sourcing ~/.zshenv.local, which is what your own overrides ride on"
grep -q '^set ' "$SRC/inputrc" || die "$ORIGIN/inputrc is not a readline config"
grep -q '^columns = \[' "$SRC/atuin/config.toml" || die "$ORIGIN/atuin/config.toml is not this atuin config, or did not arrive whole"
if [ -n "$zsh_bin" ]; then
  for f in zshrc zshenv; do
    "$zsh_bin" -n -f "$SRC/$f" </dev/null >/dev/null 2>&1 || die "$ORIGIN/$f is not a file zsh can parse"
  done
fi

# ── dependencies ─────────────────────────────────────────────────────────────
# Each is a warning and never a refusal: the files are worth having before the
# tools they name, and each tool's block in the zshrc is guarded on it. Nothing
# below is run — a tool is located and named, not executed.
echo "== dependencies =="
if [ -n "$zsh_bin" ]; then
  echo "zsh at $(short "$zsh_bin")"
else
  echo "zsh not on PATH — installing anyway; these files are read the first time zsh starts. Without it nothing can say where zsh reads its zshrc, and no zsh file is checked for a parse"
fi
hl_dir=""
for d in "$HL_PREFIX/share/zsh-syntax-highlighting" "$HOME/.zsh/zsh-syntax-highlighting"; do
  if [ -f "$d/zsh-syntax-highlighting.zsh" ]; then hl_dir="$d"; break; fi
done
if [ -n "$hl_dir" ]; then
  echo "zsh-syntax-highlighting at $(short "$hl_dir")"
else
  echo "zsh-syntax-highlighting not found in $(short "$HL_PREFIX/share") or ~/.zsh, the two places the zshrc looks — without it the command line is not coloured as you type (brew install zsh-syntax-highlighting)"
fi
if [ -f "$HL_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  echo "zsh-autosuggestions at $(short "$HL_PREFIX/share/zsh-autosuggestions")"
else
  echo "zsh-autosuggestions not found in $(short "$HL_PREFIX/share"), where the zshrc looks — without it no suggestion is drawn ahead of the cursor (brew install zsh-autosuggestions)"
fi
tool_line() { # tool_line <tool> <found note, or empty> <what goes without it> <how to install>
  local bin
  bin="$(command -v "$1" 2>/dev/null || true)"
  if [ -n "$bin" ]; then
    echo "$1 at $(short "$bin")${2:+ — $2}"
  else
    echo "$1 not on PATH — $3 ($4)"
  fi
}
tool_line starship "" "the prompt stays the one your own lines set" "brew install starship"
tool_line fzf "the zshrc runs \`fzf --zsh\`, which fzf $FZF_FLOOR added" "no ctrl+t file finder, alt+c directory jump or **<TAB> completion" "brew install fzf"
tool_line atuin "" "ctrl+r searches through fzf where it is installed, else zsh's own search, and suggestions come from zsh's history" "brew install atuin"
tool_line eza "the ls, ll and lt aliases pass --hyperlink=auto, which eza $EZA_FLOOR added" "ls, ll and lt stay what they were" "brew install eza"
tool_line fd "" "fzf walks with its own walker, which does not read .gitignore" "brew install fd"
tool_line bat "" "man pages page as they did, and fzf's ctrl+t preview has nothing to run" "brew install bat"
tool_line zoxide "" "no \`z\` to jump by frecency" "brew install zoxide"
tool_line mise "" "no per-directory node and python versions" "brew install mise"
tool_line zed "" "\$EDITOR is nano" "brew install --cask zed"

echo
echo "== where zsh reads its zshenv and zshrc =="
if [ -z "$zsh_bin" ]; then
  echo "zsh not on PATH, so nothing can say — the lines go to ~/.zshenv and ~/.zshrc, which zsh reads unless ZDOTDIR is set"
else
  if [ "$env_dir" = "$HOME_DIR" ]; then
    echo "$(short "$ZSHENV"), by zsh's own answer"
  else
    echo "$(short "$ZSHENV"), by zsh's own answer: the system zshenv sets ZDOTDIR=$(short "$env_dir"), so it never reads ~/.zshenv"
  fi
  if [ "$rc_dir" = "$HOME_DIR" ]; then
    echo "$(short "$ZSHRC"), by zsh's own answer"
  else
    echo "$(short "$ZSHRC"), by zsh's own answer: its zshenv files set ZDOTDIR=$(short "$rc_dir"), so it never reads ~/.zshrc"
  fi
fi

# ── what this run will touch, said before the first write ────────────────────
plan_line() { # plan_line <rc> <line>
  if holds_line "$1" "$2"; then
    touching "$1" "already there: $2"
  elif [ -e "$1" ] || [ -L "$1" ]; then
    touching "$1" "one line appended: $2"
  else
    touching "$1" "created: $2"
  fi
}
# readline reads /etc/inputrc only when ~/.inputrc is absent, so a new
# ~/.inputrc holding our line alone would drop it: measured on Ubuntu 24.04's
# bash 5.2, its Home and End in the \e[1~ form and its word-motion keys went
# unbound, and under the C locale eight-bit input and output went off.
# Included first, it reads as before, with ours after it winning.
inputrc_fresh=no
if [ ! -e "$INPUTRC" ] && [ ! -L "$INPUTRC" ] && [ -f "$SYSTEM_INPUTRC" ]; then inputrc_fresh=yes; fi
# atuin reads its config under this one name, so a file there wins by staying,
# and a directory that only holds one is never written under.
atuin_copy=no
if [ ! -e "$ATUIN_CONF" ] && [ ! -L "$ATUIN_CONF" ]; then atuin_copy=yes; fi

[ -d "$CONFIG_HOME" ] || touching "$CONFIG_HOME" "the directory configs live under, created"
[ -d "$ZSH_DIR" ] || touching "$ZSH_DIR" "to hold this config's own directory, created"
[ -d "$PREEN_DIR" ] || touching "$PREEN_DIR" "this config's own directory, created"
touching "$PREEN_DIR/zshrc" "the interactive shell's config"
touching "$PREEN_DIR/zshenv" "what every zsh reads first: PATH, the editor"
touching "$PREEN_DIR/inputrc" "readline's settings, for bash and the rest"
touching "$HUSHLOGIN" "silences login's Last login line — copied if absent"
if [ "$atuin_copy" = yes ] && [ ! -d "$ATUIN_DIR" ]; then touching "$ATUIN_DIR" "atuin's config directory, created"; fi
touching "$ATUIN_CONF" "atuin's settings — copied if absent"
plan_line "$ZSHENV" "$ZSHENV_LINE"
if [ "$inputrc_fresh" = yes ]; then
  touching "$INPUTRC" "created: $SYSTEM_INPUTRC_LINE, then $INPUTRC_LINE"
else
  plan_line "$INPUTRC" "$INPUTRC_LINE"
fi
plan_line "$ZSHRC" "$ZSHRC_LINE"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
refuse_unwritable_dir "$CONFIG_HOME"
for d in "$ZSH_DIR" "$PREEN_DIR"; do refuse_linked_dir "$d"; done
if [ "$atuin_copy" = yes ]; then refuse_linked_dir "$ATUIN_DIR"; fi
# The zshenv and zshrc zsh reads may sit under a ZDOTDIR: the policy holds for
# every directory between ~ and it, or for the ZDOTDIR alone outside ~.
refuse_linked_path() { # refuse_linked_path <dir> — refuse_linked_dir for each directory from ~ down to <dir>, or <dir> alone outside ~
  local d rest
  case "$1" in
    "$HOME_DIR") ;;
    "$HOME_DIR"/*)
      d="$HOME_DIR"; rest="${1#"$HOME_DIR"/}"
      while [ -n "$rest" ]; do
        d="$d/${rest%%/*}"
        case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
        refuse_linked_dir "$d"
      done ;;
    *) refuse_linked_dir "$1" ;;
  esac
}
refuse_linked_path "$env_dir"
refuse_linked_path "$rc_dir"
for d in "$ZSH_DIR" "$PREEN_DIR" "$ATUIN_DIR"; do
  [ "$d" != "$ATUIN_DIR" ] || [ "$atuin_copy" = yes ] || continue
  if [ -e "$d" ] && { [ ! -d "$d" ] || [ ! -w "$d" ]; }; then die "$(short "$d") is not a directory this run can write into. Nothing was changed."; fi
done
if [ ! -e "$HUSHLOGIN" ] && [ ! -L "$HUSHLOGIN" ] && [ ! -w "$HOME" ]; then
  die "$(short "$HOME") is not writable, so $(short "$HUSHLOGIN") cannot be created. Nothing was changed."
fi

# The text test, with zsh or without, read before zsh's own parse: an appended
# line becomes part of the file's last command when the last line ends in an
# odd run of backslashes, or when the last line that is neither blank nor a
# comment ends in &&, || or a pipe — not &|, zsh's whole background command —
# which zsh carries on past blank lines and comments. A # outside quotes at a
# word start — the line's start, or after a blank, ;, & or | — starts a
# comment, which carries nothing; not after (, where (#i) is a glob flag.
# zsh -n passes the backslash, &&, || ends alike, and each probe line below
# parses the same after &&, || as after a whole command. The quote tracking
# is a line's own, and misreads shapes such as a $'…' holding \', quotes
# nested in $(…), or a # after a blank inside ${…} or backticks. Where it
# misreads, zsh's probes below catch a backslash join, and zsh -n refuses a
# pending pipe as unparsable; a pending && or || passes them all.
pending_end() { # pending_end <file> → "<line number> <backslash|&&|…>" when a line appended to it would join its last command; nothing otherwise
  awk '
    function code(s,   i, c, q, prev, out) {
      esc = 0; q = ""; prev = " "; out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q == "\047") { if (c == "\047") q = ""; out = out c; prev = c; continue }
        if (c == "\\") { if (i == length(s)) esc = 1; out = out "__"; i++; prev = "_"; continue }
        if (q == "\"") { if (c == "\"") q = ""; out = out c; prev = c; continue }
        if (c == "\047" || c == "\"") q = c
        else if (c == "#" && prev ~ /^[ \t;&|]$/) break
        out = out c; prev = c
      }
      open = (q != "")
      sub(/[ \t]+$/, "", out)
      return out
    }
    { last = $0; if ($0 !~ /^[ \t]*(#.*)?$/) { sig = $0; at = NR } }
    END {
      code(last)
      if (esc && !open) { print NR " backslash"; exit }
      s = code(sig)
      if (at == 0 || open) exit
      if (s ~ /&&$/) print at " &&"
      else if (s ~ /\|\|$/) print at " ||"
      else if (s ~ /\|&$/) print at " |&"
      else if (s ~ /\|$/ && s !~ /&\|$/) print at " |"
    }' "$1"
}
# zsh -n parses without running anything, startup files included. It passes a
# file that ends inside a here-document, which then reads every line after it
# as text — so after it two probe lines are parsed after the file, as the
# append would leave it: one wrong only when it is read as a command at all,
# and one wrong only when it joins the line above, for a join the text test
# cannot read, such as a backslash after a $'…' string holding a \' and a #.
probe_parse() { # probe_parse <file> <probe line> → true when zsh parses the file with the line appended
  { cat "$1"; [ -z "$(tail -c 1 "$1")" ] || printf '\n'; printf '%s\n' "$2"; } > "$WORK/probe.zsh"
  "$zsh_bin" -n -f "$WORK/probe.zsh" </dev/null >/dev/null 2>&1
}
# The directories the writes below create before any rc is appended to, so a
# zshenv or zshrc that ZDOTDIR puts in one of them can be created there.
run_creates() { # run_creates <dir> → true when the run makes <dir> before its appends
  case "$1" in "$CONFIG_HOME"|"$ZSH_DIR"|"$PREEN_DIR") return 0 ;; esac
  [ "$1" = "$ATUIN_DIR" ] && [ "$atuin_copy" = yes ]
}
refuse_rc() { # refuse_rc <rc> <line> <zsh|readline>
  local f="$1" line="$2" dir pending said
  if holds_line "$f" "$line"; then return 0; fi
  refuse_linked_rc "$f" "$line"
  if [ ! -e "$f" ]; then
    dir="$(dirname "$f")"
    if [ -d "$dir" ]; then
      [ -w "$dir" ] || die "$(short "$dir") is not a directory this run can create $(basename "$f") in. Nothing was changed."
    else
      run_creates "$dir" || die "$(short "$dir") is not a directory this run can create $(basename "$f") in. Nothing was changed."
    fi
    return 0
  fi
  # Readable too: the text test and zsh's parse below read it.
  { [ -f "$f" ] && [ -r "$f" ] && [ -w "$f" ]; } || die "$(short "$f") is not a file this run can read and append to. Nothing was changed."
  [ "$3" = zsh ] && [ -s "$f" ] || return 0
  pending="$(pending_end "$f")"
  case "${pending#* }" in
    '') ;;
    backslash) die "line ${pending%% *} of $(short "$f") ends in a backslash, which would carry the appended line into it. Nothing was changed." ;;
    *) die "line ${pending%% *} of $(short "$f") ends in \`${pending#* }\`, which would carry the appended line into it. Nothing was changed." ;;
  esac
  [ -n "$zsh_bin" ] || return 0
  said="$("$zsh_bin" -n -f "$f" </dev/null 2>&1 >/dev/null)" \
    || die "zsh cannot parse $(short "$f"), so a line appended to it would never run — zsh -n says: $(head -n 1 <<< "$said"). Nothing was changed."
  if probe_parse "$f" ')'; then
    die "$(short "$f") ends inside a here-document, which would read the appended line as its text. Nothing was changed."
  fi
  if ! probe_parse "$f" 'if :; then :; fi'; then
    die "zsh would read a line appended to $(short "$f") as part of its line $(awk 'END { print NR }' "$f"), not as a command of its own. Nothing was changed."
  fi
}
refuse_rc "$ZSHENV" "$ZSHENV_LINE" zsh
refuse_rc "$INPUTRC" "$INPUTRC_LINE" readline
refuse_rc "$ZSHRC" "$ZSHRC_LINE" zsh

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
copy_into "$SRC/zshrc" "$PREEN_DIR/zshrc"
copy_into "$SRC/zshenv" "$PREEN_DIR/zshenv"
copy_into "$SRC/inputrc" "$PREEN_DIR/inputrc"
copy_if_absent "$WORK/hushlogin" "$HUSHLOGIN"
# copy_if_absent places a file, never a directory, so atuin's is made here — and
# registered in the plan above, because it is a thing this run creates.
if [ "$atuin_copy" = yes ]; then make_dir "$ATUIN_DIR"; fi
copy_if_absent "$SRC/atuin/config.toml" "$ATUIN_CONF"
# Last, so an rc only ever points at copies already on disk; the zshrc line
# after the zshenv one, which every zsh reads first.
append_line_once "$ZSHENV" "$ZSHENV_LINE"
if [ "$inputrc_fresh" = yes ]; then
  printf '%s\n%s\n' "$SYSTEM_INPUTRC_LINE" "$INPUTRC_LINE" > "$INPUTRC" || die "could not write $(short "$INPUTRC")"
  record "created         $(short "$INPUTRC")"
else
  append_line_once "$INPUTRC" "$INPUTRC_LINE"
fi
append_line_once "$ZSHRC" "$ZSHRC_LINE"

echo
echo "Next: open a new terminal tab, or run exec zsh in the one you have."
