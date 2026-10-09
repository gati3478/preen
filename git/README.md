# git

The author's git config. `git pull` rebases, a stack of branches rebases as
one, and `git rebase -i` files `fixup!` commits under their targets; diffs
read through [delta](https://github.com/dandavison/delta), side by side with
line numbers; a conflict shows the common ancestor between its markers, and a
resolution made once is replayed; remotes prune themselves, and a first push
needs no `-u`. Take it alone: the installer fetches the installer library the
pieces share from this repository, the way it fetches the config, and nothing
it installs points back here.

## What it takes over

The installer appends one line to your git config:

```
[include] path = ~/.config/git/preen/gitconfig
```

It goes in the file `git config --global` writes to: `~/.gitconfig` when it
is there, else `~/.config/git/config` when only that is; with neither, a new
`~/.gitconfig` holds it alone. git reads `~/.config/git/config` first, then
`~/.gitconfig`, so that file is also the last git reads. The run says which,
and why.

The line reads a whole config in place, so it wins over every line above it
that sets the same key, in your file or in a `~/.config/git/config` read
before it. A line below it wins over it. Your name and email are not asked
for, and nothing here writes them: the copy sets neither.

- **A symlinked git config** — stow's layout, a dotfiles repository's — is
  refused, with the line to add in the file it points at; once that file
  holds it, a re-run says `already there`.
- **`GIT_CONFIG_GLOBAL`**, set at all, is refused: git then reads that one
  file in place of both of its own — none, set empty — and a line in either
  is not read.
- **`XDG_CONFIG_HOME`** naming a directory other than `~/.config` is refused:
  git then reads its config and its ignore under it, and the run knows only
  `~/.config/git`.
- **`~/.config/git/ignore`**, git's global ignore, is copied only where
  nothing is there. A `core.excludesFile` of yours names another file in its
  place, and git then reads that one alone.

## What you need

**Required**

- **git**, measured with 2.43.0 on Ubuntu 24.04, and 2.54.0 (Apple's) and
  2.56.0 on macOS. Not found — or found as macOS's `/usr/bin/git` stub, which
  asks to install the developer tools when run — the installer says so and
  installs anyway; git reads the file once it is there. Without git — or
  with one whose read fails, which the run names in git's words — the run
  cannot ask git to read your file, so it checks only that the file's last
  line does not end in a backslash, and does not read what
  `~/.gitconfig.local` includes.

**Optional**

- **delta**, the pager this config names for `git log`, `git diff` and
  `git show`, and for `git add -p`'s hunks. Without it the pager falls back
  to `less`, else `cat`, and `git add -p` shows git's own colours.
- **git-lfs.** The config declares LFS's filter and marks it required, for a
  machine where git-lfs is installed. Without git-lfs, in a repository whose
  `.gitattributes` routes files through LFS, `git add` of those files fails,
  and so does a clone's checkout of them, while with no config git takes
  those files as they are (measured on 2.43.0 and 2.56.0).
  [What changes](#what-changes) has the lines that turn the filter off.

The installer names each it did not find.

## Install

No clone needed. To print the plan and stop, writing nothing — `bash -s --`
hands the flag to the script:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/git/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/git/install.sh | bash
```

Or from a clone of this repository, `./git/install.sh`, with `--dry-run` for
the plan alone. It asks nothing — there is nothing to ask. The plan for an
empty home:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/git                              git's config directory, created
~/.config/git/preen                        this config's own directory, created
~/.config/git/preen/gitconfig              the config
~/.config/git/ignore                       the global ignore — copied if absent
~/.gitconfig                               created: [include] path = ~/.config/git/preen/gitconfig
```

A file of yours without the line reads `one line appended: <line>` instead.

It

1. looks for git, delta, less and git-lfs. None of them stops it; it runs git
   only to ask its version and to read config files, each read deaf to every
   other config, never to write one;
2. copies `gitconfig` into `~/.config/git/preen/` — a copy, never a symlink,
   backed up beside itself as `gitconfig.unpreened.<timestamp>` if a
   different one was there, left untouched if identical;
3. copies `ignore` to `~/.config/git/ignore` where nothing is there. A file
   already there stays, with no backup, because nothing is replaced: the run
   says `unchanged` when it holds this config's bytes, and `left alone` when
   it is anything else, a symlink included;
4. appends `[include] path = ~/.config/git/preen/gitconfig` to the file named
   above, once. Your file is not otherwise touched, and with none it becomes
   that line. The append is last, so a run that stops earlier never leaves
   the line pointing at a file that is not there.

A re-run with nothing changed rewrites nothing and takes no backup: the copy
comes back `unchanged` and the line `already there`.

**Refusals**, all of them before the first write, so a stopped run has changed
nothing: `GIT_CONFIG_GLOBAL` is set, empty included; `XDG_CONFIG_HOME` names a
directory other than `~/.config`; `~/.config`, `~/.config/git` or
`~/.config/git/preen` is a symlink, dangling or not — the copy would land in
whatever it points at, which something else manages; `~/.config` is not a
directory, is not writable, or cannot be created, or `~/.config/git` or
`preen/` cannot be written into; the file the line goes in is a symlink
without the line — the append would land in its target, so the line belongs
there instead; that file lacks the line and cannot be read and appended to,
or its `.lock`, which git holds while it rewrites the file, is there;
`~/.gitconfig.local` is, or links to, that file or the copy, or is not a file,
or, where git can be asked, includes either — read one include deep — or is
one git cannot read;
where git can be asked, git cannot read the file the line goes in, or would
not read the appended line as a line of its own — after a value ending in a
backslash, say; where it cannot, that file's last line ends in a backslash; a
source file that is missing, empty, or not the file it claims to be.

git's read runs nothing in the file: `git config -f <file> --no-includes
--list`, with no system or global config, so one of yours that git cannot
read does not stop the run's own read.

## Your overrides

A line of yours below the appended line wins over this config, and so does
`~/.gitconfig.local`, which the copy includes at its end —
`git config -f ~/.gitconfig.local pull.rebase false` writes there. A line
above the appended line loses, for every key the copy sets, and so does a
line in a `~/.config/git/config` git reads before the file holding it.

`git config --global` does not always write below the line. Given a key
whose section is already in your file above the line — a `[pull]` you had
before, say — git adds it to that section, and the copy still wins:
measured, `git config --global pull.rebase false` into an existing `[pull]`
left `git config --get pull.rebase` at the copy's `true`. A key whose section
is not there yet goes in a new section at the end, below the line, and wins.
`git config --show-origin --get <key>` names the file a value comes from.

Never put the appended line in `~/.gitconfig.local`: the copy includes that
file, so the two would include each other in a circle, and git then stops
every command, `git --version` included, with
`exceeded maximum include depth` (measured). Where git can be asked, the
installer refuses a `~/.gitconfig.local` that includes the file the line goes
in or the copy.

## What changes

The choices felt at once, each with the lines that turn it off, for
`~/.gitconfig.local` or below the appended line. git reads the copy's value
and then yours, so a key the copy sets can be set again but not unset: the
pager's undo names `less`, git's default with no `PAGER` set, and a pager
your `PAGER` names goes there in its place.

| What you notice | Undo |
| --- | --- |
| `git pull` rebases your local commits onto the ones it fetched, instead of merging them | `[pull]`<br>`rebase = false` |
| `git log`, `git diff` and `git show` page through delta where it is installed, side by side with line numbers, and `git add -p` shows its hunks through it, in place of the pager your `PAGER` names | `[core]`<br>`pager = less`<br>`[interactive]`<br>`diffFilter = cat` |
| a commit takes CRLF line endings in as LF (`core.autocrlf input`) | `[core]`<br>`autocrlf = false` |
| rebasing a branch moves the other branches that point at commits it rewrites (`rebase.updateRefs`) | `[rebase]`<br>`updateRefs = false` |
| without git-lfs, in a repository whose `.gitattributes` routes files through LFS, `git add` of those files and a clone's checkout of them fail | `[filter "lfs"]`<br>`process =`<br>`required = false` |

The LFS lines are for a machine without git-lfs: delete them once it is
installed, or the filter stays off.

The rest are quieter — `fetch.prune`, `fetch.followRemoteHEAD`,
`push.autoSetupRemote`,
`rerere.enabled`, `rebase.autosquash`, `diff.algorithm`,
`merge.conflictstyle`, `init.defaultBranch`, `core.untrackedCache` and
delta's own options — and each is set back the same way, by its key below
the line or in `~/.gitconfig.local`.

## Leaving

1. Delete the appended line, `[include] path = ~/.config/git/preen/gitconfig`,
   from the file the run named, `~/.gitconfig` or `~/.config/git/config`.
   Where that line is all the file holds, delete the file.
2. Delete `~/.config/git/preen/`.
3. For `~/.config/git/ignore`, read what the run said: `copied` or
   `unchanged` means the file held this config's bytes and can go;
   `left alone` means something else was there, and the run never touched
   it.
4. `~/.gitconfig.local` is yours. Once the line is gone, nothing of this
   config includes it: move what it holds into your own file, or include it
   from there.

A backup the run took sits in `~/.config/git/preen/` beside the copy, as
`gitconfig.unpreened.<timestamp>`: the copy as it was before a later run
replaced it, your edits to it included. Keep it before you delete that
directory, if you want those edits.

Took the whole repository through `bin/bootstrap`? Then `~/.gitconfig` is a
link into your clone, which already carries this config: the installer says
so and writes nothing.

## License

MIT
