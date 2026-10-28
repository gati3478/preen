#!/usr/bin/env bash
usage() { cat <<'EOF'
usage: ./terminal/kitty/install.sh [--dry-run]

Take this kitty configuration alone.

Copies the config, its palette and the tab title for your home into
~/.config/kitty/preen, copies the files kitty insists on reading from
~/.config/kitty itself, and appends ONE line to your own kitty.conf:

  include preen/kitty.conf

Nothing else in your file changes, but a last line with no newline gets one,
and if you have no kitty.conf yet it becomes that line alone. Copies, never
symlinks, and nothing here points back at this repo afterwards.

  from a clone:    ./terminal/kitty/install.sh [flags]
  from the mirror: curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.3/terminal/kitty/install.sh | bash

There is nothing to ask, so nothing is asked.

kitty reads includes last-wins, so the appended line beats everything above it
in your kitty.conf. Keep a line of your own by moving it BELOW that line, or
into ~/.config/kitty/preen/local.conf, which this config reads after
everything else. That file is yours: nothing here writes it. A tab title in
it wins over ours; a run names its line, with the path it collapses when that
is not your home. tab-title.conf beside it is this installer's: a run
replaces its one line with no backup, and anything else there is backed up
first.

open-actions.conf, mime.types and choose-files.conf are read by kitty from
~/.config/kitty itself, under those names and no others, so a file of yours at
one of them is left exactly as it is and said so. bat's config, which sets the
theme the scrollback pager draws in, is copied to ~/.config/bat/config the
same way: only where none of yours exists.

To update, run the install line from this piece's page again, which names
the newest release: an earlier copy this setup shipped is replaced
with no backup, at those four too; anything else in preen/ is overwritten
only after a timestamped backup beside it; and a re-run with
nothing changed rewrites nothing. Every refusal comes before the first
write; among them, a symlinked ~/.config, ~/.config/kitty or preen/ is
refused, or ~/.config/bat when bat's config would be copied, and so is a
symlinked kitty.conf whose target lacks the line, which belongs in the
target. A kitty.conf linked into a clone of the whole setup already has this
config, and the run says so and writes nothing.

  --dry-run   print what the run would touch and stop, having written nothing
  -h, --help  print this and exit

  PREEN_SOURCE  piped, a preen tree to fetch from instead of this release,
                as a URL or file://
  KITTY_SOURCE  piped, this piece's directory in such a tree; the rest
                comes from the tree it is in, unless PREEN_SOURCE names one
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
PIECE="terminal/kitty"   # this piece's path under the mirror root
PREEN_REF=v2.2.3   # this installer's release: the tag it fetches from, and the helper's marker
# A slash ending an override would double the one joined after it, and leave
# a root taken from it a level too deep.
trim_slash() { printf '%s' "$1" | sed 's#/*$##'; }   # trim_slash <url> → it with any trailing slash dropped
ROOT_URL="$(trim_slash "${PREEN_SOURCE:-https://raw.githubusercontent.com/gati3478/preen/$PREEN_REF}")"
SOURCE_URL="$(trim_slash "${KITTY_SOURCE:-$ROOT_URL/$PIECE}")"
# KITTY_SOURCE names this piece's directory and the helper sits at the root
# above it, so an override takes the root with it instead of leaving it on the
# mirror. Two levels are stripped here where prompt/'s installer strips one,
# because PIECE is two deep.
if [ -n "${KITTY_SOURCE:-}" ] && [ -z "${PREEN_SOURCE:-}" ]; then ROOT_URL="${SOURCE_URL%/*/*}"; fi

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || SELF_DIR=""; fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The shared library comes from this script's own tree, else from the root
# the configs come from, never the shell's directory. Its marker names its
# release; another release's may not do what this installer asks.
helper_ok() { # helper_ok <file> <where it is from> → true when it is this release's helper, false when it is no helper; stops the run on another release's
  grep -qxF "PREEN_INSTALL_LIB=$PREEN_REF" "$1" && return 0
  grep -q '^PREEN_INSTALL_LIB=' "$1" || return 1
  echo "install.sh: $2 is preen $(sed -n 's/^PREEN_INSTALL_LIB=//p' "$1") but this installer is $PREEN_REF" >&2
  exit 1
}
LIB=""
candidate="$SELF_DIR/../../lib/install.sh"
if [ -f "$candidate" ] && helper_ok "$candidate" "$candidate"; then LIB="$candidate"; fi
if [ -z "$LIB" ]; then
  LIB="$WORK/lib.sh"
  curl -fsSL "$ROOT_URL/lib/install.sh" -o "$LIB" 2>/dev/null || { echo "install.sh: could not fetch $ROOT_URL/lib/install.sh" >&2; exit 1; }
  helper_ok "$LIB" "$ROOT_URL/lib/install.sh" || { echo "install.sh: $ROOT_URL/lib/install.sh is not the shared installer helper" >&2; exit 1; }
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
BAT_CONF="$CONFIG_HOME/bat/config"
KITTY_APP="/Applications/kitty.app/Contents/MacOS/kitty"
FONT_FILE_PREFIX="FiraCodeNerdFontMono"   # how the cask names the files
FONT_NAME="FiraCode Nerd Font Mono"       # how kitty.conf asks for it
FONT_CASK="font-fira-code-nerd-font"
# The home the shipped tab title collapses to '~'. bin/bootstrap carries the
# same constant for the same line; kitty expands no variable in that option.
AUTHORED_HOME="/Users/gati3478"
# HOME as tab-title.awk reads it: without its trailing slashes, so /h/ names
# /h. A HOME of slashes alone is read as given.
TITLE_HOME="$HOME"
while [ "${TITLE_HOME%/}" != "$TITLE_HOME" ]; do TITLE_HOME="${TITLE_HOME%/}"; done
[ -n "$TITLE_HOME" ] || TITLE_HOME="$HOME"

# ── a home that took the whole setup ─────────────────────────────────────────
# Its kitty.conf is a link into the setup's clone, which already carries this
# config; the include line appended there would dirty that clone.
if links_into_clone "$KITTY_CONF"; then
  echo "$(short "$KITTY_CONF") links into a clone of the whole setup, which already carries this config. Nothing was changed."
  exit 0
fi

# ── where the configs come from ──────────────────────────────────────────────
locate_sources kitty.conf
if [ "$SRC" = "$WORK/src" ]; then
  # shellcheck disable=SC2086  # ROOT_FILES is a list of names, meant to split
  for f in current-theme.conf tab-title.awk $ROOT_FILES; do fetch "$f"; done
fi
# shellcheck disable=SC2086
for f in kitty.conf current-theme.conf tab-title.awk $ROOT_FILES; do
  [ -s "$SRC/$f" ] || die "$ORIGIN/$f is missing or empty"
done
# curl -f already refuses a 404; these refuse a 200 that is not the file, and a
# foreign file beside a clone. Each line is load-bearing rather than
# decorative: the tab title and the overlay ride on the globincludes, and
# kitty.conf's `include current-theme.conf` resolves to a file that has to be a
# palette.
grep -q '^globinclude tab-title\.conf$' "$SRC/kitty.conf" \
  || die "$ORIGIN/kitty.conf is not this config — it must end with \`globinclude tab-title.conf\`, which is what the tab title for your home rides on"
grep -q '^globinclude local\.conf$' "$SRC/kitty.conf" \
  || die "$ORIGIN/kitty.conf is not this config — it must end with \`globinclude local.conf\`, which is what your own overrides ride on"
grep -q '^background[[:space:]]' "$SRC/current-theme.conf" \
  || die "$ORIGIN/current-theme.conf is not a kitty colour scheme"
# The program that writes the tab title. A download cut off between two rules
# still parses, so it must end on its marker line; one cut mid-block fails to
# parse, and a file that is not this program lacks the rule local.conf is read by.
grep -q '^want == "local"' "$SRC/tab-title.awk" && awk -f "$SRC/tab-title.awk" </dev/null >/dev/null 2>&1 \
  && [ "$(tail -n 1 "$SRC/tab-title.awk")" = '# end of tab-title.awk: install.sh refuses a copy whose last line is not this one' ] \
  || die "$ORIGIN/tab-title.awk is not the program that writes the tab title, or did not arrive whole"
# scrollback_pager runs bat with no theme of its own; the shell piece takes
# this config too, so it is kept in bat's own directory.
locate_root_file terminal/bat/config '--theme="ansi"' '--theme="ansi"'

# ── dependencies ─────────────────────────────────────────────────────────────
# Each is a warning and never a refusal: the files are worth having before the
# thing that reads them, and an adopter may install kitty, the font, bat or
# Sublime Text after this run. Nothing below launches kitty — the binary is
# located and named, not executed. bat and subl, which kitty runs, are looked
# for where kitty looks for a program: find_tool's directories.
echo "== dependencies =="
kitty_bin=""
if [ -x "$KITTY_APP" ]; then
  kitty_bin="$KITTY_APP"
else
  kitty_bin="$(find_tool kitty || true)"
fi
if [ -n "$kitty_bin" ]; then
  echo "kitty at $(short "$kitty_bin")"
else
  echo "kitty not found, at $KITTY_APP or $(tool_where) — installing anyway; these files are read the first time kitty starts (brew install --cask kitty)"
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
  echo "$FONT_NAME not found in $(short "$HOME/Library/Fonts") or /Library/Fonts — without it kitty falls back to its own monospace face, and the ligatures, the dotted zero and the oldstyle figures this config asks for are not there (brew install --cask $FONT_CASK)"
fi

bat_bin="$(find_tool bat || true)"
if [ -n "$bat_bin" ]; then
  echo "bat at $(short "$bat_bin")"
else
  echo "bat not found $(tool_where) — this config pages the scrollback through it, so until bat is there the scrollback pager opens on nothing (brew install bat)"
fi

subl_bin="$(find_tool subl || true)"
if [ -n "$subl_bin" ]; then
  echo "subl at $(short "$subl_bin")"
else
  echo "subl not found $(tool_where) — open-actions.conf launches it when you click a file path, so a click does nothing until it is there, or until you put your editor's name in that file (brew install --cask sublime-text)"
fi

# ── the tab title ────────────────────────────────────────────────────────────
# kitty.conf's tab_title_template collapses the working directory to '~' for a
# home that is a literal, authored for one machine. The line is read out of
# kitty.conf rather than repeated here, and rewritten for this HOME by
# tab-title.awk, the program bin/bootstrap runs too; it says why it is awk.
echo
echo "== tab title =="
title_line=""
if [ "$TITLE_HOME" = "$AUTHORED_HOME" ]; then
  echo "this is the home the tab title was authored for — no tab-title.conf needed"
else
  title_line="$(awk -v want=title -v authored="$AUTHORED_HOME" -f "$SRC/tab-title.awk" "$SRC/kitty.conf")"
  # local.conf, read after tab-title.conf, may set a tab title of its own:
  # tab-title.awk names its line, and the path it collapses when that is not
  # this home. Their file: named, never written.
  local_title="$(LC_ALL=C awk -v want=local -f "$SRC/tab-title.awk" "$PREEN_DIR/local.conf" 2>/dev/null)" || local_title=""
  local_line="${local_title%% *}"; local_path="${local_title#* }"
  # Said before the refusals and the write, so it is what a run writes, never
  # what the file holds.
  if [ -z "$title_line" ]; then
    echo "$ORIGIN/kitty.conf has no tab_title_template line — no tab-title.conf needed"
  elif [ -n "$local_path" ]; then
    echo "$(short "$PREEN_DIR/local.conf") line $local_line, read after tab-title.conf, sets a tab title that collapses $local_path"
  elif [ -n "$local_title" ]; then
    echo "$(short "$PREEN_DIR/local.conf") line $local_line, read after tab-title.conf, sets a tab title"
  else
    home_lit="${TITLE_HOME//\\/\\\\}"
    case "$title_line" in
      *"'$home_lit'"*|*"\"$home_lit\""*) echo "the tab title a run writes to $(short "$PREEN_DIR/tab-title.conf") collapses this home to '~'" ;;
      *) echo "the tab title a run writes to $(short "$PREEN_DIR/tab-title.conf") does not collapse this home" ;;
    esac
  fi
fi

# tab-title.conf is this installer's, written whole, so the line kitty reads
# always names this HOME. local.conf, read after it, is the adopter's, and a
# tab title of theirs there wins. A plain file of one tab_title_template line
# is this installer's own, for another home or an older kitty.conf: updated
# with no backup, which the doctor would otherwise warn about on every run
# after. Anything else there is place()'s to decide.
TITLE_CONF="$PREEN_DIR/tab-title.conf"
if [ -n "$title_line" ]; then printf '%s\n' "$title_line" > "$WORK/tab-title.conf"; fi
title_outcome() { # title_outcome → what the run will do to tab-title.conf: place()'s outcome, or updated for the installer's own line
  if [ ! -L "$TITLE_CONF" ] && [ -f "$TITLE_CONF" ] && ! cmp -s "$WORK/tab-title.conf" "$TITLE_CONF" \
    && awk 'NR == 1 { ok = /^tab_title_template / } END { exit !(NR == 1 && ok) }' "$TITLE_CONF" 2>/dev/null; then
    echo updated
  else
    place_outcome "$WORK/tab-title.conf" "$TITLE_CONF"
  fi
}

# ── the include in your kitty.conf ───────────────────────────────────────────
# kitty reads a file once: a later include of one it has read, keyed on its
# path after normpath, is skipped and named a bad line at every launch. So
# the include that takes effect is the first line resolving to
# preen/kitty.conf by kitty's own rule (kitty/conf/utils.py parse_line): the
# line stripped of kitty's whitespace, \r with it; the key `include`; `~`
# expanded; a relative path read against kitty.conf's directory. An include
# spelled through a variable or `~user`, padded with a multibyte space or
# continued onto a `\` line, and a globinclude, are taken as written. Paths go
# in through the environment: awk -v reads a backslash in one, which a HOME
# may hold, as an escape.
first_include() { # first_include <your kitty.conf> → the line number of the include of this config that takes effect; nothing when there is none
  PREEN_HOME="$HOME" PREEN_BASE="$KITTY_DIR" LC_ALL=C awk '
    function norm(p,   lead, s, t, n, i, k, out) {
      lead = (p ~ /^\/\// && p !~ /^\/\/\//) ? "//" : ((p ~ /^\//) ? "/" : "")
      n = split(p, s, "/"); k = 0
      for (i = 1; i <= n; i++) {
        if (s[i] == "" || s[i] == ".") continue
        if (s[i] == ".." && k > 0 && t[k] != "..") { k--; continue }
        if (s[i] == ".." && lead != "") continue
        t[++k] = s[i]
      }
      out = lead
      for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") t[i]
      return out == "" ? "." : out
    }
    BEGIN {
      home = ENVIRON["PREEN_HOME"]; sub(/\/+$/, "", home)
      base = ENVIRON["PREEN_BASE"]; ours = norm(base "/preen/kitty.conf")
    }
    {
      line = $0
      sub(/^[ \t\v\f\r\034-\037]+/, "", line); sub(/[ \t\v\f\r\034-\037]+$/, "", line)
      if (!match(line, /^include[ \t\v\f\r\034-\037]+/)) next
      p = substr(line, RLENGTH + 1)
      if (p == "~") p = (home == "") ? "/" : home
      else if (substr(p, 1, 2) == "~/") p = home substr(p, 2)
      if (p !~ /^\//) p = base "/" p
      if (norm(p) == ours) { print FNR; exit }
    }
  ' "$1" 2>/dev/null
}
# So whether kitty.conf already holds the line is kitty's question, not an
# exact match's: the helper's holds_line, which the plan, the refusals and the
# append each ask of this one line, is answered from the include found once,
# here.
include_at=""
if [ -f "$KITTY_CONF" ] && [ -r "$KITTY_CONF" ]; then include_at="$(first_include "$KITTY_CONF")"; fi
holds_line() { [ -n "$include_at" ]; }

# ── your lines above the include, which this config overrides ────────────────
# kitty reads kitty.conf top to bottom and the included config where its line
# is, so a setting of yours above that line which this config also makes
# loses to it — unless a line of yours below the include sets it again. A
# directive is named by its first word, with the exceptions kitty keeps per
# key: a map by its keys, read as kitty/options/utils.py parse_shortcut reads
# them (lower case, cmd and ⌘ as super and so on, the modifiers in any
# order); a mouse_map by its button, event and modes; env by the variable,
# and only the variable is named; modify_font size by its font, and the rest
# of modify_font, font_features, symbol_map, narrow_symbols, action_alias and
# kitten_alias by their first argument. A line is split on kitty's
# whitespace, and one with no value is no setting. The include family,
# exe_search_path, watcher, filter_notification and detect_url_regex add to
# what is there rather than replace it, so they never lose. Not compared: a
# map with an option (--when-focus-on, --mode); remote_control_password and
# menu_map, each kept per entry; and an env of this config's whose value
# holds a `$`, which kitty expands against the variables set before it,
# yours among them. Files your kitty.conf includes are not read.
overridden() { # overridden <your kitty.conf> <the include's line number, 0 when it is to be appended> <this config's files…> → "<line number> <directive>" for each line of yours that loses
  local conf="$1" at="$2"; shift 2
  PREEN_CONF="$conf" LC_ALL=C awk -v at="$at" '
    BEGIN { conf = ENVIRON["PREEN_CONF"] }
    function trim(line) { sub(/^[ \t\v\f\r\034-\037]+/, "", line); sub(/[ \t\v\f\r\034-\037]+$/, "", line); return line }
    function shortcut(spec,   p, n, i, j, m, t, out) {
      n = split(spec, p, "+"); out = ""
      for (i = 1; i < n; i++) {
        m = p[i]
        if (m == "cmd" || m == "command" || m == "\342\214\230") m = "super"
        else if (m == "control" || m == "\342\214\203") m = "ctrl"
        else if (m == "opt" || m == "option" || m == "\342\214\245") m = "alt"
        else if (m == "\342\207\247") m = "shift"
        p[i] = m
      }
      for (i = 2; i < n; i++) for (j = i; j > 1 && p[j - 1] > p[j]; j--) { t = p[j]; p[j] = p[j - 1]; p[j - 1] = t }
      for (i = 1; i < n; i++) out = out p[i] "+"
      return out p[n]
    }
    function keys(spec,   s, n, i, out) {
      spec = tolower(spec)
      if (spec ~ /\+$/) spec = substr(spec, 1, length(spec) - 1) "plus"
      gsub(/\+\+/, "+plus", spec)
      while (match(spec, /[^+]>/)) spec = substr(spec, 1, RSTART) "\001" substr(spec, RSTART + 2)
      n = split(spec, s, "\001"); out = ""
      for (i = 1; i <= n; i++) out = out (i > 1 ? ">" : "") shortcut(s[i])
      return out
    }
    function key(line,   w, n, k) {
      n = split(trim(line), w, /[ \t\v\f\r\034-\037]+/); k = w[1]
      if (n < 2 || k ~ /^[#\\]/) return ""
      if (k ~ /^(include|globinclude|envinclude|geninclude|exe_search_path|watcher|filter_notification|detect_url_regex|remote_control_password|menu_map)$/) return ""
      if (k == "map") return (w[2] !~ /^--/) ? "map " keys(w[2]) : ""
      if (k == "mouse_map") return (n >= 4) ? k " " w[2] " " w[3] " " w[4] : ""
      if (k == "env") { sub(/=.*/, "", w[2]); return k " " w[2] }
      if (k == "modify_font" && w[2] == "size") return k " size " w[3]
      if (k ~ /^(font_features|symbol_map|narrow_symbols|modify_font|action_alias|kitten_alias)$/) return k " " w[2]
      return k
    }
    function shown(line,   w) {
      split(trim(line), w, /[ \t\v\f\r\034-\037]+/)
      if (w[1] == "env") { sub(/=.*/, "", w[2]); return "env " w[2] }
      if (w[1] == "modify_font" && w[2] == "size") return w[1] " size " w[3]
      if (w[1] ~ /^(map|font_features|symbol_map|narrow_symbols|modify_font|action_alias|kitten_alias)$/) return w[1] " " w[2]
      if (w[1] == "mouse_map") return w[1] " " w[2] " " w[3] " " w[4]
      return w[1]
    }
    FILENAME != conf { k = key($0); if (k != "" && !(k ~ /^env / && $0 ~ /=.*\$/)) ours[k] = 1; next }
    { k = key($0); if (k == "" || !(k in ours)) next
      if (at == 0 || FNR < at) { line[++n] = FNR; name[n] = shown($0); kk[n] = k }
      else if (FNR > at) below[k] = 1 }
    END { for (i = 1; i <= n; i++) if (!(kk[i] in below)) print line[i] " " name[i] }
  ' "$@" "$conf"
}
lost=""
if [ -f "$KITTY_CONF" ] && [ -r "$KITTY_CONF" ]; then
  if [ -n "$title_line" ]; then
    lost="$(overridden "$KITTY_CONF" "${include_at:-0}" "$SRC/kitty.conf" "$SRC/current-theme.conf" "$WORK/tab-title.conf")"
  else
    lost="$(overridden "$KITTY_CONF" "${include_at:-0}" "$SRC/kitty.conf" "$SRC/current-theme.conf")"
  fi
fi

# ── what this run will touch, said before the first write ────────────────────
[ -d "$CONFIG_HOME" ] || touching "$CONFIG_HOME" "the directory configs live under, created"
[ -d "$KITTY_DIR" ] || touching "$KITTY_DIR" "kitty's config directory, created"
[ -d "$PREEN_DIR" ] || touching "$PREEN_DIR" "this config's own directory, created"
touching_place "$SRC/kitty.conf" "$PREEN_DIR/kitty.conf" "$PIECE/kitty.conf" "the config"
touching_place "$SRC/current-theme.conf" "$PREEN_DIR/current-theme.conf" "$PIECE/current-theme.conf" "the palette it includes"
if [ -n "$title_line" ]; then touching "$TITLE_CONF" "the tab title for this home — $(outcome_words "$(title_outcome)")"; fi
touching_line "$KITTY_CONF" "$INCLUDE_LINE"
while IFS= read -r l; do
  [ -z "$l" ] || touching "$KITTY_CONF" "line ${l%% *}: ${l#* } (yours, above the include) loses to this config"
done <<< "$lost"
touching_if_absent "$SRC/open-actions.conf" "$KITTY_DIR/open-actions.conf" "$PIECE/open-actions.conf" "what a click on a link does"
touching_if_absent "$SRC/mime.types" "$KITTY_DIR/mime.types" "$PIECE/mime.types" "the file types behind it"
touching_if_absent "$SRC/choose-files.conf" "$KITTY_DIR/choose-files.conf" "$PIECE/choose-files.conf" "kitty's file picker, kitten choose-files"
touching_dir_for "$BAT_CONF" "bat's config directory, created"
touching_if_absent "$SRC_ROOT/terminal/bat/config" "$BAT_CONF" terminal/bat/config "bat's theme: the terminal's palette"
show_plan

# ── the last refusals, before the first write ────────────────────────────────
refuse_unwritable_dir "$CONFIG_HOME"
for d in "$KITTY_DIR" "$PREEN_DIR"; do refuse_linked_dir "$d"; done
# Only a kitty.conf the run appends to is checked: one holding the line is
# never written.
if ! holds_line "$KITTY_CONF" "$INCLUDE_LINE"; then
  refuse_linked_rc "$KITTY_CONF" "$INCLUDE_LINE"
  # A kitty.conf that cannot be written — root-owned after a sudo edit, or a
  # directory — would stop the run at its last write, with the copies already
  # on disk. Asked here, beside the symlink refusals, so a stopped run has
  # changed nothing.
  if [ -e "$KITTY_CONF" ] && { [ ! -f "$KITTY_CONF" ] || [ ! -w "$KITTY_CONF" ]; }; then
    die "$(short "$KITTY_CONF") is not a file this run can append to. Nothing was changed."
  fi
fi
for d in "$KITTY_DIR" "$PREEN_DIR"; do refuse_unwritable_if_there "$d"; done
refuse_dir_for "$BAT_CONF"

if [ "$dry_run" = yes ]; then
  echo
  echo "Nothing was written. Drop --dry-run to do it."
  exit 0
fi

# ── the writes ───────────────────────────────────────────────────────────────
echo
echo "== installing =="
copy_into "$SRC/kitty.conf" "$PREEN_DIR/kitty.conf" "$PIECE/kitty.conf"
copy_into "$SRC/current-theme.conf" "$PREEN_DIR/current-theme.conf" "$PIECE/current-theme.conf"
if [ -n "$title_line" ] && [ "$(title_outcome)" = updated ]; then
  { rm -f "$TITLE_CONF" && cp "$WORK/tab-title.conf" "$TITLE_CONF"; } || die "could not replace $(short "$TITLE_CONF")"
  record "updated         $(short "$TITLE_CONF")"
elif [ -n "$title_line" ]; then
  copy_into "$WORK/tab-title.conf" "$TITLE_CONF"
fi
# shellcheck disable=SC2086
for f in $ROOT_FILES; do copy_if_absent "$SRC/$f" "$KITTY_DIR/$f" "$PIECE/$f"; done
copy_if_absent_into "$SRC_ROOT/terminal/bat/config" "$BAT_CONF" terminal/bat/config
# Last, so a kitty.conf that includes this config only ever points at files
# already on disk.
append_line_once "$KITTY_CONF" "$INCLUDE_LINE"

echo
echo "Next: open a new kitty window, or reload the config with ctrl+cmd+, in the one you have."
