# shell · zsh and readline

The author's interactive zsh, and readline's rc beside it. Up and Down
search history by what you have typed; `>` refuses to overwrite a file
(`>|` does); every open shell shares one long, deduplicated history;
completion is a menu that ignores case; the keymap is emacs whatever
`$EDITOR` says. Where they are installed, starship draws the prompt, fzf
finds files and directories, atuin answers ctrl+r from a history that knows
where each command ran and whether it worked, and zsh-syntax-highlighting
and zsh-autosuggestions colour and complete the line as you type. Readline —
bash, and the other programs built on it — gets the same quiet, case-blind
completion. Take it alone: the installer fetches the installer library the
pieces share from this repository, and nothing it installs points back here.

## What it takes over

The installer appends one line to your zshrc, and that line sources a whole
zshrc. Read last, it wins over every line above it in your file that sets the
same thing: the prompt (starship, where installed); the keymap — it declares
emacs, so a vi-mode user, oh-my-zsh's vi-mode plugin included, is back in
emacs mode; the aliases it defines (`ls`, `ll` and `lt` become eza, where
installed); the history file, `~/.zsh_history`, so entries in another file are
no longer read; `SDKMAN_DIR`, the completion styles and the shell options.
Your PATH entries stay. A line below it runs after it and wins — which is
where installers append: a `mise activate` added there puts back the prompt
hook this zshrc removes.

`EDITOR` and `VISUAL` are not among them: both come from the zshenv line,
which zsh reads before any zshrc. To keep your own editor, set both,
`export EDITOR=… VISUAL=…`, in `~/.zshenv.local`, read at the end of the
zshenv: every zsh sees them there, where from a zshrc only an interactive
one would. An `EDITOR` set alone leaves `VISUAL` ours, which ctrl+x ctrl+e,
and git on a terminal, read first.

- **oh-my-zsh** keeps working: nothing errors, `compinit` runs twice and
  leaves two dump files, a zsh-syntax-highlighting or zsh-autosuggestions
  loaded as an oh-my-zsh plugin is loaded again without doubling its hooks,
  and starship, where installed, replaces the oh-my-zsh theme.
- **powerlevel10k** with its instant prompt keeps its prompt. During its
  start the shell's output is not a terminal, so the fzf and atuin key
  bindings, which this zshrc sets up only on a terminal, are not bound. Over
  ssh, where tmux will not start, the line this zshrc prints about it trips
  p10k's warning about console output.
- **A symlinked `.zshrc`** — prezto's layout, stow's — is refused, with the
  line to add in the file it points at; once that file holds it, a re-run
  says `already there`.
- **`ZDOTDIR`**: zsh is asked where it reads its zshenv and its zshrc, and
  each line goes to the file it names; the run says which, and why when it is
  not `~/.zshenv` or `~/.zshrc`. zsh is asked as a non-login, non-interactive
  shell with `ZDOTDIR` unset, so a `ZDOTDIR` exported before zsh starts, or
  set only in a login file or for an interactive shell, is not followed:
  there the lines belong in the files it names, by hand.

`~/.zprofile` is not taken. The shipped one is the author's login PATH — the
JetBrains Toolbox, SDKMAN, Playdate and Antigravity installer lines, JDK 21
as `JAVA_HOME` — kept in that file because those installers write
`~/.zprofile` themselves; and on a Mac with Homebrew your own
`~/.zprofile` already runs `brew shellenv`, as Homebrew's installer asks.

## What you need

**Required**

- **zsh**, as your shell. Not found, the installer says so and installs
  anyway; the files are read when zsh starts.

**Optional** — each block of the zshrc is guarded on its tool, so a missing
one costs only what it does:

- **zsh-syntax-highlighting** and **zsh-autosuggestions**, from Homebrew
  (`$HOMEBREW_PREFIX/share`); the highlighter also from a clone at
  `~/.zsh/zsh-syntax-highlighting`, the form a machine without root uses. The
  zshrc looks nowhere else, so a Linux package's copy under `/usr/share` is
  not read. Without them the line is not coloured as you type, and no
  suggestion is drawn ahead of the cursor.
- **starship**, for the prompt; without it the prompt stays the one your own
  lines set. Its config is the [statusline piece](../prompt/README.md)'s
  `starship.toml`, taken there.
- **fzf**, for ctrl+t, alt+c and `**<TAB>`, recent enough for `fzf --zsh`;
  **fd**, which fzf walks with so that `.gitignore` is read.
- **atuin**, for ctrl+r; without it ctrl+r is fzf's, else zsh's own.
- **eza**, for `ls`, `ll` and `lt`, recent enough for `--hyperlink=auto`;
  without it they stay what they were.
- **bat**, for manual pages and fzf's preview.
- **zoxide** for `z`, **mise** for per-directory runtimes, and **Sublime
  Text** as `$EDITOR`, `subl -w` — nano without it.

The installer names each it did not find, and the release fzf and eza need.

## Install

The plan, writing nothing:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.4/shell/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.4/shell/install.sh | bash
```

Or from a clone, `./shell/install.sh`. It asks nothing. The plan for an
empty home, on a Mac:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/zsh                              to hold this config's own directory, created
~/.config/zsh/preen                        this config's own directory, created
~/.config/zsh/preen/zshrc                  the interactive shell's config — copied
~/.config/zsh/preen/zshenv                 what every zsh reads first: PATH, the editor — copied
~/.config/zsh/preen/inputrc                readline's settings, for bash and the rest — copied
~/.hushlogin                               silences login's Last login line — copied
~/.config/atuin                            atuin's config directory, created
~/.config/atuin/config.toml                atuin's settings — copied
~/.config/bat                              bat's config directory, created
~/.config/bat/config                       bat's theme: the terminal's palette — copied
~/.config/ripgrep                          ripgrep's config directory, created
~/.config/ripgrep/config                   rg's flags: hidden files, smart case — copied
~/.config/ncdu                             ncdu's config directory, created
~/.config/ncdu/config                      ncdu's colours: the terminal's palette — copied
~/.zshenv                                  created: source ~/.config/zsh/preen/zshenv
~/.inputrc                                 created: $include ~/.config/zsh/preen/inputrc
~/.zshrc                                   created: source ~/.config/zsh/preen/zshrc
```

Each line says what this run does to your home. A file of yours reads
`backed up, then replaced` in `preen/` and `left alone (yours)` at the paths
copied only where none is there; an earlier copy reads
`updated (an earlier copy)`; and a file of yours without its line reads
`one line appended: <line>`.

Where `/etc/inputrc` exists, as on most Linux systems, readline stops reading
it once `~/.inputrc` exists, so a new `~/.inputrc` includes it first:

```
~/.inputrc                                 created: $include /etc/inputrc, then $include ~/.config/zsh/preen/inputrc
```

It

1. asks zsh where it reads its zshenv and zshrc, and looks for the two
   plugins and each tool above, saying what it did not find; none of them
   stops it, and it runs none of them;
2. copies `zshrc`, `zshenv` and `inputrc` into `~/.config/zsh/preen/`, a
   different file there first backed up beside itself as
   `<file>.unpreened.<timestamp>`, an earlier copy this setup shipped
   replaced without one;
3. copies `~/.hushlogin`, empty, and the configs of atuin, bat (from
   [`terminal/bat/`](../terminal/bat/)), ncdu (from
   [`terminal/ncdu/`](../terminal/ncdu/)) and ripgrep (from
   [`ripgrep/`](../ripgrep/)), each only where nothing is there or an
   earlier copy this setup shipped is; anything else stays, said `unchanged`
   or `left alone`. ripgrep's is not copied while `RIPGREP_CONFIG_PATH`
   names another file, and the plan says so;
4. appends `source ~/.config/zsh/preen/zshenv` to the zshenv zsh reads,
   `$include ~/.config/zsh/preen/inputrc` to `~/.inputrc` and
   `source ~/.config/zsh/preen/zshrc` to the zshrc zsh reads, each once.
   Nothing else in your files changes, but a last line with no newline gets
   one. The appends are last, so a run that stops earlier leaves no line
   pointing at nothing.

A re-run with nothing changed rewrites nothing and takes no backup.

Every refusal comes before the first write, and a dry run makes each one.
Among them, a symlinked directory the files go in is refused, since they
would land wherever it points, and so is a symlinked zshrc, zshenv or
`~/.inputrc` without its line. So is a zsh file the appended line would join
to its last command — a last line ending in a backslash, a last command
ending in `&&`, `||` or a pipe, an open here-document — or one zsh cannot
parse.

## Updating

Run the install line from this page again: it names the newest release.
From a clone, `git pull`, then `./shell/install.sh`. An earlier copy this
setup shipped comes back `updated`, with no backup. One you edited is not: a
copy in `~/.config/zsh/preen/` is backed up beside itself first, and
`~/.hushlogin` or a tool's config is left alone. A line of yours belongs
below an appended line, or in `~/.zshrc.local` or `~/.zshenv.local` (Your
overrides).

## Your overrides

A line of yours below the appended line runs after this config and wins.
Two files the copies read are yours too, and nothing here writes them.
`~/.zshrc.local`, read at the end of the zshrc, just before the highlighter,
wins over the zshrc. `~/.zshenv.local`, read at the end of the zshenv, wins
over the zshenv but not over a zshrc, which zsh reads after it: a setting
both make, `HISTFILE` say, is the zshrc's. If your own files already source a
file by either name, it now runs twice.

For readline, a line below the `$include` in `~/.inputrc` wins.

## What changes

The choices felt at once, each with the lines that undo it, for
`~/.zshrc.local` or below the appended line where its row names no other
place.

| What you notice | Undo |
| --- | --- |
| `>` refuses to overwrite a file; `>\|` does (`NO_CLOBBER`) | `unsetopt NO_CLOBBER` |
| a mistyped command is offered a correction (`CORRECT`) | `unsetopt CORRECT` |
| `*` matches dotfiles (`GLOB_DOTS`) | `unsetopt GLOB_DOTS` |
| word motion stops at every character but a letter or digit (`WORDCHARS=''`) | zsh's default, `WORDCHARS='*?_-.[]~=/&;!#$%^(){}<>'` |
| Up and Down search history by what is typed before the cursor | `bindkey '^[[A' up-line-or-history`<br>`bindkey '^[[B' down-line-or-history`<br>`bindkey '^[OA' up-line-or-history`<br>`bindkey '^[OB' down-line-or-history` |
| where eza is installed, `ls` is eza, whose flags are not all ls's: `ls -ltr` is an error | `unalias ls` |
| `$EDITOR` is `subl -w`, Sublime Text, where the zshenv finds `subl` — on PATH, in Homebrew's bin or `/usr/local/bin` — else nano, and always nano over ssh | `export EDITOR=… VISUAL=…` in `~/.zshenv.local` |
| over ssh, where tmux is installed, a shell attaches to the tmux session `remote`, and leaving tmux ends the login | `unset SSH_CONNECTION` above the appended line in your zshrc, since this config's tmux block runs before `~/.zshrc.local` is read; tools that read it then see no ssh session |
| where rg reads the ripgrep config this piece ships, it searches hidden files but never `.git`, and ignores case until the pattern holds a capital | `unset RIPGREP_CONFIG_PATH` in `~/.zshenv.local` |

## Leaving

1. Delete the appended lines: `source ~/.config/zsh/preen/zshrc` from the
   zshrc the run named, `~/.zshrc` or `$ZDOTDIR/.zshrc`;
   `source ~/.config/zsh/preen/zshenv` from the zshenv it named, `~/.zshenv`
   or `$ZDOTDIR/.zshenv`; and `$include ~/.config/zsh/preen/inputrc` from
   `~/.inputrc`. Where that line is all a file holds — or, in an `~/.inputrc`
   the run created, that line and `/etc/inputrc`'s include — delete the file
   instead.
2. Delete `~/.config/zsh/preen/`, and `~/.config/zsh` with it where nothing
   else is in it.
3. For `~/.hushlogin` and atuin's, bat's, ripgrep's and ncdu's configs, read
   what the run said of each: `copied`, `updated` or `unchanged` means the
   file holds what this setup shipped, so it can go unless you had it before
   the first run: the shipped `~/.hushlogin` is empty, so an empty one of
   your own reads `unchanged` too. `left alone` means the run did not write
   it. A `--dry-run` says which is which now: `an earlier copy` is this
   setup's. A directory the run `created` goes with its file; the kitty
   piece copies bat's config too, so keep it while you keep that piece.
4. `~/.zsh_history` holds what this config recorded, and
   `~/.zcompdump-<zsh version>` beside it is the completion cache this zshrc
   writes. A history file of yours by another name is where it was.

## License

MIT
