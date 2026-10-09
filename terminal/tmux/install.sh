#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./terminal/tmux/install.sh [--dry-run]

Take this tmux configuration alone.

Copies the config into ~/.config/tmux/preen and appends ONE line to the last
of tmux's own files that is there — ~/.config/tmux/tmux.conf, else
~/.tmux.conf:

  source-file -q ~/.config/tmux/preen/tmux.conf

That is the whole edit to your file. Nothing in it is rewritten or removed,
and with neither file there, a new ~/.config/tmux/tmux.conf holds that line
alone. tmux reads both files when both are there, ~/.tmux.conf first. Copies,
never symlinks: the file becomes yours to tune, and nothing here points back
at this repo afterwards.

  from a clone:    ./terminal/tmux/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/terminal/tmux/install.sh | bash

There is nothing to ask, so nothing is asked.

The appended line reads a whole config in place, so it wins over every line
above it in your file, and a line below it wins over it.
~/.config/tmux/local.conf, which the copy reads before it starts its plugin
manager, wins over it too. That file is yours: nothing here writes it.

Nothing is overwritten without a timestamped backup beside it, and a re-run
with nothing changed rewrites nothing. Every refusal comes before the first
write; among them: a symlinked ~/.config, ~/.config/tmux or preen/, or one
the run can neither write into nor create; a symlinked file the line goes in
whose target lacks it, which belongs in the target; that file lacking the
line and not one the run can read and append to, or with a last line ending
in a backslash, comment or not, which would carry the line into it; where
tmux is installed and its parse check runs, a file tmux cannot parse, or
whose open quote would take the line as its text; and an XDG_CONFIG_HOME
that names a directory other than ~/.config, where this config's own paths
all are. A file linked into a clone of the whole setup already has this
config, and the run says so and writes nothing.

  --dry-run   print what the run would touch and stop, having written nothing
  -h, --help  print this and exit
EOF
}
set -euo pipefail

# Every argument is answered before the temp directory, the helper's fetch and
# tmux, so --help and an argument error write nothing and need no network. The
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
PIECE="terminal/tmux"   # this piece's path under the mirror root
ROOT_URL="${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/main}"
SOURCE_URL="${TMUX_SOURCE:-$ROOT_URL/$PIECE}"
# TMUX_SOURCE names this piece's directory and the helper sits at the root
# above it, so an override takes the root with it instead of leaving it on the
# mirror. Two levels are stripped, because PIECE is two deep.
if [ -n "${TMUX_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*/*}"; fi

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || SELF_DIR=""; fi
WORK="$(mktemp -d)"
PROBE_DIR=""   # the parse check's own socket directory, once it is made
tmux_bin="$(command -v tmux 2>/dev/null || true)"
trap 'rm -rf "$WORK"; if [ -n "$PROBE_DIR" ]; then "$tmux_bin" -S "$PROBE_DIR/s" kill-server >/dev/null 2>&1 || true; rm -rf "$PROBE_DIR"; fi' EXIT

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

CONFIG_HOME="$HOME/.config"
TMUX_DIR="$CONFIG_HOME/tmux"
PREEN_DIR="$TMUX_DIR/preen"
TPM_DIR="$TMUX_DIR/plugins/tpm"
DOT_CONF="$HOME/.tmux.conf"
XDG_CONF="$TMUX_DIR/tmux.conf"
LINE='source-file -q ~/.config/tmux/preen/tmux.conf'
# The load-bearing ends of the shipped file: the overlay an adopter's own lines
# go in, and the plugin manager's start, which has to be read last.
OVERLAY_LINE='source-file -q ~/.config/tmux/local.conf'
TPM_LINE="if-shell '[ -x ~/.config/tmux/plugins/tpm/tpm ]' \"run '~/.config/tmux/plugins/tpm/tpm'\""

# tmux reads ~/.tmux.conf, then ~/.config/tmux/tmux.conf, every one that is
# there, and tpm reads the second when it is there, else the first: the last
# one there is the file both read. A link counts as there, dangling or not, so
# the symlink policy below meets it.
if there "$XDG_CONF"; then
  TARGET="$XDG_CONF"
elif there "$DOT_CONF"; then
  TARGET="$DOT_CONF"
else
  TARGET="$XDG_CONF"
fi

# ── a home that took the whole setup ─────────────────────────────────────────
# Its tmux.conf is a link into the setup's clone, which already carries this
# config; the line appended there would dirty that clone.
if links_into_clone "$TARGET"; then
  echo "$(short "$TARGET") links into a clone of the whole setup, which already carries this config. Nothing was changed."
  exit 0
fi

# ── tmux's own parse, nothing in the file run ────────────────────────────────
# `source-file -n` parses a file and runs none of it, and -v prints each
# command parsed as `<file>:<line>: <command>`; a file tmux cannot parse is
# rc 1 and tmux's message. It needs a server: one of its own, started with no
# config on a socket in a directory made for it, so no other server is ever
# asked — under /tmp, because tmux refuses a socket path past the sun_path
# limit and a temp directory's path can get near it.
probe=none
probe_said=""
tmux_parse() { # tmux_parse <file> → true when tmux parses it; what it printed in PARSED
  PARSED="$("$tmux_bin" -S "$PROBE_DIR/s" -f /dev/null start-server \; source-file -nv "$1" </dev/null 2>&1)"
}
tmux_says() { # tmux_says <file it parsed> → tmux's last word on it, the file's own path written as "line"
  local last
  last="$(tail -n 1 <<< "$PARSED")"
  case "$last" in "$1:"*) last="line ${last#"$1:"}" ;; esac
  printf '%s' "$last"
}
if [ -n "$tmux_bin" ]; then
  if ! PROBE_DIR="$(mktemp -d /tmp/preen-tmux.XXXXXX 2>/dev/null)"; then
    PROBE_DIR=""
    probe=failed; probe_said="no directory for its socket could be made in /tmp"
  elif tmux_parse /dev/null; then
    probe=ok
  else
    # A server that would not start, or a tmux whose source-file lacks -n:
    # measured on 2.6, the flag is refused before any server starts.
    probe=failed; probe_said="tmux says: $(head -n 1 <<< "$PARSED")"
  fi
fi

# ── where the config comes from ──────────────────────────────────────────────
locate_sources tmux.conf
[ -s "$SRC/tmux.conf" ] || die "$ORIGIN/tmux.conf is missing or empty"
# curl -f already refuses a 404; these refuse a 200 that is not the file, and a
# foreign file beside a clone. A download cut between two lines still parses,
# so the file must end on its own last line.
[ "$(tail -n 1 "$SRC/tmux.conf")" = "$TPM_LINE" ] \
  || die "$ORIGIN/tmux.conf is not this config, or did not arrive whole — it must end on the line that starts its plugin manager, tpm"
grep -qxF -- "$OVERLAY_LINE" "$SRC/tmux.conf" \
  || die "$ORIGIN/tmux.conf is not this config — it must read ~/.config/tmux/local.conf, which is what your own overrides ride on"
if [ "$probe" = ok ]; then
  tmux_parse "$SRC/tmux.conf" || die "$ORIGIN/tmux.conf is not a file tmux can parse — tmux says: $(tmux_says "$SRC/tmux.conf")"
fi

# ── dependencies ─────────────────────────────────────────────────────────────
# Each is a warning and never a refusal: the file is worth having before the
# tools it names, and its plugin manager is started only where it is there.
# tmux alone is run, for its version and the parse check; pbcopy and tpm are
# located, never run.
echo "== dependencies =="
if [ -z "$tmux_bin" ]; then
  echo "tmux not on PATH — installing anyway; the file is read when a tmux server starts. The parse check needs tmux, so no file is checked but for a last line ending in a backslash (brew install tmux)"
else
  echo "$("$tmux_bin" -V 2>/dev/null || echo tmux) at $(short "$tmux_bin")"
  if [ "$probe" = failed ]; then
    echo "the parse check could not run — $probe_said — so no file is checked but for a last line ending in a backslash"
  fi
fi
if [ -x "$TPM_DIR/tpm" ]; then
  echo "tpm at $(short "$TPM_DIR")"
else
  # Read off the config, so the list is the one the copy carries.
  plugins="$(awk -F"'" '/^set -g @plugin / { n = split($2, p, "/"); if (p[n] != "tpm") out = out (out == "" ? "" : ", ") p[n] } END { print out }' "$SRC/tmux.conf")"
  echo "tpm not found at $(short "$TPM_DIR") — the plugins this config lists, $plugins, need it: git clone https://github.com/tmux-plugins/tpm $(short "$TPM_DIR"), then C-Space I inside tmux"
fi
pbcopy_bin="$(command -v pbcopy 2>/dev/null || true)"
if [ -n "$pbcopy_bin" ]; then
  echo "pbcopy at $(short "$pbcopy_bin")"
else
  echo "pbcopy not on PATH — y in copy mode and a mouse drag pipe the selection to it, so without it the selection reaches tmux's paste buffer, which C-Space ] pastes, and the clipboard write tmux sends the terminal, which a terminal may ignore"
fi
# A tpm of the adopter's own is named with its line, and left as it is.
tpm_runs() { # tpm_runs <file> → "<line number> <line>" for each line of it, not a comment, that runs a tpm
  awk '/^[[:space:]]*#/ { next }
    (" " $0 " ") ~ /[^[:alnum:]_-]run(-shell)?[^[:alnum:]_-]/ && /tpm\/tpm/ { sub(/^[[:space:]]+/, ""); print FNR " " $0 }' "$1" 2>/dev/null || true
}
for f in "$DOT_CONF" "$XDG_CONF"; do
  [ -f "$f" ] && [ -r "$f" ] || continue
  while IFS= read -r run_line; do
    [ -n "$run_line" ] || continue
    echo "$(short "$f") line ${run_line%% *} runs tpm: ${run_line#* } — this config starts the tpm at $(short "$TPM_DIR"), where one is there"
  done <<< "$(tpm_runs "$f")"
done

# ── where the line goes ──────────────────────────────────────────────────────
echo
echo "== where the line goes =="
if [ "$TARGET" = "$DOT_CONF" ]; then
  echo "$(short "$DOT_CONF"): it is here and $(short "$XDG_CONF") is not"
elif there "$DOT_CONF"; then
  echo "$(short "$XDG_CONF"): both it and $(short "$DOT_CONF") are here, and tmux reads it second"
elif there "$XDG_CONF"; then
  echo "$(short "$XDG_CONF"): it is here and $(short "$DOT_CONF") is not"
else
  echo "$(short "$XDG_CONF"), created: neither it nor $(short "$DOT_CONF") is here"
fi
if [ "$TARGET" = "$XDG_CONF" ] && holds_line "$DOT_CONF" "$LINE"; then
  echo "$(short "$DOT_CONF") holds the line too, at line $(grep -nxF -- "$LINE" "$DOT_CONF" | head -n 1 | cut -d: -f1)"
fi

# ── what this run will touch, said before the first write ────────────────────
[ -d "$CONFIG_HOME" ] || touching "$CONFIG_HOME" "the directory configs live under, created"
[ -d "$TMUX_DIR" ] || touching "$TMUX_DIR" "tmux's config directory, created"
[ -d "$PREEN_DIR" ] || touching "$PREEN_DIR" "this config's own directory, created"
touching "$PREEN_DIR/tmux.conf" "the config"
touching_line "$TARGET" "$LINE"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
refuse_other_xdg "and this config's own paths are all under ~/.config/tmux"
refuse_unwritable_dir "$CONFIG_HOME"
for d in "$TMUX_DIR" "$PREEN_DIR"; do refuse_linked_dir "$d"; done
for d in "$TMUX_DIR" "$PREEN_DIR"; do refuse_unwritable_if_there "$d"; done

# A last line ending in an odd run of backslashes carries the next line into
# it, a comment's included: measured, an appended line after one was read as
# arguments of the command above, which voids the whole file, or as part of
# the comment, silently. Read with tmux or without, before tmux's own parse.
backslash_end() { # backslash_end <file> → the number of its last line when that line ends in an odd run of backslashes; nothing otherwise
  awk '{ last = $0 } END { n = 0; while (n < length(last) && substr(last, length(last) - n, 1) == "\\") n++; if (n % 2) print NR }' "$1"
}
# The file as the append would leave it parses, and tmux prints the line as a
# command of its own at its own line number. An open quote passes the parse
# and takes the line as its text: measured, tmux printed it inside the string.
own_command() { # own_command <file> <line number> → true when tmux's parse printed this line's command at that line
  local want="$1:$2: source-file -q "
  want="$want" awk 'BEGIN { want = ENVIRON["want"] }
    index($0, want) == 1 && index(substr($0, length(want) + 1), ".config/tmux/preen/tmux.conf") { found = 1 }
    END { exit !found }' <<< "$PARSED"
}
# A parse error anywhere voids the whole file, so a line in one tmux cannot
# parse, appended or there already, is never read.
refuse_unparsed() { # refuse_unparsed — stop the run when tmux, where it can be asked, cannot parse TARGET as it stands
  [ "$probe" = ok ] || return 0
  tmux_parse "$TARGET" \
    || die "tmux cannot parse $(short "$TARGET"), so it reads none of that file now — tmux says: $(tmux_says "$TARGET"). Nothing was changed."
}
refuse_target() { # refuse_target — stop the run where the line cannot go in TARGET, or tmux would not read it there as a command of its own
  local pending probe_conf n
  # Readable, as holds_line found the line in it: parsed as it stands.
  if holds_line "$TARGET" "$LINE"; then refuse_unparsed; return 0; fi
  refuse_linked_rc "$TARGET" "$LINE"
  there "$TARGET" || return 0
  # Readable too: the text test and tmux's parse read it.
  { [ -f "$TARGET" ] && [ -r "$TARGET" ] && [ -w "$TARGET" ]; } || die "$(short "$TARGET") is not a file this run can read and append to. Nothing was changed."
  [ -s "$TARGET" ] || return 0
  pending="$(backslash_end "$TARGET")"
  [ -z "$pending" ] || die "line $pending of $(short "$TARGET") ends in a backslash, which would carry the appended line into it. Nothing was changed."
  [ "$probe" = ok ] || return 0
  refuse_unparsed
  probe_conf="$WORK/probe.conf"
  { cat "$TARGET"; [ -z "$(tail -c 1 "$TARGET")" ] || printf '\n'; printf '%s\n' "$LINE"; } > "$probe_conf"
  n="$(awk 'END { print NR }' "$probe_conf")"
  tmux_parse "$probe_conf" \
    || die "tmux cannot parse $(short "$TARGET") with the line appended — tmux says: $(tmux_says "$probe_conf"). Nothing was changed."
  own_command "$probe_conf" "$n" \
    || die "tmux would read a line appended to $(short "$TARGET") as part of a command above it, not as a command of its own. Nothing was changed."
}
refuse_target

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
copy_into "$SRC/tmux.conf" "$PREEN_DIR/tmux.conf"
# Last, so the line only ever points at a copy already on disk.
append_line_once "$TARGET" "$LINE"

echo
echo "Next: start tmux, or load the line into a tmux already running with tmux source-file $(short "$TARGET")"
