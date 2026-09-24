# preen

A macOS terminal and editor setup — kitty, zsh, tmux, starship, the cship
statusline for Claude Code, Zed, Sublime Text — in Gruvbox on Fira Code, and
the taste behind it, written as assertions a checker runs against live config.
_Preen_: to groom to your own standard. Generated from a private repository,
whose files these are, published as they are; what stays there is said under
The model.

## Take one piece

The statusline, [`prompt/`](prompt/README.md), which needs
[cship](https://github.com/stephenleo/cship) 1.8.2 or newer; or the terminal,
[`terminal/kitty/`](terminal/kitty/README.md). To see what a script would do
and stop — the statusline's script asks its two questions first:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/prompt/install.sh | bash -s -- --dry-run
```

To do it:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/prompt/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/terminal/kitty/install.sh | bash
```

Each fetches its files and one shared helper from here, copies the files into
your config — copies, never symlinks — and wires one entry: the `statusLine`
key of `~/.claude/settings.json`, merged into what is there; one `include`
line appended to `~/.config/kitty/kitty.conf`. Nothing is written before the
plan is printed, and a refusal comes before any write; a symlinked directory
the copies would land under is one. `--help` is each script's manual.

## Take the setup

On a Mac without Homebrew, install it first from [brew.sh](https://brew.sh);
it also brings the Command Line Tools that `git clone` needs.

```sh
git clone https://github.com/gati3478/preen ~/preen
cd ~/preen && ./bin/bootstrap
./bin/preen doctor
```

`bootstrap` names what is missing: the tools the setup needs, asking before
it goes on without them, and the optional ones, each with what goes without
it. It asks your name and email for git and sets them as `user.name` and
`user.email` in `~/.gitconfig.local`, leaving the rest of that file as it is;
deploys every row of `manifest.tsv`; and writes
`~/.config/kitty/tab-title.conf`, which holds your home, the one path kitty's
config language cannot template. It ends by naming each overlay the shipped
files read and everything it set aside. The statusline is linked but not
wired: its installer, run from the clone, wires it.

`bootstrap` makes every refusal, its own or `preen apply`'s, before its first
write, and it does not modify your clone. What it finds in the way:

- a symlinked directory between `~` and a file it deploys, the layout stow
  leaves, is one such refusal;
- a plain file of yours is kept beside itself as `<file>.unpreened`;
- a symlink is never written through: at a `link` row it is replaced and its
  old target printed, at a `copy` row it is moved aside;
- a plain `~/.gitconfig` of yours, or a `~/.ssh/config` plain or linked,
  becomes the `.local` beside it, unless one is there or yours already names
  it: git reads that file last and keeps the last value, ssh reads it first
  and keeps the first, so every line of yours wins;
- your own `~/.zshenv`, `~/.zprofile` and `~/.zshrc`, set aside as above, go
  unread: their lines belong in the `.local` beside each, which the shipped
  file sources.

The shipped `ssh/config` then names Proton Pass's agent socket for every
host. Keys on disk still sign; `IdentityAgent SSH_AUTH_SOCK` under `Host *`
in `config.local` keeps an agent of your own.

`preen doctor` reads every row back, then runs its own checks of the tools,
warning rather than failing where one is absent. The author's preferences are
asserted against your live config only when asked (python 3.11 or newer),
because they are the author's:

```sh
~/preen/bin/preen doctor --taste
```

## What changes when you take the setup

Some of the author's choices are felt at once. An undo line goes in an
overlay, where it wins over the shipped file: the one its row names, or else
its tool's — `~/.zshrc.local`, `~/.config/kitty/local.conf`,
`~/.gitconfig.local` or `~/.ssh/config.local`.

| Tool | What you notice | Undo |
| --- | --- | --- |
| zsh | `>` refuses to overwrite a file; `>\|` does (`NO_CLOBBER`) | `unsetopt NO_CLOBBER` |
| zsh | a mistyped command is offered a correction (`CORRECT`) | `unsetopt CORRECT` |
| zsh | `*` matches dotfiles (`GLOB_DOTS`) | `unsetopt GLOB_DOTS` |
| zsh | word motion stops at every character but a letter or digit (`WORDCHARS=''`) | zsh's default, `WORDCHARS='*?_-.[]~=/&;!#$%^(){}<>'` |
| zsh | Up and Down search history by what is typed before the cursor | `bindkey '^[[A' up-line-or-history`<br>`bindkey '^[[B' down-line-or-history`<br>`bindkey '^[OA' up-line-or-history`<br>`bindkey '^[OB' down-line-or-history` |
| zsh | `ls` is eza, whose flags are not all ls's: `ls -ltr` is an error | `unalias ls` |
| zsh | `$EDITOR` is Zed only where `~/.zshenv` finds `zed` on PATH, which it searches before the login files add Homebrew and `/usr/local/bin`: so nano in a kitty tab, and always over ssh | `export EDITOR=… VISUAL=…` in `~/.zshenv.local` |
| zsh | over ssh, where tmux is installed, a shell attaches to the tmux session `remote`, and leaving tmux ends the login | `unset SSH_CONNECTION` in `~/.zprofile.local`; tools that read it then see no ssh session |
| zsh | `~/.zprofile` carries the author's JetBrains Toolbox, SDKMAN, Playdate and Docker lines — PATH entries and a `PLAYDATE_SDK_PATH` export, harmless where those are absent — and Antigravity's, which puts `~/.local/bin` ahead of Homebrew. Where a JDK 21 is installed, `JAVA_HOME` is it | `unset PLAYDATE_SDK_PATH` in `~/.zprofile.local`; `path=("$HOMEBREW_PREFIX/bin" $path)` there puts Homebrew back ahead; for another JDK, `export JAVA_HOME=…` and `path=("$JAVA_HOME/bin" $path)` there, since JDK 21's `bin` is ahead of `/usr/bin` |
| kitty | the left Option key is Alt, so characters typed with Option take the right one (`macos_option_as_alt`) | `macos_option_as_alt no` |
| kitty | selecting text copies it, replacing the clipboard (`copy_on_select`) | `copy_on_select no` |
| kitty | cmd+q saves the session and the next launch restores it (`startup_session`); before the first save, kitty logs that it cannot read the file and opens its usual window | `startup_session none`<br>`map cmd+q quit` |
| git | `git pull` rebases, and refuses while the working tree has local edits (`pull.rebase`) | `rebase = false` under `[pull]` |
| git | git pages through delta, side by side, or through less without it | `pager = less` under `[core]` |
| ssh | ssh asks Proton Pass's agent for every host (`IdentityAgent`) | `IdentityAgent SSH_AUTH_SOCK` under `Host *` |

## Updating

```sh
cd ~/preen && git pull --rebase --no-autostash && ./bin/preen apply
```

A `link` row reads the clone, so it changes the moment the clone does.
`preen apply` then deploys any new row and resets a `copy` row an application
has rewritten, keeping the rewrite beside it; `preen doctor` lists every such
backup.

A tool that edits `~/.zshrc` or `~/.gitconfig` edits the clone, because those
are links, and the pull then refuses and changes nothing, whatever your own
pull, rebase or merge settings say: that is what its flags are for.
`git -C ~/preen status --short` names the file and `git -C ~/preen diff`
shows the edit. Its lines belong in the `.local` overlay beside the live
file; `git -C ~/preen checkout -- <file>` then clears it, and the pull goes
through.

kitty's tab title does not follow the clone: bootstrap writes its line into
`~/.config/kitty/tab-title.conf`, which wins over `kitty.conf`, so a change
to it arrives with a re-run of `./bin/bootstrap`.

## Leaving

In this order:

1. `~/preen/bin/preen doctor` lists under backups each file set aside beside
   a deployed one.
2. If you wired the statusline from the clone, delete the `statusLine` entry
   from `~/.claude/settings.json`, and any backup of that file: it predates
   what Claude Code wrote since.
3. Remove the links: every `link` row of `manifest.tsv` points into `~/preen`.
4. Move each backup back in its place. Where a file has several, the bare
   `<file>.unpreened` is the oldest, what was there when the setup first
   replaced the file; the numbered ones are later rewrites.
5. Remove each `copy` row's file that had no backup and that you did not have
   before.
6. Move `~/.gitconfig.local` to `~/.gitconfig` and `~/.ssh/config.local` to
   `~/.ssh/config` where no backup went back: once the links are gone,
   nothing reads them.
7. Remove `~/.config/kitty/tab-title.conf`, which is the setup's, and the
   clone.

If you ran `macos/apply.sh`, `sh` the `macos.unpreened.*.sh` it named, to put
back the settings it changed.

## What is here

```
prompt/            the Claude Code statusline; its own page and installer
terminal/kitty/    the terminal; its own page and installer
terminal/tmux/     tmux for SSH: true colour, mouse, a deep history, resurrect
terminal/bat/      one line: bat in the terminal's palette
terminal/ncdu/     one line: ncdu in the terminal's palette
shell/             zsh in three files split by cost, inputrc, hushlogin, atuin
editor/zed/        settings, a keymap on a JetBrains base, tasks
editor/sublime/    settings, Terminus to match, a vendored light scheme
git/               gitconfig, the global ignore; identity asked for, never here
gh/                the CLI's own preferences
ripgrep/           flags: hidden in, .git out, smart case, clickable matches
mise/              the runtime manager's global pins
ssh/               an Include for your own config, then the agent line; no hosts
macos/             System Settings, run by hand: --dry-run lists each change, a run saves what it replaces
bin/               bootstrap, preen — apply and doctor — and what the doctor runs
lib/               install.sh, the half the installers share
manifest.tsv       the source's public rows: file → live path → link or copy
preferences.toml   each preference's value and why, and the rows that check it
LICENSE            MIT
```

## The model

**One table drives install and verification.** `manifest.tsv` maps each file
here to its live path and says whether the row is a symlink or a copy.
`preen apply` installs from it; `preen doctor` checks against it. There is
no second list, so "installed" and "checked" read the same row.

**`link` or `copy`, decided by who writes the file.** Where an application only
reads its config, the live file is a symlink and the repo file _is_ the config.
Where the application rewrites its own config — Sublime, gh, kitty for its
theme file — the row is a copy, because a symlink would be replaced by a plain
file the first time it saved.

**A piece stands alone through the tool's own include.** kitty reads its
includes last-wins, so `terminal/kitty/` lands under a directory of its own
plus one `include` line in your `kitty.conf`, never an edit inside it; the
three files kitty reads by name from its config root are copied only where
you have none. A tool with one file and no include — the statusline — is
copied and tailored by its installer. Nothing installed either way points
back here.

**Themes are a family, not one scheme.** Gruvbox Dark Hard where code runs —
kitty, the statusline — and Gruvbox Light Hard where it is read — Zed,
Sublime; Fira Code throughout, the Nerd Font build in the terminal.
kitty's palette is its own included file, so a swap touches one file, and
each piece's page carries its palette table.

**Not here:** what cannot ship — the IntelliJ IDEA tree (it names an
employer), the fonts, the Obsidian snippets, the real ssh hosts, the git
identity, each machine's overlays and its half of `preferences.toml`, the
personal scripts, the prose that argues every preference and the wiki around
it, and the tools that publish this mirror and pull rewritten copies back.
Comments in these files cite them — `docs/preferences.md`, `traps.md`,
`preen publish` — because the files are published as they are. Nothing here
reads those, nothing breaks without them, and `preen doctor --taste` says so
once and carries on.

## Make it yours

Fork or clone, keep `manifest.tsv`'s format and the two verbs, `preen apply` and
`preen doctor`, replace the rows with your own files, and delete every directory
you do not want along with its rows. The checks in `bin/preen-doctor` probe the
tools the author runs; read them and cut what is not yours.

MIT.
