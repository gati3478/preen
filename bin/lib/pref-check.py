#!/usr/bin/env python3
"""usage: python3 bin/lib/pref-check.py [--spec-files | --validate-spec | --prove | --read TARGET KEY]

Assert the preference spec against LIVE application config. With no argument,
run every assertion.

  --spec-files       print the spec files it reads; exit 3 when there are none
  --validate-spec    check the spec's structure only, never live config
  --prove            empty a COPY of each text-read target and require every
                     row it feeds to go red
  --read TARGET KEY  read one live value (debugging)
  -h, --help         print this and exit

The spec is public/preferences.toml plus one hosts/<name>/preferences.toml per
machine, read as one document (see spec_files).

Emits one TAB-separated `status<TAB>message` line per assertion, for
bin/lib/pref-check.sh to colour the same way preen doctor colours everything else.
Statuses: ok | fail | warn, plus `section` for a heading the wrapper prints bare.

Reads the DEPLOYED path, never this repo's copy: a `copy`-mode entry can be
legitimately stale between preen pull runs, and the question this asks is what the
application actually renders. Ends with the surfaces section: each closed
surface's tools, installed version against closed-at, read without launching
an application.

Exit status is 1 if any assertion failed or --read could not read, else 0; 2 is
an argument error; 3 is --spec-files finding no spec. Never prints a tally — a
count drifts between the checker and the checked and nobody notices.
"""

import copy
import glob
import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from xml.parsers.expat import ExpatError

READ = "--read"
MODES = ("--spec-files", "--validate-spec", "--prove", READ)


def argv_problem(argv):
    """The argument error in argv, or None for an invocation the usage allows."""
    for arg in argv:
        if arg.startswith("-") and arg not in MODES:
            return f"unknown argument: {arg}"
    modes = [arg for arg in argv if arg in MODES]
    if len(modes) > 1:
        return f"one mode at a time: {' '.join(modes)}"
    if argv and argv[0] not in MODES:
        return f"unknown argument: {argv[0]}"
    if argv[:1] == [READ]:
        return None if len(argv) == 3 else f"{READ} takes TARGET KEY"
    if len(argv) > 1:
        return f"unknown argument: {argv[1]}"
    return None


# Ahead of the tomllib gate so both answer on any python. Only when run:
# obsidian-gaps.py and the tests import this file, and their argv is not ours.
if __name__ == "__main__":
    if "-h" in sys.argv[1:] or "--help" in sys.argv[1:]:
        print(__doc__, end="")
        sys.exit(0)
    if problem := argv_problem(sys.argv[1:]):
        print(f"pref-check: {problem} (see --help)", file=sys.stderr)
        sys.exit(2)

try:
    import tomllib
except ImportError:
    sys.exit("pref-check: needs python >= 3.11 (tomllib)")

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# `public/` is stripped when preen publish builds the mirror, so anything shipped
# from it sits one directory higher there. Every path this file derives from the
# repo takes the first of the two that exists — never both, which for the spec
# would merge one document with itself.
LAYOUTS = ("public", "")


def _shipped(*parts):
    """A repo path that the mirror flattens: public/<parts> here, <parts> there."""
    for top in LAYOUTS:
        candidate = os.path.join(REPO, top, *parts) if top else os.path.join(REPO, *parts)
        if os.path.exists(candidate):
            return candidate
    return os.path.join(REPO, LAYOUTS[0], *parts)


def spec_files():
    """(paths, discovered) — the files that make up the spec.

    The spec is ONE document in several files, merged at load: a shipped half
    the mirror carries, and one half per host for that machine's targets and its
    [surfaces]. A [pref.X] header therefore lives in the shipped half while the
    entries that assert it live beside the host-bound targets they name. Either
    kind may be absent — a mirror has no hosts/, and a machine could ship
    nothing — so a half is read when it is there and not looked for twice.

    PREF_SPEC names the files outright, `os.pathsep`-separated, and stops
    discovery. Without it the only way to test this checker is to mutate the
    real config, which is a test that can break the machine it runs on.
    """
    env = os.environ.get("PREF_SPEC")
    if env:
        return [p for p in env.split(os.pathsep) if p], False
    found = []
    shipped = _shipped("preferences.toml")
    if os.path.isfile(shipped):
        found.append(shipped)
    found += sorted(glob.glob(os.path.join(REPO, "hosts", "*", "preferences.toml")))
    return found, True


SPEC_FILES, SPEC_DISCOVERED = spec_files()


def spec_name(path):
    """A spec file as a message names it: relative to the repo where it is one."""
    rel = os.path.relpath(os.path.abspath(path), REPO)
    return os.path.basename(path) if rel.startswith("..") else rel


def _prose_path():
    """(path, why-there-is-none) — the prose half.

    preferences.md is the authority; the cross-check below is what stops the two
    halves from disagreeing, which they did in both directions until 14-08-2026.

    A spec DISCOVERED in the source layout pairs with docs/preferences.md,
    whatever its files are called. In the FLAT layout there is none and there
    never can be: docs/ does not ship, so naming that path in the mirror's own
    doctor output would be both a lie and a private path in a public place.
    A single PREF_SPEC file derives its pair from its own name, so a fixture can
    supply one; several derive nothing, having no single name to derive from.
    """
    env = os.environ.get("PREF_PROSE")
    if env:
        return env, ""
    if SPEC_DISCOVERED:
        if SPEC_FILES and SPEC_FILES[0] == os.path.join(REPO, "preferences.toml"):
            return "", "no prose half ships with the mirror"
        return os.path.join(REPO, "docs", "preferences.md"), ""
    if len(SPEC_FILES) == 1:
        return os.path.splitext(SPEC_FILES[0])[0] + ".md", ""
    return "", "no prose half to derive from several spec files"


PROSE, PROSE_ABSENT = _prose_path()
# The published half. This spec ships with the whole setup but not with
# prompt/ taken alone, so the palette table in public/prompt/README.md is the
# only statement of the palette a stranger adopting the statusline alone can read.
# That makes it a DECLARED mirror, and the cross-check below is what earns it
# the word "declared". In the mirror it is prompt/README.md — the same two
# layouts the spec has, so it is found the same way.
PUBLISHED = os.environ.get("PREF_PUBLISHED") or _shipped("prompt", "README.md")
# The kitty drop-in's page carries the palette too, read off the theme file that
# ships beside it — so it is held to that file as well as to the spec. Checked
# only when the prompt page is the repo's own: a fixture must not drag it in.
PUBLISHED_THEME_PAGE = None if os.environ.get("PREF_PUBLISHED") else _shipped("terminal", "kitty", "README.md")
SHIPPED_THEME = _shipped("terminal", "kitty", "current-theme.conf")

# Which tables several files may CONTRIBUTE to, by their path from the document
# root. `*` is any name. Everything not listed is atomic: a whole [targets.N], a
# [pref.X.targets.Y] entry, one surface's tool, one probe's path table — defined
# in exactly one file, or the merge refuses. That refusal is the whole answer to
# "a second copy that drifts": the split may divide the document, never restate
# any part of it.
MERGEABLE = (
    (),
    ("targets",), ("pref",), ("surfaces",), ("probes",), ("oracles",),
    ("pref", "*"), ("pref", "*", "targets"),
    ("surfaces", "*"), ("surfaces", "*", "tools"),
)


def _mergeable(path):
    return any(len(p) == len(path) and all(a in ("*", b) for a, b in zip(p, path))
               for p in MERGEABLE)


def _record_origin(origin, path, value, fname):
    """Note which file defined a table AND everything under it.

    Recording only the table would leave a later conflict two levels down
    unable to name the first definer — the message said "defined in both ? and
    …", which is the diagnostic failing at exactly the job it exists for.
    """
    origin[".".join(path)] = fname
    if isinstance(value, dict):
        for key, inner in value.items():
            _record_origin(origin, path + (str(key),), inner, fname)


# Where a name is a NAME — a target, a pref, an entry — rather than a field.
# TOML is case-sensitive and every reader here is not: `[targets.T1]` beside
# `[targets.t1]` loads as two targets, and the row pointing at one of them picks
# by exact spelling while a reader looking for the file finds whichever it was
# handed. Two names that differ only in case are one name for the purpose of
# refusing, and the refusal is the point.
NAME_SCOPES = (("targets",), ("pref",), ("pref", "*", "targets"))


def _names_here(path):
    return any(len(p) == len(path) and all(a in ("*", b) for a, b in zip(p, path))
               for p in NAME_SCOPES)


def _merge_into(dst, src, origin, path, fname, problems):
    for key, value in src.items():
        here = path + (str(key),)
        label = ".".join(here)
        if key not in dst:
            folded = _names_here(path) and next(
                (k for k in dst if str(k).lower() == str(key).lower()), None)
            if folded:
                first = ".".join(path + (str(folded),))
                problems.append(
                    f"{label} collides with {first}, defined in {origin.get(first, '?')} — "
                    "two names differing only in case are one name to everything that "
                    "reads them")
                continue
            dst[key] = value
            _record_origin(origin, here, value, fname)
            continue
        if isinstance(dst[key], dict) and isinstance(value, dict) and _mergeable(here):
            _merge_into(dst[key], value, origin, here, fname, problems)
            continue
        problems.append(f"{label} is defined in both {origin.get(label, '?')} and {fname} — "
                        "the halves may divide the spec, never restate a part of it")


def merge_specs(paths):
    """(spec, origin, problems) — the halves read as one document.

    `origin` maps a table path (`pref.x.targets.y`) to the file that defined it,
    so a diagnostic can name the file its offending table came from rather than
    a filename that is now one of several.
    """
    spec, origin, problems = {}, {}, []
    for path in paths:
        fname = spec_name(path)
        try:
            with open(path, "rb") as fh:
                data = tomllib.load(fh)
        except (OSError, tomllib.TOMLDecodeError) as exc:
            problems.append(f"{fname} could not be loaded — {exc}")
            continue
        _merge_into(spec, data, origin, (), fname, problems)
    return spec, origin, problems

NUMERIC = re.compile(r"-?\d+(?:\.\d+)?$")

STATES = ("enforce", "unreachable", "n_a")
MATCHERS = ("want", "want_contains", "want_all_contain", "want_any_contain", "want_any", "want_absent")


class ReadError(Exception):
    """A config could not be read in a way the caller should report, not crash on."""


class ReadSkip(Exception):
    """A live read that cannot honestly run right now — reported as a warn, never a fail.

    The Obsidian reader raises this when the app is not running: a closed app
    is not drift, and a checker must not launch one to find out (see
    _obscap_capture). Deliberately NOT a ReadError subclass, so the main loop
    cannot fold it into "could not read", which is a failure.
    """


def _tool_run(argv, **kw):
    """Run a reader's own tool, or ReadSkip if the machine does not have it.

    Four readers hand the question to the application that owns the format —
    `git config`, `gh config`, `ssh -G`, `defaults read` — which is what makes
    them agree with the application rather than with a parser someone wrote.
    The cost is the binary, and a machine without it is not a machine with
    drift: an absent tool is a measurement that could not be taken, the same
    ReadSkip the defaults oracle raises when kitty is not installed. Without
    this, a checkout on a machine with no `gh` went red on every row naming it.

    A tool named in PREEN_BARE_STUBS is absent too: macOS's /usr/bin stub with
    no Command Line Tools behind it, which raises an install dialog when run.
    pref-check.sh finds those by a file test.
    """
    if os.path.basename(argv[0]) in os.environ.get("PREEN_BARE_STUBS", "").split():
        raise ReadSkip(f"{argv[0]} needs the Command Line Tools here (xcode-select --install)")
    try:
        return subprocess.run(argv, capture_output=True, text=True, **kw)
    except OSError as exc:
        raise ReadSkip(f"{argv[0]} is not installed") from exc


# ── readers ───────────────────────────────────────────────────────────────────
# Most of these are hand-rolled, and the reasons differ. Zed's and Sublime's
# JSON carries comments AND trailing commas (jq fails outright on both);
# kitty.conf is `key value` with no delimiter; tmux.conf is a command script
# rather than a config format at all (see read_tmux). IDEA is plain XML and uses
# the stdlib parser — an earlier version of this comment counted it as
# unparseable, which its own implementation refutes. TOML needs no hand-rolling
# either: the prompts are written in the same format as this spec, so the
# tomllib import above already reads them.
#
# ⚠️ This block has now been wrong about its own contents twice — once about
# IDEA, and once when read_tmux was added and the count above it was not
# updated. Do not reintroduce a number here.


def _strip_jsonc(text):
    """Remove // and /* */ comments and trailing commas, string-aware throughout.

    Both transformations must respect string literals, and for the same reason:
    a `//` inside a URL must survive, and so must a comma inside a string that
    happens to be followed by whitespace and a brace.

    An earlier version walked the text for comments and then ran
    `re.sub(r",(\\s*[}\\]])", r"\\1", …)` over the result — a naive regex that did
    not know about strings, in a function whose own docstring explained why a
    regex cannot do this correctly. It silently turned `{"a": "x, }"}` into
    `{"a": "x }"}`: not an error, a wrong value. Corrected 14-08-2026.
    """
    out = []
    i, n = 0, len(text)
    in_str = False
    # Index into `out` of the last emitted comma that could still turn out to be
    # trailing, or None. Whitespace does not clear it; anything else does.
    pending_comma = None
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            pending_comma = None
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c == ",":
            pending_comma = len(out)
            out.append(c)
            i += 1
            continue
        if c in "}]" and pending_comma is not None:
            out[pending_comma] = ""
            pending_comma = None
            out.append(c)
            i += 1
            continue
        if not c.isspace():
            pending_comma = None
        out.append(c)
        i += 1
    return "".join(out)


def _dotted(data, key):
    """Walk a dotted key path; None the moment a segment is missing.

    Shared by the two structured formats, so a missing key cannot come to mean
    one thing in JSONC and another in TOML.
    """
    cur = data
    for part in key.split("."):
        # A numeric segment indexes a list — `cship.lines.0` is the statusline's
        # first line. Out of range is a missing segment, like any other.
        if isinstance(cur, list) and part.isdigit() and int(part) < len(cur):
            cur = cur[int(part)]
            continue
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def read_jsonc(path, key, **_opts):
    with open(path, encoding="utf-8-sig") as fh:
        data = json.loads(_strip_jsonc(fh.read()))
    return _dotted(data, key)


def read_toml(path, key, **_opts):
    """The TOML surfaces — starship.toml, cship.toml, atuin's config.

    cship renders its first line by invoking Starship, so both files describe
    one prompt and both answer to this reader. Values here are style strings
    ("bold #fabd2f", "fg:#8ec07c") rather than bare colours, which is why the
    palette entries in the spec match on the hex instead of comparing whole.
    """
    with open(path, "rb") as fh:
        data = tomllib.load(fh)
    return _dotted(data, key)


# kitty resolves an `include` INLINE, at the point it appears, so the config is
# one directive stream spanning several files rather than a file plus some
# appendices. Scanning only the named file therefore reports the parent's value
# for any key an include also sets — and kitty.conf here ENDS with its theme
# `include`, so every assertion was one theme edit away from being read wrong.
#
# Every rule below was measured against kitty's own parser rather than inferred
# from its docs (`kitty +runpy` -> kitty.config.load_config, kitty 0.48.2,
# 14-08-2026), each with a control differing only in the thing under test:
#
#   inline, not deferred  include leaf(beam) and THEN `cursor_shape block`
#                         yields block. Deferred includes would yield beam.
#   overrides the parent  `cursor_shape block` then include child(underline)
#                         yields underline; the same file with the include line
#                         removed yields block.
#   twice means once      include leaf(beam), `cursor_shape block`, include leaf
#                         yields block — the repeat include is dropped, so the
#                         guard below must be a permanent set and not a
#                         recursion stack.
#   continuation          a line whose stripped form starts with `\` continues
#                         the previous one; leading whitespace and the `\` are
#                         removed and the halves join with no separator.
#
# ⚠️ ONE MEASURED DIVERGENCE, deliberately not reproduced. Given an include
# CYCLE (a includes b, b includes a) kitty discards the WHOLE of b — a's own
# settings survive and b's are dropped entirely, which `scrollback_lines 12345`
# in a and `cursor_shape underline` in b confirmed independently. This reader
# skips only the re-entry, so it would report b's values. Matching kitty needs
# parse-into-a-buffer-then-discard, and the case cannot arise in a config with
# no include cycle. Recorded rather than silently claimed as parity.
KITTY_FILE_INCLUDES = ("include", "globinclude")
KITTY_OPAQUE_INCLUDES = ("envinclude", "geninclude")


def _kitty_include_targets(directive, spec, base):
    """Resolve an include spec to concrete paths the way kitty does.

    A relative path resolves against the INCLUDING file's directory, not the
    top-level one, and environment variables are expanded — kitty documents
    `${USER}.conf` and a synthetic `KITTY_OS`.
    """
    spec = os.path.expandvars(spec)
    if not os.path.isabs(spec):
        spec = os.path.join(base, spec)
    if directive == "globinclude":
        return sorted(glob.glob(spec, recursive=True))
    return [spec]


def _kitty_directives(path, seen=None):
    """Yield (key, value) for every directive kitty applies, includes expanded.

    Two different notions of "where this file is" are needed, and conflating
    them is a real bug rather than a nicety:

      identity — realpath, for the already-included guard. Two spellings of one
                 file must count as one, or the dedup and cycle guards miss.
      location — the LOGICAL directory, for resolving relative includes.

    ⚠️ kitty resolves an include against the directory of the path it was GIVEN,
    not the directory the symlink points into. Measured, because this is exactly
    the live shape here — `~/.config/kitty/kitty.conf` is a symlink into this
    repo, and both directories happen to contain a same-named theme conf, so a
    reader that follows the symlink first gets the right answer by luck and the
    wrong file by construction. Control: a symlinked config whose two candidate
    directories hold DIFFERENT leaf files resolves to the one beside the
    symlink under `kitty.config.load_config`. Using realpath here read the other
    one; found 14-08-2026.
    """
    if seen is None:
        seen = set()
    real = os.path.realpath(path)
    if real in seen:
        return
    seen.add(real)
    # A missing include is not an error to swallow — kitty warns and carries on,
    # so contributing nothing is what the application actually does.
    if not os.path.isfile(real):
        return
    with open(real, encoding="utf-8-sig") as fh:
        text = fh.read()

    logical = []
    for raw in text.splitlines():
        stripped = raw.strip()
        if stripped.startswith("\\") and logical:
            logical[-1] += stripped[1:]
        else:
            logical.append(stripped)

    base = os.path.dirname(os.path.abspath(path))
    for line in logical:
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        directive = parts[0]
        value = parts[1].strip() if len(parts) > 1 else ""
        if directive in KITTY_OPAQUE_INCLUDES:
            raise ReadError(
                f"{os.path.basename(real)} uses `{directive}`, which kitty resolves from "
                "the environment or a subprocess — this reader cannot see it, and "
                "answering from the rest of the file would report a partial config as "
                "if it were the whole one"
            )
        if directive in KITTY_FILE_INCLUDES:
            for target in _kitty_include_targets(directive, value, base):
                yield from _kitty_directives(target, seen)
            continue
        yield directive, value


def read_kitty(path, key, accumulate=False, **_opts):
    """Last occurrence wins for scalars; every occurrence for accumulating keys.

    kitty has two classes of directive and they behave oppositely. `font_size`
    and `cursor_shape` are scalars — a later line replaces an earlier one. But
    `font_features`, `map`, `symbol_map`, `env` and `modify_font` ACCUMULATE:
    every line stays live, keyed by its first argument.

    Reading only the last of those was a real defect, not a theoretical one.
    kitty.conf carries `font_features` twice, once per face, and the checker
    returned only the Bold line — so the ligature assertion was green while
    reading a line the preference was not about, and deleting `+calt` from the
    Regular face would not have failed it. Found 14-08-2026.

    `accumulate` is opt-in per spec entry rather than inferred: guessing from
    "did this key appear twice?" would silently switch semantics the first time
    someone set a scalar twice.

    ⚠️ `map` and `mouse_map` accumulate but are NOT a flat list, and reading
    them as one is its own wrong-line defect. A binding is keyed by its key
    spec, a later line for the same spec REPLACES the earlier one, a spec with
    no action UNMAPS it, and `clear_all_shortcuts` / `clear_all_mouse_actions`
    discard everything declared above them. A flat read reports a binding that
    a line further down has already overridden or deleted — so `want_any` on
    the intended action stays green over a config that no longer does it.
    Overridden lines are dropped here; an unmap is KEPT, as its bare key spec,
    because the preference "this key does X" must fail on it and the ctrl+shift
    ceiling probe reads the unmaps to decide whether the plane is still kitty's.
    """
    if accumulate and key in ("map", "mouse_map"):
        return _kitty_bindings(path, key) or None
    found = [value for name, value in _kitty_directives(path) if name == key]
    if not found:
        return None
    return found if accumulate else found[-1]


# kitty's own modifier spellings — its `mod_map` (options/utils.py, frozen
# bytecode, 10-09-2026): ctrl/control/⌃, shift/⇧, alt/opt/option/⌥,
# super/cmd/command/⌘, and kitty_mod/kitty. Two lines that spell one chord
# differently are ONE binding to kitty, and were two entries here until an
# audit planted `map super+t new_tab` over `map cmd+t new_tab_with_cwd` and
# watched the row stay green; the symbols and the bare `kitty` were the next
# audit's finding, the same day.
_KITTY_MODS = {
    "control": "ctrl", "⌃": "ctrl", "⇧": "shift",
    "cmd": "super", "command": "super", "⌘": "super",
    "opt": "alt", "option": "alt", "⌥": "alt",
    "kitty": "kitty_mod",
}
# kitty's key-name alias tables, read off its frozen key_names.py at 0.48.2
# (10-09-2026). `parse_shortcut` resolves the final token through them by its
# UPPERCASE form, so `cmd+return` and `cmd+enter` are one binding, as are
# `ctrl+plus`, `ctrl++` and `ctrl+PLUS`.
_KITTY_FUNCTIONAL_ALIASES = {
    "ESC": "ESCAPE", "PGUP": "PAGE_UP", "PAGEUP": "PAGE_UP", "PGDN": "PAGE_DOWN",
    "PAGEDOWN": "PAGE_DOWN", "RETURN": "ENTER", "ARROWUP": "UP", "ARROWDOWN": "DOWN",
    "ARROWRIGHT": "RIGHT", "ARROWLEFT": "LEFT", "DEL": "DELETE",
    "KP_PLUS": "KP_ADD", "KP_MINUS": "KP_SUBTRACT",
}
_KITTY_CHARACTER_ALIASES = {
    "SPC": " ", "SPACE": " ", "STAR": "*", "MULTIPLY": "*", "PLUS": "+", "MINUS": "-",
    "BAR": "|", "PIPE": "|", "HYPHEN": "-", "EQUAL": "=", "UNDERSCORE": "_", "COMMA": ",",
    "PERIOD": ".", "DOT": ".", "SLASH": "/", "BACKSLASH": "\\", "TILDE": "~", "GRAVE": "`",
    "GRAVE_ACCENT": "`", "APOSTROPHE": "'", "SEMICOLON": ";", "COLON": ":",
    "LEFT_BRACKET": "[", "RIGHT_BRACKET": "]",
}
# Every `map` option takes a value, in `--x v` or `--x=v` form, and an unknown
# `--x` is a hard error — read off kitty's `parse_options_for_map` (frozen
# bytecode, 10-09-2026): each `--` word is partitioned on `=`, and when there
# is no `=` the NEXT word is the value. So there is no boolean flag to special-
# case, and a reader that consumes the next token for every bare `--x` is
# exactly kitty's rule. A four-name allowlist stood here for a day and keyed
# `--on-unknown end ctrl+x …` on `end`, so a later mode-entering line never
# overrode the ctrl+x above it: three of kitty's seven options were missing.


def _kitty_keyspec(spec, kitty_mod):
    """One key spec in a canonical form, so kitty's spellings of it agree.

    Modifiers are aliased, `kitty_mod` is expanded, and the modifier SET is
    sorted — kitty does not care about their order. The final key token
    follows `parse_shortcut` (frozen bytecode, 10-09-2026) step for step: a
    trailing `+` is the `plus` key; the token's UPPERCASE form is looked up in
    the character-alias table, which also maps each capital letter to its
    lowercase (so `cmd+T` is `cmd+t`, and `ctrl+PLUS`, `ctrl+plus`, `ctrl++`
    are all `+`); what is then a single character is that character (a
    non-ASCII one as written, so `ö` and `Ö` stay two keys); anything longer
    is uppercased and passed through the functional-alias table, so `F7`,
    `f7`, `Return`, `enter` and `ESCAPE`/`esc` land where kitty lands them.
    Not modelled: the native keysym lookup a name reaches only when every
    table misses, and whatever the keyboard layout does with a character.
    """
    chords = []
    for chord in str(spec).split(">"):
        if chord.endswith("+") and len(chord) > 1:
            chord = chord[:-1] + "plus"
        parts = chord.split("+")
        mods, base = parts[:-1], parts[-1]
        base = _KITTY_CHARACTER_ALIASES.get(base.upper(), base)
        if len(base) == 1:
            base = base.lower() if base.isascii() else base
        else:
            base = _KITTY_FUNCTIONAL_ALIASES.get(base.upper(), base.upper())
        expanded = []
        for m in mods:
            m = _KITTY_MODS.get(m.strip().lower(), m.strip().lower())
            expanded.extend(kitty_mod if m == "kitty_mod" else [m])
        chords.append("+".join(sorted(set(expanded)) + [base]))
    return ">".join(chords)


def _kitty_bindings(path, key):
    """Every `map`/`mouse_map` line still in force, in first-declaration order.

    Order is kept stable so a reader of the output sees the config's own shape;
    a re-declaration updates its entry in place rather than moving to the end.

    Identity is the canonical key spec — for `mouse_map`, the button, the event
    AND the modes, all three of which kitty's grammar requires
    (`mouse_map button-name event-type modes action`): `left click` and
    `left press` are different bindings and both are live.

    Flags are stripped from the IDENTITY while the whole line stays the VALUE.
    That makes a mode-scoped mapping collide with a global one on the same key,
    which is wrong — but wrong in the safe direction: the surviving value still
    carries its flags, so an exact or substring matcher fails rather than
    passing. A false red is a prompt to read the line; a false green is not.
    """
    clear = "clear_all_shortcuts" if key == "map" else "clear_all_mouse_actions"
    # kitty_mod is a scalar and last-wins, so it is resolved before the pass.
    raw_mod = None
    for name, value in _kitty_directives(path):
        if name == "kitty_mod":
            raw_mod = value
    kitty_mod = sorted({_KITTY_MODS.get(m.strip().lower(), m.strip().lower())
                        for m in str(raw_mod or "ctrl+shift").split("+") if m.strip()})

    live = {}
    for name, value in _kitty_directives(path):
        if name == clear and str(value).strip().lower() in ("yes", "y", "true"):
            live.clear()
            continue
        if name != key:
            continue
        # kitty tokenises the option prefix with a shell lexer, so a quoted
        # value (`--new-mode "my mode"`) is one word; `str.split` would hand
        # `mode"` to the identity. An action argument with an unbalanced quote
        # would make shlex refuse the whole line, and the plain split is the
        # fallback for that — the identity is in the first words either way.
        try:
            tokens = shlex.split(str(value))
        except ValueError:
            tokens = str(value).split()
        rest = []
        i = 0
        while i < len(tokens):
            t = tokens[i]
            if not t.startswith("-"):
                rest = tokens[i:]
                break
            if "=" not in t:
                i += 1  # a bare option's value is the next token, not the key spec
            i += 1
        if not rest:
            continue
        if key == "map":
            ident = _kitty_keyspec(rest[0], kitty_mod)
        else:
            # button, event, modes — a partial line cannot be resolved, so it
            # keys on what it has rather than colliding with a complete one.
            ident = " ".join([_kitty_keyspec(rest[0], kitty_mod)]
                             + [t.lower() for t in rest[1:3]])
        live[ident] = str(value).strip()
    return list(live.values())


def read_kitty_blocks(path, key, **_opts):
    """One `open-actions.conf` entry as a whole, addressed `block1`, `block2`, …

    open-actions.conf shares kitty's `key value` grammar, so the ordinary kitty
    reader parses it — but that reader FLATTENS the file, and this file's
    meaning is not flat. kitty takes the first ENTRY whose criteria all match,
    entries are separated by blank lines, and an entry's `action` belongs to the
    criteria above it. Read flat, the directives are a bag: swap which action
    sits in which entry, or move `mime text/*` ahead of the fragment entry —
    which tests no mime, so a text file's `#line` link matches both — and every
    row stays green while the click lands somewhere else. Order is the behaviour
    here, so the unit of assertion is the entry, in file order.
    """
    hit = re.fullmatch(r"block([1-9]\d*)", key)
    if hit is None:
        # `block0` and `block01` are addresses that cannot mean what they look
        # like. Refusing beats answering "absent", which a want_absent row
        # would read as a pass.
        raise ReadError(f"kittyblocks keys are block1, block2, …; got '{key}'")
    with open(path, encoding="utf-8-sig") as fh:
        text = fh.read()
    # Same refusal as _kitty_directives: an unresolvable include means the file
    # in hand is not the whole config, and every index below it would shift.
    for line in text.splitlines():
        first = line.strip().split(None, 1)[0] if line.strip() else ""
        if first in ("include", "globinclude", "envinclude"):
            raise ReadError(f"{os.path.basename(path)} has an `{first}` — this reader "
                            "addresses entries by position and cannot resolve one")
    blocks = []
    for chunk in re.split(r"\n[ \t]*\n", text):
        logical = []
        for raw in chunk.splitlines():
            stripped = raw.strip()
            if stripped.startswith("\\") and logical:
                logical[-1] += stripped[1:]          # kitty's continuation
            elif stripped and not stripped.startswith("#"):
                logical.append(stripped)
        if logical:
            blocks.append("; ".join(logical))
    index = int(hit.group(1))
    return blocks[index - 1] if index <= len(blocks) else None


def read_idea(path, key, **_opts):
    """`COMPONENT/OPTION`, `COMPONENT/ELEMENT@ATTR`, or a bare `OPTION`.

    The bare form exists because codestyles/*.xml puts options directly under
    <code_scheme> with no <component> wrapper, unlike options/*.xml. A bare key
    matching more than once is an ERROR rather than a first-match-wins guess —
    codestyles/Default.xml already carries two `CODE_STYLE_DEFAULTS` options, so
    silently taking the first would be a coin flip presented as a fact.

    The `ELEMENT@ATTR` form was added 07-09-2026 because IDEA's active theme is
    not an <option> at all: laf.xml carries `<laf themeId="..."/>` and
    colors.scheme.xml `<global_color_scheme name="..."/>`. That put the one
    value most likely to be changed by a stray click outside every reader, so
    `editor_theme / idea_editor` sat `n_a` and NOTHING asserted it — while the
    name was written out in five living places. All five went stale together
    when the theme moved to the Soft variant, and the only thing that noticed
    was a copy-mode byte diff. Same >1 rule as the bare form, same reason.

    No defusedxml dependency. These files are written by IDEA on this machine,
    so anyone able to poison them already has code execution and XXE buys them
    nothing. The one class worth closing cheaply is entity expansion, which
    needs a DOCTYPE — IDEA never emits one, so rejecting it costs nothing and
    is not a judgement call about severity.
    """
    with open(path, encoding="utf-8-sig") as fh:
        text = fh.read()
    if "<!DOCTYPE" in text:
        raise ReadError("refusing to parse XML with a DOCTYPE")
    root = ET.fromstring(text)
    if "/" in key:
        comp_name, opt_name = key.split("/", 1)
        for comp in root.iter("component"):
            if comp.get("name") == comp_name:
                if "@" in opt_name:
                    el_name, attr = opt_name.split("@", 1)
                    hits = [e.get(attr) for e in comp.iter(el_name)
                            if e.get(attr) is not None]
                    if len(hits) > 1:
                        raise ReadError(
                            f"'{el_name}@{attr}' matches {len(hits)} elements in {comp_name}")
                    return hits[0] if hits else None
                for opt in comp.iter("option"):
                    if opt.get("name") == opt_name:
                        return opt.get("value")
        return None
    hits = [o.get("value") for o in root.iter("option") if o.get("name") == key]
    if len(hits) > 1:
        raise ReadError(f"bare key '{key}' matches {len(hits)} options — scope it as COMPONENT/{key}")
    return hits[0] if hits else None


TMUX_SET = ("set", "set-option", "setw", "set-window-option")
TMUX_BIND = ("bind", "bind-key")
TMUX_UNBIND = ("unbind", "unbind-key")
# A condition evaluated at run time, unlike %if which this reader can at least
# SEE. A bind inside one is refused rather than missed.
TMUX_INLINE_IF = ("if-shell", "if")
TMUX_BIND_WORD = re.compile(r"\b(bind|bind-key|unbind|unbind-key)\b")
# The same coarse test for the other direction: a conditional that pulls in a
# file. `\bsource\b` catches `source-file` too, the hyphen being a boundary.
TMUX_SOURCE_WORD = re.compile(r"\bsource\b")
TMUX_OPAQUE = ("source", "source-file")
# %else and %elif stay inside the block %if opened, so only these two move depth.
TMUX_BLOCK_OPEN, TMUX_BLOCK_CLOSE = "%if", "%endif"
TMUX_CONDITIONAL = ("%if", "%elif", "%else", "%endif")


def _tmux_logical_lines(text):
    """Join continuations.

    Measured: tmux drops the backslash and the newline and KEEPS the next
    line's indentation, where kitty strips it — `"part-one \\"` + `"   part-two"`
    comes back with four spaces. The two directive-stream readers are not
    interchangeable.
    """
    out, pending = [], ""
    for raw in text.split("\n"):
        if raw.endswith("\\"):
            pending += raw[:-1]
            continue
        out.append(pending + raw)
        pending = ""
    if pending:
        out.append(pending)
    return out


def _tmux_commands(line):
    r"""Split one logical line into commands and drop any trailing comment.

    Both rules are measured, and the first version of this reader had both
    wrong:

      comment    `#` opens a comment only at the start of a WORD. `set -g @k
                 #fabd2f` leaves the option unset because tmux ate the value as
                 a comment, while unquoted `set -g status-style bg=#1d2021`
                 resolves fine. Leaving the comment for shlex — the original —
                 meant one apostrophe in one unrelated comment ("don't") raised
                 "No closing quotation" and failed EVERY assertion against a
                 file tmux reads happily. Handing shlex `comments=True` instead
                 is not the fix: it would cut the unquoted `bg=#1d2021` case
                 that currently works.
      separator  `;` ends a command, `\;` does not. Without this a second
                 command on the same line became value tokens of the first, and
                 the reader reported the FIRST value where tmux resolves the
                 second — silently.
    """
    cmds, cur, quote, i, word_start = [], "", None, 0, True
    while i < len(line):
        c = line[i]
        if quote:
            # A backslash escapes inside DOUBLE quotes only — tmux and shlex
            # agree, and the deployed config relies on the single-quoted half
            # (`\E[...` sequences stay literal there). Without this the string
            # closes early at an escaped quote, and everything after it reparses
            # as unquoted: `"a\"b #fabd2f"` turned the `#` into a word-initial
            # comment and took the rest of the FILE with it, the same blast
            # radius as the apostrophe bug this scanner was written to fix.
            if c == "\\" and quote == '"' and i + 1 < len(line):
                cur += line[i:i + 2]
                i += 2
                continue
            cur += c
            if c == quote:
                quote = None
            i, word_start = i + 1, False
            continue
        if c in "'\"":
            quote, cur, i, word_start = c, cur + c, i + 1, False
            continue
        if c == "\\" and i + 1 < len(line):
            cur += line[i:i + 2]
            i, word_start = i + 2, False
            continue
        if c == "#" and word_start:
            break
        if c == ";":
            cmds.append(cur)
            cur, i, word_start = "", i + 1, True
            continue
        cur += c
        word_start, i = c.isspace(), i + 1
    cmds.append(cur)
    return [c for c in (seg.strip() for seg in cmds) if c]


def _tmux_raw_commands(text):
    """Yield (parts, segment) for every non-empty command in one file's text.

    A generator of its own so `_tmux_segments` can pull the NEXT command while
    gathering an `if-shell` block body.
    """
    for line in _tmux_logical_lines(text):
        for segment in _tmux_commands(line):
            try:
                parts = shlex.split(segment, comments=False)
            except ValueError as exc:
                raise ReadError(f"unparseable tmux line ({exc}): {segment[:60]}") from exc
            if parts:
                yield parts, segment


def _tmux_names(word, text):
    """Does `text` use `word` as a whole tmux name?

    Coarse on purpose — the twin of TMUX_BIND_WORD, and used for the same job:
    deciding whether a run-time condition is about the thing being asked for.
    The boundaries know tmux's name alphabet rather than Python's `\\b`, so
    `status-left` does not match inside `status-left-length` and `@probe` does
    not match inside `@probe2`. Over-matching here costs a refusal; under-
    matching costs a wrong answer reported as a fact.
    """
    return re.search(rf"(?<![\w@-]){re.escape(word)}(?![\w-])", text) is not None


def _tmux_follow_path(head, parts, path, host):
    """The file a `source-file` line brings in — or a ReadError saying why not.

    Exactly one form is followed, the overlay hook the deployed config carries:
    `source-file -q <one plain path>`. It is the only one with both properties a
    reader needs, measured against tmux 3.7c on an isolated socket:

      in place   a base that sets an option and THEN sources an overlay setting
                 it resolves to the OVERLAY's value; move the source line above
                 the base's own `set` and the same two files resolve to the
                 BASE's. So the include is a position in one stream, not a merge
                 of two files.
      silent     `-q` on a missing path loads rc=0, the lines after it still
                 apply, and an attached client sees nothing. WITHOUT -q the same
                 line puts an attached client's pane into view-mode showing the
                 path, so such a file is not self-contained. Only an ATTACHED
                 client is told: `start-server` and a detached session are quiet
                 either way, which is what made the first two controls agree
                 when they should have differed.

    Everything else is refused, each because what it brings in is not a function
    of the text here: another flag (-F, -n, -v, -t) changes what is read or how,
    a glob or a `#{format}` resolves against the filesystem or the server rather
    than the file, and a relative path resolves against the SERVER's cwd — the
    same fixture answered RELATIVE-FOUND from one directory and NOTFOUND from
    another, and nothing in the file says which. A `host` target is refused
    outright: its file is fetched off the box to a local temp path, so following
    anything would read THIS machine's overlay and report it as the box's — a
    wrong answer that looks right.

    ⚠️ One refusal is scope, not parity: tmux DOES read several paths from one
    `source-file -q a b`, in order — measured, both options came back set. The
    hook is one optional overlay, so a list is refused rather than followed.
    Recorded so the next reader knows this is a choice and not a gap.
    """
    idx = 1
    while idx < len(parts) and parts[idx].startswith("-") and parts[idx] != "-":
        idx += 1
    flags, args = parts[1:idx], parts[idx:]
    where = f"{os.path.basename(path)} uses `{head}"

    if host:
        raise ReadError(
            f"{where}` and lives on {host} — its file is read here as a local copy, so "
            "following that path would answer with this machine's file"
        )
    if flags != ["-q"]:
        raise ReadError(
            f"{where}{' ' + ' '.join(flags) if flags else ''}`, and only `{head} -q` is "
            "followed — without -q a missing file is an error tmux shows the client, and "
            "any other flag changes what is read"
        )
    if len(args) != 1:
        raise ReadError(
            f"{where} -q` with {len(args)} paths — one overlay is followed, not a list"
        )
    target = os.path.expanduser(args[0])
    if any(c in target for c in "*?[") or "#{" in target:
        raise ReadError(
            f"{where} -q {args[0]}`, whose path is a glob or a format — what it names is "
            "decided by the filesystem or the server, not by this file"
        )
    if not os.path.isabs(target):
        raise ReadError(
            f"{where} -q {args[0]}`, a relative path — tmux resolves it against the "
            "server's cwd, which this file does not say"
        )
    return target


def _tmux_segments(path, host=None, chain=(), depth=0):
    """Yield (parts, segment, depth) for every command the tmux readers see.

    ONE stream, with a followed `source-file` expanded in place — so last-wins,
    `-u`, `unbind`, the `-a` refusals and the %if depth all carry across the
    boundary with no rule restated. Both readers walk this, which is what keeps
    the follow rule from drifting between them.

    A missing followed file contributes nothing, silently: that is what tmux
    does with -q, so there is no error to swallow. A followed file that leads
    back to one still open on the way in is a cycle and is refused. The guard is
    the CHAIN and not a permanent set, because tmux has no include-once — the
    same file sourced twice in sequence really is applied twice, and the second
    one wins.

    ⚠️ An `if-shell` is yielded WHOLE, its `{ … }` body gathered into the
    segment text, because the body does not arrive nested. Measured: a block
    written across lines hands this scanner `if-shell 'true' {`, then the body's
    `set` as an ordinary top-level command, then a bare `}` — so a reader that
    looked only at heads read the body as unconditional. With
    `if-shell 'false' { set -g @probe IFFALSE }` spread over lines the option
    reader answered IFFALSE where tmux resolves BASE: a value off a branch that
    never ran. Gathering hides the body from both readers, which then refuse the
    construct as a whole. The same block written on ONE line was already one
    command, and answered BASE — wrong the other way, from the same hole.
    """
    real = os.path.realpath(path)
    if real in chain:
        raise ReadError(
            f"{os.path.basename(path)} sources a file that sources it back — a cycle, "
            "so no part of it is the whole config"
        )
    chain = chain + (real,)

    with open(path, encoding="utf-8-sig") as fh:
        text = fh.read()

    stream = _tmux_raw_commands(text)
    for parts, segment in stream:
        head = parts[0]
        if head in TMUX_CONDITIONAL:
            if head == TMUX_BLOCK_OPEN:
                depth += 1
            elif head == TMUX_BLOCK_CLOSE:
                depth = max(0, depth - 1)
            continue
        if head in TMUX_OPAQUE:
            if depth:
                raise ReadError(
                    f"{os.path.basename(path)} sources a file inside a %if block — "
                    "this reader cannot evaluate the condition, so whether those "
                    "directives apply at all would be a guess"
                )
            target = _tmux_follow_path(head, parts, path, host)
            if os.path.isfile(target):
                yield from _tmux_segments(target, host, chain, depth)
            continue
        if head in TMUX_INLINE_IF:
            # Braces are counted as whole TOKENS: `{` opens a block only as an
            # argument of its own, so a format condition like `#{==:1,1}` — one
            # token, carrying both braces — is not mistaken for one.
            braces = parts.count("{") - parts.count("}")
            while braces > 0:
                nxt = next(stream, None)
                if nxt is None:
                    raise ReadError(
                        f"{os.path.basename(path)} leaves a `{head}` block unclosed, so "
                        "where the condition stops governing is not in the file"
                    )
                segment += " " + nxt[1]
                braces += nxt[0].count("{") - nxt[0].count("}")
            if TMUX_SOURCE_WORD.search(segment):
                raise ReadError(
                    f"{os.path.basename(path)} sources a file inside `{head}`, a condition "
                    "evaluated at run time — what it brings in is conditional, so no part "
                    "of this file is the whole config"
                )

        yield parts, segment, depth


def read_tmux(path, key, accumulate=False, host=None, **_opts):
    """`set -g key value` — last occurrence wins, matching kitty's scalar contract.

    ⚠️ **tmux.conf is a command script, not a config format.** It has a statement
    separator, a conditional preprocessor, flags that change how a value is
    stored, and two ways to bring in directives from outside the file. Reading
    it as `key value` lines is what produced every defect an audit found here on
    25-08-2026. This reader models the subset that behaves like a config and
    REFUSES the rest — a refusal is a failed assertion, a guess is a green one.

    Measured against tmux 3.7c's own parser on an isolated socket
    (`tmux -L probe -f fixture new-session -d`, then `show-options -gv`):

      last wins      the same `set -g` twice returns the SECOND value.
      one namespace  a `setw` key answers to `show-options -g` as readily as to
                     `show-window-options -g`, so the file reads as one stream.
      quotes         single and double are both stripped, inner spaces kept.
      -u             on a USER option (`@name`) the option is removed outright,
                     so unset is the right answer. On a BUILT-IN it reverts to
                     tmux's DEFAULT — `status-left` came back as
                     `[#{session_name}] `, not absent — which this reader cannot
                     supply, so that half is refused. The first version claimed
                     removal for both, having measured only the user half.

    Refused rather than answered, each because the live value is not a function
    of this file alone:

      -a           appends to whatever the option already held: tmux's built-in
                   default for a built-in, or an earlier value. `set -ga
                   update-environment APPENDED` came back as tmux's own built-in
                   list plus the appended entry — a value no amount of reading
                   this file produces.
      -F           expands formats at set time, so `#{host}` is stored as the
                   hostname.
      -o           declines to overwrite an already-set option, which makes
                   last-wins the wrong rule.
      no -g        sets a session-scope option that shadows the global this
                   reader models.
      %if          a branch this reader cannot evaluate. Refused only when the
                   REQUESTED key is set inside one, so an unrelated block costs
                   nothing.
      if-shell     a condition evaluated at RUN time, refused on the same
                   key-scoped terms. read_tmux_bind has refused this shape for
                   bindings since 09-09-2026 and this reader had no twin until
                   17-09-2026: `if-shell 'true' 'set -g @probe IFSET'` resolves
                   to IFSET in tmux and read as BASE here, silently, because the
                   head is not a `set`. `if` is the same command.
      source-file  in every form but the one `_tmux_segments` follows — the
                   `-q` overlay hook with a single plain path, read in place.
                   Each refused form (no -q, another flag, several paths, a glob
                   or format, a path inside %if, a cycle, or any of it on a
                   `host` target) is refused there, with the measurement.

    ⚠️ NOT refused, and this reader's real boundary: `run` / `run-shell`. The
    deployed tmux.conf's last line runs tpm (`run` inside an `if-shell` guard),
    and a plugin can write options at runtime — tmux-continuum writes
    `status-right` (continuum.tmux:42). Refusing would make the reader useless
    against any config with a plugin manager, so its scope is what the FILE
    declares. Measured 25-08-2026: no loaded plugin writes any asserted key.
    Re-run the grep rather than trusting this sentence:
      grep -rE 'set(_tmux_option|-option)?.*<key>' ~/.config/tmux/plugins
    """
    found = []
    for parts, segment, depth in _tmux_segments(path, host):
        head = parts[0]
        if head in TMUX_INLINE_IF:
            # The twin of read_tmux_bind's guard, scoped to the requested key
            # the way %if is. Silence here is not neutral: it hands back the
            # value from OUTSIDE the condition as though the condition were not
            # there, which is the answer tmux gives only when the branch happens
            # not to run.
            if _tmux_names(key, segment):
                raise ReadError(
                    f"`{key}` is decided by `{head}`, a condition evaluated at run time — "
                    "this reader cannot run it, and answering from the rest of the file "
                    "would report the unconditional value as the live one"
                )
            continue
        if head not in TMUX_SET:
            continue

        # Flags are the LEADING dash tokens only. Partitioning the whole
        # token list instead — the original — pulled a value starting with
        # `-` into the flag cluster, which emptied the value, and folded its
        # letters into the flag test: `set -g @k "-x-marks"` raised a
        # fabricated "-a (append)" diagnostic off the `a` in `marks`.
        idx = 1
        while idx < len(parts) and parts[idx].startswith("-") and parts[idx] != "-":
            idx += 1
        flags, rest = parts[1:idx], parts[idx:]
        if not rest or rest[0] != key:
            continue

        if depth:
            raise ReadError(
                f"`{key}` is set inside a %if block — this reader cannot evaluate the "
                "condition, and taking a branch would be a guess reported as a fact"
            )

        cluster = "".join(f.lstrip("-") for f in flags)
        for flag, why in (
            ("a", "appends to whatever the option already held (a built-in default, or an "
                  "earlier value) — not reconstructable from this file"),
            ("F", "expands formats at set time, so the stored value is not the text here"),
            ("o", "declines to overwrite an already-set option, so last-wins does not apply"),
        ):
            if flag in cluster:
                raise ReadError(f"`{key}` is set with -{flag}, which {why}")
        if "g" not in cluster:
            raise ReadError(
                f"`{key}` is set without -g — that is a session-scope option shadowing the "
                "global this reader models, and the two can differ"
            )
        if "u" in cluster:
            # A user option is genuinely removed; a built-in reverts to a
            # default this reader has no way to name.
            if key.startswith("@"):
                found = []
                continue
            raise ReadError(
                f"`{key}` is unset with -u, which reverts a built-in option to tmux's own "
                "default rather than removing it — this reader cannot supply that default"
            )

        found.append(rest[1] if len(rest) > 1 else "")

    if not found:
        return None
    return found if accumulate else found[-1]


def _tmux_bind_scope(key):
    """Split an assertion key into (table, keystroke).

    Bindings live in named tables and the same keystroke means different things
    in each — `v` is begin-selection in copy-mode-vi and unbound in prefix — so
    the table is required rather than defaulted, the way a bare option name is
    scoped as COMPONENT/key elsewhere in this file. Partition on the FIRST
    slash, so a binding on the slash key itself is written `prefix//`.
    """
    table, sep, stroke = key.partition("/")
    if not sep or not table or not stroke:
        raise ReadError(
            f"tmux binding key '{key}' is not scoped to a table — write it as "
            "TABLE/KEYSTROKE (prefix/|, root/M-Left, copy-mode-vi/v)"
        )
    return table, stroke


def _tmux_key_norm(stroke):
    """One spelling per keystroke, so a comparison cannot miss a shadowing line.

    tmux folds the case of a NAMED key and of a modifier prefix — `bind left`
    and `bind M-LEFT` bind Left and M-Left — while a single-character key stays
    literal, `h` and `H` being different keys. A byte comparison therefore read
    `bind left select-pane -R` as "Left is not bound", which is a want_absent
    row's passing answer over a line that both shadows the arrow and points it
    the wrong way. Measured against tmux on both installed versions.

    The output is a canonical form for comparison only, never shown to anyone.
    Modifiers are sorted so `C-M-h` and `M-C-h` meet.
    """
    mods, rest = set(), stroke
    while len(rest) > 2 and rest[1] == "-" and rest[0] in "CcMmSs":
        mods.add(rest[0].upper())
        rest = rest[2:]
    if rest == " ":
        rest = "Space"                      # tmux canonicalises a literal space
    if len(rest) > 1:
        rest = rest.lower()
    return "".join(sorted(mods)) + "|" + rest


def read_tmux_bind(path, key, accumulate=False, host=None, **_opts):
    """`bind [-nr] [-T table] key command…` — the key table, which read_tmux cannot see.

    read_tmux models the `set` stream and skips every other command, so until
    this reader existed not one binding in either deployed tmux.conf was
    asserted by anything. No such assertion was ever written — but one aimed at
    read_tmux to prove a binding GONE would have passed vacuously, since no
    `set` line ever carries a keystroke, and that is why the absence rows in
    pref.tmux_keys are routed through here instead.

    ⚠️ That hazard does not end at the reader boundary: a None from ANY reader
    is a `want_absent` row's passing answer. So every way this reader can fail
    to see a binding is a way for such a row to go green over the very line it
    was written to catch. An audit on 09-09-2026 found four, all now closed and
    all covered by tests/battery/2026-09-09-tmuxbind-reader.sh: clustered
    `-rT`/`-nT`/`-rN` flags, a glued `-N'note'`, a key spelled in another case,
    and a bind inside `if-shell`. Add a case there before trusting a new one.

    The key is `TABLE/KEYSTROKE`; the value is the command with its arguments,
    rejoined after shlex. Rejoining is what makes one assertion cover both
    machines: the Mac writes `-c "#{pane_current_path}"` and the box writes it
    single-quoted, and shlex strips either, so both read as the same string.

    tmux semantics this reader follows:

      last wins    a second `bind` of the same key in the same table replaces
                   the first, so the assertion sees the effective binding.
      unbind       clears what came before it for that key, so `bind h …` then
                   `unbind h` reads as unset — the answer tmux gives.
      -n           is `-T root`, and `-T` wins over it: `bind -nT copy-mode-vi X`
                   lands in copy-mode-vi.
      -T, -N       take an argument, which may be glued into the same token or
                   clustered behind other flags (`-rT prefix h`, `-N'note' g`).
                   Consuming the whole token as one opaque flag read the
                   argument as the keystroke and lost the binding.
      key spelling a NAMED key and a modifier prefix fold case (`left` binds
                   Left), a single-character key does not (`h` and `H` differ),
                   and a literal space is Space. Compared through
                   `_tmux_key_norm`, never byte-for-byte.

    Refused rather than answered, each because the table is then not a function
    of this file alone:

      -a           clears a whole table at once — refused when it names the
                   table being asked about, ignored when it names another.
      %if          a branch this reader cannot evaluate, refused only when the
                   REQUESTED binding sits inside one.
      if-shell     a run-time condition, refused whenever it wraps a bind at
                   all: unlike `%if` there is no branch to look inside.
      source-file  in every form but the `-q` overlay hook `_tmux_segments`
                   follows. An overlay's bindings are read in place, so it can
                   `unbind` a key the base bound and the key reads as not bound
                   — measured: `list-keys -T prefix` over that pair shows the
                   overlay's binding and no trace of the base's.

    ⚠️ Scope: the FILE's bindings. Two things live outside it. Stock bindings
    are not here at all — `prefix Left` is select-pane in tmux's own table and
    no line declares it, so what this reader can assert about a stock key is
    that nothing in the file SHADOWS it (`want_absent`). And tpm writes
    bindings at runtime; the Mac's prefix table gains five that way, and `run`
    is not refused here for the same reason read_tmux does not refuse it.

    ⚠️ `-r` (repeatable) is not exposed. The value is the command only, so an
    assertion cannot tell a repeatable binding from a plain one.
    """
    table_want, stroke_want = _tmux_bind_scope(key)
    stroke_norm = _tmux_key_norm(stroke_want)

    found = []
    for parts, segment, depth in _tmux_segments(path, host):
        head = parts[0]
        if head in TMUX_INLINE_IF and TMUX_BIND_WORD.search(segment):
            raise ReadError(
                f"{os.path.basename(path)} binds a key inside `{head}`, a condition this "
                "reader cannot evaluate — and silence here would read as 'not bound', "
                "which is a want_absent's PASSING answer"
            )
        is_bind = head in TMUX_BIND
        if not is_bind and head not in TMUX_UNBIND:
            continue

        explicit_table, root_flag, clears_table, idx = None, False, False, 1
        while idx < len(parts) and parts[idx].startswith("-") and parts[idx] != "-":
            token = parts[idx]
            idx += 1
            chars, pos = token[1:], 0
            while pos < len(chars):
                ch = chars[pos]
                # -T and -N take an argument: the REST of this token if there
                # is one, else the next token. Clustering is legal —
                # `bind -rT prefix h` and `bind -N'note' g` are both real —
                # and reading the cluster as one opaque flag consumed the
                # argument as the keystroke, so the binding vanished and a
                # want_absent row went green over a binding that was there.
                if ch in "TN":
                    arg = chars[pos + 1:]
                    if not arg:
                        if idx >= len(parts):
                            raise ReadError(
                                f"`{head} -{ch}` is missing its argument: {segment[:60]}"
                            )
                        arg = parts[idx]
                        idx += 1
                    if ch == "T":
                        explicit_table = arg
                    break               # the rest of the token was the argument
                if ch == "a":
                    clears_table = True
                elif ch == "n":
                    root_flag = True
                pos += 1

        # -T wins over -n: `bind -nT copy-mode-vi X` lands in copy-mode-vi,
        # measured against tmux on both installed versions.
        if explicit_table is not None:
            table = explicit_table
        elif root_flag:
            table = "root"
        else:
            table = "prefix"

        if clears_table:
            # Scoped to the table it names: `unbind -a -T copy-mode-vi` says
            # nothing about the prefix table.
            if table != table_want:
                continue
            raise ReadError(
                f"`{head} -a` clears the `{table}` table, so this file no longer "
                "determines what that table holds"
            )

        rest = parts[idx:]
        if not rest or table != table_want or _tmux_key_norm(rest[0]) != stroke_norm:
            continue

        if depth:
            raise ReadError(
                f"`{key}` is bound inside a %if block — this reader cannot evaluate the "
                "condition, and taking a branch would be a guess reported as a fact"
            )

        if is_bind:
            found.append(" ".join(rest[1:]))
        else:
            found = []

    if not found:
        return None
    return found if accumulate else found[-1]


def _strip_flags_comment(line):
    """A word-initial `#` outside quotes starts a comment — bat's measured
    rule, not a guess: `--theme=Bad # c` warns about `Bad`, a glued
    `ansi#x` is a literal, and a `#` inside quotes ships with the value.
    POSIX-shell shaped — the same class of finding the tmux reader records.
    An audit refuted this file's first claim ("full-line comments only"),
    which would have folded a trailing comment into the value.
    """
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i].rstrip()
    return line


def read_flags(path, key, accumulate=False, **_opts):
    """One command-line flag per line — bat's config format.

    `key` is the flag name without its `--`; both spellings are read
    (`--theme="ansi"`, `--theme ansi`). Semantics measured against bat
    itself, not its README: surrounding quotes are not part of the value
    (the unknown-theme warning names the theme unquoted), a repeated
    flag's LAST occurrence is the one bat acts on (bad-then-good config is
    silent, good-then-bad warns), and comments are POSIX-shell shaped —
    see _strip_flags_comment.
    """
    found = []
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            line = _strip_flags_comment(line.strip())
            if not line.startswith("--"):
                continue
            head = line[2:].split(None, 1)
            if "=" in head[0]:
                name, _, value = line[2:].partition("=")
            else:
                name = head[0]
                value = head[1] if len(head) > 1 else ""
            if name.strip() != key:
                continue
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\'\"":
                value = value[1:-1]
            found.append(value)
    if not found:
        return None
    return found if accumulate else found[-1]


def read_rgconf(path, key, accumulate=False, **_opts):
    """ripgrep's config: one shell ARGUMENT per line, verbatim.

    Measured against rg 15.2.0, not its guide: quotes are NOT stripped — a
    fully-quoted flag is read as the positional PATTERN, which demotes the
    real pattern to a path and poisons the whole invocation; a trailing
    `# comment` is part of the argument ("unrecognized flag"); and
    `--flag value` on one line is ONE unrecognised flag — a value rides
    `--flag=value` or its own line (the latter this reader refuses to
    model). Blank lines are ignored; comments are full lines starting
    with `#`; `--no-<flag>` negates and the LAST occurrence wins.

    `key` is the long-flag name without `--`. A presence flag answers
    "on"/"off" (negation-aware); `--key=value` answers the value. Any
    line this reader cannot model — a short flag, a bare argument, a
    quote anywhere — is REFUSED: a refusal is a failed assertion, a
    guess is a green one (the tmux rule). A quote in a value would be
    legal to rg, but here it is far more likely the bat-config habit
    that poisons flags, so it refuses rather than answers.
    """
    found = []
    with open(path, encoding="utf-8-sig") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            if '"' in line or "'" in line:
                raise ReadError(f"quote in an rg config line — rg passes it through verbatim (a quoted flag becomes the PATTERN): {line[:60]!r}")
            if line.startswith("-") and not line.startswith("--"):
                raise ReadError(f"short flag — this reader models long flags only: {line[:60]!r}")
            if not line.startswith("--"):
                raise ReadError(f"bare argument line — rg would take it as a positional pattern/path: {line[:60]!r}")
            body = line[2:]
            name, eq, value = body.partition("=")
            if " " in name or "\t" in name:
                raise ReadError(f"space-form `--flag value` is ONE unrecognised flag to rg (measured 15.2.0): {line[:60]!r}")
            if eq:
                if name == key:
                    found.append(value)
            elif name == key:
                found.append("on")
            elif name == "no-" + key:
                found.append("off")
    if not found:
        return None
    return found if accumulate else found[-1]


def read_ncduconf(path, key, accumulate=False, **_opts):
    """ncdu's config: one command-line option per line, argument ON the line.

    Measured against ncdu 2.9.2: `--color dark` (space-separated, one
    line) is the accepted shape; quotes are NOT stripped (`--color
    "dark"` reaches ncdu verbatim → "Unknown --color option"); options
    apply in file order, so a repeated setter's LAST occurrence wins
    (probed: a bad value on the second line errors AFTER the first is
    accepted). A malformed line is FATAL — unknown flag, bad value,
    quoted value all exit 1 before the UI opens. (A first probe read the
    opposite off a pipeline: `rc=$?` after `| head` measured head. The
    audit re-measured ncdu directly, both -o and interactive.) The one
    run-past mechanism is the documented `@` prefix, and it is SILENT,
    not a warning. Full-line `#` comments; blank lines ignored.

    `key` is the long-option name without `--`. `@`-prefixed lines
    (error-suppressed), short flags and `=`-form values are refused
    rather than modelled — none is measured.
    """
    found = []
    with open(path, encoding="utf-8-sig") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if '"' in line or "'" in line:
                raise ReadError(f"quote in an ncdu config line — ncdu takes it verbatim and rejects the value: {line[:60]!r}")
            if not line.startswith("--"):
                raise ReadError(f"ncdu config line this reader does not model (@-prefix, short flag, or bare text): {line[:60]!r}")
            if "=" in line.split(None, 1)[0]:
                raise ReadError(f"`--flag=value` form is unmeasured against ncdu — use `--flag value`: {line[:60]!r}")
            name, _, value = line[2:].partition(" ")
            if name == key:
                found.append(value.strip())
    if not found:
        return None
    return found if accumulate else found[-1]


def _strip_zsh_comment(line):
    """Word-initial `#` starts a comment — line start or after whitespace.

    Same glued-#-is-literal rule as _strip_flags_comment, which keeps
    zshrc's `(#q...)` glob qualifiers out of the comment rule. UNLIKE the
    flags reader this one is quote-blind — none of the three shell files
    puts a space-then-# inside a quoted value (verified 26-08-2026); a
    future one would need a real word splitter here.
    """
    for i, ch in enumerate(line):
        if ch == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i]
    return line


# The zsh directives that are a TABLE keyed by name, so a later line for the
# same name replaces the earlier one and a deletion removes it — read flat,
# the earlier line stays in the list and a row on it stays green over a
# config that no longer does it (the kitty `map` defect of 10-09-2026, found
# again here by the audit the same evening). The value kept is the line as
# written; only the IDENTITY is resolved.
_ZSH_TABLE_DIRECTIVES = ("alias", "bindkey", "zstyle", "hash")
_ZSH_BLOCK_OPEN = ("if", "case", "while", "until", "for", "select", "function")
_ZSH_BLOCK_CLOSE = ("fi", "esac", "done", "}")
_ZSH_BINDKEY_KEYMAPLESS = ("-e", "-v", "-d", "-l", "-N", "-A", "-D", "-L", "-p")


def _zsh_words(rest):
    """Shell-split a directive's arguments; the raw split if a quote is open."""
    try:
        return shlex.split(rest)
    except ValueError:
        return rest.split()


def _zsh_identity(directive, rest):
    """(table, name) a later line of the same directive would replace, or None.

    alias NAME=…            ("alias", NAME); `-g` shares the table, `-s` (suffix
                            aliases) is its own
    bindkey [-M map] KEY …  ("bindkey", (map, KEY)); `-a` is `-M vicmd`, `-s`
                            binds a string to the same KEY; the keymap-wide
                            forms (-e, -v, -d, -l, -N, -A, -D, -L, -p) name no key
    zstyle [-e] CTX STYLE … ("zstyle", (CTX, STYLE))
    hash -d NAME=…          ("hash", NAME); the command-hash form is its own table
    """
    words = _zsh_words(rest)
    if directive == "alias":
        table = "salias" if any(w == "-s" for w in words if w.startswith("-")) else "alias"
        defs = [w.split("=", 1)[0] for w in words if not w.startswith("-") and "=" in w]
        return (table, defs[0]) if defs else None
    if directive == "bindkey":
        keymap, string_bind, rest_words = "main", False, []
        i = 0
        while i < len(words):
            w = words[i]
            if w == "-M" and i + 1 < len(words):
                keymap = words[i + 1]; i += 2; continue
            if w == "-a":
                keymap = "vicmd"; i += 1; continue
            if w in _ZSH_BINDKEY_KEYMAPLESS:
                return None
            if w in ("-s", "-r", "-R"):
                i += 1; continue
            rest_words = words[i:]
            break
        return ("bindkey", (keymap, rest_words[0])) if rest_words else None
    if directive == "zstyle":
        args = [w for w in words if not w.startswith("-")]
        if any(w in ("-d", "-L", "-g", "-s", "-b", "-a", "-t", "-T", "-m") for w in words[:1]):
            return None
        return ("zstyle", (args[0], args[1])) if len(args) >= 2 else None
    if directive == "hash":
        named = "-d" in words
        defs = [w.split("=", 1)[0] for w in words if not w.startswith("-") and "=" in w]
        return ("hash-d" if named else "hash", defs[0]) if defs else None
    return None


def _zsh_deletions(directive, rest):
    """The identities a line REMOVES: unalias, unhash, zstyle -d, bindkey -r."""
    words = _zsh_words(rest)
    if directive == "unalias":
        table = "salias" if "-s" in words else "alias"
        return [(table, w) for w in words if not w.startswith("-")]
    if directive == "unhash":
        table = "hash-d" if "-d" in words else "hash"
        return [(table, w) for w in words if not w.startswith("-")]
    if directive == "zstyle" and words[:1] == ["-d"]:
        args = words[1:]
        if len(args) == 1:
            return [("zstyle", (args[0], None))]      # every style of the context
        return [("zstyle", (args[0], st)) for st in args[1:]]
    if directive == "bindkey" and "-r" in words:
        ident = _zsh_identity("bindkey", rest)
        return [ident] if ident else []
    return []


def read_zsh(path, key, accumulate=False, **_opts):
    """zsh startup files as directive lines — the TEXT half of the shell teeth.

    Two shapes are read, after backslash-continuations are joined and
    word-initial comments stripped:

      NAME=value      assignments — `export ` prefix and one layer of
                      quotes removed; `key` is the NAME
      <key> rest      first-word directives (setopt, bindkey, zstyle,
                      alias, eval, source, exec, typeset, ssh-add ...) —
                      the value is the rest of the line, verbatim

    Text sees the PROGRAM, not its effect: every conditional branch
    appears (EDITOR yields both 'nano' and 'zed --wait'), and eval-created
    bindings are invisible — assert those through zshcap instead. A
    guarded `[ -f ... ] && source ...` line's first word is `[`, so plugin
    source gates are also zshcap territory. Non-accumulate returns the
    LAST occurrence, matching zsh assignment semantics.

    Since 10-09-2026 the table directives (alias, bindkey, zstyle, hash)
    are read the way zsh keeps them: at the TOP LEVEL of the file a later
    line for the same name replaces the earlier one and `unalias`,
    `unhash`, `zstyle -d` and `bindkey -r` remove it, so an accumulated
    list holds only what is still in force. Inside an `if`/`case`/loop or a
    function body a line keeps the branch semantics above — appended, and
    neither overriding nor overridden — because which branch runs is not
    the text's to know; an override that crosses a block boundary is the
    one shape this does not model, and it errs green, like every flat read.
    """
    with open(path, encoding="utf-8-sig") as fh:
        text = fh.read()
    found = []            # (identity-or-None, value), in file order
    depth = 0
    for line in text.replace("\\\n", " ").split("\n"):
        line = _strip_zsh_comment(line).strip()
        if not line:
            continue
        first = line.split(None, 1)[0]
        if first in _ZSH_BLOCK_CLOSE:
            depth = max(0, depth - 1)
        stripped = line[len("export "):] if line.startswith("export ") else line
        if stripped.startswith(key + "="):
            value = stripped[len(key) + 1:].strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                value = value[1:-1]
            found.append((None, value))
        else:
            head = line.split(None, 1)
            rest = head[1].strip() if len(head) > 1 else ""
            if depth == 0 and key in _ZSH_TABLE_DIRECTIVES:
                # A deletion may be spelled with the directive itself
                # (`zstyle -d`, `bindkey -r`) or with its un- twin.
                for gone in _zsh_deletions(head[0], rest):
                    if gone[0] == "zstyle" and gone[1][1] is None:
                        found = [f for f in found if not (f[0] and f[0][0] == "zstyle" and f[0][1][0] == gone[1][0])]
                    else:
                        found = [f for f in found if f[0] != gone]
            if head[0] == key:
                ident = _zsh_identity(key, rest) if depth == 0 and key in _ZSH_TABLE_DIRECTIVES else None
                if ident is not None:
                    found = [f for f in found if f[0] != ident]
                found.append((ident, rest))
        if first in _ZSH_BLOCK_OPEN or line.endswith("{") or line.endswith("() {"):
            depth += 1
    values = [v for _, v in found]
    if not values:
        return None
    return values if accumulate else values[-1]


# One probe per process: every zshcap assertion reads the same capture, so
# a doctor run pays for ONE PTY zsh, not one per entry. A failed probe is
# cached too — twenty entries must not retry a dead PTY twenty times.
_ZSHCAP_SECTIONS = {}
_ZSHCAP_ERROR = None

# Each section opens with a marker line, deliberately several characters
# long: zle's EOF artifact (^D + two backspaces — see zcap.sh) resolves by
# column, so the first two columns of the FIRST output line can carry
# residue when nothing overwrites them. A marker line overwrites both
# cells; the data lines never come first.
_ZSHCAP_PROBE = (
    # `bindkey -L` is the main keymap only; the menuselect keymap and the
    # main->emacs link are printed beside it so a binding that lives in
    # the menu, and the keymap choice itself, are assertable (02-09-2026).
    'print -r -- "--BINDKEY--"; bindkey -L; bindkey -M menuselect -L 2>/dev/null; bindkey -lL main; '
    'print -r -- "--WIDGETS--"; print -rl -- ${(k)widgets}; '
    # Aliases and functions are the END STATE a `[ -f ] && source` gate or
    # an `unalias` leaves behind; text cannot see either. A hook a tool
    # looks up by name at call time (fzf's _fzf_compgen_path) is only
    # provably wired if the function exists here.
    'print -r -- "--ALIASES--"; alias -L; '
    'print -r -- "--FUNCTIONS--"; print -rl -- ${(k)functions}; '
    'print -r -- "--PARAMS--"; '
    'print -r -- "HISTSIZE=$HISTSIZE"; print -r -- "SAVEHIST=$SAVEHIST"; '
    'print -r -- "HISTFILE=$HISTFILE"; print -r -- "EDITOR=$EDITOR"; '
    'print -r -- "LESS=$LESS"; print -r -- "READNULLCMD=$READNULLCMD"; '
    'print -r -- "RIPGREP_CONFIG_PATH=$RIPGREP_CONFIG_PATH"; '
    'print -r -- "HOMEBREW_NO_ANALYTICS=$HOMEBREW_NO_ANALYTICS"; '
    'print -r -- "HOMEBREW_BAT=$HOMEBREW_BAT"; '
    'print -r -- "FZF_CTRL_T_COMMAND=$FZF_CTRL_T_COMMAND"; '
    'print -r -- "ZSH_AUTOSUGGEST_STRATEGY=$ZSH_AUTOSUGGEST_STRATEGY"; '
    'print -r -- "ZSH_AUTOSUGGEST_MANUAL_REBIND=$ZSH_AUTOSUGGEST_MANUAL_REBIND"; '
    'print -r -- "ZSH_HIGHLIGHT_HIGHLIGHTERS=$ZSH_HIGHLIGHT_HIGHLIGHTERS"; '
    # The lines a governed box is asserted on that the Mac's entries never
    # needed: the picker's palette flag and previews, the motion and
    # reporting parameters, the prompt's identity, and LS_COLORS' bit depth
    # (a box whose ls needs the variable rides the palette only if every
    # code in it is 4-bit — the same rider rule as HL_OFF_PALETTE below).
    'print -r -- "FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS"; '
    'print -r -- "FZF_CTRL_T_OPTS=$FZF_CTRL_T_OPTS"; '
    'print -r -- "FZF_ALT_C_OPTS=$FZF_ALT_C_OPTS"; '
    'print -r -- "MANPAGER=$MANPAGER"; '
    'print -r -- "WORDCHARS=$WORDCHARS"; print -r -- "REPORTTIME=$REPORTTIME"; '
    'print -r -- "zle_highlight=$zle_highlight"; '
    'print -r -- "PROMPT=$PROMPT"; print -r -- "RPROMPT=$RPROMPT"; '
    # VISUAL is text-asserted as the literal `$EDITOR`; only live says the
    # expansion happened. CORRECT_IGNORE had no live half at all.
    'print -r -- "VISUAL=$VISUAL"; print -r -- "CORRECT_IGNORE=$CORRECT_IGNORE"; '
    # `typeset -U path` is a MECHANISM whose end state is an absence, so the
    # text half can only prove the line exists — not that a later rebuild
    # (.zprofile's, mise's, .zshrc's re-front) left the result deduplicated.
    # An explicit loop, not a quoted `:#` filter, which would test the JOINED
    # string and answer all-or-nothing (traps.md). `(Ie)` and not `(I)`: the
    # bare I subscript searches by PATTERN, so an entry containing a glob
    # metacharacter fails to match its own duplicate and the absence assertion
    # goes vacuously green — the exact failure this line exists to catch
    # (audit, 09-09-2026). The `e` flag makes it string equality.
    'typeset -a _sn=() _dp=(); '
    'for _p in "${path[@]}"; do if (( ${_sn[(Ie)$_p]} )); then _dp+=("$_p"); else _sn+=("$_p"); fi; done; '
    'print -r -- "PATH_DUPES=${(j:,:)_dp:-none}"; '
    'typeset -a _lc=(${(s.:.)LS_COLORS}) _lo=(); '
    'for _s in "${_lc[@]}"; do if [[ $_s == *"38;5;"* || $_s == *"48;5;"* || $_s == *"38;2;"* || $_s == *"48;2;"* ]]; then _lo+=("$_s"); fi; done; '
    'print -r -- "LS_COLORS_OFF_PALETTE=${(j:,:)_lo:-none}"; '
    'print -r -- "precmd_functions=$precmd_functions"; '
    'print -r -- "chpwd_functions=$chpwd_functions"; '
    # One line per hook the spec wants ABSENT, so the assertion reads
    # `=absent` (want_any, exact) instead of want_absent over the whole
    # params list. Same explicit loop as HL_OFF_PALETTE, same reason.
    '_m=absent; for _s in "${precmd_functions[@]}"; do [[ $_s == _mise_hook_precmd ]] && _m=present; done; '
    'print -r -- "mise_precmd_hook=$_m"; '
    '_m=absent; for _s in "${chpwd_functions[@]}"; do [[ $_s == _mise_hook_chpwd ]] && _m=present; done; '
    'print -r -- "mise_chpwd_hook=$_m"; '
    # Sorted in a subshell, on purpose: in the probe shell itself the (o)
    # sort flag is a no-op — a plain three-word array came back unsorted,
    # and LC_ALL=C in the same shell did not change that — while a forked
    # subshell of it sorts, and `zsh -f` sorts everywhere. Measured
    # 02-09-2026, cause not chased. The subshell is the fix; LC_ALL=C pins
    # the collation on top so the order cannot follow the locale.
    'print -r -- "nameddirs=$(LC_ALL=C; print -r -- ${(ok)nameddirs})"; '
    # The rider rule for the two plugins: every highlight style must be a
    # named colour or a 0-15 index. A hex or a 256-colour index anywhere
    # is listed; `none` is the compliant answer, asserted with want_any
    # (exact) because a STYLE can be valued `none` too. Explicit loop, not
    # `${(M)arr:#pat}`: inside double quotes that filters the JOINED
    # string, so the first draft printed every style or nothing and its
    # controls read the joined output as a catch — the battery caught it
    # 02-09-2026. `\\#` because the shell runs EXTENDED_GLOB.
    'typeset -a _hl=(${(v)ZSH_HIGHLIGHT_STYLES} ${(v)ZSH_HIGHLIGHT_PATTERNS} $ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE) _off=(); '
    'for _s in "${_hl[@]}"; do case $_s in (*fg=\\#*|*bg=\\#*|*fg=<16->*|*bg=<16->*) _off+=("$_s");; esac; done; '
    'print -r -- "HL_OFF_PALETTE=${(j:,:)_off:-none}"; '
    'print -r -- "--SETOPT--"; setopt; '
    # zstyle -L prints the RESOLVED styles — the half that caught the
    # completion colours asserted as a directive name over an empty
    # expansion (27-08-2026).
    'print -r -- "--ZSTYLE--"; zstyle -L'
)

_ZSHCAP_HOSTS = {}

_ZSHCAP_MARKERS = {
    "--BINDKEY--": "bindkey",
    "--WIDGETS--": "widgets",
    "--ALIASES--": "aliases",
    "--FUNCTIONS--": "functions",
    "--PARAMS--": "params",
    "--SETOPT--": "setopt",
    "--ZSTYLE--": "zstyle",
}


def _zshcap_remote(host):
    """The same probe on a governed box, through sshd's PTY instead of `script`.

    `-tt` forces the PTY a piped caller would not get; env -i clears
    SSH_CONNECTION so the box's tmux auto-attach stays out of the probe, and
    TERM is what a pane there actually has. The reply is cleaned the way zcap
    cleans its own — CR stripped, an ESC byte refused, col -b for zle's EOF
    artefact — so the parser below sees one shape from either machine. A
    host that does not answer is a ReadSkip, never a ReadError: offline is
    not drift.
    """
    cmd = ('env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" TERM=tmux-256color LANG=en_US.UTF-8 '
           'zsh -l -i -c ' + shlex.quote(_ZSHCAP_PROBE))
    try:
        proc = subprocess.run(["ssh", "-tt", *_SSH_OPTS, host, cmd],
                              capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL)
    except (subprocess.TimeoutExpired, OSError) as exc:
        raise ReadSkip(f"{host} did not answer the live zsh probe — {exc}")
    out = proc.stdout.replace("\r", "")
    if proc.returncode != 0 and "--SETOPT--" not in out:
        why = (proc.stderr or out).strip().splitlines()
        raise ReadSkip(f"{host} unreachable for the live zsh probe (rc={proc.returncode}: {why[0][:120] if why else 'no output'})")
    if "\x1b" in out:
        raise ReadError(f"{host} live zsh probe output contains an ESC byte — refusing to strip it silently (zcap.sh)")
    col = subprocess.run(["col", "-b"], input=out, capture_output=True, text=True)
    return col.stdout


def _zshcap_capture(host=None):
    global _ZSHCAP_ERROR
    if host:
        # One capture per host per run, the local cache's shape. A ReadSkip
        # is cached too, so an offline box costs one attempt, not one per
        # assertion.
        if host in _ZSHCAP_HOSTS:
            got = _ZSHCAP_HOSTS[host]
            if isinstance(got, Exception):
                raise got
            return got
        fixture = os.environ.get("ZSHCAP_FIXTURE_" + re.sub(r"[^A-Za-z0-9]", "_", host).upper())
        try:
            if fixture:
                with open(fixture, encoding="utf-8-sig") as fh:
                    out = fh.read()
            else:
                out = _zshcap_remote(host)
            sections = _zshcap_parse(out)
        except (ReadSkip, ReadError) as exc:
            _ZSHCAP_HOSTS[host] = exc
            raise
        if not sections:
            _ZSHCAP_HOSTS[host] = ReadError(f"{host} live zsh probe produced no recognisable sections")
            raise _ZSHCAP_HOSTS[host]
        _ZSHCAP_HOSTS[host] = sections
        return sections
    if _ZSHCAP_ERROR:
        raise ReadError(_ZSHCAP_ERROR)
    if _ZSHCAP_SECTIONS:
        return _ZSHCAP_SECTIONS
    fixture = os.environ.get("ZSHCAP_FIXTURE")
    if fixture:
        with open(fixture, encoding="utf-8-sig") as fh:
            out = fh.read()
    else:
        zcap = os.path.join(os.path.dirname(os.path.abspath(__file__)), "zcap.sh")
        try:
            # stdin MUST be explicit: macOS `script` relays its stdin into
            # the PTY, and with some caller stdins (measured: this harness's
            # own) it produces nothing and exits 0 — an empty capture with a
            # clean exit code; a CLOSED stdin hangs it outright (also
            # measured). /dev/null makes the probe caller-independent, the
            # same isolation zcap's env -i gives the environment.
            proc = subprocess.run(
                ["bash", "-c", 'source "%s" && zcap %s' % (zcap, shlex.quote(_ZSHCAP_PROBE))],
                capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL,
            )
        except subprocess.TimeoutExpired:
            _ZSHCAP_ERROR = "zsh live probe timed out after 60s"
            raise ReadError(_ZSHCAP_ERROR)
        out = proc.stdout
        if proc.returncode != 0 or "--SETOPT--" not in out:
            _ZSHCAP_ERROR = (
                "zsh live probe failed (rc=%d): %s"
                % (proc.returncode, (proc.stderr or out).strip()[:200])
            )
            raise ReadError(_ZSHCAP_ERROR)
    _ZSHCAP_SECTIONS.update(_zshcap_parse(out))
    if not _ZSHCAP_SECTIONS:
        _ZSHCAP_ERROR = "zsh live probe produced no recognisable sections"
        raise ReadError(_ZSHCAP_ERROR)
    return _ZSHCAP_SECTIONS


def _zshcap_parse(out):
    sections, current = {}, None
    for line in out.splitlines():
        name = _ZSHCAP_MARKERS.get(line.strip())
        if name:
            current = sections.setdefault(name, [])
            continue
        if current is not None and line.strip():
            current.append(line.rstrip())
    return sections


def read_zshcap(path, key, accumulate=False, host=None, **_opts):
    """The live END STATE of the interactive shell — the other half.

    `path` names the config whose effect is probed (it keeps the spec's
    shape); the read itself runs zcap — env -i, PTY, ESC-guarded — so it
    measures what a real interactive shell resolves AFTER every eval-time
    init and every .local overlay, not what any one file says. This is the
    half that catches last-binding-wins clobbers: atuin's default Up-arrow
    binding would have replaced the prefix search with zero text change.

    `key` is a capture section: bindkey | widgets | aliases | functions |
    params | setopt | zstyle. Pair with accumulate + want_any_contain, the
    same shape as kitty's map — or accumulate + want_absent for an alias
    that must be GONE (run-help's, which would shadow the function).
    ZSHCAP_FIXTURE substitutes a recorded capture (tests; CI validates the
    spec without ever reading live config).
    """
    lines = _zshcap_capture(host).get(key)
    if not lines:
        return None
    return lines if accumulate else lines[-1]


def read_nanorc(path, key, accumulate=False, **_opts):
    """nano's rc file: `set NAME [VALUE]`, `unset NAME`, `include GLOB`, `bind`.

    A bare `set NAME` is a switch and reads as `true`; `unset NAME` reads as
    `false`; a valued `set` reads ONE word, or one double-quoted string, and
    ignores the rest of the line — nano 9.2's own parse, measured on the box
    07-09-2026 with a control: `set guidestripe abc` errors at startup,
    `set guidestripe 80   # trailing` does not. `include` accumulates.
    """
    found = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 2)
            verb = parts[0]
            if verb == "set" and len(parts) >= 2 and parts[1] == key:
                if len(parts) < 3 or parts[2].startswith("#"):
                    # A switch, or a switch followed by text nano never reads.
                    val = "true"
                else:
                    rest = parts[2]
                    m = re.match(r'"([^"]*)"', rest)
                    val = m.group(1) if m else rest.split(None, 1)[0]
                found.append(val)
            elif verb == "unset" and len(parts) >= 2 and parts[1] == key:
                found.append("false")
            elif verb == key == "include" and len(parts) >= 2:
                found.append(line[len("include"):].strip())
            elif verb == key and verb in ("bind", "unbind") and len(parts) >= 2:
                # `bind KEY FUNCTION MENU` / `unbind KEY MENU`, whole (09-09-2026).
                found.append(line[len(verb):].strip())
    if not found:
        return None
    return found if accumulate else found[-1]


def read_gitcfg(path, key, accumulate=False, **_opts):
    """One git config file, read by git's own parser — includes followed.

    `--includes` is load-bearing: for a `--file` read git honours [include]
    only when asked (measured 28-08-2026, git 2.55: an included key came
    back rc=1 without the flag, resolved with it). [includeIf "gitdir:…"]
    evaluates against the CURRENT repository, so with no repo in play a
    conditional include contributes nothing — a work-identity overlay is
    therefore asserted against its own file, not through this one.

    Values arrive in application order with an include applied inline at
    the point it appears (one/two/three across a main-then-include
    fixture), so non-accumulate takes the LAST — git's own last-wins.
    `-z` is load-bearing: a VALUE can itself contain a newline
    (`k = "one\\ntwo"`), and the newline-separated form splits it into
    phantom entries — two values read as three (measured 28-08-2026).
    NUL-separated output keeps a value's newlines inside the value.

    rc=1 covers both a missing key and a malformed key NAME; stderr is
    what separates them (measured: a missing key is silent, a sectionless
    one prints "key does not contain a section"). A malformed FILE is
    rc=128. A malformed name and a malformed file are both reported
    rather than read as unset; only the silent rc=1 means None.
    """
    proc = _tool_run(
        ["git", "config", "--file", path, "--includes", "-z", "--get-all", key],
        timeout=10,
    )
    if proc.returncode == 1 and not proc.stderr.strip():
        return None
    if proc.returncode != 0:
        raise ReadError(f"git config rc={proc.returncode}: {proc.stderr.strip()[:160]}")
    # v1\0v2\0…vn\0 — drop only the terminator's empty tail, so a
    # genuinely empty value survives.
    found = proc.stdout.split("\0")[:-1] if proc.stdout else []
    if not found:
        return None
    return found if accumulate else found[-1]


def read_ghcfg(path, key, accumulate=False, **_opts):
    """gh's config, answered by gh itself. GH_CONFIG_DIR pins the read to
    the directory holding `path`, so a fixture dir and the real one answer
    identically.

    A key containing `/` is host-scoped: `github.com/git_protocol` asks
    `gh config get -h github.com`. That split is the point — hosts.yml
    overrides config.yml per host, and the two disagreed here silently
    (measured 28-08-2026, gh 2.98: the file said https while the effective
    value was ssh). Asserting only the global half would reopen that gap.
    hosts.yml also holds OAuth tokens; gh returns the one asked-for value
    and this checker never opens the file itself.

    An unknown key and a MALFORMED config file are both rc=1 with the
    story on stderr ("could not find key" vs "invalid yaml" — both
    measured 28-08-2026), so unlike git there is no silent rc=1 to lean
    on. The missing-key message is matched by content; every other rc=1
    is reported rather than read as unset — a corrupt file must not
    diagnose as a missing preference.
    """
    env = dict(os.environ, GH_CONFIG_DIR=os.path.dirname(path) or ".")
    if "/" in key:
        host, name = key.split("/", 1)
        cmd = ["gh", "config", "get", "-h", host, name]
    else:
        cmd = ["gh", "config", "get", key]
    proc = _tool_run(cmd, timeout=10, env=env)
    if proc.returncode == 1:
        if "could not find key" in proc.stderr:
            return None
        raise ReadError(f"gh config rc=1: {proc.stderr.strip()[:160]}")
    if proc.returncode != 0:
        raise ReadError(f"gh config rc={proc.returncode}: {proc.stderr.strip()[:160]}")
    value = proc.stdout.strip()
    return [value] if accumulate else value


def read_sshcfg(path, key, accumulate=False, **_opts):
    """A host's RESOLVED client config — `ssh -G -F`, the parser ssh runs.

    `key` is `host/option`. -G prints the post-resolution state, which is
    the only honest one: Host-stanza matching, first-obtains precedence
    and unit normalisation all happen inside ssh — ControlPersist 10m
    comes back 600, ControlMaster no comes back false, LocalForward
    repeats one line per forward (all measured 28-08-2026, OpenSSH 10.3).
    A host matching NO stanza still resolves, to ssh's defaults, so a
    typo'd host fails on the wanted value rather than on the read.

    -F confines the read to the named file — the system ssh_config's
    SendEnv lines vanish under `-F /dev/null` (measured), so a fixture
    and the deployed file answer identically. stderr is noise
    ("Pseudo-terminal will not be allocated…") unless rc != 0; a
    malformed file is rc=255 with an empty resolution.
    """
    host, _, option = key.partition("/")
    if not option:
        raise ReadError(f"sshcfg key must be host/option, got '{key}'")
    proc = _tool_run(["ssh", "-G", "-F", path, host], timeout=10)
    if proc.returncode != 0:
        raise ReadError(f"ssh -G rc={proc.returncode}: {proc.stderr.strip()[:160]}")
    want = option.lower()
    found = []
    for line in proc.stdout.splitlines():
        k, _, v = line.partition(" ")
        if k == want:
            found.append(v)
    if not found:
        return None
    return found if accumulate else found[-1]


# ── Obsidian: the app's own resolved state, one probe per process ─────────────
# Obsidian writes a key when it is set, so a key ABSENT from app.json is the
# shipped default and the file cannot say what that default is (a present
# key may be a default too — one toggled away and back stays written). A
# theme knob is inert until the theme's plugin has applied it.
# app.vault.getConfig() is the resolver the app itself consults —
# this.config[key], else the shipped defaults object (read off 1.13.7's
# source, 03-09-2026) — and the DOM carries the END STATE: the computed CSS
# variables the theme and its plugin set, font-feature-settings on a
# synthetic view element (a note need not be open), the body classes Minimal
# and Style Settings toggle, the custom hotkeys. The CLI's `eval` (1.13.7)
# hands all of it back as one JSON document.
#
# ⚠️ Call `obsidian-cli`, never the bare name. On this machine `obsidian` on
# PATH resolved to the Electron executable: the installer-added app-dir entry
# the zprofile carried until 03-09-2026 shadowed Homebrew's `obsidian` →
# `obsidian-cli` symlink, and the case-insensitive volume maps `obsidian` to
# `Obsidian`. That binary forwards to a running instance and BOOTS a GUI
# instance when there is none, never returning — each probe made through it
# while the app was closed on 03-09-2026 ran to its alarm. The real CLI talks
# to the app over a socket and answers "The CLI is unable to find Obsidian"
# instead (its own message, read off the binary) — so that answer is the one
# oracle for "closed", and the reader SKIPS (warn) on it: a closed app is not
# drift, and launching one is not a checker's to do. (A `pgrep` guard was
# tried first and dropped: under the tool sandbox pgrep sees the GUI app and
# not `bash`, so it cannot be relied on and cannot be tested.)
# The binary is overridable so the suite can prove both answers with a fake —
# the same reason PREF_SPEC exists.
OBSIDIAN_BIN = os.environ.get("OBSCAP_BIN", "/Applications/Obsidian.app/Contents/MacOS/obsidian-cli")
OBSIDIAN_NOT_RUNNING = "unable to find Obsidian"
OBSIDIAN_ASAR_GLOB = os.path.expanduser("~/Library/Application Support/obsidian/obsidian-*.asar")

# Every vault-config key the spec may ask for. getConfig answers the DEFAULT
# for a key app.json omits, which is the whole point of reading it here.
OBSIDIAN_CONFIG_KEYS = (
    "textFontFamily", "monospaceFontFamily", "interfaceFontFamily", "baseFontSize",
    "theme", "cssTheme", "enabledCssSnippets", "accentColor",
    "vimMode", "showLineNumber", "showIndentGuide", "readableLineLength",
    "foldHeading", "foldIndent", "livePreview", "spellcheck",
    "promptDelete", "trashOption", "alwaysUpdateLinks", "useMarkdownLinks",
    "attachmentFolderPath", "uriCallbacks",
)

_OBSCAP_PROBE = (
    "(function(){"
    "var cfg={};" + json.dumps(list(OBSIDIAN_CONFIG_KEYS)) + ".forEach(function(k){cfg[k]=app.vault.getConfig(k)});"
    "var cs=getComputedStyle(document.body),css={};"
    "['font-text','font-monospace','font-interface','font-text-size','line-width','line-width-wide',"
    "'line-height','font-ui-small','tx1','tx2','bg1','bg2'].forEach(function(v){css[v]=cs.getPropertyValue('--'+v).trim()});"
    # A synthetic element carrying each view's class: the rule the snippet
    # targets resolves without a note being open, and the div is gone before
    # anything paints.
    "var ffs={};['source','preview','rendered'].forEach(function(n){var d=document.createElement('div');"
    "d.className=n==='rendered'?'markdown-rendered':'markdown-'+n+'-view';document.body.appendChild(d);"
    "ffs[n]=getComputedStyle(d).fontFeatureSettings;d.remove()});"
    "return JSON.stringify({"
    "version:(navigator.userAgent.match(/obsidian\\/([\\d.]+)/)||[])[1]||null,"
    "config:cfg,css:css,ffs:ffs,"
    "theme:app.customCss.theme,themes:Object.keys(app.customCss.themes||{}),"
    "snippets:{all:app.customCss.snippets,enabled:Array.from(app.customCss.enabledSnippets||[])},"
    "body:{classes:Array.from(document.body.classList)},"
    "community:{enabled:Array.from(app.plugins.enabledPlugins),installed:Object.keys(app.plugins.manifests),"
    # An enabled id with no manifest behind it: the app keeps the id and
    # loads nothing (the Hider entry outlived its uninstall, 05-09-2026).
    # A string, `none` when empty, so the spec can want one answer.
    "orphans:Array.from(app.plugins.enabledPlugins).filter(function(k){return !app.plugins.manifests[k]}).join(',')||'none'},"
    "core:Object.fromEntries(Object.keys(app.internalPlugins.plugins).map(function(k){return[k,app.internalPlugins.plugins[k].enabled]})),"
    "hotkeys:app.hotkeyManager.customKeys,"
    # A plugin's own switches, read off its loaded settings object — null
    # when the plugin is not loaded, so the line reads UNSET rather than a
    # default the file cannot vouch for.
    "plugins:{dataview:(function(d){return d?{js:d.settings.enableDataviewJs,inlineJs:d.settings.enableInlineDataviewJs,inline:d.settings.enableInlineDataview}:null})(app.plugins.plugins.dataview)},"
    # The plugins' startup update check is a localStorage flag, live-only.
    "updates:{pluginsAuto:app.plugins.autoCheckForUpdates}"
    "})})()"
)
_OBSCAP_DATA = None
_OBSCAP_ERROR = None
_OBSCAP_SKIP = None


def _obscap_capture(path):
    global _OBSCAP_DATA, _OBSCAP_ERROR, _OBSCAP_SKIP
    if _OBSCAP_ERROR:
        raise ReadError(_OBSCAP_ERROR)
    if _OBSCAP_SKIP:
        raise ReadSkip(_OBSCAP_SKIP)
    if _OBSCAP_DATA is not None:
        return _OBSCAP_DATA
    fixture = os.environ.get("OBSCAP_FIXTURE")
    if fixture:
        with open(fixture, encoding="utf-8-sig") as fh:
            _OBSCAP_DATA = json.load(fh)
        return _OBSCAP_DATA
    # `vault=` names the vault the target path sits in, so the read cannot
    # follow whichever vault was focused last.
    vault = os.path.basename(os.path.dirname(os.path.dirname(path)))
    try:
        proc = subprocess.run(
            [OBSIDIAN_BIN, f"vault={vault}", "eval", f"code={_OBSCAP_PROBE}"],
            capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL,
        )
    except subprocess.TimeoutExpired:
        _OBSCAP_ERROR = "obsidian-cli eval timed out after 30s with the app running — is the CLI enabled in its settings?"
        raise ReadError(_OBSCAP_ERROR)
    except OSError as exc:
        _OBSCAP_ERROR = f"obsidian-cli not runnable at {OBSIDIAN_BIN}: {exc}"
        raise ReadError(_OBSCAP_ERROR)
    if OBSIDIAN_NOT_RUNNING in proc.stderr + proc.stdout:
        _OBSCAP_SKIP = "Obsidian is not running — its CLI could not find the app; the live half needs it open, and never launches it"
        raise ReadSkip(_OBSCAP_SKIP)
    # eval prints its result on one line behind `=> `; anything else on stdout
    # is the CLI's own chatter.
    result = next((line[3:] for line in proc.stdout.splitlines() if line.startswith("=> ")), None)
    if proc.returncode != 0 or result is None:
        _OBSCAP_ERROR = "obsidian eval returned no result (rc=%d): %s" % (
            proc.returncode, (proc.stderr or proc.stdout).strip()[:200])
        raise ReadError(_OBSCAP_ERROR)
    try:
        _OBSCAP_DATA = json.loads(result)
    except json.JSONDecodeError as exc:
        _OBSCAP_ERROR = f"obsidian eval result is not JSON: {exc}"
        raise ReadError(_OBSCAP_ERROR)
    return _OBSCAP_DATA


def read_obsidiancap(path, key, accumulate=False, **_opts):
    """Obsidian's live end state — the other half of every .obsidian/ text read.

    `path` names the vault's appearance.json (it keeps the spec's shape and
    locates the vault); the read itself is one `obsidian eval` per process,
    cached like zshcap's PTY. `key` is a dotted path into the probe's JSON:
    config.<vault key> is getConfig's answer (defaults included), css.<var>
    a computed body variable, ffs.<view> the resolved font-feature-settings,
    body.classes / snippets.enabled / community.enabled lists (pair with
    accumulate + want_any), core.<plugin id> a core module's on/off,
    community.orphans the enabled ids with no plugin on disk (`none` when
    there are none), plugins.dataview.js / .inlineJs Dataview's own JS
    switches and .inline its inline-query switch, updates.pluginsAuto the plugins' startup update check,
    hotkeys.<command id>.0.key a custom binding.
    OBSCAP_FIXTURE substitutes a recorded document (tests; CI never reaches
    a running app).
    """
    value = _dotted(_obscap_capture(path), key)
    if value is None:
        return None
    if accumulate:
        return value if isinstance(value, list) else [value]
    return value


def _defaults_array(text):
    """A `defaults` array of SCALARS as one comma-joined line, else None.

    `defaults read` pretty-prints an array over several lines, so a row
    asserting one would spread its own result down the output, and its order
    — the preference for AppleLanguages — could only be stated as a
    multi-line want. Joining is what `normalise` already does with every
    other reader's lists, so the want reads `en-US,ka-GE` and says the order.
    An array holding anything but scalars (AppleEnabledInputSources is an
    array of dicts) is handed back untouched, as is a one-line value that
    merely looks parenthesised.
    """
    if "\n" not in text or not (text.startswith("(") and text.endswith(")")):
        return None
    items = []
    for line in text[1:-1].splitlines():
        line = line.strip().rstrip(",").strip()
        if not line:
            continue
        if line[0] in "({" or "=" in line or ";" in line:
            return None
        items.append(line[1:-1] if len(line) > 1 and line[0] == '"' == line[-1] else line)
    return ",".join(items) if items else None


def read_defaults(path, key, **_opts):
    """macOS settings — `defaults read <domain> <key>`, the live answer.

    `path` is the preference domain (NSGlobalDomain is what `-g` means), never
    a file: the plist under ~/Library/Preferences lags cfprefsd, which is the
    process that answers here. Absence has three spellings and all read as
    None: "Could not find key", "does not exist", and "Domain '…' not found"
    — the last because a domain need not exist at all before
    public/macos/apply.sh first writes it, which on a fresh Mac is the state
    of com.apple.Siri, com.apple.WindowManager, com.apple.menuextra.clock and
    com.apple.screencapture. `want_absent` accepts each, `want` refuses each;
    any other failure is a ReadError with defaults' own words. Booleans arrive
    as 1/0 and strings as themselves, so the spec's wants for this format are
    the text `defaults read` prints — an array of scalars after the join
    above, and every want after the number-folding `normalise` applies to all
    readers. Added 16-09-2026 for the macOS surface.
    """
    proc = _tool_run(["defaults", "read", path, key], stdin=subprocess.DEVNULL)
    if proc.returncode != 0:
        err = proc.stderr.strip()
        if ("does not exist" in err or "Could not find key" in err
                or ("Domain" in err and "not found" in err)):
            return None
        raise ReadError(f"defaults read {path} {key}: {err or 'failed'}")
    text = proc.stdout.strip()
    return _defaults_array(text) or text


READERS = {
    "jsonc": read_jsonc,
    "defaults": read_defaults,
    "toml": read_toml,
    "kitty": read_kitty,
    "kittyblocks": read_kitty_blocks,
    "tmux": read_tmux,
    "tmuxbind": read_tmux_bind,
    "flags": read_flags,
    "rgconf": read_rgconf,
    "ncduconf": read_ncduconf,
    "idea": read_idea,
    "zsh": read_zsh,
    "zshcap": read_zshcap,
    "gitcfg": read_gitcfg,
    "ghcfg": read_ghcfg,
    "sshcfg": read_sshcfg,
    "obsidiancap": read_obsidiancap,
    "nanorc": read_nanorc,
}


# ── ceiling probes ────────────────────────────────────────────────────────────
# An `unreachable` entry with recheck="auto" is not a shrug — it re-proves the
# ceiling from data the application ships, so a lifted limitation is noticed
# rather than sat on. Each probe returns (still_unreachable, detail).


def probe_sublime_caret_styles():
    pkg = spec_path("probes", "sublime_caret_styles", "shipped_package",
                    "/Applications/Sublime Text.app/Contents/MacOS/Packages/Default.sublime-package")
    if not os.path.exists(pkg):
        return None, "Default.sublime-package not found"
    try:
        with zipfile.ZipFile(pkg) as z:
            text = z.read("Preferences.sublime-settings").decode("utf-8", "replace")
    except (KeyError, zipfile.BadZipFile) as exc:
        return None, f"could not read shipped defaults ({exc})"
    # ANCHORED to the caret_style setting it is about. The shipped defaults
    # contain six "Valid values are" comments (line endings, tabs, hover
    # popups, git diff target…), and the caret one is first ONLY by current file
    # ordering. Matching the earliest would keep answering "still unreachable"
    # after a reorder, because `underline` is absent from those other lists too —
    # a check returning the same answer regardless of what it read. Found
    # 14-08-2026.
    # Anchor by LOCATING caret_style first, then taking the nearest preceding
    # "Valid values are". A single forward regex cannot express "nearest
    # preceding" and the attempt at one over-constrained the gap and matched
    # nothing — the probe then reported "unverifiable", which is at least honest
    # but useless. Searching backwards from the setting is what "anchored"
    # actually requires.
    setting = text.find('"caret_style"')
    if setting == -1:
        return None, "caret_style is no longer in the shipped defaults — re-read them by hand"
    starts = [m.start() for m in re.finditer(r"Valid values are ", text[:setting])]
    if not starts:
        return None, "no 'Valid values are' comment precedes caret_style — re-read it by hand"
    m = re.match(r"Valid values are ([^.]*)\.", text[starts[-1]:], re.S)
    if not m:
        return None, "the caret_style doc comment changed shape — re-read it by hand"
    doc = m.group(1)
    values = ", ".join(re.findall(r'"(\w+)"', doc)) or doc.strip()
    return ("underline" not in doc.lower()), f"accepts {values}"


def _js_object_to_json(text):
    """A minified object literal -> JSON: quote bare keys, !0/!1 -> booleans.

    Enough for the shapes the shipped defaults use (string, number, boolean,
    null, list, nested object); a key inside a string cannot match because
    the bare-key pattern needs a `{` or `,` immediately before it.
    """
    text = re.sub(r'([{,])([A-Za-z_$][\w$]*):', r'\1"\2":', text)
    return json.loads(text.replace("!0", "true").replace("!1", "false"))


def _brace_span(text, start):
    """The balanced {...} beginning at text[start], string-aware."""
    depth, i, in_str = 0, start, False
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    raise ValueError("unbalanced object literal")


_ASAR_NAME = re.compile(r"obsidian-(\d+(?:\.\d+)*)\.asar$")


def _obsidian_asar_version(path):
    """The version tuple in an archive's name, or () for a name that is not
    one — `obsidian-1..asar` used to reach int('') and crash the chooser."""
    m = _ASAR_NAME.search(os.path.basename(path))
    return tuple(int(x) for x in m.group(1).split(".")) if m else ()


def obsidian_asar_path():
    """The installed app archive with the highest VERSION — not the last name
    alphabetically, which would rank 1.9 above 1.13. One chooser, shared with
    bin/lib/obsidian-gaps.py; None when nothing is installed."""
    asars = glob.glob(spec_path("probes", "obsidian_caret", "asar_glob", OBSIDIAN_ASAR_GLOB))
    return max(asars, key=_obsidian_asar_version) if asars else None


def obsidian_config_defaults():
    """(version, defaults) — the object getConfig falls back to, off the installed asar.

    The asar is an uncompressed archive, so the app's own source is greppable
    without extracting it. Anchored on the object's first key rather than an
    offset; a version that moves or renames it returns (None, reason) instead
    of a guess. Shared with bin/lib/obsidian-gaps.py so there is one reader
    of this object, not two.
    """
    path = obsidian_asar_path()
    if path is None:
        return None, f"no installed app archive matches {OBSIDIAN_ASAR_GLOB}"
    version = ".".join(str(x) for x in _obsidian_asar_version(path))
    with open(path, "rb") as fh:
        text = fh.read().decode("utf-8", "replace")
    anchor = text.find("{alwaysUpdateLinks:")
    if anchor == -1:
        return None, f"{version}: the config-defaults object is not anchored where 1.13.7 kept it — re-read the asar by hand"
    try:
        return version, _js_object_to_json(_brace_span(text, anchor))
    except (ValueError, json.JSONDecodeError) as exc:
        return None, f"{version}: the config-defaults object no longer parses as a plain literal ({exc})"


def probe_obsidian_caret():
    """Still no caret-shape option among the editor settings the app ships?

    The CodeMirror caret is a bar; a setting for its shape would appear in
    the vault-config defaults first. Scanned by key name, and the detail
    names keys actually read so a probe that stopped reading is visible.
    """
    version, got = obsidian_config_defaults()
    if version is None:
        return None, got
    hits = [k for k in got if re.search(r"cursor|caret", k, re.I)]
    if hits:
        return False, f"{version} ships an editor option about the caret: {', '.join(hits)}"
    sample = ", ".join(list(got)[:3])
    return True, f"{version}'s editor options carry no cursor or caret key ({sample}, …)"


def _kitty_reference_conf():
    """kitty's shipped annotated reference, or (None, why).

    The path carries a Sphinx content hash that moves on a version bump — the
    very event a defaults reader exists to notice — so it is globbed, never
    written down. `PREF_KITTY_REF` overrides it, the same way `PREF_PUBLISHED`
    overrides the published palette: the app does not exist in CI, and a reader
    that cannot be pointed at a fixture cannot be tested there.
    """
    override = os.environ.get("PREF_KITTY_REF")
    refs = [override] if override else sorted(glob.glob(spec_path(
        "oracles", "kitty", "reference_conf_glob",
        "/Applications/kitty.app/Contents/Resources/doc/kitty/html/"
        "_downloads/*/kitty.conf")))
    if not refs:
        return None, "kitty's shipped reference conf is not where it was — re-read it by hand"
    try:
        with open(sorted(refs)[0], encoding="utf-8", errors="replace") as fh:
            return fh.read(), None
    except OSError as exc:
        return None, f"could not read kitty's shipped reference conf ({exc})"


def kitty_shipped_default(key):
    """kitty's own documented default for one option, or (None, why).

    Some rows assert a value the config deliberately does NOT carry, because
    it is kitty's default and the file holds only non-defaults. Text alone
    cannot watch those: an absent key reads as absent whatever kitty would do
    with it, so an upstream default flip retires the preference with every
    assertion green. The reference conf that ships INSIDE the app is the
    instrument — pure text, no binary, and version-locked by construction.

    In it every option appears once as a commented `# name value`, and a
    valueless option (`# option_name`) is a documented empty default rather
    than a parse failure, so it returns "" rather than None.

    Two refusals rather than a guess. The gap is a space-or-tab class, never
    the generic whitespace one, which matches a newline and would let a bare
    `#` line make the NEXT, uncommented line look like a documented default.
    And a key matching more than once has no single default — `map` and
    `mouse_map` appear many times — so it returns None rather than the first
    of many, the same >1 rule read_idea uses. ⚠️ The other accumulating
    directives (`font_features`, `symbol_map`, `env`, `modify_font`, `watcher`
    …) appear ONCE, valueless, and come back as "" like any empty scalar
    default; the caller refuses an empty default, because nothing positive can
    be said about it (main, and `entry_problems` for a row that also says
    `accumulate`).

    ⚠️ Two different failures, and they are not the same colour. The INSTRUMENT
    being absent — no kitty installed, the reference conf moved — raises
    ReadSkip, so the row warns: a stranger without the application has no drift
    to report, only no measurement, which is what every probe here already does.
    A reference conf that reads fine and does NOT document the key returns
    (None, why) and the row stays red, because that is a spec naming an option
    the application does not have.
    """
    text, err = _kitty_reference_conf()
    if text is None:
        raise ReadSkip(err)
    hits = re.findall(rf"^#[ \t]*{re.escape(key)}(?:[ \t]+(.*))?$", text, re.M)
    if not hits:
        return None, f"'{key}' is not an option in kitty's shipped reference conf"
    if len(hits) > 1:
        return None, (f"'{key}' appears {len(hits)} times in kitty's shipped reference conf — "
                      "an accumulating directive has no single default to read")
    return (hits[0] or "").strip(), None


# A format whose application ships its own defaults in readable text. Only such
# a target may carry `unset_reads_default` — without an oracle the flag would
# silently degrade to "an absent key always passes", which is the hole it
# exists to close.
DEFAULT_ORACLES = {"kitty": kitty_shipped_default}


def probe_kitty_ctrl_shift_plane():
    """Is the ctrl+shift plane still kitty's, so tmux can never be told about it?

    A tmux binding without the prefix has to live on a chord kitty forwards.
    ctrl+shift is the obvious plane and kitty claims most of it by DEFAULT.
    Two halves, and both are read, because a default only stands while the live
    config leaves it standing — an earlier version of this probe asserted that
    in its docstring and checked only the first half, so `kitty_mod alt` or a
    `no_op` would have freed the plane while it still reported the ceiling
    intact (audit, 09-09-2026):

      shipped   the reference conf the app ships, where a default appears as a
                commented `# map` line. Not the running process: reading
                kitty's live keymap means invoking the kitty binary.
      live      ~/.config/kitty/kitty.conf through this file's kitty reader,
                for a changed `kitty_mod`, `clear_all_shortcuts`, or a `no_op`
                over one of the arrows.

    The arrows decide it. Letters could be rearranged around whatever kitty
    leaves free; a spatial scheme needs the four, and if kitty stops claiming
    them the ceiling has genuinely lifted.
    """
    text, err = _kitty_reference_conf()
    if text is None:
        return None, err

    # A default is a commented `# map`; an uncommented one would be a shipped
    # override. Both forms count as "kitty claims it".
    claimed = set(re.findall(r"^#?\s*map\s+(?:--\S+\s+)*kitty_mod\+(\w+)\s",
                             text, re.M))
    if not claimed:
        return None, "no kitty_mod map lines in the shipped reference conf — re-read it by hand"

    arrows = {"up", "down", "left", "right"}
    taken_arrows = sorted(arrows & claimed)
    free_letters = sorted(set("abcdefghijklmnopqrstuvwxyz") - claimed)
    detail = ("kitty's shipped defaults claim ctrl+shift+%s; the free letters are %s"
              % ("/".join(taken_arrows) or "no arrow", ", ".join(free_letters) or "none"))
    if not taken_arrows:
        return False, detail + " — the arrows are no longer kitty's"

    # The live half: a default holds only while the config leaves it alone.
    live = os.path.expanduser(spec_path("probes", "kitty_ctrl_shift_plane",
                                        "live_config", "~/.config/kitty/kitty.conf"))
    if not os.path.exists(live):
        return None, detail + ", but the live kitty.conf is missing — check it by hand"
    try:
        kitty_mod = read_kitty(live, "kitty_mod")
        cleared = read_kitty(live, "clear_all_shortcuts")
        maps = read_kitty(live, "map", accumulate=True) or []
    except ReadError as exc:
        return None, f"could not read the live kitty config ({exc})"

    if str(cleared).strip().lower() in ("yes", "y", "true"):
        return False, "kitty.conf sets clear_all_shortcuts — the whole plane is forwarded"
    if kitty_mod and kitty_mod.strip().lower().replace(" ", "") not in ("ctrl+shift", "shift+ctrl"):
        return False, f"kitty_mod is `{kitty_mod.strip()}` — ctrl+shift is no longer kitty's"
    freed = sorted({
        m.group(1).lower() for m in (
            re.match(r"(?:--\S+\s+)*(?:kitty_mod|ctrl\+shift)\+(up|down|left|right)\b"
                     r"(?:\s+no_op)?\s*$", str(entry).strip(), re.I)
            for entry in maps
        ) if m
    })
    if len(freed) == len(arrows):
        return False, "kitty.conf no_ops every ctrl+shift arrow — the plane is forwarded"
    if freed:
        return True, detail + f"; kitty.conf frees {', '.join(freed)} but not the rest"
    return True, detail


def probe_mac_nano_is_pico():
    """Is the Mac's headless EDITOR still pico wearing nano's name?

    `public/shell/zshenv` sets `EDITOR=nano` for the SSH/headless branch, and
    on macOS `/usr/bin/nano` is a SYMLINK to `/usr/bin/pico` — UW PICO, the
    Pine component, which reads no rc file of its own. So the box's nano
    surface (rulers, indent guides, whitespace, word motion, all asserted
    there against `~/.nanorc`) has nothing to land on here.

    Two halves, because either one lifts the ceiling: the symlink could stop
    pointing at pico, or a real nano could appear. Homebrew's would be found
    first — `.zprofile` puts `/opt/homebrew/bin` ahead of `/usr/bin` — so the
    branch would silently start getting the editor the config already names.
    Deliberately NOT run: `nano --version`, which pico answers by opening the
    editor (measured 09-09-2026).
    """
    # Every prefix that precedes /usr/bin in this machine's login PATH and
    # could plausibly carry a nano. Named explicitly rather than derived: the
    # probe runs in preen doctor's process, whose PATH is not the login shell's.
    candidates = spec_path("probes", "mac_nano_is_pico", "real_nano_candidates",
                           ("/opt/homebrew/bin/nano", "/opt/homebrew/sbin/nano",
                            "/usr/local/bin/nano", "~/.local/bin/nano",
                            "~/.cargo/bin/nano", "~/.local/share/mise/shims/nano"))
    real = [p for p in (os.path.expanduser(c) for c in candidates) if os.path.exists(p)]
    if real:
        return False, f"a real nano is installed at {real[0]} and resolves before /usr/bin"
    sys_nano = spec_path("probes", "mac_nano_is_pico", "system_nano", "/usr/bin/nano")
    if not os.path.exists(sys_nano):
        return None, "/usr/bin/nano is gone and no Homebrew nano replaced it — re-read the branch by hand"
    if not os.path.islink(sys_nano):
        return None, "/usr/bin/nano is no longer a symlink — read what it is before trusting this row"
    dest = os.readlink(sys_nano)
    if os.path.basename(dest) != "pico":
        return False, f"/usr/bin/nano now points at {dest}, not pico"
    return True, "/usr/bin/nano -> pico (UW PICO), which reads no rc file, and no real nano is installed"


def probe_fd_colour_modes():
    """Can fd render in the terminal's 16 colours yet?

    Two routes exist and both fail at 10.5.0. `--color` takes when-to-colour
    (auto/always/never), never a DEPTH — that is the half this probe watches,
    because a `16` or `ansi` value appearing there is exactly how the ceiling
    would lift. The other route, LS_COLORS, is not a probe but a measurement:
    setting it REPLACES fd's compiled-in ~250-rule extension table rather than
    recolouring it, so a 4-bit LS_COLORS discards the file-type differentiation
    it was meant to recolour (measured 09-09-2026: `LS_COLORS=di=34` left
    README.md and blocked-upstream.md with no colour at all, where the default
    gave them 48;5;186;38;5;16 and 38;5;185).

    Read from fd's own --help at the installed binary, not from a doc.
    """
    fd = spec_path("probes", "fd_colour_modes", "fd_binary", "/opt/homebrew/bin/fd")
    if not os.path.exists(fd):
        return None, "fd is not installed at the Homebrew path — re-read this row by hand"
    try:
        out = subprocess.run([fd, "--help"], capture_output=True, text=True,
                             timeout=15).stdout
    except (OSError, subprocess.SubprocessError) as exc:
        return None, f"could not ask fd for its options ({exc})"
    block = re.search(r"--color <when>(.*?)(?:\n\s*-[a-zA-Z-]|\Z)", out, re.S)
    if not block:
        return None, "fd's --help no longer documents `--color <when>` — re-read it by hand"
    values = set(re.findall(r"^\s*-\s*(\w+):", block.group(1), re.M))
    if not values:
        return None, "could not read --color's accepted values from fd's --help"
    depth = values & {"16", "ansi", "4bit", "4-bit"}
    if depth:
        return False, f"fd's --color now accepts {'/'.join(sorted(depth))} — a colour DEPTH, so the ceiling has lifted"
    return True, (f"fd's --color takes only when-to-colour ({'/'.join(sorted(values))}), never a depth; "
                  "LS_COLORS replaces its extension table wholesale rather than recolouring it")


PROBES = {
    "fd_colour_modes": probe_fd_colour_modes,
    "mac_nano_is_pico": probe_mac_nano_is_pico,
    "sublime_caret_styles": probe_sublime_caret_styles,
    "obsidian_caret": probe_obsidian_caret,
    "kitty_ctrl_shift_plane": probe_kitty_ctrl_shift_plane,
}

# Every path literal inside a probe or the defaults oracle is THIS machine's.
# `[probes.<name>]` and `[oracles.<format>]` let a spec name its own, so a
# checkout elsewhere can point them at real paths without editing code. An
# absent table or key is the literal, so a spec that says nothing behaves
# exactly as before. Precedence: an env override (PREF_KITTY_REF, PREF_ASAR_GLOB
# …) beats the spec, which beats the literal — a fixture must win over a spec it
# did not write.
SPEC_PATH_KEYS = {
    "probes": {
        "sublime_caret_styles":   ("shipped_package",),
        "obsidian_caret":         ("asar_glob",),
        "kitty_ctrl_shift_plane": ("live_config",),
        "mac_nano_is_pico":       ("system_nano", "real_nano_candidates"),
        "fd_colour_modes":        ("fd_binary",),
    },
    "oracles": {
        "kitty": ("reference_conf_glob",),
    },
}
SPEC_PATHS = {"probes": {}, "oracles": {}}


def spec_path(kind, name, key, default):
    """One probe-or-oracle path literal, as the spec overrides it or as written."""
    got = SPEC_PATHS.get(kind, {}).get(name, {}).get(key)
    return got if got else default


def validate_spec_paths(spec):
    """Structural problems in [probes] and [oracles], as (label, problem) pairs.

    A name or key this file does not implement is a failure rather than a
    no-op: a spec that thinks it is moving a path, and is not, is the silent
    kind of wrong this checker exists to refuse.
    """
    out = []
    for kind in ("probes", "oracles"):
        table = spec.get(kind)
        if table is None:
            continue
        known = PROBES if kind == "probes" else DEFAULT_ORACLES
        singular = kind[:-1]
        if not isinstance(table, dict):
            out.append((f"[{kind}]", "is not a table"))
            continue
        for name, entry in sorted(table.items(), key=lambda kv: str(kv[0])):
            label = f"[{kind}.{name}]"
            if name not in known:
                out.append((label, f"unknown {singular} — known: {', '.join(sorted(known))}"))
                continue
            if not isinstance(entry, dict):
                out.append((label, "is not a table"))
                continue
            allowed = SPEC_PATH_KEYS[kind].get(name, ())
            for key in sorted(entry, key=str):
                if key not in allowed:
                    out.append((label, f"unknown path key '{key}' — this {singular} names "
                                       f"{', '.join(allowed) if allowed else 'no paths'}"))
    return out


# ── normalisation ─────────────────────────────────────────────────────────────


def normalise(value):
    """Render a read value as a comparable string, canonical across syntaxes.

    The point is that one preference expressed in four config languages should
    not read as four different values:

      lists    [80, 100, 120] (JSON) and "80,100,120" (IDEA XML) -> "80,100,120"
      bools    JSON true and XML "true" -> "true". Without this, the spec had to
               carry `want = "True"` — CPython's str(bool) leaking into a
               hand-edited SSOT, which breaks the moment a reader changes.
      numbers  kitty's text "16.0" and JSON's 16 -> "16". Without this the same
               preference needed want="16.0" for kitty and want="16" for Zed,
               and a perfectly valid `font_size 16` in kitty.conf would fail.

    kitty's own literals (`yes`/`no`) are deliberately NOT folded into booleans:
    they are what that file actually says, and pretending otherwise would make
    the spec disagree with the config a reader is looking at.
    """
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list):
        return ",".join(normalise(v) or "" for v in value)
    if isinstance(value, (int, float)):
        f = float(value)
        return str(int(f)) if f.is_integer() else str(f)
    s = str(value).strip()
    if NUMERIC.match(s):
        f = float(s)
        return str(int(f)) if f.is_integer() else str(f)
    return s


# ── spec validation ───────────────────────────────────────────────────────────
# THE one home for the spec's structural rules. Both the live run and
# `--validate-spec` call these, and nothing else may restate them.
#
# tests/test-pref-check.sh used to carry a second copy of these rules inline, to
# validate the shipped spec. Two copies of a rule is the exact defect this repo
# exists to close, and this pair had already drifted: the test's copy never
# checked `recheck = "auto"` probe names, so a spec THIS checker rejects could
# pass the suite's "structurally valid" step. The suite now calls
# `--validate-spec` instead of re-deriving anything.


def resolve_target(name, entry, targets, where="the spec"):
    """Return (target_dict, expanded_path, error_message).

    A target with `host` lives on another machine: its path is kept
    ~/-relative for the box to expand, and remote_path() below turns it into
    a local file at read time.

    `where` is the file this ENTRY came from. The spec is several files now, so
    "in preferences.toml" would name a document rather than the half a reader
    has to open.
    """
    tname = entry.get("target", name)
    t = targets.get(tname)
    if not isinstance(t, dict):
        return None, None, f"unknown target '{tname}' in {where}"
    if "path" not in t or "format" not in t:
        return None, None, f"target '{tname}' is missing path or format"
    if t["format"] not in READERS:
        return None, None, f"target '{tname}' has unknown format '{t['format']}'"
    if t.get("host"):
        if not re.fullmatch(r"[A-Za-z0-9._-]+", t["host"]):
            return None, None, f"target '{tname}' has an unusable host '{t['host']}'"
        # The path is interpolated into a program that runs on the remote
        # machine — the remote pull verb's manifest discipline applies here too.
        if (t["format"] != "zshcap" and not re.fullmatch(r"~/[A-Za-z0-9._/-]+", t["path"])) or ".." in t["path"]:
            return None, None, f"target '{tname}' on {t['host']} needs a plain ~/-relative path, got '{t['path']}'"
        return t, t["path"], None
    return t, os.path.expanduser(t["path"]), None


# ── remote targets ────────────────────────────────────────────────────────────
# A `host` on a target block means the config lives on a machine this repo
# governs over ssh. Every such file is fetched in ONE ssh call per host per run
# — base64-framed with a sentinel, the same shape as the remote pull verb — and
# handed to the ordinary reader as a local temp file, so no reader knows the
# difference. An unreachable host is a ReadSkip: a laptop offline is not
# drift, and the doctor must not go red for it.
_REMOTE = {}          # host -> {remote_path: local_path | None}  or  ReadSkip
_REMOTE_DIR = ""
_SSH_OPTS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"]


def _remote_fetch(host, targets):
    global _REMOTE_DIR
    if host in _REMOTE:
        return _REMOTE[host]
    paths = sorted({t["path"] for t in targets.values()
                    if isinstance(t, dict) and t.get("host") == host and t.get("format") != "zshcap"})
    prog = "set -u\n"
    for p in paths:
        prog += ('p="$HOME/%s"\nif [ -r "$p" ]; then echo "=== FILE %s ==="; base64 "$p"; '
                 'else echo "=== MISSING %s ==="; fi\n' % (p[2:], p, p))
    prog += 'echo "--- end ---"\n'
    try:
        proc = subprocess.run(["ssh", "-n", *_SSH_OPTS, host, prog],
                              capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL)
    except (subprocess.TimeoutExpired, OSError) as exc:
        _REMOTE[host] = ReadSkip(f"{host} did not answer — {exc}")
        return _REMOTE[host]
    if proc.returncode != 0 or "--- end ---" not in proc.stdout:
        why = (proc.stderr or proc.stdout).strip().splitlines()
        _REMOTE[host] = ReadSkip(f"{host} unreachable (rc={proc.returncode}: {why[0][:120] if why else 'no output'})")
        return _REMOTE[host]
    import base64, tempfile
    if not _REMOTE_DIR:
        _REMOTE_DIR = tempfile.mkdtemp(prefix="pref-check-remote.")
    files, cur, buf = {}, None, []
    def flush():
        if cur is not None:
            local = os.path.join(_REMOTE_DIR, host + "__" + cur[2:].replace("/", "__"))
            with open(local, "wb") as fh:
                fh.write(base64.b64decode("".join(buf)))
            files[cur] = local
    for line in proc.stdout.splitlines():
        m = re.fullmatch(r"=== FILE (\S+) ===", line)
        if m:
            flush(); cur, buf = m.group(1), []
            continue
        m = re.fullmatch(r"=== MISSING (\S+) ===", line)
        if m:
            flush(); cur = None; files[m.group(1)] = None
            continue
        if line == "--- end ---":
            flush(); cur = None
            continue
        if cur is not None:
            buf.append(line)
    _REMOTE[host] = files
    return files


def remote_path(t, targets):
    """The local file standing in for a remote target's path — None if the box
    does not have it, ReadSkip (raised) if the box could not be asked."""
    got = _remote_fetch(t["host"], targets)
    if isinstance(got, ReadSkip):
        raise got
    return got.get(t["path"])


def entry_problems(name, entry, targets, where="the spec"):
    """Structural faults in one [pref.X.targets.Y] entry, as messages.

    Reads no live config, so this is safe to run in CI where none of the
    applications exist.

    An ABSENT `state` is `enforce`: that is what all but a handful of entries
    say, and a host half full of bare entries should not have to repeat it. A
    PRESENT one this file does not know stays the failure it always was — a
    typo must never be read as a default.
    """
    state = entry.get("state", "enforce")
    if state not in STATES:
        return [f"unknown state '{entry.get('state')}' in {where}"]

    if state == "n_a":
        return []

    if state == "unreachable":
        if entry.get("recheck") == "auto":
            # A typo here used to fall through to the manual branch and print
            # "unreachable, manual re-check" — cancelling the subscription with a
            # message asserting it never had one.
            probe = entry.get("probe")
            if probe not in PROBES:
                return [f"recheck='auto' names unknown probe '{probe}'"]
        elif not entry.get("evidence"):
            # Without evidence the entry is the shrug the design says it is not,
            # and the live run would print a bare "?" as its justification.
            return ["state='unreachable' with no evidence — record why, or it is a shrug"]
        return []

    problems = []
    # Quote the state only when the file wrote one: naming `state='enforce'` on
    # an entry that never said it sends the reader looking for a line to fix
    # that is not there.
    said = "state='enforce' with no" if entry.get("state") else "no"
    if not entry.get("key"):
        problems.append(f"{said} key")
    present = [m for m in MATCHERS if entry.get(m) is not None]
    if not present:
        problems.append(f"{said} want / want_contains / want_all_contain / want_any_contain / want_any / want_absent")
    # Every matcher takes a QUOTED string; `want = 16` would otherwise never
    # match, because every read is normalised to a string before comparison.
    bad_type = [m for m in present if not isinstance(entry[m], str)]
    if bad_type:
        problems.append(f"{', '.join(bad_type)} must be a quoted string")
    # An EMPTY string on any matcher but `want` matches everything — `"" in got`
    # is always true — so a row truncated to want_contains = "" is green
    # forever (auditor, 16-09-2026). `want = ""` stays legal: it asserts a blank.
    empty = [m for m in present if m != "want" and entry[m] == ""]
    if empty:
        problems.append(f"{', '.join(empty)} is empty and would match anything")
    t, _, err = resolve_target(name, entry, targets, where)
    if err:
        problems.append(err)
    elif entry.get("unset_reads_default") and t["format"] not in DEFAULT_ORACLES:
        problems.append(f"unset_reads_default on format '{t['format']}', which ships no defaults oracle")
    elif entry.get("unset_reads_default") and entry.get("accumulate"):
        # An accumulating directive's "default" is a whole shipped TABLE, not a
        # value, so reading one line of it would pass a row over a config that
        # declares none of them.
        problems.append("unset_reads_default with accumulate — an accumulating directive has no single default")
    return problems


CEILING_HEADING = "## Where this cannot be reached"
CEILING_CODE = re.compile(r"`([a-z_]+ / [a-z_0-9]+)`")


def prose_ceilings(path):
    """The `pref / target` codes in preferences.md's ceiling table, or None.

    None means the file has no ceiling table — a distinct answer from "the table
    lists nothing", and the caller reports it rather than letting it read as
    agreement. Only TABLE CELLS are scanned, and a cell must be exactly one
    code: prose in that section mentions these codes in passing, and matching
    those would make the check agree with itself.
    """
    with open(path, encoding="utf-8-sig") as fh:
        text = fh.read()
    start = text.find(CEILING_HEADING)
    if start == -1:
        return None
    rest = text[start + len(CEILING_HEADING):]
    end = rest.find("\n## ")
    section = rest if end == -1 else rest[:end]

    codes = set()
    for line in section.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        for cell in (c.strip() for c in line.strip("|").split("|")):
            m = CEILING_CODE.fullmatch(cell)
            if m:
                codes.add(m.group(1))
    return codes


PUBLISHED_HEX = re.compile(r"^\|[^|]*\|\s*`(#[0-9a-fA-F]{6})`\s*\|", re.M)
PUBLISHED_FAMILY = re.compile(r"(\w+)\s+`(#[0-9a-fA-F]{6})`")
ANY_HEX = re.compile(r"#[0-9a-fA-F]{6}")


def emit_published_palette_correspondence(spec, targets):
    """Compare the published palette table against what this spec asserts.

    The mirror ships `public/` and nothing else, so public/prompt/README.md
    cannot defer to preferences.md the way every other page here does — its
    readers have only that file. Until 25-08-2026 the spec header claimed "no
    other copy of them belongs anywhere" while this copy shipped, unpoliced, and
    a theme swap would have updated the spec and left the published palette
    describing the previous theme.

    ONE DIRECTION: every hex this spec asserts must appear in the published
    table. The table also documents colours the spec says nothing about (green,
    red, foreground, ...), so checking the converse would manufacture failures
    out of a more complete document.

    Silent when the spec declares no terminal palette — a fixture spec must not
    drag the real repo's README into an unrelated test.
    """
    pal = spec.get("pref", {}).get("terminal_palette")
    if not pal:
        return 0

    asserted = set()
    for entry in pal.get("targets", {}).values():
        for m in MATCHERS:
            v = entry.get(m)
            if isinstance(v, str):
                asserted.update(h.lower() for h in ANY_HEX.findall(v))
    if not asserted:
        return 0

    if not os.path.isfile(PUBLISHED):
        emit("warn", f"published palette: cross-check skipped — nothing at {PUBLISHED}")
        return 0

    with open(PUBLISHED, encoding="utf-8") as fh:
        text = fh.read()
    name = os.path.basename(PUBLISHED)
    failed = 0

    table = {h.lower() for h in PUBLISHED_HEX.findall(text)}
    missing = sorted(asserted - table)
    if missing:
        emit("fail", f"published palette: {name}'s table is missing {', '.join(missing)} — "
                     "the mirror ships it and this spec does not, so it is the only palette "
                     "statement its readers get")
        failed = 1
    else:
        emit("ok", f"published palette: {name}'s table carries every asserted hex")

    theme = pal.get("value")
    if isinstance(theme, str):
        if theme in text:
            emit("ok", f"published palette: {name} names the asserted theme ({theme})")
        else:
            emit("fail", f"published palette: {name} does not name '{theme}' — a theme swap "
                         "moved the spec and left the published heading behind")
            failed = 1

    failed |= _theme_page_correspondence(asserted, theme)

    # The model-family colours are a second published copy, of cship.toml rather
    # than of this spec. Same failure mode, and there is now a reader for it.
    cship = targets.get("cship")
    # The paragraph, not the line: the published list wraps, and matching one
    # line silently dropped the last family — a check that under-reports while
    # printing ok for the ones it did reach.
    line = None
    if "Model families:" in text:
        para = text[text.index("Model families:"):]
        line = para.split("\n\n", 1)[0].replace("\n", " ")
    if isinstance(cship, dict) and line:
        path = os.path.expanduser(cship.get("path", ""))
        if os.path.isfile(path):
            for family, hexval in PUBLISHED_FAMILY.findall(line):
                try:
                    live = read_toml(path, f"cship.model.family_style.{family.lower()}")
                except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError) as exc:
                    emit("fail", f"published palette: could not read cship families — {exc}")
                    failed = 1
                    break
                if live is None:
                    continue
                if hexval.lower() in str(live).lower():
                    emit("ok", f"published palette: {family} family matches cship.toml ({hexval})")
                else:
                    emit("fail", f"published palette: {name} says {family} is {hexval}, "
                                 f"cship.toml says '{live}'")
                    failed = 1
    return failed


def _theme_page_correspondence(asserted, theme):
    """The kitty drop-in's palette tables against the spec and the theme file.

    The page says its tables are read off current-theme.conf, and both ship, so
    a hex on the page that the file does not carry is a stale copy — the same
    failure the prompt page had before 25-08-2026, one directory over. Returns
    1 on a mismatch, 0 otherwise and when the page is not there to check.
    """
    if not PUBLISHED_THEME_PAGE or not os.path.isfile(PUBLISHED_THEME_PAGE):
        return 0
    with open(PUBLISHED_THEME_PAGE, encoding="utf-8") as fh:
        text = fh.read()
    name = "terminal/kitty/README.md"
    failed = 0
    table = {h.lower() for h in ANY_HEX.findall(text)}
    missing = sorted(asserted - table)
    if missing:
        emit("fail", f"published palette: {name}'s tables are missing {', '.join(missing)}")
        failed = 1
    else:
        emit("ok", f"published palette: {name}'s tables carry every asserted hex")
    if os.path.isfile(SHIPPED_THEME):
        with open(SHIPPED_THEME, encoding="utf-8") as fh:
            shipped = {h.lower() for h in ANY_HEX.findall(fh.read())}
        stale = sorted(table - shipped)
        if stale:
            emit("fail", f"published palette: {name} lists {', '.join(stale)}, which "
                         "current-theme.conf beside it does not carry — the table is read off that file")
            failed = 1
        else:
            emit("ok", f"published palette: every hex on {name} is in current-theme.conf")
    if isinstance(theme, str) and theme not in text:
        emit("fail", f"published palette: {name} does not name '{theme}'")
        failed = 1
    return failed


def emit_ceiling_correspondence(spec):
    """Assert preferences.md's ceiling table and the spec's `unreachable` entries
    are the same set. Returns 1 if they are not.

    preferences.md promises "if one ever lifts, it is noticed." Until 14-08-2026
    nothing compared the two lists and they disagreed in BOTH directions, so a
    ceiling could be listed and unwatched, or watched and unlisted.
    """
    declared = {
        f"{pid} / {tname}"
        for pid, pref in spec.get("pref", {}).items()
        for tname, entry in pref.get("targets", {}).items()
        if entry.get("state") == "unreachable"
    }
    if not os.path.isfile(PROSE):
        if not declared:
            # Neither half has a ceiling in it, so there is no pair to compare
            # and nothing to report. Keeps an all-`n_a` spec genuinely silent,
            # which is a property the suite asserts.
            return 0
        # Ceilings are declared but there is no prose half at all — the shape of
        # a test fixture rather than of the real SSOT. A test asserts the
        # SHIPPED pair does not take this branch, so the skip cannot quietly
        # become permanent.
        emit("warn", f"ceilings: cross-check skipped — no prose half at {PROSE}"
                     if PROSE else f"ceilings: cross-check skipped — {PROSE_ABSENT}")
        return 0

    listed = prose_ceilings(PROSE)
    if listed is None:
        emit("fail", f"ceilings: {os.path.basename(PROSE)} has no '{CEILING_HEADING.lstrip('# ')}' table — the two halves of the SSOT went unchecked")
        return 1

    prose_name = os.path.basename(PROSE)
    failed = 0
    for code in sorted(declared - listed):
        emit("fail", f"ceilings: `{code}` is unreachable in the spec but absent from {prose_name}'s ceiling table")
        failed = 1
    for code in sorted(listed - declared):
        emit("fail", f"ceilings: {prose_name} lists `{code}`, which is not an unreachable entry in the spec")
        failed = 1
    if not failed:
        emit("ok", f"ceilings: {prose_name}'s table and the spec's unreachable entries match")
    return failed


# ── surfaces: the version event ───────────────────────────────────────────────
# "A closed surface re-enters only on an event." Until 11-09-2026 the event was
# remembered, not observed: atuin and gh print their own update notices, and
# every other bump needed a sweep run by hand against a stamp file. This reads
# the installed version of every tool a closed surface names and compares it
# with the version the surface was closed at — never by launching an
# application: a bundle's Info.plist, Homebrew's linked keg, a manifest, an
# archive name, or one CLI binary run with one version flag in an empty world.
# A moved version is a WARN naming the surface, because a bump is a signal for
# a pass, not drift in a value; an unreadable one is a warn too, since an app
# that moved is an event of its own kind. Nothing here may crash the run, and
# nothing read from the machine may split an output line: every input problem
# is a printed line, and every printed string is scrubbed of control characters.

SURFACE_READERS = ("plist", "brew", "command", "asar", "json", "zip")
SURFACE_NAME = re.compile(r"[A-Za-z0-9_.@+-]+")
FORMULA_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9@._+-]*")
_CONTROL = re.compile(r"[\x00-\x1f\x7f]")
# The only argv[1] a `command` may carry. One binary, one flag: nothing that
# can name, build or read a second program — no shell, no -c, no -e, no script
# path, no subcommand word (`sh version` would run ./version). `-v` is not
# here: on the shells and on vim it means verbose, and verbose means RUN — zsh
# read ~/.zshenv and tmux forked a server under it (audit, 11-09-2026).
VERSION_FLAGS = ("--version", "-version", "-V", "-productVersion", "-buildVersion")
_KITTY_WORD = re.compile(r"\bkitt(?:y|en)\b", re.I)
_DIGIT = re.compile(r"\d")
# Homebrew's prefix: the linked keg is `opt/<formula>`, a symlink into the
# Cellar whose target's basename IS the version — read off the filesystem, no
# brew call. PREF_BREW_PREFIX lets the suite build a fixture Cellar.
BREW_PREFIX = os.environ.get("PREF_BREW_PREFIX") or os.environ.get("HOMEBREW_PREFIX") or (
    "/opt/homebrew" if os.path.isdir("/opt/homebrew") else "/usr/local")
ASAR_GLOB = os.environ.get("PREF_ASAR_GLOB") or OBSIDIAN_ASAR_GLOB
COMMAND_TIMEOUT = float(os.environ.get("PREF_COMMAND_TIMEOUT") or 10)
# What a version command sees: a system PATH, a scratch HOME and cwd, nothing
# inherited. A flag that starts the program instead of printing (vim's -V)
# then starts it with no rc file, no plugin path, no variable to load code
# through, and nowhere durable to write — and the timeout ends it as
# unreadable.
COMMAND_PATH = "/usr/bin:/bin:/usr/sbin:/sbin"


def _scrub(text):
    """Control characters out of anything that reaches an output line."""
    return _CONTROL.sub("?", str(text))


def _forbidden_binary(text):
    """The kitty binary named in a command — argv[0], a path component, a
    bundle id. Tested on the raw string and on the unquoted argv, so a quoted
    or escaped spelling folds back to the word first; and again at run time
    on the RESOLVED path, so a symlink under another name is refused where
    it lands (traps.md § "Never `kitty @` or `kitten @` from a script")."""
    return bool(_KITTY_WORD.search(text))


def _command_argv(command):
    """(argv, problem) for a `command` string — the whole rule in one place."""
    try:
        argv = shlex.split(command)
    except ValueError as exc:
        return [], f"`command` does not parse — {exc}"
    if not argv:
        return [], "`command` must be a non-empty string"
    if _forbidden_binary(command) or _forbidden_binary(" ".join(argv)):
        return argv, "`command` names the kitty binary — never from a check; read the bundle's Info.plist"
    if len(argv) != 2 or argv[1] not in VERSION_FLAGS:
        return argv, f"`command` is one binary and one version flag ({', '.join(VERSION_FLAGS)}) — nothing that can name a second program"
    head = argv[0]
    if "/" in head and not (head.startswith("/") or head.startswith("~/")):
        return argv, "`command` binary is a relative path — it would resolve against whatever the doctor's cwd is; use an absolute path, ~/…, or a bare name"
    return argv, None


def surface_problems(tool):
    """Structural problems with one tool entry of a [surfaces.*.tools] table.
    Shared by --validate-spec and the run, like entry_problems(). Touches no
    file and runs nothing."""
    if not isinstance(tool, dict):
        return ["tool entry is not a table"]
    problems = []
    for k, v in tool.items():
        if isinstance(v, str) and _CONTROL.search(v):
            problems.append(f"`{k}` carries a control character")
    readers = [k for k in SURFACE_READERS if k in tool]
    if len(readers) != 1:
        problems.append(f"needs exactly one of {'/'.join(SURFACE_READERS)}, has {len(readers)}")
    at = tool.get("at")
    if not isinstance(at, str) or not at.strip():
        problems.append("`at` must be a non-empty quoted string — the version the surface was closed at")
    for k in ("plist", "json", "zip", "member"):
        if k in tool and not (isinstance(tool[k], str) and tool[k].strip()):
            problems.append(f"`{k}` must be a non-empty path")
    if ("member" in tool) != ("zip" in tool):
        problems.append("`zip` and `member` go together — the archive, and the JSON file inside it")
    if "brew" in tool and not (tool["brew"] is True or (isinstance(tool["brew"], str) and FORMULA_NAME.fullmatch(tool["brew"]))):
        problems.append("`brew` is true (the formula is the tool's name) or a formula name — letters, digits, @ . _ + -, no path")
    if "asar" in tool and tool["asar"] is not True:
        problems.append("`asar` is true — Obsidian's installed archive, the readers' own chooser")
    if "command" in tool:
        command = tool["command"] if isinstance(tool["command"], str) else ""
        _, problem = _command_argv(command)
        if problem:
            problems.append(problem)
    unknown = sorted(set(tool) - set(SURFACE_READERS) - {"at", "member"})
    if unknown:
        problems.append(f"unknown field(s): {', '.join(unknown)}")
    return problems


def _version_from_json(data, where):
    if not isinstance(data, dict):
        raise ReadError(f"{where} is not a JSON object")
    version = data.get("version")
    if not isinstance(version, str) or not version.strip():
        raise ReadError(f"{where} carries no string `version`")
    return version.strip()


def _read_plist_version(tool):
    path = os.path.expanduser(tool["plist"])
    try:
        with open(path, "rb") as fh:
            data = plistlib.load(fh)
    except OSError as exc:
        raise ReadError(f"no bundle at {path} — {exc.strerror}")
    except (plistlib.InvalidFileException, ExpatError, ValueError, OverflowError, TypeError) as exc:
        raise ReadError(f"{path} is not a readable plist — {exc}")
    if not isinstance(data, dict):
        raise ReadError(f"{path} has no dict at its root")
    version = data.get("CFBundleShortVersionString")
    if not isinstance(version, str) or not version.strip():
        raise ReadError(f"{path} carries no string CFBundleShortVersionString")
    return version.strip()


def _read_brew_version(name, tool):
    formula = name if tool["brew"] is True else tool["brew"]
    if not FORMULA_NAME.fullmatch(formula):
        raise ReadError(f"{formula!r} is not a formula name")
    prefix = os.path.realpath(BREW_PREFIX)
    if not os.path.isdir(prefix):
        raise ReadError(f"no Homebrew prefix at {BREW_PREFIX}")
    opt = os.path.join(prefix, "opt", formula)
    if not os.path.islink(opt):
        raise ReadError(f"{formula} has no linked keg under {BREW_PREFIX}/opt")
    keg = os.path.realpath(opt)
    cellar = os.path.join(prefix, "Cellar", formula) + os.sep
    if not keg.startswith(cellar):
        raise ReadError(f"{opt} points outside the Cellar, at {keg}")
    if not os.path.isdir(keg):
        raise ReadError(f"{opt} points at {keg}, which is not a keg directory")
    version = os.path.basename(keg)
    if not _DIGIT.search(version):
        raise ReadError(f"{opt} points at {version!r}, which carries no digit — not a version")
    return version


def _read_asar_version():
    found = [p for p in glob.glob(os.path.expanduser(ASAR_GLOB))
             if os.path.isfile(p) and _obsidian_asar_version(p)]
    if not found:
        raise ReadError(f"no Obsidian archive named obsidian-<version>.asar matches {ASAR_GLOB}")
    return ".".join(str(n) for n in _obsidian_asar_version(max(found, key=_obsidian_asar_version)))


def _read_json_version(tool):
    path = os.path.expanduser(tool["json"])
    try:
        with open(path, "rb") as fh:
            data = json.load(fh)
    except OSError as exc:
        raise ReadError(f"no file at {path} — {exc.strerror}")
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as exc:
        raise ReadError(f"{path} is not JSON — {exc}")
    return _version_from_json(data, path)


def _read_zip_version(tool):
    path = os.path.expanduser(tool["zip"])
    member = tool["member"]
    try:
        with zipfile.ZipFile(path) as zf:
            raw = zf.read(member)
    except OSError as exc:
        raise ReadError(f"no archive at {path} — {exc.strerror}")
    except zipfile.BadZipFile as exc:
        raise ReadError(f"{path} is not a zip — {exc}")
    except KeyError:
        raise ReadError(f"{path} has no member {member}")
    except (RuntimeError, NotImplementedError, ValueError, zipfile.LargeZipFile) as exc:
        raise ReadError(f"{path}:{member} cannot be read — {exc}")
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as exc:
        raise ReadError(f"{path}:{member} is not JSON — {exc}")
    return _version_from_json(data, f"{path}:{member}")


def _read_command_version(tool):
    argv, problem = _command_argv(tool["command"])
    if problem:
        raise ReadError(problem)
    head = os.path.expanduser(argv[0])
    if "/" not in head:
        resolved = shutil.which(head)
        if resolved is None:
            raise ReadError(f"{head} is not on PATH")
        head = resolved
    real = os.path.realpath(head)
    if _forbidden_binary(real):
        raise ReadError(f"{argv[0]} resolves to {real} — the kitty binary, refused")
    argv = [head, argv[1]]
    with tempfile.TemporaryDirectory(prefix="pref-surface-") as scratch:
        env = {"PATH": COMMAND_PATH, "HOME": scratch, "TMPDIR": scratch, "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}
        try:
            out = subprocess.run(argv, capture_output=True, text=True, errors="replace",
                                 stdin=subprocess.DEVNULL, cwd=scratch, env=env,
                                 timeout=COMMAND_TIMEOUT)
        except subprocess.TimeoutExpired:
            raise ReadError(f"{' '.join(argv)} ran past {COMMAND_TIMEOUT:g} s — a flag that starts the program is not a version flag")
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            raise ReadError(f"{argv[0]} — {exc}")
    # The first non-empty line, from stdout or — `ssh -V` — stderr.
    line = next((l.strip() for stream in (out.stdout, out.stderr)
                 for l in stream.splitlines() if l.strip()), "")
    if out.returncode != 0:
        raise ReadError(f"{' '.join(argv)} exited {out.returncode}" + (f" — {line}" if line else ""))
    if not line:
        raise ReadError(f"{' '.join(argv)} printed nothing")
    if not _DIGIT.search(line):
        # A line with no digit is not a version — a usage line, a warning, a
        # shell's "command not found". Stamping `at` from it would read as
        # closed forever.
        raise ReadError(f"{' '.join(argv)} printed '{line}', which carries no digit — not a version")
    return line


def read_surface_version(name, tool):
    """The installed version of one validated tool, or raise ReadError."""
    if "plist" in tool:
        return _read_plist_version(tool)
    if "brew" in tool:
        return _read_brew_version(name, tool)
    if "asar" in tool:
        return _read_asar_version()
    if "json" in tool:
        return _read_json_version(tool)
    if "zip" in tool:
        return _read_zip_version(tool)
    return _read_command_version(tool)


def _surface_tables(spec):
    """(problems, surfaces) — the structural verdict on [surfaces] as a whole.
    Absent is fine; present and not a non-empty table of tables is not."""
    if "surfaces" not in spec:
        return [], {}
    surfaces = spec["surfaces"]
    if not isinstance(surfaces, dict):
        return ["[surfaces] is not a table"], {}
    if not surfaces:
        return ["[surfaces] is present but declares no surface"], {}
    return [], surfaces


def _surface_tool_problems(sname, surface):
    """(problems keyed by label, tools) for one surface, structure only."""
    if not SURFACE_NAME.fullmatch(sname):
        return {f"surface {_scrub(sname)!r}": ["surface name must be letters, digits, _ . @ + -"]}, {}
    if not isinstance(surface, dict):
        return {f"surface {sname}": ["is not a table"]}, {}
    tools = surface.get("tools")
    if not isinstance(tools, dict) or not tools:
        return {f"surface {sname}": [f"declares no [surfaces.{sname}.tools] table — watches nothing"]}, {}
    extra = sorted(set(surface) - {"tools"})
    problems = {}
    if extra:
        problems[f"surface {sname}"] = [f"unknown field(s): {', '.join(_scrub(e) for e in extra)}"]
    for name, tool in tools.items():
        if not SURFACE_NAME.fullmatch(str(name)):
            problems[f"surface {sname} / {_scrub(name)!r}"] = ["tool name must be letters, digits, _ . @ + -"]
            continue
        found = surface_problems(tool)
        if found:
            problems[f"surface {sname} / {name}"] = found
    return problems, tools


def validate_surfaces(spec):
    """Every structural problem in [surfaces], as (label, problem) pairs.
    Reads nothing and runs nothing — safe where no application exists."""
    top, surfaces = _surface_tables(spec)
    out = [("[surfaces]", p) for p in top]
    for sname, surface in sorted(surfaces.items(), key=lambda kv: str(kv[0])):
        problems, _ = _surface_tool_problems(str(sname), surface)
        for label, found in problems.items():
            out.extend((label, _scrub(p)) for p in found)
    return out


def emit_surface_events(spec):
    """One line per tool of every closed surface. Returns 1 only for a
    malformed entry — a moved version is a warn, never a failure."""
    if "surfaces" not in spec:
        return 0
    emit("section", "== surfaces ==")
    failed = 0
    top, surfaces = _surface_tables(spec)
    for problem in top:
        emit("fail", f"[surfaces]: {problem}")
        failed = 1
    for sname, surface in sorted(surfaces.items(), key=lambda kv: str(kv[0])):
        sname = str(sname)
        problems, tools = _surface_tool_problems(sname, surface)
        for label, found in problems.items():
            for problem in found:
                emit("fail", f"{label}: {_scrub(problem)}")
            failed = 1
        for name, tool in sorted(tools.items(), key=lambda kv: str(kv[0])):
            label = f"surface {sname} / {name}"
            if not SURFACE_NAME.fullmatch(str(name)) or label in problems:
                continue
            try:
                installed = _scrub(read_surface_version(name, tool))
            except ReadError as exc:
                emit("warn", f"{label}: version unreadable — {_scrub(exc)}")
                continue
            at = _scrub(tool["at"].strip())
            if installed == at:
                emit("ok", f"{label}: {installed}, as closed")
            else:
                emit("warn", f"{label}: EVENT — closed at {at}, installed {installed}; re-enter the surface, then stamp `at`")
    return failed


_SINK = None


def emit(status, message, kind=""):
    # `--prove` runs the assertion loop twice and compares the two verdicts, so
    # it needs the lines as values rather than as output. Nothing else sets the
    # sink, and it is always cleared in a finally.
    #
    # `kind` never reaches the output. It carries WHY a line says what it says,
    # for the one caller that has to tell two identical-looking failures apart —
    # a row red because the config's content decided it, and a row red because
    # the document could not be read at all. Parsing that back out of the
    # message text would be a second statement of the same rule, one sentence
    # rewrite from silently disagreeing.
    if _SINK is None:
        print(f"{status}\t{message}")
    else:
        _SINK.append((status, message, kind))


# Formats whose "path" is not a file this checker could empty: two run the
# application's own resolver over a live process, and a `defaults` path is a
# preferences DOMAIN. A row on one of them is out of --prove's scope, and said
# so rather than dropped.
LIVE_FORMATS = ("zshcap", "obsidiancap", "defaults")

# The emptiest document each reader still accepts, MEASURED by handing one to
# every reader with a key out of the real spec: each answered "absent" rather
# than raising. Anything not named here is a line format, where empty is the
# empty file.
#
# ⚠️ Two readers answered a VALUE for an emptied file, because they ask the
# application rather than parse the text: `gh config get accessible_colors`
# returns `disabled` and `ssh -G` resolves its own defaults. Rows on those are
# provable only where the wanted value differs from the application's default —
# the rest survive, and survive HONESTLY: the file's content really does not
# decide them. They are reported as survivors, not exempted.
EMPTY_DOCUMENT = {"jsonc": "{}\n", "idea": "<application/>\n"}
RESOLVER_FORMATS = ("ghcfg", "sshcfg")


def empty_document(fmt):
    """The emptiest document `fmt`'s reader still reads as "key absent".

    `PREF_PROVE_EMPTY=<format>=<text>` replaces one, which is how the branch
    that refuses to score an UNREADABLE copy as a proof is testable at all:
    every entry above was chosen because its reader accepts it, so nothing in
    the real table can reach that branch. Same seam, same reason, as
    PREF_KITTY_REF — a path that cannot be aimed at a fixture cannot be tested.
    """
    override = os.environ.get("PREF_PROVE_EMPTY", "")
    name, sep, text = override.partition("=")
    if sep and name == fmt:
        return text
    return EMPTY_DOCUMENT.get(fmt, "")


def prove_scope(tname, entry, targets, where):
    """Why this row is out of --prove's scope, or None when it is in.

    Ordered so the answer names the row's OWN property first — a want_absent
    row is unprovable wherever its file lives — and only then this machine's.
    """
    state = entry.get("state", "enforce")
    if state == "n_a":
        return "not asserted (state = n_a)"
    if state == "unreachable":
        return "a ceiling, not a file assertion (state = unreachable)"
    if entry_problems(tname, entry, targets, where):
        return "structurally invalid — the ordinary run reports it"
    if entry.get("want_absent") is not None:
        return ("want_absent — an emptied file is this row's PASSING answer, "
                "so emptying one proves nothing about it")
    t, path, err = resolve_target(tname, entry, targets, where)
    if err:
        return f"unresolvable target — {err}"
    if t.get("host"):
        return f"remote — the file lives on {t['host']}, and a copy emptied here says nothing about it"
    if t["format"] in LIVE_FORMATS:
        return f"read from a live application, not a file ({t['format']})"
    if not os.path.isfile(path):
        return f"not deployed here — nothing at {t['path']}"
    return None


def prove(spec, targets, came_from):
    """Mutate a COPY of every text-read target and require each row to go red.

    A row that stays green over an emptied config is not asserting the file's
    content — whatever else it may be doing, it cannot fail because of what the
    file says, and until this verb existed that was provable only one row at a
    time, by hand, in a dated battery.

    Two runs of the ordinary assertion loop, laid side by side: the CONTROL on
    the real files, which must be green or the row proves nothing by going red;
    and the mutated run on the copies. The real files are never opened for
    writing — the copies live in a temp directory that is removed on the way
    out, and each sits alone in its own subdirectory, so an include or a
    `source-file` beside the original is simply absent.
    """
    rows, failed = [], 0
    for pref_id, pref in sorted(spec.get("pref", {}).items()):
        for tname, entry in sorted(pref.get("targets", {}).items()):
            label = f"{pref_id} / {tname}"
            why = prove_scope(tname, entry, targets, came_from(pref_id, tname))
            if why:
                emit("warn", f"{label}: out of scope — {why}")
            else:
                rows.append((label, pref_id, tname, entry))

    if not rows:
        return failed

    scratch = tempfile.mkdtemp(prefix="pref-prove.")
    try:
        emptied = copy.deepcopy(targets)
        for _, _, tname, entry in rows:
            name = entry.get("target", tname)
            t = targets[name]
            room = os.path.join(scratch, name)
            os.makedirs(room, exist_ok=True)
            copy_path = os.path.join(room, os.path.basename(os.path.expanduser(t["path"])))
            with open(copy_path, "w", encoding="utf-8") as fh:
                fh.write(empty_document(t["format"]))
            emptied[name]["path"] = copy_path

        only = {"pref": {}}
        for label, pref_id, tname, entry in rows:
            only["pref"].setdefault(pref_id, {}).setdefault("targets", {})[tname] = entry
        control = _run_quietly(only, targets, came_from)
        mutated = _run_quietly(only, emptied, came_from)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)

    # The three lists are laid side by side by POSITION, so an assertion loop
    # that ever emitted a different number of lines than there are rows would
    # hand every verdict to the wrong row — silently, and looking fine.
    if not len(rows) == len(control) == len(mutated):
        emit("fail", f"--prove cannot line up its runs: {len(rows)} rows against "
                     f"{len(control)} control and {len(mutated)} mutated lines")
        return 1

    for (label, _, tname, entry), (cs, cm, _ck), (ms, mm, mk) in zip(rows, control, mutated):
        name = entry.get("target", tname)
        said = cm.split(": ", 1)[-1]
        if cs != "ok":
            emit("fail", f"{label}: control is not green — '{cs}' on the real file "
                         f"({said}), so emptying it proves nothing")
            failed = 1
        elif ms == "ok" and entry.get("unset_reads_default"):
            emit("ok", f"{label}: reads the shipped default — correctly still ok with {name} emptied")
        elif ms == "ok":
            hint = (f", and {targets[name]['format']} answers from the application's own defaults"
                    if targets[name]["format"] in RESOLVER_FORMATS else "")
            emit("fail", f"{label}: SURVIVES — still ok with {name} emptied{hint}, "
                         "so nothing in that file can make this row fail")
            failed = 1
        elif ms == "fail" and mk != "unreadable":
            emit("ok", f"{label}: proved — goes red with {name} emptied")
        else:
            # Red for a reason that is not the assertion — the emptied document
            # did not parse, or the read was skipped — proves nothing about
            # whether this row's config content decides it. Scoring that as a
            # proof is the vacuous pass this verb exists to refuse, reproduced
            # inside the verb itself.
            emit("warn", f"{label}: unprovable — an emptied {name} is not a document this "
                         f"reader can read ({mm.split(': ', 1)[-1]})")
    return failed


def _run_quietly(spec, targets, came_from):
    """The assertion loop's lines as values: one per row, in the loop's order."""
    global _SINK
    _SINK = []
    try:
        emit_assertions(spec, targets, came_from, "")
        return _SINK
    finally:
        _SINK = None


def main():
    argv = sys.argv[1:]

    if argv and argv[0] == "--spec-files":
        # The shell half can no longer know where a spec lives — there are three
        # layouts — so it asks. rc 3 is "this checkout has none", the one answer
        # that keeps its section silent; the list itself is what it guards on.
        # Not 2: that is an argument error, which must not silence it.
        for path in SPEC_FILES:
            print(spec_name(path))
        return 0 if SPEC_FILES else 3

    spec, origin, load_problems = merge_specs(SPEC_FILES)
    read = ", ".join(spec_name(p) for p in SPEC_FILES) or "no spec file was found"
    if load_problems:
        for problem in load_problems:
            emit("fail", problem)
        return 1

    # Where an entry came from, for a diagnostic that has to name one file out
    # of several. Falls back to the whole list rather than to a filename that
    # might be the wrong half.
    def came_from(pref_id, tname):
        return origin.get(f"pref.{pref_id}.targets.{tname}", read)

    targets = spec.get("targets")
    if not isinstance(targets, dict):
        emit("fail", f"no [targets] table in {read}")
        return 1

    SPEC_PATHS["probes"] = spec.get("probes") if isinstance(spec.get("probes"), dict) else {}
    SPEC_PATHS["oracles"] = spec.get("oracles") if isinstance(spec.get("oracles"), dict) else {}

    if argv and argv[0] == "--validate-spec":
        # Structure only, never live config — safe in CI, where none of the
        # applications exist. This is what tests/test-pref-check.sh calls
        # instead of restating the rules.
        failed = emit_ceiling_correspondence(spec)
        for pref_id, pref in sorted(spec.get("pref", {}).items()):
            entries = pref.get("targets", {})
            if not entries:
                emit("warn", f"{pref_id}: declared with no targets — asserts nothing")
                continue
            for tname, entry in sorted(entries.items()):
                for problem in entry_problems(tname, entry, targets, came_from(pref_id, tname)):
                    emit("fail", f"{pref_id} / {tname}: {problem}")
                    failed = 1
        for label, problem in validate_surfaces(spec) + validate_spec_paths(spec):
            emit("fail", f"{label}: {problem}")
            failed = 1
        if not failed:
            emit("ok", "spec is structurally valid")
        return failed

    if argv and argv[0] == "--prove":
        return prove(spec, targets, came_from)

    if argv and argv[0] == READ:
        tname, key = argv[1], argv[2]
        t = targets.get(tname)
        if not isinstance(t, dict):
            sys.exit(f"unknown target '{tname}' — known: {', '.join(sorted(targets))}")
        path = os.path.expanduser(t["path"])
        host = t.get("host")
        try:
            if host and t["format"] != "zshcap":
                path = remote_path(t, targets)
                if path is None:
                    sys.exit(f"{t['path']} is not on {host}")
            print(normalise(READERS[t["format"]](path, key, accumulate=True, host=host)))
        except ReadSkip as exc:
            sys.exit(f"skipped {key} from {t['path']}: {exc}")
        except (OSError, ReadError, ET.ParseError, json.JSONDecodeError, tomllib.TOMLDecodeError, UnicodeDecodeError) as exc:
            sys.exit(f"could not read {key} from {t['path']}: {exc}")
        return 0

    failed = emit_ceiling_correspondence(spec)
    failed |= emit_published_palette_correspondence(spec, targets)
    for label, problem in validate_spec_paths(spec):
        emit("fail", f"{label}: {problem}")
        failed = 1
    failed |= emit_assertions(spec, targets, came_from, read)
    failed |= emit_surface_events(spec)
    return failed


def emit_assertions(spec, targets, came_from, read):
    """One line per [pref.X.targets.Y] entry, read from the live config.

    Lifted out of main() so `--prove` can run the SAME loop twice — once on the
    real files, once on emptied copies — instead of restating what a row means,
    which is the one kind of second copy this checker exists to refuse. Exactly
    one line per entry, in sorted order: that is what lets the two runs be laid
    side by side.
    """
    failed = 0
    prefs = spec.get("pref", {})
    if not prefs:
        emit("warn", f"no [pref.*] entries in {read}")

    for pref_id, pref in sorted(prefs.items()):
        entries = pref.get("targets", {})
        if not entries:
            # A preference declared and asserted nowhere is invisible, which is
            # indistinguishable from not having written it down at all.
            emit("warn", f"{pref_id}: declared with no targets — asserts nothing")
            continue

        for tname, entry in sorted(entries.items()):
            label = f"{pref_id} / {tname}"

            # Spec shape is validated BEFORE any file is touched. Reading these
            # inside the try meant a hand-edit that omitted `key` raised
            # KeyError there and then raised the identical KeyError inside the
            # handler that was supposed to report it — an uncaught traceback
            # from the malformation most likely to actually occur. The rules
            # themselves live in entry_problems(), which --validate-spec shares.
            problems = entry_problems(tname, entry, targets, came_from(pref_id, tname))
            if problems:
                for problem in problems:
                    emit("fail", f"{label}: {problem}")
                failed = 1
                continue

            state = entry.get("state")

            if state == "n_a":
                continue

            if state == "unreachable":
                if entry.get("recheck") == "auto":
                    still, detail = PROBES[entry["probe"]]()
                    if still is None:
                        emit("warn", f"{label}: ceiling unverifiable — {detail}")
                    elif still:
                        emit("ok", f"{label}: still unreachable ({detail})")
                    else:
                        emit("fail", f"{label}: THE CEILING LIFTED — {detail}. Go claim the preference and set state='enforce'.")
                        failed = 1
                else:
                    emit("warn", f"{label}: unreachable, manual re-check — {entry['evidence']}")
                continue

            key = entry["key"]
            want = entry.get("want")
            want_contains = entry.get("want_contains")
            want_all_contain = entry.get("want_all_contain")
            # The dual of want_all_contain: SOME entry must carry it. For a
            # preference that lives on one line of an accumulating directive —
            # a `map` among many. want_all_contain would indict the other
            # bindings, and a non-accumulate read sees only the LAST line,
            # which is the wrong-line defect `accumulate` exists to close.
            want_any_contain = entry.get("want_any_contain")
            # The exact form of the above: SOME entry must EQUAL this. A
            # substring cannot tell `_fzf_compgen_path` from
            # `_fzf_compgen_pathX`, nor a main-keymap binding from the
            # menuselect line that repeats its text — both survived the
            # 02-09-2026 battery under want_any_contain. For a list whose
            # entries are whole names or whole lines, equality is the
            # honest matcher.
            want_any = entry.get("want_any")
            # Some settings express a preference by NEGATION. Sublime's ligature
            # options are the case that forced this: `liga`/`clig`/`calt` are on
            # by default and are turned off by `no_liga`/`no_clig`/`no_calt`, so
            # "ligatures are on" is only assertable as "none of those appear."
            # Asserting `dlig` instead — as this spec first did — checks a
            # different feature and stays green while the stated preference is
            # switched off.
            want_absent = entry.get("want_absent")

            # entry_problems() already rejected an entry whose target does not
            # resolve, so this cannot fail here — asserted rather than assumed,
            # because the guarantee lives in another function.
            t, path, resolve_err = resolve_target(tname, entry, targets)
            assert t is not None and path is not None, resolve_err
            host = t.get("host")
            if host and t["format"] != "zshcap":
                try:
                    path = remote_path(t, targets)
                except ReadSkip as exc:
                    emit("warn", f"{label}: skipped — {exc}")
                    continue
                if path is None:
                    emit("warn", f"{label}: {t['path']} not on {host} — skipped")
                    continue
            elif not host and t["format"] != "defaults" and not os.path.exists(path):   # a defaults domain is not a file
                emit("warn", f"{label}: {t['path']} not deployed — skipped")
                continue

            accumulate = bool(entry.get("accumulate"))
            try:
                raw = READERS[t["format"]](path, key, accumulate=accumulate, host=host)
            except ReadSkip as exc:
                emit("warn", f"{label}: skipped — {exc}")
                continue
            except (OSError, ReadError, ET.ParseError, json.JSONDecodeError, tomllib.TOMLDecodeError, UnicodeDecodeError) as exc:
                emit("fail", f"{label}: could not read {key} — {exc}", kind="unreadable")
                failed = 1
                continue

            # A row whose wanted value IS the application's default asserts a
            # key the config deliberately never writes. Reading the shipped
            # default in its place is what turns "the key is absent" — which is
            # true whatever the application would do — into a statement about
            # the behaviour. Every matcher below then judges the default on the
            # same terms as a written value, so an upstream flip fails the row
            # instead of passing it.
            from_default = False
            if raw is None and entry.get("unset_reads_default"):
                try:
                    shipped, why = DEFAULT_ORACLES[t["format"]](key)
                except ReadSkip as exc:
                    # The instrument is absent, not disagreeing. A checkout
                    # without the application has nothing to measure, and that
                    # is a warn here for the same reason it is one in every
                    # probe — going red would make a stranger's clean machine
                    # look like drift.
                    emit("warn", f"{label}: {key} is unset and its shipped default is unverifiable — {exc}")
                    continue
                if shipped is None:
                    emit("fail", f"{label}: {key} is unset and its shipped default could not be read — {why}")
                    failed = 1
                    continue
                if shipped == "":
                    # A valueless `# key` line is a documented EMPTY default —
                    # and for the accumulating directives (font_features, env,
                    # symbol_map …) it is the whole shipped table, which is not
                    # a value. Either way there is nothing to state positively,
                    # and handing "" to want_absent is the absent-passes hole
                    # this flag exists to close.
                    emit("fail", f"{label}: {key} is unset and kitty's shipped default for it is EMPTY — "
                                 "nothing to compare, so unset_reads_default cannot back this row")
                    failed = 1
                    continue
                raw, from_default = shipped, True

            # Provenance goes in the MESSAGE, never the label: the labels are
            # what the mutation batteries match on.
            src = f" [{t['format']}'s own default, not the config]" if from_default else ""

            # want_absent is checked FIRST, because it is the one matcher for
            # which a missing key is the PASSING case. Sublime's ligatures are
            # the live example: they are on by default and switched off by
            # `no_calt`, so deleting `font_options` entirely satisfies the
            # preference. Until 14-08-2026 the UNSET branch below ran first and
            # reported `font_options is UNSET (want None)` — a failure, with a
            # nonsense expectation, for a config that was correct.
            # Case-insensitive since 10-09-2026: this matcher only ever names a
            # DISABLING spelling, and the applications fold case on their side
            # — kitty lowercases a mouse_map's modes before it checks them
            # (`parse_mouse_map`, frozen bytecode), so `UNGRABBED` unbound the
            # click while the exact-case test read it as absent. Folding can
            # only make the test stricter, which is the safe direction.
            if want_absent is not None:
                got_abs = "" if raw is None else normalise(raw)
                where = "unset" if raw is None else f"'{got_abs}'"
                if want_absent.lower() in got_abs.lower():
                    emit("fail", f"{label}: {key} is {where}{src}, which must NOT contain '{want_absent}'")
                    failed = 1
                else:
                    emit("ok", f"{label}: {key} does not disable it ({where}{src}, '{want_absent}' absent)")
                continue

            if raw is None:
                emit("fail", f"{label}: {key} is UNSET (want {want or want_contains or want_all_contain or want_any_contain or want_any})")
                failed = 1
                continue

            if want_all_contain is not None:
                items = raw if isinstance(raw, list) else [raw]
                missing = [i for i in items if want_all_contain not in str(i)]
                if missing:
                    emit("fail", f"{label}: {key} — {len(missing)} of {len(items)} entries lack '{want_all_contain}'{src}: {missing}")
                    failed = 1
                else:
                    emit("ok", f"{label}: every {key} entry contains {want_all_contain}{src}")
                continue

            if want_any_contain is not None:
                items = raw if isinstance(raw, list) else [raw]
                if any(want_any_contain in str(i) for i in items):
                    emit("ok", f"{label}: a {key} entry contains {want_any_contain}{src}")
                else:
                    emit("fail", f"{label}: {key} — none of {len(items)} entries contain '{want_any_contain}'{src}")
                    failed = 1
                continue

            if want_any is not None:
                items = raw if isinstance(raw, list) else [raw]
                if any(str(i).strip() == want_any for i in items):
                    emit("ok", f"{label}: a {key} entry is exactly {want_any}{src}")
                else:
                    emit("fail", f"{label}: {key} — none of {len(items)} entries equals '{want_any}'{src}")
                    failed = 1
                continue

            got = normalise(raw)
            if want_contains is not None:
                if want_contains in got:
                    emit("ok", f"{label}: {key} contains {want_contains}{src}")
                else:
                    emit("fail", f"{label}: {key} is '{got}'{src}, missing '{want_contains}'")
                    failed = 1
            else:
                # A want that itself carries edge whitespace is compared
                # whitespace-exact against the RAW read. normalise trims, so a
                # module format and its space-less twin read the same and a lost
                # separator — modules run together — stayed green; starship's
                # one-space fill symbol and an EMPTY symbol, which collapses the
                # layout, read the same too (both audits, 16-09-2026). Every
                # other want keeps the normalised compare that folds numbers and
                # booleans across syntaxes.
                exact = want is not None and want != want.strip()
                shown = str(raw) if exact else got
                if shown == want:
                    emit("ok", f"{label}: {key} = {shown}{src}")
                else:
                    emit("fail", f"{label}: {key} is '{shown}'{src}, want '{want}'")
                    failed = 1

    return failed


if __name__ == "__main__":
    sys.exit(main())
