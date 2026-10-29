# gh

The author's [GitHub CLI](https://cli.github.com) config, which follows the
choices the git config made: gh's git operations use SSH, its paged
output reads through [delta](https://github.com/dandavison/delta) like
`git diff`, its colours are the terminal's own sixteen, and it sends no
telemetry. Take it alone: the installer fetches the installer library the
pieces share from this repository, and nothing it installs points back here.

## What it takes over

The installer sets each key this directory's `config.yml` gives a value to
in your `~/.config/gh/config.yml`, through `gh config set` — gh's own writer,
which rewrites that key's line and keeps your aliases, every other key, known
to gh or not, and the file's mode, in gh's own layout: it drops your blank
lines and indentation, and can drop a comment; a backup beside your file
keeps it as it was. With no `config.yml`, gh first writes its own commented
defaults, its `co` alias among them. A key left blank here —
`editor`, `browser`, `http_unix_socket` — is not set, so a value of yours
stays; `version` and `aliases` are not set either.

`~/.config/gh/hosts.yml`, which holds your login, is never written.

- **A symlinked `config.yml`** — stow's layout, a dotfiles repository's — is
  refused where a key differs, with the keys to set in the file it points at:
  gh would write through the link. Once that file holds them, a re-run says
  each is `already` set.
- **`GH_CONFIG_DIR`** naming a directory other than `~/.config/gh`, or with
  it unset **`XDG_CONFIG_HOME`** naming one other than `~/.config`, is
  refused: gh then reads its config there, and the run knows only
  `~/.config/gh`.

## What you need

**Required**

- **gh**, measured with 2.102.0 on macOS and Ubuntu 24.04. Not found, a
  real run stops before any write; `--dry-run` prints the keys without it.

**Optional**

- **delta**, the pager this config names. Without it, a paged gh command says
  it failed to start the pager and prints its output unpaged.

The installer names each it did not find.

## Install

The plan, writing nothing:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.5/gh/install.sh | bash -s -- --dry-run
```

To install:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/v2.2.5/gh/install.sh | bash
```

Or from a clone, `./gh/install.sh`. It asks nothing. The plan for an empty
home:

```
== will touch ==
~/.config                                  the directory configs live under, created by gh
~/.config/gh                               gh's config directory, created by gh
~/.config/gh/config.yml                    gh's own defaults, then each differing key below set
```

A `config.yml` of yours reads `backed up, then each differing key below set`
instead. Below the plan, each key: the value gh reads now, then this
config's, or `already` where the two agree.

It

1. looks for gh and delta, and runs gh only as `gh --version`,
   `gh config get` and `gh config set`, each with telemetry off;
2. copies your `config.yml`, if there is one, to
   `config.yml.unpreened.<timestamp>` beside it;
3. sets each key that differs, saying each as it goes.

A run that finds every key already set writes nothing and takes no backup.
If gh fails part-way, the run stops with gh's words and names the backup.

Every refusal comes before the first write, and a dry run makes each one but
a missing gh; among them those under What it takes over, a symlinked
`~/.config` or `~/.config/gh`, a directory the run cannot write, a
`config.yml` it cannot write where a key differs, and a `config.yml` or
`hosts.yml` gh cannot read — bad YAML, say — in gh's own words.

## Updating

Run the install line from this page again: it names the newest release.
From a clone, `git pull`, then `./gh/install.sh`. gh reads one file and has
no overlay, so a re-run sets back each key that differs, an undo of yours
included, after backing up `config.yml`.

## Your overrides

A key you set after the run — `gh config set pager less` — wins until the
next run, which sets it back, after a backup.

gh reads `git_protocol` per host from `hosts.yml` first, so one there wins
over this file's for that host. `gh config get -h github.com git_protocol`
prints the one in force.

## What changes

Each undo is one command. A blank `pager` is gh's default, which gh's own
comment on it says refers to the environment.

| What you notice | Undo |
| --- | --- |
| gh's git operations — `gh repo clone`, say — use SSH, not HTTPS (`git_protocol`) | `gh config set git_protocol https` |
| gh's paged output — `gh pr diff`, say — goes through delta (`pager`) | `gh config set pager ''` |
| gh colours with the terminal's sixteen, so its output follows the terminal's palette (`accessible_colors`) | `gh config set accessible_colors disabled` |
| gh sends no telemetry (`telemetry`) | `gh config set telemetry enabled` |

The rest — `prompt`, `prefer_editor_prompt`, `color_labels`,
`accessible_prompter` and `spinner` — hold gh 2.102.0's own defaults, set so
a config of yours that changed one returns to them.

## Leaving

Set each key back with its undo above, or move the backup over the file:
`config.yml.unpreened.<timestamp>` is `config.yml` as it was before the run,
so a key you set since is lost that way. Where the run found no
`config.yml`, delete the one gh wrote: gh reads its defaults without one.

## License

MIT
