#!/usr/bin/env bash
usage() { cat <<'EOF'
Take this statusline alone.

Copies cship.toml — and starship.toml if you say so — into ~/.config, wires
cship into ~/.claude/settings.json, and prints what it did and what it left
alone. Copies, never symlinks: the files become yours to tune, and nothing
here points back at this repo afterwards.

  from a clone:    ./prompt/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/prompt/install.sh | bash -s -- [flags]

It asks two questions when it has a terminal to ask on. Each flag answers
one; with both answered it asks nothing, and with no terminal it takes the
defaults — starship.toml left alone, the account module hidden:
  --with-starship | --no-starship       take starship.toml too — this REPLACES
                                        your shell prompt, not only line 1
  --account-label NAME | --no-account   what line 2 calls your account, or
                                        hide the module in your copy

--dry-run prints what the run would touch and stops, having written nothing.

Nothing is overwritten without a timestamped backup beside it. A statusLine
entry that runs anything but cship is left alone. A re-run with nothing
changed rewrites nothing. Every refusal comes before the first write.
Refuses to run as root.
EOF
}
set -euo pipefail

# --help answers with no network, so it is read before the helper is fetched.
for arg in "$@"; do case "$arg" in -h|--help) usage; exit 0 ;; esac; done

# ── the shared helper ────────────────────────────────────────────────────────
# The generic half of every drop-in installer here: the questions, the source
# resolution, the copies and their backup rule. Beside this script in a clone;
# otherwise fetched from the mirror exactly as the configs are — same trust,
# same mechanism — and checked for its marker line before it is sourced.
PIECE="prompt"   # this piece's path under the mirror root
ROOT_URL="${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/main}"
SOURCE_URL="${PROMPT_SOURCE:-$ROOT_URL/$PIECE}"
# PROMPT_SOURCE names this piece's directory and the helper sits a level above
# it, so an override takes the root with it instead of leaving it on the mirror.
if [ -n "${PROMPT_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*}"; fi

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

CSHIP_FLOOR="1.8.2"   # per-window usage tokens and CSHIP_ACCOUNT arrived here
REFRESH_SECONDS=60    # re-render on a timer, so the clock and windows move while idle
CONFIG_DIR="$HOME/.config"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"   # Claude Code's own override for where settings.json lives
SETTINGS="$CLAUDE_DIR/settings.json"

with_starship=""
account_mode=""
account_label=""
dry_run=no
while [ $# -gt 0 ]; do
  case "$1" in
    --with-starship) with_starship=yes ;;
    --no-starship)   with_starship=no ;;
    --no-account)    account_mode=hide ;;
    --dry-run)       dry_run=yes ;;
    --account-label)
      # `-*`, not `--*`: the guard exists to catch a forgotten name followed
      # by a flag, and reading only long flags let `--account-label -x` take
      # `-x` as the label. A label that genuinely starts with a dash is the
      # price, and nobody has one.
      case "${2:-}" in ''|-*) die "--account-label needs a name after it (or say --no-account)" ;; esac
      shift
      account_label="$1"
      account_mode=label
      ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
  shift
done
[ "$(id -u)" -eq 0 ] && die "refusing to run as root — this installs user files"

# The label lands inside a JSON string inside a shell command line. Letters,
# digits, space, dot, underscore, dash — at least one not a space — and
# nothing else: byte-wise, so a newline or a non-ASCII letter is refused too.
label_ok() {
  [ -n "${1// /}" ] && [ "$(printf '%s' "$1" | LC_ALL=C tr -d 'A-Za-z0-9._ -' | wc -c)" -eq 0 ]
}
if [ "$account_mode" = label ] && ! label_ok "$account_label"; then
  die "--account-label: a name of letters, digits, space, '.', '_', '-' (or say --no-account)"
fi

# ── where the configs come from ──────────────────────────────────────────────
locate_sources cship.toml
# curl -f already refuses a 404; this refuses a 200 that is not the file, and
# an empty or foreign file beside a clone.
{ [ -s "$SRC/cship.toml" ] && grep -q '^\[cship\]' "$SRC/cship.toml"; } || die "$ORIGIN/cship.toml is not a cship config"

# ── dependencies ─────────────────────────────────────────────────────────────
echo "== dependencies =="
cship_bin="$(command -v cship 2>/dev/null || true)"
# cship's installer puts it in ~/.local/bin, cargo in ~/.cargo/bin; neither
# need be on PATH for the statusline, which is wired by absolute path below.
for candidate in "$HOME/.local/bin/cship" "$HOME/.cargo/bin/cship"; do
  if [ -z "$cship_bin" ] && [ -x "$candidate" ]; then cship_bin="$candidate"; fi
done
if [ -z "$cship_bin" ]; then
  die "cship not found. Install it first, either way, then re-run this:
  curl -fsSL https://cship.dev/install.sh | bash     # binary + a starter config + statusLine wiring
  cargo install cship                                 # binary only"
fi
case "$cship_bin" in /*) ;; *) cship_bin="$(cd "$(dirname "$cship_bin")" && pwd)/${cship_bin##*/}" ;; esac   # a relative PATH entry
cship_version="$("$cship_bin" --version 2>/dev/null | awk '{ print $2 }')"
# cship prints a bare `1.8.3` today. If upstream ever tags with a `v`, the
# comparison below would sort `v1.9.0` under `1.8.2` and refuse every
# install — telling an adopter their NEWER cship is too old.
cship_version="${cship_version#v}"
if [ -z "$cship_version" ] || ! version_ge "$cship_version" "$CSHIP_FLOOR"; then
  die "cship $cship_version at $cship_bin — this config needs $CSHIP_FLOOR or newer"
fi
echo "cship $cship_version at $(short "$cship_bin")"

# starship 1.26 creates ~/.cache/starship on any invocation, --version
# included, and a dry run had promised to leave the home alone (the audit of
# 22-09-2026). Its cache goes to this run's temp directory, gone on exit.
export STARSHIP_CACHE="$WORK/starship-cache"
starship_bin="$(command -v starship 2>/dev/null || true)"
if [ -n "$starship_bin" ]; then
  echo "starship $("$starship_bin" --version 2>/dev/null | head -1 | awk '{ print $2 }') at $(short "$starship_bin")"
else
  echo "starship not on PATH — line 1 of the statusline stays absent until it is; lines 2 and 3 render regardless"
fi

# ── settings.json, probed before anything is written ─────────────────────────
# Apple's python3 caches the bytecode of every module it imports under
# ~/Library/Caches/com.apple.python, so the probe below left thirty-odd files
# in a home the dry run had promised to leave alone (found by
# tests/test-readme.sh, 22-09-2026). Off, for every python this script runs.
export PYTHONDONTWRITEBYTECODE=1
# python3 is probed by running it: on a Mac without the Command Line Tools,
# /usr/bin/python3 is a stub that exists, so `command -v` alone would say yes
# and the first real call would abort.
python3_bin="$(command -v python3 2>/dev/null || true)"
if [ -n "$python3_bin" ] && ! "$python3_bin" -c 'import json' >/dev/null 2>&1; then python3_bin=""; fi
if [ -e "$CLAUDE_DIR" ] && [ ! -d "$CLAUDE_DIR" ]; then die "$(short "$CLAUDE_DIR") is not a directory"; fi
if [ -L "$SETTINGS" ] && [ ! -e "$SETTINGS" ]; then die "$(short "$SETTINGS") is a symlink to nothing — fix it, then re-run; nothing was changed"; fi
if [ -d "$SETTINGS" ]; then die "$(short "$SETTINGS") is a directory"; fi
# States: nodir (no Claude Code yet) · nopython · absent (no file, or no
# statusLine in it) · cship (any entry that runs cship — its installer's bare
# `cship`, or a lone cship path with at most a CSHIP_ACCOUNT prefix, this
# script's own included — which is taken over) · other (anything else runs
# there: left alone).
existing_command=""
existing_refresh=""
if [ ! -d "$CLAUDE_DIR" ]; then
  settings_state=nodir
elif [ -z "$python3_bin" ]; then
  settings_state=nopython
elif [ ! -f "$SETTINGS" ]; then
  settings_state=absent
else
  probe="$("$python3_bin" - "$SETTINGS" <<'PY'
import json, os, shlex, sys
def out(state, command="", refresh="none"):
    print(state); print(command); print(refresh); sys.exit(0)
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except (OSError, ValueError):
    data = None
if not isinstance(data, dict):
    out("invalid")
entry = data.get("statusLine")
if entry is None:
    out("absent")
if not isinstance(entry, dict):
    out("other", json.dumps(entry))
cmd = entry.get("command")
try:
    words = shlex.split(cmd) if isinstance(cmd, str) else []
except ValueError:
    words = []
ours = (entry.get("type") == "command" and len(words) in (1, 2)
        and (len(words) == 1 or words[0].startswith("CSHIP_ACCOUNT="))
        and os.path.basename(words[-1]) == "cship")
out("cship" if ours else "other", cmd if isinstance(cmd, str) else json.dumps(entry), entry.get("refreshInterval", "none"))
PY
)"
  settings_state="${probe%%$'\n'*}"; probe="${probe#*$'\n'}"
  existing_command="${probe%%$'\n'*}"; existing_refresh="${probe#*$'\n'}"
  [ "$settings_state" = invalid ] && die "$(short "$SETTINGS") is not a JSON object — fix it, then re-run; nothing was changed"
fi
case "$settings_state" in absent|cship)   # the rewrite and its backup both need room
  if [ ! -w "$CLAUDE_DIR" ] || { [ -e "$SETTINGS" ] && [ ! -w "$SETTINGS" ]; }; then
    die "$(short "$SETTINGS") or $(short "$CLAUDE_DIR") is not writable — nothing was changed"
  fi
  ;;
esac

# ── the two questions ────────────────────────────────────────────────────────
if [ -z "$with_starship" ]; then
  with_starship=no
  if [ "$INTERACTIVE" = yes ]; then
    echo
    echo "== starship =="
    echo "starship.toml here styles line 1 — and, because starship reads one file, your shell prompt."
    echo "Taking it replaces $(short "$CONFIG_DIR/starship.toml") (backed up first)."
    case "$(ask 'Take starship.toml too? [y/N] ')" in [yY]*) with_starship=yes ;; esac
  fi
fi
if [ -z "$account_mode" ]; then
  account_mode=hide
  if [ "$INTERACTIVE" = yes ]; then
    echo
    echo "== account label =="
    echo "Line 2 names the account a session runs under. Left to itself the module shows the"
    echo "organisation name cship fetches, and on a personal account that is your email address."
    echo "A label here is shown instead, fetched from nowhere. Blank hides the module in your copy."
    reply="$(ask 'Label (blank = hide): ')"
    if label_ok "$reply"; then
      account_mode=label
      account_label="$reply"
    elif [ -n "$reply" ]; then
      echo "letters, digits, space, '.', '_', '-' only — hiding the module instead"
    fi
  fi
fi

# ── the last refusals, before the first write ────────────────────────────────
if [ -L "$CONFIG_DIR" ] && [ ! -e "$CONFIG_DIR" ]; then die "$(short "$CONFIG_DIR") is a symlink to nothing"; fi
if [ -e "$CONFIG_DIR" ]; then
  [ -d "$CONFIG_DIR" ] || die "$(short "$CONFIG_DIR") is not a directory"
  [ -w "$CONFIG_DIR" ] || die "$(short "$CONFIG_DIR") is not writable — nothing was changed"
else
  [ -w "$HOME" ] || die "$(short "$HOME") is not writable, so $(short "$CONFIG_DIR") cannot be created"
fi
wanted="cship.toml"
if [ "$with_starship" = yes ]; then wanted="cship.toml starship.toml"; fi
for f in $wanted; do
  if [ -d "$CONFIG_DIR/$f" ] && [ ! -L "$CONFIG_DIR/$f" ]; then die "$(short "$CONFIG_DIR/$f") is a directory"; fi
done
if [ "$with_starship" = yes ] && [ "$SRC" = "$WORK/src" ]; then fetch starship.toml; fi

# ── the copies ───────────────────────────────────────────────────────────────
# The copy is the source byte for byte, or with the account hidden: cship's
# own switch under [cship.account], and the module's slot dropped — the space
# that separated it from $cship.model would otherwise stay as a blank cell on
# line 2. Either way the header and the slot must each appear once, so a file
# that is not this config is refused rather than copied. awk passes every
# other byte through, Nerd Font glyphs included.
prepare_copy() { # prepare_copy <source> <copy> hide|keep
  awk -v mode="$3" '
    /^\[cship\.account\][[:space:]]*(#.*)?$/ { header++; print; if (mode == "hide") print "disabled = true"; next }
    { slot += gsub(/\$cship\.account /, (mode == "hide") ? "" : "&"); print }
    END { if (header != 1 || slot != 1) exit 1 }
  ' "$1" > "$2" || die "$ORIGIN/cship.toml is not the shape this installer knows — [cship.account] and its slot in lines must each appear once"
}

# ── what this run will touch, said before the first write ────────────────────
touching "$CONFIG_DIR/cship.toml" "the statusline's config"
if [ "$with_starship" = yes ]; then touching "$CONFIG_DIR/starship.toml" "line 1, and your shell prompt with it"; fi
case "$settings_state" in absent|cship) touching "$SETTINGS" "the statusLine entry" ;; esac
show_plan
if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

echo
echo "== copying =="
if [ "$account_mode" = hide ]; then prepare_copy "$SRC/cship.toml" "$WORK/cship.toml" hide; else prepare_copy "$SRC/cship.toml" "$WORK/cship.toml" keep; fi
[ -d "$CONFIG_DIR" ] || { mkdir -p "$CONFIG_DIR"; echo "created         $(short "$CONFIG_DIR")"; }
place "$WORK/cship.toml" "$CONFIG_DIR/cship.toml"
if [ "$with_starship" = yes ]; then
  place "$SRC/starship.toml" "$CONFIG_DIR/starship.toml"
else
  echo "left alone      $(short "$CONFIG_DIR/starship.toml")   (say --with-starship to take it)"
fi

# ── settings.json ────────────────────────────────────────────────────────────
echo
echo "== wiring =="
command="$(sq "$cship_bin")"
if [ "$account_mode" = label ]; then
  # The same path cship gives a multi-account launcher: the process that
  # starts cship states the account, and cship fetches nothing for it.
  command="CSHIP_ACCOUNT='{\"organization_name\":\"$account_label\"}' $command"
fi
manual_entry="\"statusLine\": { \"type\": \"command\", \"command\": \"${command//\"/\\\"}\", \"refreshInterval\": $REFRESH_SECONDS }"
# settings.json is not placed the way the configs are: it is one key merged into
# a file Claude Code itself rewrites in place, so a symlink here is written
# through and its backup is a copy beside the link.
wire() { # back up the file if there is one, set statusLine, keep every other key
  local bak through=""
  if [ -f "$SETTINGS" ]; then
    bak="$(backup_name "$SETTINGS")"
    cp "$SETTINGS" "$bak"
    echo "backed up       $(short "$SETTINGS") -> $(short "$bak")"
  fi
  "$python3_bin" - "$SETTINGS" "$command" "$REFRESH_SECONDS" <<'PY'
import json, sys
path, command, refresh = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    data = {}
entry = data.get("statusLine")
entry = dict(entry) if isinstance(entry, dict) else {}   # a padding you set on it stays
entry.update({"type": "command", "command": command, "refreshInterval": refresh})
data["statusLine"] = entry
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
  if [ -L "$SETTINGS" ]; then through=" — a symlink, written through to $(readlink "$SETTINGS")"; fi
  echo "wired           $(short "$SETTINGS")$through"
  wired="wired — statusLine runs $(short "$cship_bin") every $REFRESH_SECONDS s"
  label_applied=yes
}
wired="not wired"
label_applied=no
case "$settings_state" in
  absent) wire ;;
  cship)
    if [ "$existing_command" = "$command" ] && [ "$existing_refresh" = "$REFRESH_SECONDS" ]; then
      echo "unchanged       $(short "$SETTINGS") — statusLine already runs this"
      wired="unchanged — statusLine already runs this"
      label_applied=yes
    else
      # cship's own installer writes `"command": "cship"` and nothing else;
      # this config wants the same binary with a refresh timer and, if you
      # gave one, the label. Same tool, so it is taken over — and said.
      echo "statusLine in $(short "$SETTINGS") runs cship already ($existing_command) — replacing it with this config's entry"
      wire
    fi
    ;;
  other)
    wired="left alone — statusLine runs something else"
    echo "statusLine in $(short "$SETTINGS") runs something other than a bare cship — left as it is:"
    echo "  $existing_command"
    echo "To switch to this config, set it by hand to:"
    echo "  $manual_entry"
    ;;
  nopython)
    wired="not wired — no working python3"
    echo "no working python3, so $(short "$SETTINGS") was not edited. Add this by hand:"
    echo "  $manual_entry"
    ;;
  nodir)
    wired="not wired — no $(short "$CLAUDE_DIR")"
    echo "$(short "$CLAUDE_DIR") does not exist — is Claude Code installed? Once it is, add to $(short "$SETTINGS"):"
    echo "  $manual_entry"
    ;;
esac

# ── what happened ────────────────────────────────────────────────────────────
echo
echo "== summary =="
echo "cship.toml      $(short "$CONFIG_DIR/cship.toml")"
case "$with_starship:${STARSHIP_CONFIG:-}" in
  yes:)  echo "starship.toml   $(short "$CONFIG_DIR/starship.toml") — your shell prompt too, from the next shell" ;;
  yes:*) echo "starship.toml   $(short "$CONFIG_DIR/starship.toml") — but \$STARSHIP_CONFIG is set, and starship reads that for your prompt and for line 1, so the copy serves nothing until it is unset" ;;
  *)     echo "starship.toml   left alone" ;;
esac
case "$account_mode:$label_applied" in
  hide:*)    echo "account         hidden in your copy — disabled = true under [cship.account], its slot dropped from line 2" ;;
  label:yes) echo "account         \"$account_label\", via CSHIP_ACCOUNT in the statusLine command" ;;
  label:no)  echo "account         \"$account_label\" NOT applied — it rides the statusLine command, which was not written (see above)" ;;
esac
echo "settings.json   $wired"
echo
echo "Next: start claude. The statusline appears after the first response. Icons need a Nerd Font in the terminal."
