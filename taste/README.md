# taste · the author's, as checks

The author's preferences — the fonts, the palettes, the keys, each tool's
settings — written as checks that `preen doctor` runs against your live
config: what each application actually reads, never this repository's copy.
They are for the whole setup, once it is installed. Taking one piece never
needs them: no installer reads this directory.

- `preferences.toml` — each preference's value and why, and the rows that
  check it: what to read, and what must be there.
- `pref-check.py` — the checker. It reads a file the way its application
  does, or asks the tool itself, as through `git config` or `defaults`.
- `pref-check.sh` — what `preen doctor` runs it through, so its lines read
  as the doctor's own.
- `zcap.sh` — starts a login zsh, isolated from your environment, to read
  what your zsh config sets.

## Run it

After `bin/bootstrap`, `preen doctor --taste` runs them, as
[the setup's page](../bin/README.md) shows, with the python it names; with
an older one, or none, the doctor says so in one warn and skips them. Plain
`preen doctor` leaves them out: the taste is the author's, and a setup you
changed on purpose is not broken. Under `--taste`, a FAIL names where your
live config differs from the author's, or a file the checker could not read.

The prose that argues each preference does not ship. The doctor says once
that its cross-check against that prose is skipped, and every row still runs.
