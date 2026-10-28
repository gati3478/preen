# bootstrap · the whole setup

Every row of [`manifest.tsv`](../manifest.tsv), deployed from one clone of
this repository by `bootstrap` and read back by `preen doctor`.
[The README](../README.md#take-the-setup) gives the two blocks that run them,
bootstrap's plan first.

## What bootstrap does

`bootstrap` names each missing tool, an optional one with what goes without
it, and asks before it goes on without one the setup needs. It asks your
name and email for git and sets them in `~/.gitconfig.local`, leaving the
rest of that file as it is; deploys every row of `manifest.tsv`; and writes
`~/.config/kitty/tab-title.conf`, which holds your home, the one path kitty's
config language cannot template. Zed's and Sublime Text's settings are linked
where their pieces copy them, `~/.config/zed/global_settings.json` and
Sublime's `Packages/preen`, beneath your own `~/.config/zed/settings.json` and
`Packages/User`, which bootstrap never writes. It ends by naming each
overlay, the file of yours that wins over a shipped one, and everything it
set aside. The statusline is linked but not wired: its installer, run from
the clone, wires it. A cship you already run reads the linked `cship.toml`
at once, and with it the account module, which on a personal account shows
your email
([the statusline's page](../prompt/README.md#the-account-module-and-your-email)).
System Settings are in no row: to take them, run
`./macos/apply.sh` from the clone, as [its page](../macos/README.md) says.
The kitty, shell, tmux, git, Zed and Sublime Text installers, run after
bootstrap, find their files linked into the clone, say so and write nothing.

## What it finds in the way

Every refusal, bootstrap's or `preen apply`'s, comes before the first write,
and bootstrap never modifies your clone. What it finds:

- a symlinked directory between `~` and a file it deploys, the layout stow
  leaves, is refused;
- at a `link` row, a plain file of yours that differs from the shipped one
  is kept beside itself as `<file>.unpreened.<stamp>`, `<stamp>` the run's
  date and time;
- at a `copy` row, a file of yours stays as it is: only a copy the setup
  shipped is replaced;
- a symlink is never written through: at a `link` row it is replaced and its
  old target printed, at a `copy` row it is moved aside, except a link into
  the clone left from when the row was a link, which the copy replaces;
- a plain `~/.gitconfig`, or a `~/.ssh/config` plain or linked, becomes the
  `.local` beside it, unless one is there or yours already names it; git
  reads that file last and ssh first, so every line of yours wins; a
  `~/.gitconfig` that names the git piece's copy is kept beside itself
  instead, its lines bound for `~/.gitconfig.local` — never the git piece's
  line, which bootstrap names;
- your `~/.zshenv`, `~/.zprofile` and `~/.zshrc`, set aside as above, go
  unread: their lines belong in the `.local` beside each, which the shipped
  file sources — never the shell piece's line, which bootstrap names.

## The doctor

`preen doctor` reads every row back, then checks the tools, warning rather
than failing where one is absent. The author's preferences, in
[`taste/`](../taste/README.md), are asserted against your live config only
when asked (python 3.11 or newer), because they are the author's:

```sh
~/preen/bin/preen doctor --taste
```

## The model

**One table drives install and verification.** `preen apply` installs from
`manifest.tsv` and `preen doctor` checks against it, so "installed" and
"checked" read the same row.

**`link` or `copy`, decided by who writes the file.** Where an application only
reads its config, the live file is a symlink and the repository's file _is_
the config. Where it writes the file too — gh's and atuin's `config set`,
kitty's theme picker, Zed's keymap editor and its task saves — the row is a
copy: the write would follow a link into the clone, and the next `git pull`
would refuse. The theme picker writes the linked `kitty.conf` too, unless
given `--config-file-name local.conf`, as
[kitty's page](../terminal/kitty/README.md) says.

## What changes

These pages list the choices their pieces make that are felt at once, each
with its undo line, and the setup makes them too:
[the shell's](../shell/README.md#what-changes),
[kitty's](../terminal/kitty/README.md#what-changes),
[tmux's](../terminal/tmux/README.md#what-changes),
[git's](../git/README.md#what-changes),
[gh's](../gh/README.md#what-changes) — only where you had no plain
`config.yml` of your own — [Zed's](../editor/zed/README.md#what-changes) and
[Sublime Text's](../editor/sublime/README.md#what-changes). The setup makes
three more:

| Tool | What you notice | Undo |
| --- | --- | --- |
| zsh | `~/.zprofile` carries the author's JetBrains Toolbox, SDKMAN and Playdate lines — PATH entries and a `PLAYDATE_SDK_PATH` export, harmless where those are absent — and Antigravity's, which puts `~/.local/bin` ahead of Homebrew. Where a JDK 21 is installed, `JAVA_HOME` is it | `unset PLAYDATE_SDK_PATH` in `~/.zprofile.local`; `path=("$HOMEBREW_PREFIX/bin" $path)` there puts Homebrew back ahead; for another JDK, `export JAVA_HOME=…` and `path=("$JAVA_HOME/bin" $path)` there, since JDK 21's `bin` is ahead of `/usr/bin` |
| starship | your shell prompt is the author's two-line one, `prompt/starship.toml`, linked without asking | move your own, kept beside it as `starship.toml.unpreened.<stamp>`, to a name of its own, and `export STARSHIP_CONFIG=` that path in `~/.zshenv.local` |
| ssh | ssh asks Proton Pass's agent for every host (`IdentityAgent`); keys on disk still sign | `IdentityAgent SSH_AUTH_SOCK` under `Host *` |

Here the files a piece appends its line to are links into the clone — all
but `~/.tmux.conf` and `~/.config/git/config`, which no row replaces — so an
undo goes in an overlay the shipped file reads, and wins there: the shell's
in `~/.zshrc.local`, or the `.local` its row names; kitty's in
`~/.config/kitty/local.conf`, not the piece's `preen/local.conf`; tmux's in
`~/.config/tmux/local.conf`; git's in `~/.gitconfig.local`; ssh's in
`~/.ssh/config.local`; Zed's in `~/.config/zed/settings.json`; Sublime
Text's in `Packages/User`; gh's through `gh config set`, as on its page. The
shell's undo for tmux over ssh, `unset SSH_CONNECTION`, goes in
`~/.zprofile.local`, which a login zsh reads before the zshrc.

## Updating

```sh
cd ~/preen && git pull --rebase --no-autostash && ./bin/preen apply
```

A `link` row reads the clone, so it changes the moment the clone does.
`preen apply` then deploys any new row and updates a `copy` row's file still
holding a copy the setup shipped. One you or an application changed stays:
`preen doctor` names it as yours, and one an update is due for as behind.

A tool that edits `~/.zshrc` or `~/.gitconfig` edits the clone, because those
are links, and the pull then refuses and changes nothing, whatever your own
pull, rebase or merge settings say: that is what its flags are for.
`git -C ~/preen status --short` names the file and `git -C ~/preen diff`
shows the edit. Its lines belong in the `.local` overlay beside the live
file; `git -C ~/preen checkout -- <file>` then clears it, and the pull goes
through.

`preen apply` deletes nothing. A row the pull removes, or points at another
path, leaves the file it deployed, which can outrank the new row, or, as a
link, take a tool's writes into the clone. Right after a pull,
`git -C ~/preen diff ORIG_HEAD HEAD -- manifest.tsv` shows each as a `-`
line whose target no `+` line names, and
`git -C ~/preen log -p -- manifest.tsv` every earlier one. Delete a link
into the clone. From a copied file, delete the setup's lines and keep yours;
where none are yours, move its earliest backup back ([Leaving](#leaving)),
or delete the file where it has none.

kitty's tab title does not follow the clone: bootstrap writes its line into
`~/.config/kitty/tab-title.conf`, which wins over `kitty.conf`, so a change
to it arrives with a re-run of `./bin/bootstrap`.

## Leaving

In this order:

1. `~/preen/bin/preen doctor` lists under backups each file set aside beside
   a deployed one, and marks each `copy` row's file that holds what the
   setup shipped, `ok` or `behind`, and each that is `yours`.
2. If you wired the statusline from the clone, delete the `statusLine` entry
   from `~/.claude/settings.json`, and any backup of that file: it predates
   what Claude Code wrote since.
3. Remove the links: every `link` row of `manifest.tsv` points into `~/preen`.
4. Move each backup back in its place. Among a file's backups,
   `<file>.unpreened.<stamp>`, the earliest is the original, what was there
   before anything here replaced the file, whichever wrote it — bootstrap,
   `preen apply`, or a piece's installer; the later ones are rewrites. A
   symlink of yours at a `link` row has no backup: recreate it from the
   run's `replaced link` line, which names where it pointed.
5. Remove each `copy` row's file that holds what the setup shipped, unless
   you had it before. From one called `yours`, delete the setup's lines and
   keep yours: an application, as `gh config set` does, may have written it
   since.
6. Move `~/.gitconfig.local` to `~/.gitconfig` and `~/.ssh/config.local` to
   `~/.ssh/config` where no backup went back: once the links are gone,
   nothing reads them.
7. Remove `~/.config/kitty/tab-title.conf`, which is the setup's, and the
   clone.
8. Each piece's page ends with its own Leaving, which names what outlives
   the setup too: kitty's saved session, tmux's plugins and saves, zsh's
   history, and Sublime Text's Terminus colour schemes and `"theme"` line.
   Where you took a piece before the setup, its line is still in a file of
   yours — an original you moved back, or one no row replaced, which
   bootstrap named — and that page removes it.

If you ran `macos/apply.sh`, `sh` the `macos.unpreened.*.sh` it named, newest
first after several runs, to put back the settings it changed
([its page](../macos/README.md#putting-it-back)).
