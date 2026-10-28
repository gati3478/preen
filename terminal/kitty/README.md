# kitty · Gruvbox Dark Hard

A [kitty](https://sw.kovidgoyal.net/kitty/) configuration in Gruvbox Dark Hard
on FiraCode Nerd Font Mono, with ligatures, a dotted zero and oldstyle
figures turned on in the font itself. The caret is a thick underline that the
shell is told not to fight; selecting text copies it; fifty thousand lines of
scrollback page through [bat](https://github.com/sharkdp/bat); the audio bell
is off and a bell shows as a red symbol in the tab title instead. It also
carries the kitty half of a click seam — a file path printed by `rg` or `eza`
opens in the editor, at its line, when you click it. Take it alone: the
installer fetches its helpers from this repository — the installer library
the pieces share, and `tab-title.awk`, which writes the tab title — and
nothing it installs points back here.

## What you need

**Required**

- **kitty.** Not found, the installer says so and installs anyway — these
  files are read the first time kitty starts, whenever that is.
- **FiraCode Nerd Font Mono** (`brew install --cask font-fira-code-nerd-font`).
  Without it kitty falls back to its own monospace face and the three font
  features this config asks for are simply not there.

**Optional**

- **bat**, for the scrollback pager. `scrollback_pager` runs it by name, so
  until bat is installed the pager opens on nothing. Everything else is
  unaffected. The installer copies bat's config, which names its theme,
  where you have none of your own.
- **Sublime Text** (`brew install --cask sublime-text`), for
  [the click seam](#the-click-seam); without it a click does nothing. The
  installer says what it did not find.

## The palette

Read off `current-theme.conf`, which is Gruvbox Dark Hard as the
[gruvbox-community](https://github.com/gruvbox-community/gruvbox-contrib)
collection publishes it, with the tab and border block hand-tuned.

| Slot    | Normal    | Bright    |
| ------- | --------- | --------- |
| black   | `#3c3836` | `#928374` |
| red     | `#cc241d` | `#fb4934` |
| green   | `#98971a` | `#b8bb26` |
| yellow  | `#d79921` | `#fabd2f` |
| blue    | `#458588` | `#83a598` |
| magenta | `#b16286` | `#d3869b` |
| cyan    | `#689d6a` | `#8ec07c` |
| white   | `#a89984` | `#fbf1c7` |

| Role                  | Hex                    |
| --------------------- | ---------------------- |
| background            | `#1d2021`              |
| foreground            | `#ebdbb2`              |
| cursor / its text     | `#bdae93` / `#665c54`  |
| selection bg / fg     | `#d65d0e` / `#ebdbb2`  |
| url                   | `#458588`              |
| active tab bg / fg    | `#8ec07c` / `#1d2021`  |
| inactive tab bg / fg  | `#3c3836` / `#928374`  |
| active border         | `#8ec07c`              |
| inactive border       | `#3c3836`              |
| bell border           | `#fb4934`              |

There is no light variant.

## Install

The plan, writing nothing:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.3/terminal/kitty/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.3/terminal/kitty/install.sh | bash
```

Or from a clone, `./terminal/kitty/install.sh`. It asks nothing. The plan
for a home with no `~/.config` yet:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/kitty                            kitty's config directory, created
~/.config/kitty/preen                      this config's own directory, created
~/.config/kitty/preen/kitty.conf           the config — copied
~/.config/kitty/preen/current-theme.conf   the palette it includes — copied
~/.config/kitty/preen/tab-title.conf       the tab title for this home — copied
~/.config/kitty/kitty.conf                 created: include preen/kitty.conf
~/.config/kitty/open-actions.conf          what a click on a link does — copied
~/.config/kitty/mime.types                 the file types behind it — copied
~/.config/kitty/choose-files.conf          kitty's file picker, kitten choose-files — copied
~/.config/bat                              bat's config directory, created
~/.config/bat/config                       bat's theme: the terminal's palette — copied
```

Each line says what this run does to your home. A file of yours reads
`backed up, then replaced` in `preen/` and `left alone (yours)` at the fixed
names below; an earlier copy reads `updated (an earlier copy)`. A
`kitty.conf` of yours without the line reads `one line appended: <line>`,
followed by each setting of yours above the include that this config makes
too — a file your `kitty.conf` includes is not read — as
`line 2: cursor_shape (yours, above the include) loses to this config`.

It

1. looks for kitty, the font, bat and Sublime Text's `subl`, and says what
   it did not find; none of them stops it, and it never launches kitty;
2. copies `kitty.conf` and `current-theme.conf` into
   `~/.config/kitty/preen/`, a different file there first backed up beside
   itself as `<file>.unpreened.<timestamp>`, an earlier copy this setup
   shipped replaced without one;
3. writes `preen/tab-title.conf`, the tab title for your home: kitty expands
   no variable in that option, so the shipped title names the author's home.
   The file is **the installer's**: a file of that one line is replaced with
   no backup, anything else there is backed up first, and on the author's
   machine it is not written at all;
4. copies `open-actions.conf`, `mime.types` and `choose-files.conf` into
   `~/.config/kitty` itself, the one place kitty reads them, and bat's config,
   from [`terminal/bat/`](../bat/), to `~/.config/bat/config` — each only
   where nothing is there or an earlier copy this setup shipped is. Anything
   else stays, said `unchanged` or `left alone`. bat's one line,
   `--theme="ansi"`, draws the pager in the terminal's palette;
5. appends `include preen/kitty.conf` to `~/.config/kitty/kitty.conf`, once —
   an include of this config spelled another way counts. Nothing else in your
   file changes, but a last line with no newline gets one. The append is
   last, so a run that stops earlier leaves no include pointing at nothing.

A re-run with nothing changed rewrites nothing and takes no backup.

Every refusal comes before the first write, and a dry run makes each one.
Among them, a symlinked `~/.config`, `~/.config/kitty` or `preen/` is
refused, and `~/.config/bat` where bat's config would go in it, since the
files would land wherever it points; so is a symlinked `kitty.conf` whose
target lacks the line, which belongs in the target, and a directory or
`kitty.conf` the run cannot write.

## Updating

Run the install line from this page again: it names the newest release.
From a clone, `git pull`, then `./terminal/kitty/install.sh`. An earlier copy
this setup shipped comes back `updated`, with no backup. One you edited is
not: a copy in `preen/` is backed up beside itself first, and the files in
`~/.config/kitty` itself, or bat's config, are left alone. A setting of yours
belongs in `local.conf`, which no run writes (Your overrides).

## Your overrides

`~/.config/kitty/preen/local.conf` is read after everything else in this
config, so a line in it wins over this config's. That is where a setting of
yours belongs.

The file is yours: nothing here creates it, writes it or backs it up.
`tab-title.conf` beside it is read just before it, so a tab title in
`local.conf` wins over ours, and the run names its line.

**Lines in your own `kitty.conf` above the include line lose to this
config**: with `cursor_shape block` there, the caret is an underline after
this install. Move such a line below the include line, or into `local.conf`.

**Another theme.** `kitten themes` writes the theme you pick to
`~/.config/kitty/current-theme.conf` and appends an include of it to the end
of your own `kitty.conf`, below the include line, so it wins over this
palette. After the whole setup, `kitty.conf`
is a link into the clone, which the kitten writes through, and the next
`git pull` refuses: run `kitten themes --config-file-name local.conf`
instead, and the include lands in `~/.config/kitty/local.conf`, which that
setup reads last. `kitten choose-fonts` edits `kitty.conf` too, unless given
the same `--config-file-name local.conf`.

## What changes

The choices felt at once, each with the lines that undo it in
`~/.config/kitty/preen/local.conf`. Each undo is kitty 0.49.2's own default.

| What you notice | Undo |
| --- | --- |
| the left Option key is Alt, so characters typed with Option take the right one (`macos_option_as_alt`) | `macos_option_as_alt no` |
| selecting text copies it, replacing the clipboard (`copy_on_select`) | `copy_on_select no` |
| cmd+q saves the open windows and tabs to `~/.config/kitty/last-session.kitty`, and the next launch restores them (`startup_session`); before the first save, kitty logs that it cannot read the file and opens its usual window | `startup_session none`<br>`map cmd+q quit` |

Of the session's two lines, the first stops the session opening at launch,
the second makes cmd+q quit without saving.

## The click seam

`open-actions.conf` and `mime.types` are the kitty half of one behaviour: a
file path printed in the terminal is a link, and clicking it opens the file in
Sublime Text — at the matching line when the link carries one, in a new tab
when it is a directory. Another editor is one find-and-replace away: each
`action launch` line that opens a file names `subl`. `mime.types` adds the
file types kitty's lookup lacks or mislabels, Kotlin and `.rs` among them.

The other half is the shell writing those links — `rg --hyperlink-format=kitty`
and `eza --hyperlink` — and the [shell piece](../../shell/README.md) installs
it, not this one. Without it the two files sit idle.

`choose-files.conf` configures kitty's own file picker, `kitten choose-files`,
to see hidden files, honour `.gitignore`, skip `.git/`, and preview in
Gruvbox.

## Leaving

1. Delete the `include preen/kitty.conf` line from
   `~/.config/kitty/kitty.conf` — or the file, if that line is all it holds.
2. Delete `~/.config/kitty/preen/` — keep `local.conf` from it first if you
   made one; that file is yours.
3. For `open-actions.conf`, `mime.types`, `choose-files.conf` and
   `~/.config/bat/config`, read what the run said of each: `copied`,
   `updated` or `unchanged` means the file holds what this setup shipped, so
   it can go unless you had it before the first run; `left alone` means the
   run did not write it. A `--dry-run` says which is which now: `an earlier
   copy` is this setup's. A `~/.config/bat` the run `created` goes with its
   file; the shell piece copies bat's config too, so keep it while you keep
   that piece.
4. Delete `~/.config/kitty/last-session.kitty`, the session cmd+q saves, if
   it is there.

A backup the run took sits in `~/.config/kitty/preen/` beside the copy, as
`<file>.unpreened.<timestamp>`, your edits included: keep it before you
delete that directory, if you want them.

## License

MIT
