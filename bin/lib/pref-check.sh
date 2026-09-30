# Preference-SSOT assertions, for bin/preen-doctor to source.
#
# The Python half does the reading and deciding; this half only colours the
# result, so the section looks like every other check rather than like a foreign
# tool bolted on. Defines run_pref_checks(), which expects ok()/bad()/warn() to
# already exist in the caller.
#
# Degrades politely rather than failing the run: an absent python3, macOS's
# python3 stub with no Command Line Tools behind it, or a python older than
# 3.11 (no tomllib) produces one warn line, not a FAIL. The
# assertions are a layer on top of preen doctor, and losing them should not make
# the manifest verification look broken.

run_pref_checks() {
  local repo="$1"
  local script="$repo/bin/lib/pref-check.py"

  # Before any python3 runs: on a Mac without the Command Line Tools it is a
  # stub that raises an install dialog. bare_shim is the caller's (preen
  # doctor defines it); a shell that sources this file without it skips the
  # question.
  if declare -f bare_shim >/dev/null 2>&1 && bare_shim python3; then
    echo "== preference SSOT =="
    warn "preference checks skipped — python3 needs the Command Line Tools here (xcode-select --install)"
    return 0
  fi
  # Of the tools the checker runs (git, gh, ssh, defaults), git alone is such a
  # stub. Named in PREEN_BARE_STUBS, its rows skip rather than run it.
  local stubs=""
  if declare -f bare_shim >/dev/null 2>&1 && bare_shim git; then
    stubs="git"
  fi

  # macOS's python3 writes the bytecode of every module it imports into the
  # adopter's ~/Library/Caches/com.apple.python.
  export PYTHONDONTWRITEBYTECODE=1

  # Guard on the spec. The mirror runs this function too, against a spec in the
  # flat layout with no per-machine half. A checkout or mirror whose spec has
  # not been written yet must stay silent rather than report a checker that
  # found nothing.
  #
  # The spec is several files, a shipped half and one per machine, and the
  # shipped half sits at a different depth in the mirror, so this half ASKS the
  # Python rather than carrying a second copy of its discovery rule. rc 3 is
  # "this checkout has no spec at all", the one answer that keeps the section
  # silent. Every other failure — no python3, a python too old for tomllib, a
  # crash — falls through to the degradation lines below.
  local specrc=0
  python3 "$script" --spec-files >/dev/null 2>&1 || specrc=$?
  [ "$specrc" -eq 3 ] && return 0

  echo "== preference SSOT =="

  if ! command -v python3 >/dev/null 2>&1; then
    warn "preference checks skipped — no python3 on PATH"
    return 0
  fi

  # NOT named `status`: that identifier is read-only in zsh (an alias for $?),
  # so the first assignment to such a local aborts the function when this file
  # is sourced from zsh.
  local out err rc errfile
  errfile="$(mktemp)"
  out="$(PREEN_BARE_STUBS="$stubs" python3 "$script" 2>"$errfile")"
  rc=$?
  err="$(cat "$errfile" 2>/dev/null)"
  rm -f "$errfile"

  # An old python degrades to ONE warn, not a failure: pref-check.py reports
  # that on stderr and exits non-zero, which only stderr tells apart from a
  # crash.
  if [ -z "$out" ] && [ "$rc" -ne 0 ] && [[ "$err" == *'needs python'* ]]; then
    warn "preference checks skipped — $err"
    return 0
  fi

  # Silence is legitimate — a spec whose entries are all `n_a` emits nothing by
  # design — so emptiness alone must not read as a crash. The exit status
  # separates the two, and a crash is a FAILURE: a checker that died must not
  # let preen doctor print "no failures". stderr stays out of $out: a Python
  # warning there would arrive as an "unrecognised status" line.
  # A pattern match, not `printf | grep -q`: under preen doctor's pipefail a
  # grep that exits at the first tab leaves printf with SIGPIPE on a large
  # output, and 141 reads as "did not run".
  if [ -n "$out" ] && [[ "$out" != *$'\t'* ]]; then
    bad "preference checks did not run — $(printf '%s' "$out" | tail -1)"
    return 1
  fi
  if [ -z "$out" ] && [ "$rc" -ne 0 ]; then
    bad "preference checks crashed with no output (exit $rc)${err:+ — $err}"
    return 1
  fi

  while IFS=$'\t' read -r state msg; do
    [ -n "$state" ] || continue
    case "$state" in
      ok)   ok   "$msg" ;;
      fail) bad  "$msg" ;;
      warn) warn "$msg" ;;
      section) echo "$msg" ;;
      *)    warn "unrecognised pref-check status '$state': $msg" ;;
    esac
  done <<< "$out"

  # A checker that emits lines and THEN dies returns non-zero with the
  # traceback on stderr and nothing above naming it — preen doctor would print
  # FAILURES ABOVE over a section with no FAIL line. Name the cause.
  if [ "$rc" -ne 0 ] && [ -n "$err" ]; then
    bad "preference checks exited $rc with stderr — $(printf '%s' "$err" | tail -1)"
  fi

  return $rc
}
