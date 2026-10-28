# Zed · Gruvbox Light Hard

The author's [Zed](https://zed.dev). Gruvbox Light Hard, a theme Zed ships,
on Fira Code with ligatures, a dotted zero and oldstyle figures, and the
caret an underline, in the editor and its terminal, as in the author's kitty;
rulers at 80, 100 and 120; whitespace
shown at line edges and beside other spaces; the JetBrains keymap, so IDEA's
keys carry over; a file saved when focus leaves it, and formatted when saved;
inlay hints, inline diagnostics and sticky scroll; the project panel on the
left, hiding gitignored files, while project search reaches them and the
build directories are never scanned. alt-g opens lazygit in the centre pane,
and the task picker holds Rust and Node tasks. Take it alone: the installer
fetches the installer library the pieces share from this repository, and
nothing it installs points back here.

## What it takes over

The installer copies `settings.json` to:

```
~/.config/zed/global_settings.json
```

Zed reads that file under your own `~/.config/zed/settings.json`, which the
run never reads or writes. Zed layers, lowest first, its defaults, the
settings extensions bring, `global_settings.json`, then `settings.json` with
its per-release-channel and per-platform sections:

- a key only `global_settings.json` sets applies;
- a key both files set takes your `settings.json`'s value;
- an object both set merges key by key — your `{ "path": … }` keeps our
  `"arguments"` beside it;
- an array both set is yours whole — none of ours shows through;
- without `global_settings.json`, Zed logs nothing for it and does not create
  it.

Above both go an active settings profile, a project's own
`.zed/settings.json` for its files, and, on a remote development server,
that machine's own `settings.json`. A profile whose `base` is `"default"`,
while active, sets the rest of your `settings.json` aside and keeps this
file. `global_settings.json` takes no such sections, and nothing in Zed
writes it.

Some parts of Zed read `settings.json` alone, never this file. Among them:
Zed's Settings editor (Your overrides, below) and the lists on its sandbox
page; the settings sent to a remote server in remote development; the agent
panel's layout; whether an edit-prediction provider was chosen explicitly;
and the agent's fallback default model.

- **`keymap.json` and `tasks.json`** are read from `~/.config/zed` under
  those names alone, one file each, so they cannot be layered: each is copied
  only where nothing is there, or an earlier copy this setup shipped is.
- **A symlinked `~/.config` or `~/.config/zed`** — stow's layout, a
  dotfiles repository's — is refused. A symlink at `global_settings.json` is
  moved aside, never written through.
- **`XDG_CONFIG_HOME`**, on Linux and FreeBSD, is where Zed reads its config
  directory, so one naming a directory other than `~/.config` is refused. On
  macOS Zed reads `~/.config/zed` whatever it says, and the run goes ahead. A
  Flatpak Zed reads `$FLATPAK_XDG_CONFIG_HOME/zed`, which this run does not
  know.

## What you need

**Required**

- **Zed**, measured with 1.23.2 on macOS. Not found — at
  `/Applications/Zed.app` or on PATH on macOS, on PATH elsewhere — the
  installer says so and installs anyway; Zed reads the files when it starts.

**Optional**

- **The fonts the settings name**: Fira Code for the editor; FiraCode Nerd
  Font Mono for the editor's fallback, the terminal, the agent panel and code
  in the Markdown preview; FiraCode Nerd Font for the Markdown preview's text
  (`brew install --cask font-fira-code font-fira-code-nerd-font`). Zed's own
  default is `.ZedMono`; the run does not look for these.
- **lazygit**, which alt-g's task runs.
- **The tools the tasks call**: cargo with clippy and rustfmt,
  cargo-nextest, cargo-deny and cargo-insta for the `rust:`
  tasks; npm and npx, with the project's `dev`, `build`, `test` and `check`
  scripts and vitest, for the `node:` tasks. A task fails when its tool is
  missing; the rest are unaffected.
- **Extensions.** This piece installs none. The settings' `languages` blocks
  for Kotlin, Gradle KTS, Java, XML and Svelte apply once an extension
  provides that language, and the `lsp` blocks shape rust-analyzer and vtsls
  where Zed runs them. Gruvbox Light Hard needs none: Zed ships it.

The installer names Zed and lazygit, found or not, and runs neither.

## Install

The plan, writing nothing:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.2/editor/zed/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.2/editor/zed/install.sh | bash
```

Or from a clone, `./editor/zed/install.sh`. It asks nothing. The plan for an
empty home:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/zed                              Zed's config directory, created
~/.config/zed/global_settings.json         the settings, read under your settings.json — copied
~/.config/zed/keymap.json                  the keymap — copied
~/.config/zed/tasks.json                   the tasks — copied
```

Each line says what this run does to your home: a `keymap.json` or
`tasks.json` of yours reads `left alone (yours)`, and an earlier copy
`updated (an earlier copy)`.

It

1. looks for Zed and lazygit, and runs neither;
2. copies `settings.json` to `~/.config/zed/global_settings.json`, a
   different file there, or a symlink, first moved aside as
   `global_settings.json.unpreened.<timestamp>`, an earlier copy this setup
   shipped replaced without a backup;
3. copies `keymap.json` and `tasks.json` into `~/.config/zed` only where
   nothing is there or an earlier copy this setup shipped is; anything else
   stays, said `unchanged` or `left alone`;
4. says what Zed now reads, and what a `keymap.json` or `tasks.json` it left
   alone means for alt-g.

A re-run with nothing changed rewrites nothing and takes no backup.

Every refusal comes before the first write, and a dry run makes each one;
among them those under What it takes over, and an unwritable directory.

## Updating

Run the install line from this page again: it names the newest release.
From a clone, `git pull`, then `./editor/zed/install.sh`. An earlier copy
this setup shipped comes back `updated`, with no backup. An edited
`global_settings.json` is backed up beside itself first, and an edited
`keymap.json` or `tasks.json` is left alone. A setting of yours belongs in
your `settings.json`, which no run reads or writes.

## Your overrides

Your `~/.config/zed/settings.json` is the place, layered over ours as
[What it takes over](#what-it-takes-over) says. A key of ours that yours
leaves out stays ours: to put one back to Zed's own value, set that value —
`zed: open default settings` in the command palette shows them.

Zed's Settings editor reads your `settings.json` over Zed's defaults, and
never ours: for a key only ours sets, it shows Zed's default while Zed runs
on ours. A change made there goes into your `settings.json`, and wins.

A `keymap.json` or `tasks.json` of yours stays as it is, and the run says
what that leaves: with your keymap, alt-g, alt-z and alt-i are not bound by
this one; with our keymap and your tasks, alt-g spawns a task only where
yours, or a project's `.zed/tasks.json`, has one labelled `lazygit`. To take
a binding or a task, copy it from `keymap.json` or `tasks.json` beside this
page into yours.

On Linux, Zed's own keymap begins three chords with alt-g — `alt-g b`,
`alt-g m` and `alt-g r`, for git blame, the modified files and a review diff.
Zed drops a chord still being typed when a binding that matches outright was
loaded after it, whatever their contexts, and your keymap loads after Zed's.
So alt-g opens lazygit at once, and those three chords are out of reach while
this binding is in your keymap; remove it to have them back.

## What changes

The choices felt at once, each with the lines that set it back, for your
`~/.config/zed/settings.json`. Each undo value is Zed 1.23.2's own default —
none was run in Zed here — except for the font features: Zed's defaults name
none, and yours merge with ours key by key, so an undo turns a feature off
rather than removing it. `zero` and `onum` are off unless asked for; `calt`
is on in the editor unless turned off, and off in the terminal while
`terminal.font_features` is unset.

| What you notice | Undo |
| --- | --- |
| the theme is Gruvbox Light Hard, whatever the system's appearance | `"theme": { "mode": "system", "light": "One Light", "dark": "One Dark" }` |
| the editor's text is Fira Code at 16, with a dotted zero and oldstyle figures | `"buffer_font_family": ".ZedMono",`<br>`"buffer_font_size": 15,`<br>`"buffer_font_features": { "zero": false, "onum": false }` |
| the terminal's text has ligatures, a dotted zero and oldstyle figures, as the editor's does | `"terminal": { "font_features": { "calt": false, "zero": false, "onum": false } }` |
| the caret is an underline, in the editor and in the terminal | `"cursor_shape": "bar",`<br>`"terminal": { "cursor_shape": "block" }` |
| rulers stand at columns 80, 100 and 120 | `"wrap_guides": []` |
| whitespace shows as `·` and `→` at line edges, beside other spaces and at tabs, not only in a selection | `"show_whitespaces": "selection",`<br>`"whitespace_map": { "space": "•" }` |
| the keys are JetBrains', over Zed's own | `"base_keymap": "Zed"` |
| a file saves when focus leaves it, and saving formats it | `"autosave": "off",`<br>`"format_on_save": "off"` |
| type and parameter hints sit inline in the code, and diagnostics at the end of their line | `"inlay_hints": { "enabled": false },`<br>`"diagnostics": { "inline": { "enabled": false } }` |
| the enclosing scope stays pinned at the top as you scroll | `"sticky_scroll": { "enabled": false }` |
| a minimap shows wherever the scrollbar does | `"minimap": { "show": "never" }` |
| the project panel docks left and hides gitignored files | `"project_panel": { "dock": "right", "hide_gitignore": false }` |
| project search includes gitignored files, while the project panel, the file finder and search never see `node_modules`, `target`, `build`, `.gradle`, `dist`, `.svelte-kit`, `.turbo`, `__pycache__` or `.venv` | `"search": { "include_ignored": false },`<br>`"file_scan_exclusions": ["**/.git", "**/.svn", "**/.hg", "**/.jj", "**/.sl", "**/.repo", "**/CVS", "**/.DS_Store", "**/Thumbs.db", "**/.classpath", "**/.settings"]` |
| selecting text in the terminal copies it | `"terminal": { "copy_on_select": false }` |

The rest are quieter — `buffer_font_fallbacks`, `use_smartcase_search`,
`close_on_file_delete`, `double_click_in_multibuffer`,
`seed_search_query_from_cursor`, `vertical_scroll_margin`,
`colorize_brackets`, `redact_private_values`, `auto_signature_help`,
`tab_size` and the per-language blocks, `tabs`, `status_bar`,
`preview_tabs`, `project_panel.git_status_indicator`, `gutter`,
`indent_guides`, `git.inline_blame`, `markdown_preview`, the terminal's and
the agent's fonts, `terminal.line_height`,
`agent.play_sound_when_agent_done`, `calls.mute_on_join` and the `lsp`
blocks — and each is set back the same way, by its key in your
`settings.json`.

## Leaving

1. Delete `~/.config/zed/global_settings.json`. Without it Zed reads your
   `settings.json` over its own defaults, and logs nothing for the missing
   file.
2. A backup the run took sits beside it as
   `global_settings.json.unpreened.<timestamp>`: what was there before — a
   file or a symlink of yours, or the copy with your edits, as a later run
   found it. Rename the one you want back to `global_settings.json`, or
   delete them.
3. For `keymap.json` and `tasks.json`, read what the run said: `copied`,
   `updated` or `unchanged` means the file holds what this setup shipped, so
   it can go unless you had it before the first run; `left alone` means the
   run did not write it. A `--dry-run` says which is which now: `an earlier
   copy` is this setup's.
4. Your `settings.json` was never read or written.

## License

MIT
