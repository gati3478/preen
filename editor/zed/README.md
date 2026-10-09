# Zed · Gruvbox Light Hard

The author's [Zed](https://zed.dev). Gruvbox Light Hard, a theme Zed ships,
on Fira Code with ligatures; the caret an underline, in the editor and its
terminal, as in the author's kitty; rulers at 80, 100 and 120; whitespace
shown at line edges and beside other spaces; the JetBrains keymap, so IDEA's
keys carry over; a file saved when focus leaves it, and formatted when saved;
inlay hints, inline diagnostics and sticky scroll; the project panel on the
left, hiding gitignored files, while project search reaches them and the
build directories are never scanned. alt-g opens lazygit in the centre pane,
and the task picker holds Rust and Node tasks. Take it alone: the installer
fetches the installer library the pieces share from this repository, the way
it fetches the configs, and nothing it installs points back here.

## What it takes over

The installer copies `settings.json` to:

```
~/.config/zed/global_settings.json
```

Zed reads that file under your own `~/.config/zed/settings.json`, which the
run never reads or writes. Measured on Zed 1.23.2 on macOS, each case in a
config directory of its own:

- a key only `global_settings.json` sets applies;
- a key both files set takes your `settings.json`'s value;
- an object both set merges key by key — your `{ "path": … }` kept our
  `"arguments"` beside it;
- an array both set is yours whole — none of ours shows through;
- without `global_settings.json`, Zed logs nothing for it and does not create
  it.

Read in Zed's source at tag v1.23.2: Zed layers, lowest first, its
defaults, the settings extensions bring, `global_settings.json`, then
`settings.json` with its per-release-channel and per-platform sections.
Above both go an active settings profile, a project's own
`.zed/settings.json` for its files, and, on a remote development server,
that machine's own `settings.json`. A profile whose `base` is `"default"`,
while active, sets the rest of your `settings.json` aside and keeps this
file. `global_settings.json` takes no such sections, and nothing in Zed
writes it.

Some parts of Zed read `settings.json` alone, never this file. Among them,
read at the tag: Zed's Settings editor (Your overrides, below) and the
lists on its sandbox page; the settings sent to a remote server in remote
development; the agent panel's layout; whether an edit-prediction provider
was chosen explicitly; and the agent's fallback default model.

- **`keymap.json` and `tasks.json`** are read from `~/.config/zed` under
  those names alone, one file each, so they cannot be layered: each is copied
  only where nothing is there.
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
  cargo-nextest, cargo-audit, cargo-deny and cargo-insta for the `rust:`
  tasks; npm and npx, with the project's `dev`, `build`, `test` and `check`
  scripts and vitest, for the `node:` tasks. A task fails when its tool is
  missing; the rest are unaffected.
- **Extensions.** This piece installs none. The settings' `languages` blocks
  for Kotlin, Gradle KTS, Java, XML and Svelte apply once an extension
  provides that language, and the `lsp` blocks shape rust-analyzer and vtsls
  where Zed runs them. Gruvbox Light Hard needs none: it is among the themes
  the Zed 1.23.2 binary carries.

The installer names Zed and lazygit, found or not, and runs neither.

## Install

No clone needed. To print the plan and stop, writing nothing — `bash -s --`
hands the flag to the script:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/editor/zed/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/editor/zed/install.sh | bash
```

Or from a clone of this repository, `./editor/zed/install.sh`, with
`--dry-run` for the plan alone. It asks nothing — there is nothing to ask. The
plan for an empty home:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/zed                              Zed's config directory, created
~/.config/zed/global_settings.json         the settings, read under your settings.json
~/.config/zed/keymap.json                  the keymap — copied if absent
~/.config/zed/tasks.json                   the tasks — copied if absent
```

It

1. looks for Zed and lazygit, and runs neither;
2. copies `settings.json` to `~/.config/zed/global_settings.json` — a copy,
   never a symlink. A different file there, or a symlink, is first moved
   aside beside it as `global_settings.json.unpreened.<timestamp>`; an
   identical one is left untouched;
3. copies `keymap.json` and `tasks.json` into `~/.config/zed` where nothing
   is there. A file already there stays, with no backup, because nothing is
   replaced: the run says `unchanged` when it holds this config's bytes, and
   `left alone` when it is anything else, a symlink included;
4. says what Zed now reads, and what a `keymap.json` or `tasks.json` it left
   alone means for alt-g.

A re-run with nothing changed rewrites nothing and takes no backup:
`global_settings.json` comes back `unchanged`.

**Refusals**, all of them before the first write, so a stopped run has changed
nothing: `~/.config` or `~/.config/zed` is a symlink, dangling or not — the
copies would land in whatever it points at, which something else manages;
`~/.config` is not a directory, is not writable, or cannot be created, or
`~/.config/zed` cannot be written into; on Linux and FreeBSD,
`XDG_CONFIG_HOME` names a directory other than `~/.config`; a source file
that is missing, empty, or not the file it claims to be.

## Your overrides

Your `~/.config/zed/settings.json` is the place, and every key there wins
over ours, except while a settings profile whose `base` is `"default"` is
active: that sets the rest of your file aside and keeps ours. For an object,
set only the keys you change: the rest of ours stays. For an array, yours is
the whole list. A key of ours that yours leaves out stays ours: to put one
back to Zed's own value, set that value — `zed: open default settings` in
the command palette shows them.

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
`alt-g m` and `alt-g r`, for git blame, the modified files and a review diff
(read at the tag). How Zed settles those against this keymap's alt-g is not
measured here.

## What changes

The choices felt at once, each with the lines that set it back, for your
`~/.config/zed/settings.json`. Each undo value is Zed 1.23.2's own default,
read from the default settings its binary carries; none was run in Zed here.
The one exception is `buffer_font_features`: Zed's default names no
feature, and yours merges with ours, so the undo turns off `dlig`, which is off
unless asked for; `calt`, which ours also names, is on unless turned off.

| What you notice | Undo |
| --- | --- |
| the theme is Gruvbox Light Hard, whatever the system's appearance | `"theme": { "mode": "system", "light": "One Light", "dark": "One Dark" }` |
| the editor's text is Fira Code at 16, its discretionary ligatures on | `"buffer_font_family": ".ZedMono",`<br>`"buffer_font_size": 15,`<br>`"buffer_font_features": { "dlig": false }` |
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
   file (measured).
2. A backup the run took sits beside it as
   `global_settings.json.unpreened.<timestamp>`: what was there before — a
   file or a symlink of yours, or the copy as it was before a later run
   replaced it, your edits included. Rename the one you want back to
   `global_settings.json`, or delete them.
3. For `keymap.json` and `tasks.json`, read what the run said: `copied` or
   `unchanged` means the file held this config's bytes and can go;
   `left alone` means something else was there, and the run never touched
   it.
4. Your `settings.json` was never read or written.

Took the whole repository through `bin/bootstrap`? Then
`~/.config/zed/global_settings.json` is a link into your clone, which
already carries this config: the installer says so and writes nothing.

## License

MIT
