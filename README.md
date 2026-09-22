# preen

A macOS terminal and editor setup — kitty, zsh, tmux, starship, the cship
statusline for Claude Code, Zed, Sublime Text — in Gruvbox on Fira Code, and
the taste behind it, written as assertions a checker runs against live config.
_Preen_: to groom to your own standard. Generated from a private repository;
every file here is whole (the manifest is that repository's public rows), and
what stays there is said under The model.

## Take one piece

The statusline, [`prompt/`](prompt/README.md), which needs
[cship](https://github.com/stephenleo/cship) 1.8.2 or newer; or the terminal,
[`terminal/kitty/`](terminal/kitty/README.md). To see what a script would do
and stop — the statusline's asks its two questions first:

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
plan is printed, and a refusal comes before any write. `--help` is each
script's manual.

## Take the setup

```sh
git clone https://github.com/gati3478/preen ~/preen
cd ~/preen && ./bin/bootstrap
./bin/dot-doctor
```

`bootstrap` names what is missing and asks before going on; asks your name and
email for git and writes them to `~/.gitconfig.local`; creates two empty shell
overlays, `~/.zshenv.local` and `~/.zprofile.local`; deploys every row of
`manifest.tsv`; and writes `~/.config/kitty/local.conf`, the one path kitty's
config language cannot template. It does not modify your clone. A plain file
already where a row goes is kept beside itself as `<file>.pre-dotfiles`, the
identity file with a timestamp. A symlink there is never written through: at
a `link` row it is replaced and its old target printed, at a `copy` row it is
moved aside. An ssh config of yours becomes `~/.ssh/config.local`, which the
shipped one includes first, so every line of it wins. The shipped one then
names a password manager's agent socket for every host; keys on disk still
sign, and `IdentityAgent SSH_AUTH_SOCK` under `Host *` in `config.local`
keeps an agent of your own.

`dot-doctor` reads every row back, then runs its own checks of the tools,
warning rather than failing where one is absent. The author's preferences are
asserted against your live config only when asked (python 3.11 or newer),
because they are the author's:

```sh
~/preen/bin/dot-doctor --taste
```

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
macos/             System Settings by `defaults`; bootstrap does not run it
bin/               bootstrap, dot-apply, dot-doctor, and what the doctor runs
lib/               install.sh, the half the installers share
manifest.tsv       repo file → live path → link or copy; the one table
preferences.toml   each preference's value and why, and the rows that check it
LICENSE            MIT
```

## The model

**One table drives install and verification.** `manifest.tsv` maps each file
here to its live path and says whether the row is a symlink or a copy.
`bin/dot-apply` installs from it; `bin/dot-doctor` checks against it. There is
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
identity, each machine's overlays and its half of the spec, the personal
scripts, the prose that argues every preference and the wiki around it, and
the verbs that publish this mirror and pull rewritten copies back. Comments in
these files cite them — `docs/preferences.md`, `traps.md`, `dot-publish` —
because the files are published as they are. Nothing here reads those,
nothing breaks without them, and `dot-doctor --taste` says so once and
carries on.

## Make it yours

Fork or clone, keep `manifest.tsv`'s format and the two verbs, `dot-apply` and
`dot-doctor`, replace the rows with your own files, and delete every directory
you do not want along with its rows. The checks in `bin/dot-doctor` probe the
tools the author runs; read them and cut what is not yours.

MIT.
