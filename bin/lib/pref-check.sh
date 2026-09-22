# Preference-SSOT assertions, for bin/preen-doctor to source.
#
# The Python half does the reading and deciding; this half only colours the
# result, so the section looks like every other check rather than like a foreign
# tool bolted on. Defines run_pref_checks(), which expects ok()/bad()/warn() to
# already exist in the caller.
#
# Degrades politely rather than failing the run: an absent python3 or a python
# older than 3.11 (no tomllib) produces one warn line, not a FAIL. The
# assertions are a layer on top of preen doctor, and losing them should not make
# the manifest verification look broken.

run_pref_checks() {
  local repo="$1"
  local script="$repo/bin/lib/pref-check.py"

  # Guard on the spec. preen publish copies a short NAMED list of files into the
  # mirror rather than staging bin/ wholesale, and this script is on that list
  # — so the mirror does run this function, against a spec in the flat layout
  # and with no hosts/ half. The guard earns its place there as much as here: a
  # checkout, or a mirror, whose spec has not been written yet must stay silent
  # rather than report a checker that found nothing.
  #
  # ⚠️ This comment has now been wrong twice about its own premise: first
  # claiming preen publish "stages bin/ verbatim", then that this script "never
  # reaches the mirror" (corrected 18-09-2026, after it started shipping). Read
  # bin/preen-publish before trusting the next sentence someone writes here.
  #
  # It used to name docs/preferences.toml here. The spec is several files now —
  # a shipped half, one per host — and the shipped one sits at a different depth
  # in the mirror, so this half ASKS rather than carrying a second copy of the
  # discovery rule that would drift from the Python's the first time a layout
  # moved. rc 2 is the checker saying
  # "this checkout has no spec at all", the one answer that keeps the section
  # silent. Every other failure — no python3, a python too old for tomllib, a
  # crash — falls through to the degradation lines below, which is their job.
  local specrc=0
  python3 "$script" --spec-files >/dev/null 2>&1 || specrc=$?
  [ "$specrc" -eq 2 ] && return 0

  echo "== preference SSOT =="

  if ! command -v python3 >/dev/null 2>&1; then
    warn "preference checks skipped — no python3 on PATH"
    return 0
  fi

  # NOT named `status`: that identifier is read-only in zsh (an alias for $?),
  # so `local out status` aborts the function outright the moment anything
  # sources this file from a zsh shell. bin/preen-doctor is bash, so the bug was
  # latent — it surfaced the first time the function was sourced directly to
  # test the degradation path below. Found 14-08-2026.
  local out err rc errfile
  errfile="$(mktemp)"
  out="$(python3 "$script" 2>"$errfile")"
  rc=$?
  err="$(cat "$errfile" 2>/dev/null)"
  rm -f "$errfile"

  # The documented contract is that an old python degrades to ONE warn, not a
  # failure. pref-check.py reports that condition on stderr and exits non-zero,
  # which — with stderr discarded, as it was until 14-08-2026 — looked
  # identical to a crash. This machine's /usr/bin/python3 is 3.9, so every
  # preen doctor run outside an interactive mise shell hit that path and FAILed
  # on an environment condition the header promises is tolerated.
  if [ -z "$out" ] && [ "$rc" -ne 0 ] && [[ "$err" == *'needs python'* ]]; then
    warn "preference checks skipped — $err"
    return 0
  fi

  # Silence is legitimate — a spec whose entries are all `n_a` emits nothing by
  # design — so emptiness alone must not read as a crash. The exit status is
  # what separates the two, and a crash is a FAILURE, not a warning: this used
  # to `return 0`, so a checker that died still let preen doctor print
  # "no failures". That is the silent-success shape this repo keeps getting
  # bitten by, reproduced inside the guard written to complain about it.
  # stderr is no longer folded into $out: a Python warning on stderr would
  # otherwise arrive as an "unrecognised status" line.
  # A pattern match, not `printf | grep -q`: under preen doctor's pipefail a
  # grep that exits at the first tab leaves printf with SIGPIPE on a large
  # output, and 141 read as "did not run" (audit, 11-09-2026 — the guard
  # flipped at roughly twice today's output).
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

  # A checker that emitted lines and THEN died returned non-zero with the
  # traceback on stderr and nothing above naming it — preen doctor would print
  # FAILURES ABOVE over a section with no FAIL line. Name the cause.
  if [ "$rc" -ne 0 ] && [ -n "$err" ]; then
    bad "preference checks exited $rc with stderr — $(printf '%s' "$err" | tail -1)"
  fi

  return $rc
}
