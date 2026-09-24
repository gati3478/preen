# kitty · Gruvbox Dark Hard

A [kitty](https://sw.kovidgoyal.net/kitty/) configuration in Gruvbox Dark Hard
on FiraCode Nerd Font Mono, with ligatures, a slashed zero and oldstyle
figures turned on in the font itself. The caret is a thick underline that the
shell is told not to fight; selecting text copies it; fifty thousand lines of
scrollback page through [bat](https://github.com/sharkdp/bat); the audio bell
is off and a bell shows as a red symbol in the tab title instead. It also
carries the kitty half of a click seam — a file path printed by `rg` or `eza`
opens in the editor, at its line, when you click it. Take it alone: the
installer fetches one shared helper from this repository the way it fetches
the configs, and nothing it installs points back here.

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
  unaffected.
- **Zed**, for the click seam. `open-actions.conf` launches `zed` by name
  when you click a file path; without it a click does nothing, and with
  another editor you put its name in that file. The installer says what it
  did not find.

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

One line, no clone:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/terminal/kitty/install.sh | bash
```

Or from a clone of this repository, `./terminal/kitty/install.sh`. It asks
nothing — there is nothing to ask — and `--dry-run` prints the plan and stops
without writing:

```
== will touch ==
~/.config/kitty                            kitty's config directory, created
~/.config/kitty/preen                      this config's own directory, created
~/.config/kitty/preen/kitty.conf           the config
~/.config/kitty/preen/current-theme.conf   the palette it includes
~/.config/kitty/preen/tab-title.conf       the tab title for this home — ours; local.conf stays yours
~/.config/kitty/kitty.conf                 one line appended: include preen/kitty.conf
~/.config/kitty/open-actions.conf          what a click on a link does — kept if you have one
~/.config/kitty/mime.types                 the file types behind it — kept if you have one
~/.config/kitty/choose-files.conf          the fp picker — kept if you have one
```

It

1. looks for kitty, for the font, for bat and for Zed, and says what it did
   not find. None of the four stops it, and it never launches kitty;
2. copies `kitty.conf` and `current-theme.conf` into
   `~/.config/kitty/preen/` — copies, never symlinks, each backed up beside
   itself as `<file>.unpreened.<timestamp>` if a different one was there,
   left untouched if identical;
3. writes `~/.config/kitty/preen/tab-title.conf`: the tab title, rewritten
   for your home directory. kitty's config language expands no environment
   variable in that option, so the home to collapse to `~` has to be a
   literal, and the shipped one is the author's. The file is **the
   installer's**, replaced whole, so the line follows a change of home or of
   the shipped title: a file holding one title line is replaced with no
   backup, and anything else there — more lines, or a symlink — is backed up
   first. On the machine the title was authored for it is not written at
   all, and the run says
   `this is the home the tab title was authored for — no tab-title.conf needed`;
4. copies `open-actions.conf`, `mime.types` and `choose-files.conf` into
   `~/.config/kitty` itself, because kitty reads those three from the config
   directory root under those exact names — a copy under `preen/` is ignored.
   A file of yours at one of them is **left alone** and the run says so; no
   backup is taken, because nothing was replaced;
5. appends `include preen/kitty.conf` to `~/.config/kitty/kitty.conf`, once.
   Your file is not otherwise touched, and if you have none it becomes that
   one line. The append is last, so a run that stops earlier never leaves an
   include pointing at files that are not there.

A re-run with nothing changed rewrites nothing and takes no backup: the copies
come back `unchanged` and the include line `already there`.

**Refusals**, all of them before the first write, so a stopped run has changed
nothing: `~/.config`, `~/.config/kitty` or `~/.config/kitty/preen` is a
symlink, dangling or not — everything here would land in whatever it points
at, which something else manages; `~/.config/kitty/kitty.conf` is a symlink —
the append would land in its target, so the include line belongs there
instead; `kitty.conf` is there and cannot be appended to, or `~/.config/kitty`
or `preen/` cannot be written into — root-owned after a `sudo` edit, say;
`~/.config` is not a directory or is not writable; a source file that is
missing, empty, or not the file it claims to be.

## Your overrides

`~/.config/kitty/preen/local.conf` is read after everything else in this
config, so a line in it wins over this config's. That is where a setting of
yours belongs.

The file is yours: nothing here creates it, writes it or backs it up.
`tab-title.conf` beside it is the installer's and is read just before it, so a
tab title in `local.conf` wins over ours, and the run names its line rather
than claim its own title applies. When that line is
`active_wd.replace('<path>', '~')` for a path other than your home, the run
names the path too.

One more thing follows from kitty's last-include-wins rule, and it is worth
knowing before you wonder why a setting of yours stopped working: **lines in
your own `kitty.conf` above the include line lose to this config.** If you had
`cursor_shape block`, the caret is an underline after this install. Move the
line below the include line, or into `local.conf`.

## The click seam

`open-actions.conf` and `mime.types` are the kitty half of one behaviour: a
file path printed in the terminal is a link, and clicking it opens the file in
Zed — at the matching line when the link carries one, in a new tab when it is
a directory. Another editor is one edit away: the three `action launch` lines
name `zed`. `mime.types` is there because Python's table, which kitty
matches against, has no entry for Kotlin, Gradle, Svelte, `.tsx`,
`.properties` or `.zsh`, and mislabels `.rs`, `.ts` and `.sql`.

The other half is the shell writing those links — `rg --hyperlink-format=kitty`
and `eza --hyperlink` — and it lives in `shell/` and `ripgrep/` in this
repository. It is **not** installed here. Without it the two files sit idle and
cost nothing.

`choose-files.conf` is unrelated to the seam: it configures kitty's own
`choose-files` kitten, so that its picker sees hidden files, honours
`.gitignore`, skips `.git/`, and previews with a Gruvbox highlighting style.

## Leaving

1. Delete the `include preen/kitty.conf` line from
   `~/.config/kitty/kitty.conf` — or the file, if that line is all it holds.
2. Delete `~/.config/kitty/preen/` — keep `local.conf` from it first if you
   made one; that file is yours.
3. For `open-actions.conf`, `mime.types` and `choose-files.conf`, read the
   run's summary: a `copied` line means the file is this config's and can go;
   a `left alone` line means it was already yours and was never touched.

Where a backup was taken it sits beside the file it replaced, as
`<file>.unpreened.<timestamp>`; move it back.

Took the whole repository through `bin/bootstrap`? Then `~/.config/kitty/kitty.conf`
is a link into your clone, which already carries this config: the installer
says so and writes nothing. A `~/.config`, `~/.config/kitty` or `preen/` that
is a symlink into a dotfiles repository of your own is refused instead: replace
the link, or copy the files into that repository yourself.

## License

MIT
