# tmux · Gruvbox Dark Hard

The author's tmux, the one that holds a session over ssh. The prefix is
C-Space; `|` and `-` split the window in the pane's own directory; the mouse
selects, resizes, scrolls and copies; copy mode takes vi keys, and `y` copies
to the clipboard through `pbcopy`; windows and panes count from 1, and the
windows renumber when one closes; the history holds 200,000 lines; tmux is
told the terminal has true colour and undercurl, and lets kitty's graphics
through. The status bar is Gruvbox Dark Hard, its colours written into
`tmux.conf` literally. Where [tpm](https://github.com/tmux-plugins/tpm) is
installed, tmux-resurrect and tmux-continuum are set to save the sessions
every ten minutes and restore them when tmux starts. The saves are files on
disk, and they hold what every pane shows, its scrollback included;
[Leaving](#leaving) says where. tmux-thumbs copies a URL, path or hash on
screen by its hint letters, C-Space then Space. Take it alone: the installer
fetches the installer library the pieces share from this repository, the way
it fetches the config, and nothing it installs points back here.

## What it takes over

The installer appends one line to your tmux config:

```
source-file -q ~/.config/tmux/preen/tmux.conf
```

tmux reads both of its own files when both are there, `~/.tmux.conf` first,
then `~/.config/tmux/tmux.conf`. tpm, which installs and starts the plugins,
reads only one of them for the plugin list — `~/.config/tmux/tmux.conf` when
it is there, else `~/.tmux.conf` — and the files that one sources. So the line
goes in `~/.config/tmux/tmux.conf` when it is there, else in `~/.tmux.conf`;
with neither, a new `~/.config/tmux/tmux.conf` holds it alone. The run says
which, and why.

The line reads a whole config in place, so it wins over every line above it
in your file that sets the same thing: the prefix, the bindings it makes and
the ones it removes, the options, the status bar. A line below it runs after
it and wins.

- **tpm of your own.** A line of your files that starts a tpm is named by the
  run and left alone. This config points tpm at `~/.config/tmux/plugins` and
  starts the one there. Measured with your tpm started from `~/.tmux/plugins`
  above the line: C-Space I installed your plugins and this config's alike
  into `~/.config/tmux/plugins`.
- **A symlinked tmux config** — stow's layout, a dotfiles repository's — is
  refused, with the line to add in the file it points at; once that file
  holds it, a re-run says `already there`.
- **`XDG_CONFIG_HOME`** naming a directory other than `~/.config` is refused.
  tmux then reads `$XDG_CONFIG_HOME/tmux/tmux.conf` too, between its two
  files, and every path this config names is under `~/.config/tmux`.

## What you need

**Required**

- **tmux**, measured with 3.7c on macOS and 3.4 on Ubuntu 24.04. Not found,
  the installer says so and installs anyway; the file is read when a tmux
  server starts. Without tmux the run cannot ask tmux to parse your file, and
  checks only that its last line does not end in a backslash.

**Optional**

- **tpm** at `~/.config/tmux/plugins/tpm`, for the plugins the config lists:
  tmux-resurrect, tmux-continuum and tmux-thumbs. The config starts it only
  where it is there, so without it nothing errors and the plugins are simply
  not loaded. To add it, clone it there, then press C-Space I inside tmux,
  which installs the plugins:

  ```sh
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
  ```

- **pbcopy**, macOS's, which `y` in copy mode and a mouse drag pipe the
  selection to. Without it — over ssh to Linux, say — the selection still
  reaches tmux's paste buffer, which C-Space ] pastes, and tmux still sends it
  to the terminal as a clipboard write (`set-clipboard on`), which the
  terminal may keep or ignore. Measured with no pbcopy and a client attached:
  `y` left the selection in tmux's buffer and wrote an OSC 52 sequence
  carrying it to the client, and said nothing.

The installer names each it did not find.

## Install

No clone needed. To print the plan and stop, writing nothing — `bash -s --`
hands the flag to the script:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/terminal/tmux/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/terminal/tmux/install.sh | bash
```

Or from a clone of this repository, `./terminal/tmux/install.sh`, with
`--dry-run` for the plan alone. It asks nothing — there is nothing to ask. The
plan for an empty home:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/tmux                             tmux's config directory, created
~/.config/tmux/preen                       this config's own directory, created
~/.config/tmux/preen/tmux.conf             the config
~/.config/tmux/tmux.conf                   created: source-file -q ~/.config/tmux/preen/tmux.conf
```

A file of yours without the line reads `one line appended: <line>` instead.

It

1. looks for tmux, tpm and pbcopy, and names any line of your tmux files that
   starts a tpm of its own. None of them stops it; it runs tmux only to ask
   its version and to parse files, never to start a session;
2. copies `tmux.conf` into `~/.config/tmux/preen/` — a copy, never a symlink,
   backed up beside itself as `tmux.conf.unpreened.<timestamp>` if a
   different one was there, left untouched if identical;
3. appends `source-file -q ~/.config/tmux/preen/tmux.conf` to the file named
   above, once. Your file is not otherwise touched, and with none it becomes
   that line. The append is last, so a run that stops earlier never leaves
   the line pointing at a file that is not there.

A re-run with nothing changed rewrites nothing and takes no backup: the copy
comes back `unchanged` and the line `already there`.

**Refusals**, all of them before the first write, so a stopped run has changed
nothing: `~/.config`, `~/.config/tmux` or `~/.config/tmux/preen` is a symlink,
dangling or not — the copy would land in whatever it points at, which
something else manages; the file the line goes in is a symlink without the
line — the append would land in its target, so the line belongs there
instead; that file lacks the line and cannot be read and appended to;
`~/.config` is not a directory, is not writable, or cannot be created, or
`~/.config/tmux` or `preen/` cannot be written into; that file would not read
the appended line as a command of its own — its last line ends in a
backslash, comment or not, which carries the next line into it, or, where
tmux is installed, tmux cannot parse the file, or reads the appended line as
part of a command above it, as an open quote's text; `XDG_CONFIG_HOME` names
a directory other than `~/.config`; a source file that is missing, empty, or
not the file it claims to be.

A parse error anywhere in a tmux file voids the whole file, so a file tmux
cannot parse is refused as it stands: tmux reads none of it now. tmux's parse
runs nothing in the file — `source-file -n`, on a server of the run's own,
started with no config and stopped when the run ends.

## Your overrides

A line of yours below the appended line runs after this config and wins.

`~/.config/tmux/local.conf` is yours too, and nothing here writes it. The
copy reads it at its end, just before it starts tpm, so a line there wins
over this config and, unlike a line below the appended one, reaches the
plugins: a plugin reads its options when tpm starts it. Measured with
`set -g @thumbs-key T`: in `local.conf`, tmux-thumbs took C-Space T; below
the appended line, the option was set and thumbs had already taken C-Space
Space. A `set -g @plugin` line goes in your own file instead, above or below
the appended line: tpm reads the plugin list from that file and the files it
sources, and `local.conf` is one file further down — measured, a `@plugin`
line there was not in tpm's list.

Never put the appended line itself in `local.conf`: the copy reads
`local.conf`, so the two would read each other. Measured, tmux 3.7c stopped at
`too many nested files`, while tmux 3.4's server spun at full CPU, its memory
growing, and had not started fifteen seconds later.

## What changes

The choices felt at once, each with the lines that undo it in
`~/.config/tmux/local.conf`. Each undo was measured on tmux 3.7c and 3.4, and
puts back its row's keys and options as a server started with no config has
them, down to the note C-b ? shows for a key. Such a server's copy mode is
vi when `VISUAL`, else `EDITOR`, names a vi as it starts — `vim`, `nvim` —
and there the undo of vi keys leaves out `setw -g mode-keys emacs`.

| What you notice | Undo |
| --- | --- |
| the prefix is C-Space, and C-b does nothing | `set -g prefix C-b`<br>`bind -N "Send the prefix key" C-b send-prefix`<br>`unbind C-Space` |
| `"` and `%` split nothing; `\|` splits side by side and `-` top to bottom, and `c` opens a window, in the pane's directory | `bind -N "Split window vertically" '"' split-window`<br>`bind -N "Split window horizontally" % split-window -h`<br>`bind -N "Delete the most recent paste buffer" - delete-buffer`<br>`unbind \|`<br>`bind -N "Create a new window" c new-window` |
| tmux takes the mouse: a click selects a pane, a drag on a border resizes it, the wheel scrolls back, a drag in a pane selects and copies (`mouse on`) | `set -g mouse off` |
| copy mode takes vi keys: `v` starts a selection and `y` copies it | `setw -g mode-keys emacs`<br>`bind -T copy-mode-vi v send-keys -X rectangle-toggle` |
| windows and panes count from 1 | `set -g base-index 0`<br>`setw -g pane-base-index 0` |
| `y` and a mouse drag in copy mode pipe the selection to `pbcopy` | `unbind -T copy-mode-vi y`<br>`bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel` |

A tmux server keeps what it read until it stops, and reading the config again
does not take back a line you deleted; the undo lines above unbind and reset
explicitly, so C-Space r — which reads `~/.tmux.conf` and
`~/.config/tmux/tmux.conf` again — applies them to the server you have.

## Leaving

1. Delete the appended line, `source-file -q ~/.config/tmux/preen/tmux.conf`,
   from the file the run named, `~/.config/tmux/tmux.conf` or
   `~/.tmux.conf`. Where that line is all the file holds, delete the file.
2. Delete `~/.config/tmux/preen/`. `~/.config/tmux/local.conf` is yours: keep
   it, or delete it if it only held lines for this config.
3. Where you added tpm, it and the plugins it installed are in
   `~/.config/tmux/plugins/`, which can go with them.
4. A running tmux server keeps this config until it stops: `tmux kill-server`
   stops it, and every session in it.
5. tmux-resurrect saves to `~/.tmux/resurrect/` where that directory is
   there, else to `$XDG_DATA_HOME/tmux/resurrect/`, or to
   `~/.local/share/tmux/resurrect/` with `XDG_DATA_HOME` unset: the
   sessions' layout, in `tmux_resurrect_<time>.txt` files, and what every
   pane showed, scrollback included, in `pane_contents.tar.gz`. Once the
   server has stopped — a running one saves again — delete them, or the
   whole directory if no tmux-resurrect of your own saves to it.

A backup the run took sits in `~/.config/tmux/preen/` beside the copy, as
`tmux.conf.unpreened.<timestamp>`: the copy as it was before a later run
replaced it, your edits to it included. Keep it before you delete that
directory, if you want those edits.

Took the whole repository through `bin/bootstrap`? Then
`~/.config/tmux/tmux.conf` is a link into your clone, which already carries
this config: the installer says so and writes nothing.

## License

MIT
