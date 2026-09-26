# shellcheck shell=bash
# The half the drop-in installers here share: where a piece's files come from,
# what stops a run, how the files are placed, and what the run says before and
# after. It is sourced by a piece's install.sh and never run on its own;
# everything particular to a piece — what it probes for, what it asks, what it
# wires — stays there, and nothing below knows what is being installed.
#
# The caller sets before sourcing:
#   SOURCE_URL  where this piece's files are, mirror or local tree
#   SELF_DIR    the directory holding the caller, empty when it was piped in
#   WORK        a temp directory the caller owns and removes
# A dry run is the plan: a caller prints it with show_plan and stops there,
# so nothing below has a second, pretend path.
#
# The line below is the marker a caller greps for before it sources this file;
# it is matched whole, so nothing may join it.
#
# shellcheck disable=SC2034  # PREEN_INSTALL_LIB, INTERACTIVE and ORIGIN are read by the caller that sources this, which shellcheck cannot see from here
PREEN_INSTALL_LIB=1

STAMP="$(date +%Y%m%d-%H%M%S)"   # one per run, so a run's backups sort together

die() { echo "install.sh: $*" >&2; exit 1; }   # say why the run stops, and stop it

# Piped from curl, stdin is the script; a question has to go through the
# terminal itself, when there is one.
INTERACTIVE=no
if (: </dev/tty) 2>/dev/null; then INTERACTIVE=yes; fi
ask() { # ask <prompt> → the line typed, possibly empty
  printf '%s' "$1" >/dev/tty
  IFS= read -r reply </dev/tty || reply=""
  printf '%s' "$reply"
}

# bash 3.2 (macOS) keeps the backslash in a `${x/#$HOME/\~}` replacement, so
# the ~ is spelled by hand.
short() { # short <path> → the path with $HOME written as ~
  case "$1" in
    "$HOME"|"$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}
# A path that ends up inside a command line is quoted — and only such a path,
# so the usual case reads bare.
sq() { # sq <word> → the word as one shell word, quoted only when it needs it
  case "$1" in
    *[!A-Za-z0-9._/-]*) printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;;
    *) printf '%s' "$1" ;;
  esac
}
version_ge() { # version_ge <a> <b> → true when version a is not older than b
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$1" ]
}

# A Mac without the Command Line Tools still has /usr/bin/git and
# /usr/bin/python3: stubs that raise an install dialog when run. So the tool
# behind the stub is looked for, never run; `xcode-select -p` alone is not
# enough, it prints a stale selection and exits 0.
bare_shim() { # bare_shim <tool> → true when <tool> is macOS's /usr/bin stub with no developer tools behind it
  local dir
  [ "$(command -v "$1" 2>/dev/null)" = "/usr/bin/$1" ] && [ -x /usr/bin/xcode-select ] || return 1
  dir="$(/usr/bin/xcode-select -p 2>/dev/null)" && [ -x "$dir/usr/bin/$1" ] && return 1
  return 0
}

# A directory something else manages — a dotfiles repo linked in whole — would
# receive every file written under it, so a link there stops the run.
refuse_linked_dir() { # refuse_linked_dir <dir> — stop the run when <dir> is a symlink, dangling or not; call it before the first write
  if [ -L "$1" ]; then
    die "$(short "$1") is a symlink to $(readlink "$1") — what this run writes under it would land in that directory, which something else manages. Replace the link with a directory of its own, or put the files there yourself. Nothing was changed."
  fi
}
# The whole setup links its files into a clone of itself, and a clone's root
# holds bin/preen and manifest.tsv. The link is read one hop, so a link that
# points at itself cannot loop, and the walk up ends at /.
links_into_clone() { # links_into_clone <path> → true when <path> is a symlink into a clone of this setup
  local target dir
  [ -L "$1" ] || return 1
  target="$(readlink "$1")"
  case "$target" in /*) ;; *) target="$(dirname "$1")/$target" ;; esac
  dir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || return 1
  while :; do
    if [ -f "$dir/bin/preen" ] && [ -f "$dir/manifest.tsv" ]; then return 0; fi
    [ -n "$dir" ] || return 1
    dir="${dir%/*}"
  done
}

fetch() { # fetch <file> — one of this piece's files from SOURCE_URL into SRC, or stop
  curl -fsSL "$SOURCE_URL/$1" -o "$SRC/$1" && [ -s "$SRC/$1" ] || die "could not fetch $SOURCE_URL/$1"
}
# curl -f already refuses a 404; a caller still checks that what arrived is the
# file it asked for, because a 200 of the wrong bytes is a success.
# Only the marker file is fetched here; a piece fetches its other files itself,
# after this, and knows it is on the fetched path when SRC is under WORK.
locate_sources() { # locate_sources <marker file> — set SRC and ORIGIN: beside the caller when <marker file> is there, else a fetched copy
  if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/$1" ]; then
    SRC="$SELF_DIR"
    ORIGIN="$(short "$SRC")"
  else
    SRC="$WORK/src"
    ORIGIN="$SOURCE_URL"
    mkdir -p "$SRC"
    echo "== fetching from $SOURCE_URL =="
    fetch "$1"
  fi
}

# Two lists, one before and one after: what the run will touch is registered as
# it is decided and printed while nothing has moved yet, and what each write
# actually did is kept as it happens. A reader sees the blast radius first and
# the outcome last, and --dry-run is the plan alone.
TOUCHING=""
HAPPENED=""
touching() { # touching <path> <what it is> — register one destination for the plan
  TOUCHING="$TOUCHING$(printf '%-42s %s' "$(short "$1")" "$2")
"
}
show_plan() { # show_plan — print the registered destinations; nothing has been written yet
  [ -n "$TOUCHING" ] || return 0
  echo
  echo "== will touch =="
  printf '%s' "$TOUCHING"
}
record() { # record <line> — say what a write did, and keep it for the summary
  echo "$1"
  HAPPENED="$HAPPENED$1
"
}
show_summary() { # show_summary — print what the writes did, in the order they happened
  echo
  echo "== summary =="
  printf '%s' "$HAPPENED"
}

backup_name() { # backup_name <file> → a name beside it that nothing holds yet
  local b="$1.unpreened.$STAMP" n=1
  while [ -e "$b" ] || [ -L "$b" ]; do
    b="$1.unpreened.$STAMP.$n"
    n=$((n + 1))
  done
  printf '%s' "$b"
}
# A file is materialised as it should land, then compared with what is there:
# identical is left untouched, so a re-run backs up nothing. A symlink in the
# way is moved aside, link and all, even to identical content — the file is
# being replaced, and writing through the link would overwrite whatever it
# points at, a repo of yours say.
place() { # place <materialised file> <destination> — the destination becomes this file, whatever was there backed up beside it
  local src="$1" dst="$2" bak
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then record "unchanged       $(short "$dst")"; return 0; fi
    bak="$(backup_name "$dst")"
    mv "$dst" "$bak" || die "could not move $(short "$dst") aside"
    record "backed up       $(short "$dst") -> $(short "$bak")"
  fi
  cp "$src" "$dst" || die "could not write $(short "$dst")"
  record "copied          $(short "$dst")"
}
copy_into() { # copy_into <file> <destination> — place it under a directory this drop-in owns, creating the directory
  local dir
  dir="$(dirname "$2")"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" || die "could not create $(short "$dir")"
    record "created         $(short "$dir")"
  fi
  place "$1" "$2"
}
# For a file the tool reads by a fixed name of its own: a drop-in cannot layer
# under such a name, so whatever is there is the adopter's and stays, backup or
# no backup.
copy_if_absent() { # copy_if_absent <file> <destination> — copy only when nothing is at the destination; anything there is left alone
  if [ -e "$2" ] || [ -L "$2" ]; then
    record "left alone      $(short "$2")"
    return 0
  fi
  cp "$1" "$2" || die "could not write $(short "$2")"
  record "copied          $(short "$2")"
}
# A symlink is refused rather than followed: the target is a file something else
# manages, and an append through the link lands in it.
append_line_once() { # append_line_once <file> <line> — the file ends up holding that exact line, once
  local file="$1" line="$2"
  if [ -L "$file" ]; then die "$(short "$file") is a symlink to $(readlink "$file") — whatever manages that file should carry this line, not this installer"; fi
  if [ -f "$file" ] && grep -qxF -- "$line" "$file"; then record "already there   $(short "$file")"; return 0; fi
  if [ -e "$file" ]; then
    # A last line with no newline of its own would otherwise take this one onto its end.
    [ -z "$(tail -c 1 "$file")" ] || printf '\n' >> "$file"
    printf '%s\n' "$line" >> "$file"
    record "appended        $(short "$file")"
  else
    printf '%s\n' "$line" > "$file"
    record "created         $(short "$file")"
  fi
}
