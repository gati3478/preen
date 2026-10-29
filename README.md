# preen

![A shell prompt above Claude Code's statusline, rendered from prompt/ in the palette terminal/kitty/ sets](prompt/statusline.svg)

Below the prompt is Claude Code's statusline, and one line of shell makes it
yours. It is [`prompt/`](prompt/README.md), one piece of preen: a macOS
terminal and editor setup — kitty, zsh, tmux, Zed, Sublime Text — that checks
itself against your live config. _Preen_: to groom to your own standard.

Gruvbox Dark Hard where code runs — kitty, tmux, the statusline — and Gruvbox
Light Hard where it is read — Zed, Sublime Text; Fira Code throughout, the
Nerd Font build in the terminal.

## Take one piece

Each piece installs with a `curl … | bash` line on its page, and
`bash -s -- --dry-run` in place of the final `bash` prints the plan for your
home and writes nothing. A real run makes every refusal before its first
write and saves what it replaces: a file of yours beside itself, System
Settings' values in a script that puts them back. Your config gains an
include line, a layer beneath it, or the keys the piece sets; a file with no
such seam is copied where you have none, or replaced. Each page says which.

| Piece | What it is |
| --- | --- |
| [`prompt/`](prompt/README.md) | the picture above: Claude Code's statusline, drawn by cship, under starship's prompt |
| [`terminal/kitty/`](terminal/kitty/README.md) | kitty, the terminal: with `shell/`, a text file `rg` or `eza` prints opens in Sublime Text when clicked, at rg's matching line |
| [`shell/`](shell/README.md) | zsh and readline: history searched by what you typed, and a `>` that refuses to overwrite |
| [`terminal/tmux/`](terminal/tmux/README.md) | tmux for ssh: the prefix on C-Space, the mouse, true colour |
| [`git/`](git/README.md) | git: pulls that rebase and diffs through delta; your name and email stay yours |
| [`editor/zed/`](editor/zed/README.md) | Zed on the JetBrains keymap, with lazygit and tasks |
| [`editor/sublime/`](editor/sublime/README.md) | Sublime Text, with Terminus, its terminal, to match |
| [`gh/`](gh/README.md) | the GitHub CLI: ssh, delta, no telemetry |
| [`macos/`](macos/README.md) | System Settings, among them the Dock, Finder, the trackpad and the clock |

The statusline's plan comes first, then its install. With
[cship](https://github.com/stephenleo/cship) 1.8.2 or newer, both first ask
whether to take `starship.toml` too and what to call your account; without
it, the dry run says how to get it, and the install stops before any write.

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.7/prompt/install.sh | bash -s -- --dry-run
```

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.7/prompt/install.sh | bash
```

## Take the setup

On a Mac without Homebrew, install it first from [brew.sh](https://brew.sh);
it brings the Command Line Tools `git clone` needs. The first block clones
this repository and prints bootstrap's plan, which asks nothing and writes
nothing; the second runs bootstrap and reads the result back.

```sh
git clone https://github.com/gati3478/preen ~/preen
cd ~/preen && ./bin/bootstrap --dry-run
```

```sh
./bin/bootstrap
./bin/preen doctor
```

bootstrap asks your name and email for git, then deploys every row of
`manifest.tsv`. [The setup's page](bin/README.md) says what it does with
what it finds in the way, what changes, and how to update and leave.

Beside the pieces, the repository holds these; [`taste/`](taste/README.md)
and [`bin/`](bin/README.md) each have a page of their own.

```
terminal/bat/      bat in the terminal's palette; the kitty and shell pieces copy it
terminal/ncdu/     ncdu in the terminal's palette; the shell piece copies it
ripgrep/           flags: hidden in, .git out, smart case, clickable matches; the shell piece copies it
ssh/               an Include for your own config, then the agent line; no hosts, taken only with the whole setup
bin/               bootstrap, and preen: apply and doctor
lib/               install.sh, the installers' shared half; shipped, the list that tells the setup's copies from yours
taste/             the author's preferences, as checks preen doctor --taste runs
manifest.tsv       a row per deployed file: its live path, link or copy, permissions where set
CHANGELOG.md       each release, and what its version number promises
LICENSE            MIT
```

## Make it yours

Fork or clone, keep `manifest.tsv`'s format and the two verbs, `preen apply`
and `preen doctor`, and replace the rows and directories with your own; the
doctor's checks probe the tools the author runs, so cut what is not yours.
An installer piped from your fork fetches from this release unless
`PREEN_SOURCE` names your fork's tree, as a URL or `file://`.

## Not here

These files are generated from a private repository, so open an issue rather
than a pull request; what cannot ship stays there, and nothing here needs it.

MIT.
