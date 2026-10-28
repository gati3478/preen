# git

The author's git config. `git pull` rebases, a stack of branches rebases as
one, and `git rebase -i` files `fixup!` commits under their targets; diffs
read through [delta](https://github.com/dandavison/delta), side by side with
line numbers; a conflict shows the common ancestor between its markers, and a
resolution made once is replayed; remotes prune themselves, and a first push
needs no `-u`. Take it alone: the installer fetches the installer library the
pieces share from this repository, and nothing it installs points back here.

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
  nothing is there, or an earlier copy this setup shipped is. A
  `core.excludesFile` of yours names another file in its place, and git then
  reads that one alone.

## What you need

**Required**

- **git**, measured with 2.43.0 on Ubuntu 24.04, and 2.54.0 (Apple's) and
  2.56.0 on macOS. Not found — or found as macOS's `/usr/bin/git` stub,
  which asks to install the developer tools when run — the installer says so
  and installs anyway. Without git, or with one whose read cannot run, the
  run checks only that your file's last line does not end in a backslash.

**Optional**

- **delta**, the pager this config names for `git log`, `git diff` and
  `git show`, and for `git add -p`'s hunks. Without it the pager falls back
  to `less`, else `cat`, and `git add -p` shows git's own colours.
- **git-lfs.** The config declares LFS's filter and marks it required, for a
  machine where git-lfs is installed. Without git-lfs, in a repository whose
  `.gitattributes` routes files through LFS, `git add` of those files fails,
  and so does a clone's checkout of them, where with no config git takes
  them as they are. [What changes](#what-changes) has the lines that turn the
  filter off.

The installer names each it did not find.

## Install

The plan, writing nothing:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.3/git/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.3/git/install.sh | bash
```

Or from a clone, `./git/install.sh`. It asks nothing. The plan for an empty
home:

```
== will touch ==
~/.config                                  the directory configs live under, created
~/.config/git                              git's config directory, created
~/.config/git/preen                        this config's own directory, created
~/.config/git/preen/gitconfig              the config — copied
~/.config/git/ignore                       the global ignore — copied
~/.gitconfig                               created: [include] path = ~/.config/git/preen/gitconfig
```

Each line says what this run does to your home. An ignore of yours reads
`left alone (yours)`, an earlier copy `updated (an earlier copy)`, and a file
of yours without the line `one line appended: <line>`.

It

1. looks for git, delta, less and git-lfs. None of them stops it; it runs git
   to ask its version and to read config files, each read deaf to every
   other config, never to write one;
2. copies `gitconfig` into `~/.config/git/preen/`, a different file there
   first backed up beside itself as `gitconfig.unpreened.<timestamp>`, an
   earlier copy this setup shipped replaced without one;
3. copies `ignore` to `~/.config/git/ignore` only where nothing is there or
   an earlier copy this setup shipped is; anything else stays, said
   `unchanged` or `left alone`;
4. appends `[include] path = ~/.config/git/preen/gitconfig` to the file named
   above, once. Nothing else in your file changes, but a last line with no
   newline gets one. The append is last, so a run that stops earlier leaves
   no line pointing at nothing.

A re-run with nothing changed rewrites nothing and takes no backup.

Every refusal comes before the first write, and a dry run makes each one.
Among them, beside those under What it takes over, a symlinked `~/.config`,
`~/.config/git` or `preen/` is refused, since the copy would land wherever
it points, as is one the run cannot write into or create; so is a file the
line goes in that the run cannot read and append to, one git is rewriting,
its `.lock` there, or one git would not read the appended line from as a
line of its own, after a value ending in a backslash, say; and a
`~/.gitconfig.local` that is or links to that file or the copy, or, where
git can be asked, includes one. git's read runs nothing in the file:
`git config -f <file> --no-includes --list`, with no system or global
config.

## Updating

Run the install line from this page again: it names the newest release.
From a clone, `git pull`, then `./git/install.sh`. An earlier copy this setup
shipped comes back `updated`, with no backup. One you edited is not: the copy
in `~/.config/git/preen/` is backed up beside itself first, and
`~/.config/git/ignore` is left alone. A line of yours belongs in
`~/.gitconfig.local`, or below the appended line (Your overrides).

## Your overrides

A line of yours below the appended line wins over this config, and so does
`~/.gitconfig.local`, which the copy includes at its end —
`git config -f ~/.gitconfig.local pull.rebase false` writes there. A line
above the appended line loses, for every key the copy sets, and so does a
line in a `~/.config/git/config` git reads before the file holding it.

`git config --global` does not always write below the line. Given a key
whose section is already in your file above the line — a `[pull]` you had
before, say — git adds it to that section, and the copy still wins:
`git config --global pull.rebase false` into an existing `[pull]` leaves
`git config --get pull.rebase` at the copy's `true`. A key whose section is
not there yet goes in a new section at the end, below the line, and wins.
`git config --show-origin --get <key>` names the file a value comes from.

Never put the appended line in `~/.gitconfig.local`: the two would include
each other, and git then stops every command, `git --version` included, with
`exceeded maximum include depth`. Where git can be asked, the installer
refuses such a file.

## What changes

The choices felt at once, each with the lines that turn it off, for
`~/.gitconfig.local` or below the appended line. git reads the copy's value
and then yours, so a key the copy sets can be set again but not unset: the
pager's undo names `less`, git's default with no `PAGER` set, and a pager
your `PAGER` names goes there in its place.

| What you notice | Undo |
| --- | --- |
| `git pull` rebases your local commits onto the ones it fetched, instead of merging them, and refuses while the working tree has local edits | `[pull]`<br>`rebase = false` |
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
3. For `~/.config/git/ignore`, read what the run said: `copied`, `updated`
   or `unchanged` means the file holds what this setup shipped, so it can go
   unless you had it before the first run; `left alone` means the run did
   not write it. A `--dry-run` says which is which now: `an earlier copy` is
   this setup's.
4. `~/.gitconfig.local` is yours. Once the line is gone, nothing of this
   config includes it: move what it holds into your own file, or include it
   from there.

A backup the run took sits in `~/.config/git/preen/` beside the copy, as
`gitconfig.unpreened.<timestamp>`, your edits included: keep it before you
delete that directory, if you want them.

## License

MIT
