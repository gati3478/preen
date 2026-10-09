# Sublime Text · Gruvbox Light Hard

The author's Sublime Text. The text is Fira Code at 16, its discretionary
ligatures on, coloured by a Gruvbox Light Hard scheme vendored here, inside
[ayu](https://github.com/dempfi/ayu)'s light theme; rulers stand at columns
80, 100 and 120; white space is drawn at the start and end of a line, on a
line holding nothing else, and at every tab; the caret's line is highlighted,
and spelling is checked. [Terminus](https://github.com/randy3k/Terminus), the
terminal inside Sublime, runs in Gruvbox Dark Hard and FiraCode Nerd Font
Mono, the Nerd Font build, for a prompt's icons. Take it alone: the installer
fetches the installer library the pieces share from this repository, the way
it fetches the files, and nothing it installs points back here.

## What it takes over

The installer copies four files into a package of their own, `Packages/preen`,
in Sublime Text's data directory — `~/Library/Application Support/Sublime Text`
on macOS, `~/.config/sublime-text` on Linux:

- `Preferences.sublime-settings`, the editor's settings;
- `gruvbox-light-hard.sublime-color-scheme`, the scheme they name;
- `Terminus.sublime-settings` and `Terminus View.sublime-settings`, Terminus's
  palette and font.

It writes nothing else. `Packages/User`, where Sublime, Package Control and
you keep your own settings, is never read or written by the run — though
Package Control copies this package's `theme` there when it upgrades ayu
(Your overrides, below). It installs no package: the settings need two, ayu
for the theme and Terminus for its two files, and the run names each, found
or not. `Packages/preen` holds no Package Control
list, because Package Control would take the names such a list holds off your
own list in `Packages/User`, and delete those packages once the list was gone
(read in Package Control 4.2.8: `update_installed_packages` in
`package_manager.py`, `remove_orphaned_packages` in `package_cleanup.py`).

How Sublime reads the package, measured on Sublime Text 4215:

- **`Packages/User` wins.** Sublime reads a settings file from every package
  that has one — its own `Default` first, then the zipped packages in
  `Installed Packages/`, then the loose ones in `Packages/`, each set in
  order of name with case ignored, then `Packages/User` last — and a later
  one wins key by key. A key in your
  `Packages/User/Preferences.sublime-settings` beats the same key here.
- **A key is replaced whole.** Yours replaces ours entire even where the value
  is an object, such as Terminus's `view_settings` or `user_theme_colors`:
  nothing inside it is merged. Set `user_theme_colors` holding one colour, and
  that one colour is the whole palette Terminus reads.
- **A zipped package never wins over it; a loose one after it in the order
  does.** Terminus, installed zipped as Package Control installs it, loses its
  own `Terminus.sublime-settings` keys to this package's. A loose package whose
  name sorts after `preen`, case ignored, wins over it for a file both hold.

## What you need

**Required**

- **Sublime Text 4**, measured with build 4215 on macOS. On Linux the data
  directory is `~/.config/sublime-text`, as Package Control's
  `package_control/sys_path.py` documents it; no Linux Sublime was measured.

**Optional**

- **ayu**, whose `ayu-light.sublime-theme` is the theme these settings name.
- **Terminus**, whose settings the two Terminus files are.
- **[Package Control](https://packagecontrol.io)**, the way to get both: from
  Sublime's command palette, `Package Control: Install Package`, then the
  package's name; `Install Package Control` first where it is not there.
- **Fira Code**, the editor's font, and **FiraCode Nerd Font Mono**,
  Terminus's — two families, installed apart. The installer looks for
  neither.

The installer names ayu and Terminus, each found or not — zipped in
`Installed Packages/` or loose in `Packages/` — with how to get one missing,
and installs neither.

## Install

No clone needed. To print the plan and stop, writing nothing — `bash -s --`
hands the flag to the script:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/editor/sublime/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/editor/sublime/install.sh | bash
```

Or from a clone of this repository, `./editor/sublime/install.sh`, with
`--dry-run` for the plan alone. It asks nothing — there is nothing to ask. The
plan on a Mac where Sublime Text has run, which on Linux names
`~/.config/sublime-text` instead:

```
== will touch ==
~/Library/Application Support/Sublime Text/Packages/preen this config's own package, created
~/Library/Application Support/Sublime Text/Packages/preen/Preferences.sublime-settings the editor's settings
~/Library/Application Support/Sublime Text/Packages/preen/gruvbox-light-hard.sublime-color-scheme the colour scheme
~/Library/Application Support/Sublime Text/Packages/preen/Terminus.sublime-settings Terminus's settings
~/Library/Application Support/Sublime Text/Packages/preen/Terminus View.sublime-settings Terminus's view settings
```

It

1. looks for ayu and Terminus, and for Package Control, which decides the
   advice for one missing, in `Installed Packages/` and in `Packages/`; it
   runs none of them, nor Sublime;
2. creates `Packages/preen`, and each directory missing above it, saying each
   as it is made;
3. copies the four files into it — copies, never symlinks — each backed up
   beside itself as `<name>.unpreened.<timestamp>` if a different one was
   there, left untouched if identical. A symlink in the place of one is moved
   aside, link and all, and never written through.

A re-run with nothing changed rewrites nothing and takes no backup: each file
comes back `unchanged`.

**Refusals**, all of them before the first write, so a stopped run has changed
nothing: a symlink, dangling or not, at any directory between `~` and
`Packages/preen` — `~/Library`, `Application Support`, `Sublime Text`,
`Packages` or `preen` on macOS; `~/.config`, `sublime-text`, `Packages` or
`preen` on Linux — since the files would land in whatever it points at, which
something else manages; one of those that is not a directory, or that cannot
be written into or created; on Linux, `XDG_CONFIG_HOME` naming a directory
other than `~/.config`, since whether Sublime then keeps its data under it is
not known; a system other than macOS or Linux; a source file that is missing,
empty, or not the file it claims to be. A symlinked `Packages/User` is not
refused: nothing is written there.

## Your overrides

Your keys go in `Packages/User` — `Preferences.sublime-settings` for the
editor, `Terminus.sublime-settings` and `Terminus View.sublime-settings` for
Terminus — and win over this package's, each key whole. An edit to a copy in
`Packages/preen` holds until a re-run puts the shipped bytes back, keeping
yours beside it as a backup.

**A File Icon**, if you use it, reads `file_icon_theme` from
`Packages/User/Preferences.sublime-settings` alone, by that path, and opens
its theme picker at every start until the key is there (A File Icon 4.0.0,
`plugin.py` calling `setup_file_icon_theme` in `core/icon_theme.py`). A
package under `Packages/User` cannot answer it, so this one does not set it:
pick a theme once, and A File Icon writes the key there itself.

**Package Control copies this package's theme into `Packages/User`.**
Before it upgrades ayu — on its own, at a start, by default — while the
theme in force is one of ayu's, Package Control 4.2.8 sets `theme` to
Sublime's default, and after the upgrade sets back the value it read; both
land in `Packages/User/Preferences.sublime-settings`
(`backup_and_reset_settings` and `restore_settings` in
`package_control/package_disabler.py`). So after
your first ayu upgrade that file holds `"theme": "ayu-light.sublime-theme"`
(measured, with ayu 6.2.1). It changes nothing while it matches this
package's theme; it keeps that theme when a later copy of this package
names another, and when this package is gone. An upgrade cut short by
quitting Sublime leaves `"theme": "auto"` there instead, and so does
disabling or removing ayu through Package Control.

**Terminus's palette** is Terminus's own output. With `"theme": "user"`,
which this package sets, Terminus generates
`Packages/User/Terminus/Terminus.hidden-color-scheme` from the
`user_theme_colors` this package sets, and generates it again when either
changes (Terminus 0.3.37, `terminus/theme.py`). That file in `Packages/User`
is Terminus's write, not the installer's.

## What changes

The choices felt at once, each with the line that undoes it in your
`Packages/User/Preferences.sublime-settings`, or in the file the row names.
Each undo lands in `Packages/User`, which wins (measured, above), and is
Sublime's or Terminus's own default for the key, read from its package —
Sublime's Default package at build 4215, its macOS file for the macOS
values — except in `Terminus View.sublime-settings`, where Terminus sets no
default: there the undo names the editor's font.

| What you notice | Undo |
| --- | --- |
| the text is Fira Code at 16, its discretionary ligatures on (`dlig`) | `"font_face": "Menlo",`<br>`"font_size": 12,`<br>`"font_options": [],`<br>— on Linux `"Monospace"` and `10` |
| the text is coloured by Gruvbox Light Hard | `"color_scheme": "Mariana.sublime-color-scheme",` |
| the window around it is ayu's light theme, once ayu is installed | `"theme": "auto",` |
| rulers at columns 80, 100 and 120 | `"rulers": [],` |
| white space drawn at the start and end of a line, on a line holding nothing else, and at every tab | `"draw_white_space": ["selection"],` |
| the caret's line is highlighted | `"highlight_line": false,` |
| spelling is checked (`spell_check`) | `"spell_check": false,` |
| on macOS, the view scrolls on past the last line, as it already does on Linux | `"scroll_past_end": false,` |
| Terminus's panel is Gruvbox Dark Hard | in `Packages/User/Terminus.sublime-settings`:<br>`"theme": "adaptive",` |
| Terminus's panel is FiraCode Nerd Font Mono at 16 | in `Packages/User/Terminus.sublime-settings`:<br>`"view_settings": {},`<br>in `Packages/User/Terminus View.sublime-settings`, `"font_face"` and `"font_size"` naming the editor's font |

The rest are quieter — `trim_trailing_white_space_on_save`,
`open_files_in_new_window` and `remember_open_files` — and each is set back
the same way, by its key in your `Packages/User/Preferences.sublime-settings`.

## Leaving

1. Delete `Packages/preen/` from Sublime's data directory.
2. Delete `Packages/User/Terminus/Terminus.hidden-color-scheme`, which still
   holds this palette, and `Packages/User/Terminus.hidden-color-scheme`,
   generated from its background. A Terminus you keep generates them again
   from its own settings when it next loads and finds them missing
   (`terminus/theme.py`, `plugin_loaded`).
3. Delete `"theme": "ayu-light.sublime-theme"` from
   `Packages/User/Preferences.sublime-settings`, unless you set it yourself:
   Package Control copied it there from this package (Your overrides,
   above), and it outlives `Packages/preen`.
4. ayu and Terminus, where you installed them for this, are yours: keep them,
   or remove them — from Sublime's command palette, `Package Control: Remove
   Package`, for ones Package Control installed. Removing ayu that way also
   turns a `"theme"` line naming one of its themes into `"auto"`, Sublime's
   default.

A backup the run took sits in `Packages/preen/` beside its copy, as
`<name>.unpreened.<timestamp>`: the copy as it was before a later run
replaced it, your edits to it included. Keep it before you delete that
directory, if you want those edits.

Where the whole repository's setup linked these files into your clone, which
already carries this config, the installer says so and writes nothing.

## License

MIT. The colour scheme carries its own MIT notice, Brian Reilly's, in its
header.
