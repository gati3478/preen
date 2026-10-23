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
the pieces share, and `tab-title.awk`, which writes the tab title — the way
it fetches the configs, and nothing it installs points back here.

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
- **Sublime Text** (`brew install --cask sublime-text`), for the click seam.
  `open-actions.conf` launches it as `subl` when you click a file path, and
  `kitty.conf` has kitty look in `/opt/homebrew/bin`, where Homebrew links it
  on Apple silicon. Without Sublime Text a click does nothing; with another
  editor, you put its name in that file. The installer says what it did not find.

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

No clone needed. To print the plan and stop, writing nothing — `bash -s --`
hands the flag to the script:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.1.0/terminal/kitty/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.1.0/terminal/kitty/install.sh | bash
```

Or from a clone of this repository, `./terminal/kitty/install.sh`, with
`--dry-run` for the plan alone. It asks nothing — there is nothing to ask. The
plan for a home with no `~/.config` yet:

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
and after that line comes each setting in your `kitty.conf` above the
include that this config also makes and no line of yours below it makes
again — a file your `kitty.conf` includes is not read — as
`line 2: cursor_shape (yours, above the include) loses to this config`.

It

1. looks for kitty, for the font, for bat and for Sublime Text's `subl`, and
   says what it did not find. None of the four stops it, and it never
   launches kitty;
2. copies `kitty.conf` and `current-theme.conf` into
   `~/.config/kitty/preen/` — copies, never symlinks, each backed up beside
   itself as `<file>.unpreened.<timestamp>` if a different one was there,
   left untouched if identical, and replaced with no backup if it is an
   earlier copy this setup shipped;
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
   An earlier copy this setup shipped at one of them is `updated`, with no
   backup; anything else there stays as it is, with no backup, because
   nothing is replaced: the run says `unchanged` when it is a file holding
   this config's bytes, and `left alone` when it is anything else, a symlink
   included;
5. copies bat's config, from [`terminal/bat/`](../bat/), to
   `~/.config/bat/config` the same way: only where nothing is there, or an
   earlier copy this setup shipped is. Its one
   line is `--theme="ansi"`, the terminal's own palette, and
   `scrollback_pager` names no theme of its own;
6. appends `include preen/kitty.conf` to `~/.config/kitty/kitty.conf`, once:
   an include kitty reads as this config, spelled another way —
   `./preen/kitty.conf`, the full path — is the line already there.
   Nothing else in your file changes, but a last line with no newline gets
   one, and if you have no kitty.conf it becomes that one line. The append is
   last, so a run that stops earlier never leaves an include pointing at
   files that are not there.

A re-run with nothing changed rewrites nothing and takes no backup: the copies
come back `unchanged` and the include line `already there`.

**Refusals**, all of them before the first write, so a stopped run has changed
nothing: `~/.config`, `~/.config/kitty` or `~/.config/kitty/preen` is a
symlink, dangling or not — everything here would land in whatever it points
at, which something else manages; `~/.config/kitty/kitty.conf` is a symlink
whose target lacks the include line — the append would land in that target,
so the line belongs there instead, and a re-run then says `already there`;
`kitty.conf` lacks the line and cannot be appended to, or `~/.config/kitty`
or `preen/` cannot be written into — root-owned after a `sudo` edit, say;
`~/.config/bat` is a symlink, or cannot be written into, when bat's config
would be copied into it;
`~/.config` is not a directory, is not writable, or cannot be created; a
source file that is missing, empty, or not the file it claims to be.

## Updating

Run the install line from this page again: it names the newest release.
From a clone, `git pull`, then
`./terminal/kitty/install.sh`. An earlier copy this setup shipped comes back
`updated`, with no backup. One you edited is not: a copy in `preen/` is
backed up beside itself first, and one of the files kitty reads from
`~/.config/kitty` itself, or bat's config, is left alone. A setting of yours
belongs in `local.conf`, which no run writes (Your overrides).

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

**Another theme.** `kitten themes` writes the theme you pick to
`~/.config/kitty/current-theme.conf` and appends an include of it to the end
of your own `kitty.conf`, below the include line, so it wins over this
palette (read in kitty 0.49.2's source). After the whole setup, `kitty.conf`
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
`action launch` line that opens a file names `subl`. `mime.types` is there
because Python's table, which kitty matches against, has no entry for Kotlin,
Gradle, Svelte, `.tsx`, `.properties` or `.zsh`, and mislabels `.rs`, `.ts`
and `.sql`.

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
3. For `open-actions.conf`, `mime.types`, `choose-files.conf` and
   `~/.config/bat/config`, read what the run said of each: `copied`,
   `updated` or `unchanged` means the file holds what this setup shipped, so
   it can go unless you had it before the first run; `left alone` means the
   run did not write it. Run with `--dry-run`, the installer says why, as in
   `left alone (yours)`; a file it calls `an earlier copy` is this setup's,
   and its `copied` means nothing is there. Where the run said `created` of
   `~/.config/bat`, that directory goes with its file. The shell piece
   copies bat's config too, so keep it while you keep that piece.
4. Delete `~/.config/kitty/last-session.kitty`, the session cmd+q saves, if
   it is there.

A backup the run took sits in `~/.config/kitty/preen/` beside the copy, as
`<file>.unpreened.<timestamp>`: what was there before a later run replaced
it, your edits to it included. Keep it before you delete that directory, if
you want those edits.

Took the whole repository through `bin/bootstrap`? Then `~/.config/kitty/kitty.conf`
is a link into your clone, which already carries this config: the installer
says so and writes nothing. A `~/.config`, `~/.config/kitty` or `preen/` that
is a symlink into a dotfiles repository of your own is refused instead: replace
the link, or copy the files into that repository yourself.

## License

MIT
