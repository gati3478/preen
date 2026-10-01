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
pieces share from this repository, the way it fetches the configs, and
nothing it installs points back here.

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
which zsh reads before any zshrc. To keep your own editor, set both in
`~/.zshenv.local`, read at the end of the zshenv, so that every zsh sees
them: `export EDITOR=… VISUAL=…`. Set in your zshrc, they reach interactive
shells only, not `zsh -c` or a script. An `EDITOR` set alone leaves `VISUAL`
ours, and ctrl+x ctrl+e, and git on a terminal, read `VISUAL` first.

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
  not `~/.zshenv` or `~/.zshrc`. A `ZDOTDIR` your `~/.zshenv` sets moves the
  zshrc: zsh then reads `$ZDOTDIR/.zshrc` and never `~/.zshrc`. One the
  system zshenv sets — `/etc/zshenv`, or `/etc/zsh/zshenv` on Debian and
  Ubuntu — moves both. zsh is asked as a non-login, non-interactive shell,
  so it does not see a `ZDOTDIR` set only in a login file or only for an
  interactive shell; and `ZDOTDIR` is unset for the question, so one
  exported before zsh starts is not followed either. Where yours is one of
  those, the lines belong in the files it names, by hand.

`~/.zprofile` is not taken. The shipped one is the author's login PATH — the
JetBrains Toolbox, SDKMAN, Playdate, Docker's and Antigravity's installer
lines, JDK 21 as `JAVA_HOME` — kept in that file because those installers
write `~/.zprofile` themselves; and on a Mac with Homebrew your own
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
- **bat**, for manual pages and fzf's preview. Its config is
  [`terminal/bat/`](../terminal/bat/).
- **zoxide** for `z`, **mise** for per-directory runtimes, and **Zed** as
  `$EDITOR` — nano without it.
- **ripgrep's config**, [`ripgrep/`](../ripgrep/) at
  `~/.config/ripgrep/config`: the zshenv points rg at that file when it is
  there.

The installer names each it did not find, and the release fzf and eza need.

## Install

No clone needed. To print the plan and stop, writing nothing — `bash -s --`
hands the flag to the script:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/shell/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/shell/install.sh | bash
```

Or from a clone of this repository, `./shell/install.sh`, with `--dry-run`
for the plan alone. It asks nothing — there is nothing to ask. The plan for an
empty home, on a Mac:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/zsh                              to hold this config's own directory, created
~/.config/zsh/preen                        this config's own directory, created
~/.config/zsh/preen/zshrc                  the interactive shell's config
~/.config/zsh/preen/zshenv                 what every zsh reads first: PATH, the editor
~/.config/zsh/preen/inputrc                readline's settings, for bash and the rest
~/.hushlogin                               silences login's Last login line — copied if absent
~/.config/atuin                            atuin's config directory, created
~/.config/atuin/config.toml                atuin's settings — copied if absent
~/.zshenv                                  created: source ~/.config/zsh/preen/zshenv
~/.inputrc                                 created: $include ~/.config/zsh/preen/inputrc
~/.zshrc                                   created: source ~/.config/zsh/preen/zshrc
```

A file of yours already there reads `one line appended: <line>` instead.

Where `/etc/inputrc` exists, as on most Linux systems, readline stops reading
it once `~/.inputrc` exists, so a new `~/.inputrc` includes it first:

```
~/.inputrc                                 created: $include /etc/inputrc, then $include ~/.config/zsh/preen/inputrc
```

It

1. asks zsh where it reads its zshenv and zshrc, and looks for the two
   plugins and each tool above, saying what it did not find. None of them
   stops it, and it runs none of them;
2. copies `zshrc`, `zshenv` and `inputrc` into `~/.config/zsh/preen/` —
   copies, never symlinks, each backed up beside itself as
   `<file>.unpreened.<timestamp>` if a different one was there, left
   untouched if identical;
3. copies `~/.hushlogin`, which is empty — its whole effect is to exist — and
   `~/.config/atuin/config.toml` only where nothing is there. A file already
   at either stays as it is: the run says `unchanged` when it holds this
   config's bytes, and `left alone` when it is anything else, a symlink
   included;
4. appends `source ~/.config/zsh/preen/zshenv` to the zshenv zsh reads,
   `$include ~/.config/zsh/preen/inputrc` to `~/.inputrc` and
   `source ~/.config/zsh/preen/zshrc` to the zshrc zsh reads, each once. Your
   files are not otherwise touched, and one you have not got becomes that
   line. The appends are last, so a run that stops earlier never leaves a line
   pointing at files that are not there.

A re-run with nothing changed rewrites nothing and takes no backup: the
copies come back `unchanged` and each line `already there`.

**Refusals**, all of them before the first write, so a stopped run has changed
nothing: `~/.config`, `~/.config/zsh` or `~/.config/zsh/preen` is a symlink,
dangling or not, or `~/.config/atuin` is one when atuin's config would be
copied into it, or a directory between `~` and the zshenv or zshrc zsh reads
is — the files would land in whatever it points at, which something else
manages; the zshrc, the zshenv or `~/.inputrc` is a symlink without its line —
the append would land in its target, so the line belongs there instead; one
of them lacks its line and cannot be read and appended to; `~/.config` is not a
directory, is not writable, or cannot be created, or another directory the run
writes into cannot be written; a zsh file would carry the appended line into
its last command — its last line ends in a backslash, or the last line that
is not blank or a comment ends in `&&`, `||` or a pipe — or ends inside a
here-document, or zsh cannot parse it; zsh names a `ZDOTDIR` that is not an
absolute path, or no answer at all; a source file that is missing, empty, or
not the file it claims to be.

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

The front page's
[What changes when you take the setup](../README.md#what-changes-when-you-take-the-setup)
lists the choices felt at once, each with its undo line. Its zsh rows hold
for this piece, with these exceptions:

- the `~/.zprofile` row does not apply: this piece leaves your `~/.zprofile`
  alone;
- nothing here reads a `~/.zprofile.local`, so the tmux row's undo,
  `unset SSH_CONNECTION`, goes above the appended line in your zshrc, before
  this config's tmux block runs.

Where an undo line goes in `~/.zshrc.local`, a line below the appended one
works as well.

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
3. For `~/.hushlogin` and `~/.config/atuin/config.toml`, read what the run
   said of each: `copied` means the run put it there, and it can go;
   `unchanged` or `left alone` means a file was already there, and the run
   never touched it. The shipped `~/.hushlogin` is empty, so an empty one of
   your own reads `unchanged`. Where the run said `created` of
   `~/.config/atuin`, that directory goes with its file.
4. `~/.zsh_history` holds what this config recorded, and
   `~/.zcompdump-<zsh version>` beside it is the completion cache this zshrc
   writes. A history file of yours by another name is where it was.

Took the whole repository through `bin/bootstrap`? Then your `~/.zshrc`,
`~/.zshenv` and `~/.inputrc` are links into your clone, which already carries
this config: the installer says so and writes nothing.

## License

MIT
