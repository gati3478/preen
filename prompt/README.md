# cship · Gruvbox Dark Hard

A three-line statusline for [Claude Code](https://claude.com/claude-code),
rendered by [cship](https://github.com/stephenleo/cship): where you are,
whose session it is and which model, how much of the context and the budget
is gone, and when the usage windows reset. Take it alone: the installer fetches
one shared helper from this repository the way it fetches the configs, and
nothing it installs points back here.

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ calliope   main [!?⇡]   24                                                                           │
│   personal   Fable 5   high ↳ code                                                            30m50s │
│ █████░░░░░░░ 43%  43%(393k/1000k)    $3.42  +470 -122  5h 34% → Fri 4:00 AM     7d 72% → Tue 1:00 AM │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Rendered at 104 columns, where the metrics line has no slack left; a wider
terminal opens the gap before the usage windows. The icons are the blank
cells a terminal without a Nerd Font shows — the modules under
[Glyphs](#glyphs) each carry one, and line 1's two are starship's own, for
the branch and for Node.

## What you need

**Required**

- **cship 1.8.2 or newer.** Either of its own routes:
  `curl -fsSL https://cship.dev/install.sh | bash` (the binary, a starter
  config, and the `settings.json` wiring) or `cargo install cship` (the
  binary only). The floor is where per-window usage tokens and `CSHIP_ACCOUNT`
  arrived.
- **A Nerd Font in the terminal.** Built against FiraCode Nerd Font Mono
  (`brew install --cask font-fira-code-nerd-font`). Without one every icon is
  a blank cell — a missing glyph fills the same width as a space, so nothing
  looks broken; the icons are simply not there.
- **A dark terminal.** The palette is Gruvbox Dark Hard as literal hexes,
  chosen against its `#1d2021` ground. There is no light variant.

**Optional**

- **starship**, for line 1. With starship absent from `PATH`, line 1 is absent
  and lines 2 and 3 render as normal — exit 0, no error, nothing to configure.
  With it present, line 1 renders under **your** starship config, whatever
  that is. `starship.toml` here is the one the picture was drawn with, and
  taking it replaces your shell prompt, because starship reads one file for
  both. It is a two-line prompt: context above, a bare `❯` below, the
  toolchain at the right margin.

## Install

One line, no clone:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/prompt/install.sh | bash
```

Or from a clone of this repository, `./prompt/install.sh`. The script does
nothing to your files that it does not print, and `--help` is its manual;
read it first if that is your habit. It

1. finds cship — on `PATH`, or at `~/.local/bin/cship` or `~/.cargo/bin/cship`
   where its two installers put it — and refuses below 1.8.2;
2. asks whether to take `starship.toml` too, and what to call your account
   (next section);
3. copies `cship.toml` to `~/.config/cship.toml` — a copy, never a symlink,
   backed up beside it as `cship.toml.unpreened.<timestamp>` if one was
   there, left untouched if identical. A symlink there is moved aside even
   to identical content: the copy is yours to tune;
4. wires `statusLine` in `~/.claude/settings.json` (or under
   `CLAUDE_CONFIG_DIR`, if you set it): added when absent; taken over, after
   the same kind of backup, when it already runs a bare cship — the
   `"command": "cship"` its installer leaves, or a lone cship path with at
   most the label this script puts before it; left alone, and said so, when
   it runs anything else. Every other key is kept; the file comes back
   re-serialised with two-space indentation. When the entry is not written
   — no `~/.claude`, no working python3, another tool's entry — the exact
   entry to paste is printed.

Every refusal — no cship, or one below the floor; a `settings.json` that is
not a JSON object, not writable, or a symlink to nothing; a directory or a
read-only `~/.config` in the way — comes before the first write, so a
stopped run has changed nothing.

Under a pipe the questions still reach you through the terminal. Each flag
answers one; with both answered nothing is asked, and with no terminal the
defaults are taken — `starship.toml` left alone, the account module hidden:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/prompt/install.sh | bash -s -- --with-starship --account-label personal
./prompt/install.sh --no-starship --no-account
```

By hand it is the same steps: copy the file, optionally the second, and add
to `~/.claude/settings.json`

```json
"statusLine": { "type": "command", "command": "/absolute/path/to/cship", "refreshInterval": 60 }
```

`refreshInterval` re-renders on a timer, so the clock and the windows keep
moving while a session idles; without it the line updates only on events.
cship's own installer writes the entry without it — and re-run over an
installed cship it first runs `cship uninstall`, which deletes the entry,
then writes its bare one back, label and timer gone, your `cship.toml` left
alone. After upgrading cship that way, run this installer again: it
recognises the bare entry and takes it over.

**Leaving.** Each backup sits beside the file it replaced, as
`<file>.unpreened.<timestamp>`; move it back. Then remove the `statusLine`
entry from `settings.json`, or run `cship uninstall`, which removes the entry,
the binary and its caches and leaves `cship.toml` where it is.

Took the whole repository through `bin/bootstrap`? Both files are already
symlinked into place and none of this applies.

## The account module, and your email

`[cship.account]` on line 2 names whose session this is. Left to itself,
cship fetches the organisation name behind your credential — and on a
personal rather than a team account that name **is your email address**,
which then sits in every screenshot. The installer's question is the switch:

- **A label** goes into the statusLine command as
  `CSHIP_ACCOUNT='{"organization_name":"…"}'`. cship renders it and fetches
  nothing. This is the route cship gives a multi-account launcher — the
  process that starts cship states the account — with one account here. It
  rides the entry the installer writes, so if something other than a bare
  cship already runs there the label is not applied, and the summary says
  so rather than pretending.
- **Blank** puts `disabled = true` under `[cship.account]` in your copy and
  drops the module's slot from line 2, so no blank cell is left where it
  stood. Nothing else changes.

The shipped file carries neither: it is the author's live config, fed by a
launcher that sets the variable per session.

## What's in the layout

- **Line 1** — Starship passthrough: directory, git branch, commit on a
  detached HEAD, in-progress git operation, git status, runtime versions
  (Python, Java, Kotlin, Gradle, Rust, Node). Each module's look comes from
  `starship.toml`; which modules appear is this file's own list — starship's
  `format` minus its shell-only modules — because cship runs
  `starship module <name>` per token and never reads `format`.
- **Line 2** — account label, model (per-family colour), reasoning effort
  (per-level colour), active agent; session duration right-aligned via
  `$fill`.
- **Line 3** — 12-cell context bar, absolute token usage `43%(393k/1000k)`,
  session cost, lines added/removed; 5-hour and 7-day usage windows
  right-aligned, each with its absolute local reset time
  (`72% → Tue 1:00 AM`).

Warn/critical thresholds: context 40/70 %, cost $2/$5, usage windows
70/90 % — gold at warn, bold red at critical, each a `warn_threshold` /
`critical_threshold` pair in the file.

## Why it is shaped this way

cship is a **layout renderer, not a data source**. Claude Code pipes session
JSON to it on every refresh, and three data paths exist:

- **stdin** — `rate_limits`, cost, context, model. Always present, never
  fails. Everything shown here rides on it, including the 5h/7d windows.
- **the environment** — `CSHIP_ACCOUNT`, since 1.8.2. Whatever starts `claude`
  can hand cship a compact JSON identity, which the account module renders
  instead of looking one up. Exact, and free of the problem below.
- **the OAuth API** — per-model burn, extra usage, account info. cship reads
  the default keychain credential for it regardless of `CLAUDE_CONFIG_DIR`
  ([cship#194](https://github.com/stephenleo/cship/issues/194)), so in a
  multi-account setup every field it feeds belongs to the default account.

This layout renders nothing from the third path by design, with two
exceptions. Until the session's first API response `rate_limits` is not on
stdin yet, so the 5h/7d figures come from the OAuth path for a few seconds.
And the account module falls back to it whenever `CSHIP_ACCOUNT` is unset and
the module is not disabled — the case the section above exists for. A
per-model line existed until 02-09-2026 and was dropped for the same reason;
with one account it is safe to restore (`$cship.usage_limits.per_model` as a
fourth line, plus the `opus_format` / `sonnet_format` / `cowork_format` /
`oauth_apps_format` / `extra_usage_format` entries). cship still performs the
OAuth fetch every `ttl` seconds; a failure costs one render a 2 s stall and
then a 30 s cooldown, never a broken row.

One more thing worth knowing before filing a bug: **the metrics line's
content alone runs to about 100 cells** — the picture above is exactly that
case — so in a window narrower than that plus the right margin it overflows
however `width` is set. Nothing to fix; a reason not to run the statusline
in a narrow window.

## Tuning

- **Terminal width** — cship resolves the width for `$fill` in this order,
  unchanged through 1.8.3: the controlling TTY of an ancestor process, then
  `$COLUMNS`, then `width` in `cship.toml`, then 80. Claude Code sets
  `COLUMNS` and `LINES` before running the statusline command (it passed no
  width until
  [claude-code#22115](https://github.com/anthropics/claude-code/issues/22115)
  closed in May 2026), so in a real terminal the first two always answer and
  `width` is never read. It matters only where neither exists — Windows, the
  web and desktop apps — and there it should be your terminal's column count.
  It ships at 129; resizing a real terminal never misaligns anything, so a
  wider or narrower window is no reason to change it.
- **Right margin** — `width_offset` is the number of columns Claude Code keeps
  around the statusline. cship defaults to 3; Claude Code 2.1.258 keeps 4, and
  with 3 every right-aligned line lost its last cell to an ellipsis. It ships
  at 4. A trailing `…` on the right after a Claude Code update means it needs
  re-measuring.
- **Several accounts**, switched with `CLAUDE_CONFIG_DIR` — cship's own lookup
  reads the default keychain credential whichever account is running
  (cship#194), so it names the wrong one. Export `CSHIP_ACCOUNT` from whatever
  picks the account — compact JSON in the profile's shape, e.g.
  `{"organization_name":"work"}` — and cship renders that instead. `{label}`
  falls back to `{organization}` when no `[cship.account.labels]` entry
  matches, so sending the friendly name directly needs no map at all, and
  keeps every real organisation name out of the file. The installer wires
  `settings.json` under `CLAUDE_CONFIG_DIR` when that is set, and both
  accounts share one entry only if they share one settings file.
- **Schema** — the config declares
  `"$schema" = 'https://cship.dev/config-schema.json'`, so editors with a
  TOML LSP (Taplo, even-better-toml) validate and autocomplete it.
- **Seeing what cship sees** — `cship explain` tabulates every module's
  value beside the config block that styles it, for when a module shows
  nothing.

## Glyphs

All icons are Nerd Font glyphs: microchip (model), speedometer (effort),
account (account label), dollar (cost), clock (duration),
hourglass (5h), calendar (7d).

> [!warning] Some tooling silently flattens these glyphs into spaces
> Private-use-area codepoints (U+E000–F8FF, and the supplementary plane at
> U+F0000+) get replaced with spaces by some editors and formatters on rewrite.
> The file still _renders_ with correct widths, because a space fills the same
> cell — so the loss is invisible until you go looking for the icons. If you
> edit `cship.toml`, check the icons are still there afterwards.

## Palette — Gruvbox Dark Hard

| Role           | Hex       |
| -------------- | --------- |
| background     | `#1d2021` |
| aqua           | `#8ec07c` |
| green          | `#b8bb26` |
| gold (warn)    | `#fabd2f` |
| red (critical) | `#fb4934` |
| foreground     | `#ebdbb2` |
| blue           | `#83a598` |
| purple         | `#d3869b` |
| orange         | `#fe8019` |
| bg1 (inactive) | `#3c3836` |
| gray (dim ink) | `#928374` |

Model families: Fable `#8ec07c` · Opus `#83a598` · Sonnet `#d3869b` ·
Haiku `#b8bb26`. The table is the whole theme; `background`, `bg1` and
`gray` are the terminal's own, and no module here uses them.

## About the file itself

`cship.toml` and `starship.toml` are the author's live configuration,
published verbatim. Their comments cite files of the private source
repository — `preferences.md`, `docs/blocked-upstream.md` — that hold the
reasoning behind a few values, and `preferences.toml`, which ships with the
whole setup but not with this directory. This page carries what an adopter
needs; those comments are context, not instructions.

## License

MIT
