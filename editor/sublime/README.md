# Sublime Text · Gruvbox Light Hard

The author's Sublime Text. The text is Fira Code at 16 with its
ligatures, coloured by a Gruvbox Light Hard scheme vendored here, inside
[ayu](https://github.com/dempfi/ayu)'s light theme; rulers stand at columns
80, 100 and 120; white space is drawn at the start and end of a line, on a
line holding nothing else, and at every tab; the caret's line is highlighted,
and spelling is checked. [Terminus](https://github.com/randy3k/Terminus), the
terminal inside Sublime, runs in Gruvbox Dark Hard and FiraCode Nerd Font
Mono, the Nerd Font build, for a prompt's icons. Take it alone: the installer
fetches the installer library the pieces share from this repository, and
nothing it installs points back here.

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
or not. `Packages/preen` holds no Package Control list, because Package
Control would take the names such a list holds off your own list in
`Packages/User`, and delete those packages once the list was gone.

How Sublime reads the package:

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

- **Sublime Text 4**, measured with build 4215 on macOS; no Linux Sublime
  was measured.

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

The plan, writing nothing:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.4/editor/sublime/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.4/editor/sublime/install.sh | bash
```

Or from a clone, `./editor/sublime/install.sh`. It asks nothing. The plan on
a Mac where Sublime Text has run, which on Linux names
`~/.config/sublime-text` instead:

```
== will touch ==
~/Library/Application Support/Sublime Text/Packages/preen this config's own package, created
~/Library/Application Support/Sublime Text/Packages/preen/Preferences.sublime-settings the editor's settings — copied
~/Library/Application Support/Sublime Text/Packages/preen/gruvbox-light-hard.sublime-color-scheme the colour scheme — copied
~/Library/Application Support/Sublime Text/Packages/preen/Terminus.sublime-settings Terminus's settings — copied
~/Library/Application Support/Sublime Text/Packages/preen/Terminus View.sublime-settings Terminus's view settings — copied
```

Each line says what this run does to your home. A file of yours reads
`backed up, then replaced`, and an earlier copy `updated (an earlier copy)`.

It

1. looks for ayu and Terminus, and for Package Control, which decides the
   advice for one missing, in `Installed Packages/` and in `Packages/`; it
   runs none of them, nor Sublime;
2. creates `Packages/preen`, and each directory missing above it, saying each
   as it is made;
3. copies the four files into it, a different file there, or a symlink,
   first moved aside as `<name>.unpreened.<timestamp>`, an earlier copy this
   setup shipped replaced without a backup.

A re-run with nothing changed rewrites nothing and takes no backup.

Every refusal comes before the first write, and a dry run makes each one;
among them a symlinked directory between `~` and `Packages/preen`, since the
files would land wherever it points, and an unwritable `Packages/preen` or
directory it would be made in; on Linux, an `XDG_CONFIG_HOME` other than
`~/.config`; a system other than macOS or Linux. A symlinked `Packages/User`
is not refused: nothing is written there.

## Updating

Run the install line from this page again: it names the newest release.
From a clone, `git pull`, then `./editor/sublime/install.sh`. An earlier copy
this setup shipped comes back `updated`, with no backup; one you edited is
backed up beside itself first.
A key of yours belongs in `Packages/User`, which no run reads or writes
(Your overrides).

## Your overrides

Your keys go in `Packages/User` — `Preferences.sublime-settings` for the
editor, `Terminus.sublime-settings` and `Terminus View.sublime-settings` for
Terminus — and win over this package's, each key whole. An edit to a copy in
`Packages/preen` holds until a re-run puts the shipped bytes back, keeping
yours beside it as a backup.

**A File Icon**, if you use it, reads `file_icon_theme` from
`Packages/User/Preferences.sublime-settings` alone, by that path, and opens
its theme picker at every start until the key is there. A package under
`Packages/User` cannot answer it, so this one does not set it: pick a theme
once, and A File Icon writes the key there itself.

**Package Control copies this package's theme into `Packages/User`.**
Before it upgrades ayu — on its own, at a start, by default — while the
theme in force is one of ayu's, Package Control 4.2.8 sets `theme` to
Sublime's default, and after the upgrade sets back the value it read; both
land in `Packages/User/Preferences.sublime-settings`. So after your first
ayu upgrade that file holds `"theme": "ayu-light.sublime-theme"`. It changes
nothing while it matches this package's theme; it keeps that theme when a
later copy of this package names another, and when this package is gone. An
upgrade cut short by quitting Sublime leaves `"theme": "auto"` there instead,
and so does disabling or removing ayu through Package Control.

**Terminus's palette** is Terminus's own output. With `"theme": "user"`,
which this package sets, Terminus generates
`Packages/User/Terminus/Terminus.hidden-color-scheme` from the
`user_theme_colors` this package sets, and generates it again when either
changes. That file in `Packages/User` is Terminus's write, not the
installer's.

## What changes

The choices felt at once, each with the line that undoes it in your
`Packages/User/Preferences.sublime-settings`, or in the file the row names.
Each undo is the key's own default, Sublime's at build 4215 or Terminus's,
except in `Terminus View.sublime-settings`, where Terminus sets no default:
there the undo names the editor's font.

| What you notice | Undo |
| --- | --- |
| the text is Fira Code at 16 | `"font_face": "Menlo",`<br>`"font_size": 12,`<br>— on Linux `"Monospace"` and `10` |
| the text is coloured by Gruvbox Light Hard | `"color_scheme": "Mariana.sublime-color-scheme",` |
| the window around it is ayu's light theme, once ayu is installed | `"theme": "auto",` |
| rulers at columns 80, 100 and 120 | `"rulers": [],` |
| white space drawn at the start and end of a line, on a line holding nothing else, and at every tab | `"draw_white_space": ["selection"],` |
| the caret's line is highlighted | `"highlight_line": false,` |
| spelling is checked (`spell_check`) | `"spell_check": false,` |
| on macOS, the view scrolls on past the last line, as it already does on Linux | `"scroll_past_end": false,` |
| Terminus's panel is Gruvbox Dark Hard | in `Packages/User/Terminus.sublime-settings`:<br>`"theme": "adaptive",` |
| Terminus's panel is FiraCode Nerd Font Mono at 16 | in `Packages/User/Terminus.sublime-settings`:<br>`"view_settings": {},`<br>in `Packages/User/Terminus View.sublime-settings`, `"font_face"` and `"font_size"` naming the editor's font |

The rest are quieter — `trim_trailing_white_space_on_save` and
`open_files_in_new_window` — and each is set back the same way, by its key in
your `Packages/User/Preferences.sublime-settings`.

## Leaving

1. Delete `Packages/preen/` from Sublime's data directory.
2. Delete `Packages/User/Terminus/Terminus.hidden-color-scheme`, which still
   holds this palette, and `Packages/User/Terminus.hidden-color-scheme`,
   generated from its background. A Terminus you keep generates them again
   from its own settings when it next loads and finds them missing.
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
`<name>.unpreened.<timestamp>`, your edits included: keep it before you
delete that directory, if you want them.

## License

MIT. The colour scheme carries its own MIT notice, Brian Reilly's, in its
header.
