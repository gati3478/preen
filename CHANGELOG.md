# Changelog

Each release is a tag, and the install lines on the pages at that tag fetch
from it. A major release moves where or how a file lands, or drops a flag; a
minor one adds a piece, a row, a flag or a check; a patch changes values,
fixes and docs.

## v2.2.0

`taste/pref-check.py` fails a zsh `setopt` or `unsetopt` row matched with
`want_contains`, `want_all_contain` or `want_any_contain`, saying why: a
negated option holds its name, as `NO_GLOB_DOTS` holds `GLOB_DOTS`, so a
row wanting `GLOB_DOTS` passed a file that says `setopt NO_GLOB_DOTS`. Match
such a row with `want_any` or `want_absent` instead.

`preen doctor`, `--taste` included, colours ok, FAIL and warn only on a
terminal; piped or logged, it prints the bare words. `preen apply` refuses
to run from a linked git worktree, whose links would dangle once the
worktree went: run it from the main checkout.

The tmux piece parses your file on a server whose socket sits under
`TMPDIR`, not `/tmp` alone. It uses `/tmp` when `TMPDIR` is unset, when the
socket's path under `TMPDIR` would pass 103 bytes, the longest that starts a
server on macOS, or when no server starts under `TMPDIR`.

The pieces' pages are shorter. Only the setup's page, `bin/README.md`, now
says what the kitty, shell, tmux, git, Zed and Sublime Text installers do
after `bin/bootstrap`: find their files linked into the clone, say so and
write nothing. `prompt/cship.toml`'s comments drop the measurements behind
its widths; no setting changed.

## v2.1.0

Zed's editor text takes Fira Code's dotted zero and oldstyle figures, as
kitty's does: `buffer_font_features` names `zero` and `onum` beside `calt`,
and `taste/` checks all three in Zed, where it had recorded the figures as
out of reach. Fira Code's own zero is slashed and its `zero` feature dots
it, so the pages say dotted where they said slashed; kitty, which sets the
feature, has drawn a dotted zero all along.

Zed's terminal takes the same three. With no `terminal.font_features`, Zed
turns its terminal's ligatures off, so it drew none, with a slashed zero and
lining figures; `taste/` checks all three there too.

`dlig` leaves Zed's and Sublime Text's settings: Fira Code has no such
feature, so neither drew a discretionary ligature, and their pages no longer
claim one.

## v2.0.0

The author's preferences, as checks, move to `taste/`, with a page of their
own: `preferences.toml` from the top level, and `pref-check.py`,
`pref-check.sh` and `zcap.sh` from `bin/lib/`, which is gone. Taking one
piece never needed them, and `preen doctor --taste` finds them in the new
place; a script of yours that named the old paths needs the new ones.

The README is a table of the pieces, each linked to its page, which gives
its install line; the statusline's stays on the README too. What bootstrap
does and finds in the way, the doctor, how `manifest.tsv` drives install
and check, what changes under the
whole setup, updating and leaving move to `bin/README.md`. There, What
changes adds the starship prompt, and Leaving now recreates a symlink of
yours a run replaced and keeps what an application wrote to a copied file.
Each piece's page stands alone: kitty's gains What changes,
the shell's lists its own, and each Leaving reads a file the run called
`unchanged` as the setup's bytes, which can go unless the file was yours
before. The statusline's Leaving deletes the `settings.json` backup, older
than what Claude Code wrote since, rather than moving it back, and removes
a `cship.toml` or `starship.toml` the run copied where you had none. Notes
for a setup taken before v1.0.0 leave the pages;
[v1.3.0's README](https://github.com/gati3478/preen/blob/v1.3.0/README.md)
keeps them.

A dry run's plan says what the run will do to your home, from the decision
the run acts on: `copied`, `unchanged`, `updated (an earlier copy)`,
`backed up, then replaced`, or `left alone` with the reason, as in
`left alone (yours)`, where the plan used to state the rule, "copied if
absent or an earlier copy". kitty's plan also names each setting of yours
above the include line that this config makes again, and so overrides. An
include of kitty's config spelled another way, `./preen/kitty.conf` or the
full path, is now the line already there, where the kitty piece used to
append a second one that kitty names a bad line at every launch. The statusline's plan says what becomes of
`~/.claude/settings.json`, also where Claude Code is not installed yet, and
its dry run stops, as a real run does, on a `cship.toml` source it cannot
tailor. The kitty and shell pieces and `bin/bootstrap` look for a tool where
the shell piece's zshenv puts one, `~/.local/bin`, `/opt/homebrew/bin` and
`/usr/local/bin`, as well as on PATH, so `$EDITOR` and a click's editor are
named as they will be found. The kitty piece's own `tab-title.conf`, written
for another home, now reads `updated`.

The comments in `terminal/kitty/kitty.conf`, `shell/`'s zshenv and inputrc,
`prompt/starship.toml` and `editor/zed/settings.json` keep each line's
reason and drop the measurements behind it; no setting changed.

## v1.3.0

`preen doctor` gains a reader, `lsopen`, that asks LaunchServices for a
content type's default app, whether a handler-table entry pins the type or
LaunchServices ranks the app first. A reader that asks git, gh, ssh or
osascript fails its own row when the tool hangs past its timeout; a hang in
git, gh or ssh used to crash the preference checks and lose every row after
it.

## v1.2.0

A file clicked in kitty opens in Sublime Text, at its line when the link
carries one: `terminal/kitty/open-actions.conf` launches `subl`, and
`kitty.conf` adds `exe_search_path +/opt/homebrew/bin`, so kitty finds it
without a login shell's startup files. `shell/`'s zshenv sets `$EDITOR` to
`subl -w`, still nano over ssh or without Sublime Text; the kitty and shell
installers and `bin/bootstrap` look for `subl` where they looked for `zed`.
`preen doctor` asserts the new line, and its handler-table reader also
reads an entry LaunchServices keys by file extension.

## v1.1.1

`preen doctor --quiet` leaves a ceiling that waits on a manual re-check to
the full run, and folds the rows a host skipped, because ssh could not reach
it, into one warn naming that host. The comments in
`terminal/kitty/kitty.conf`, `editor/zed/settings.json` and Sublime's colour
scheme keep each line's reason and drop the method behind it, and
`preferences.toml`'s header names the `value` and `why` it carries beside
its checks; no setting changed.

## v1.1.0

`shell/`'s zshenv points rg at `~/.config/ripgrep/config` only where
`RIPGREP_CONFIG_PATH` is unset, so a variable of your own wins in the shell
as it already did in the installer; the installer's `--help` names more of
the refusals it makes before the first write.
`terminal/tmux/` drops its `xterm-kitty` true-colour override, which kitty's
own terminfo makes redundant. An installer run from its install line
fetches `lib/shipped`, the list that tells an earlier copy of the setup's
from your edit, only when a file is already where it would copy one.
`editor/sublime/` drops `remember_open_files`, which `hot_exit` at
Sublime's default makes redundant, and writes
`trim_trailing_white_space_on_save` and `open_files_in_new_window` as the
strings Build 4215 documents, `"all"` and `"never"`. `preen doctor` asks
atuin which config it reads, and fails when that is not the deployed one,
as with a `~/.atuin/config.toml`; it asserts kitty's scrollbar, shown while
scrolled, against kitty's own default; and a `[surfaces]` version command
given a `host` runs on that machine over ssh. A `host`, a target's too, now
starts with a letter or digit, so ssh never reads one as an option.

## v1.0.2

The front page says what each piece writes beyond its wiring, what an
update keeps, and what the setup changes, in fewer words; the
exceptions stay on each piece's page. `shell/` copies atuin's config as
atuin 18.24's template, with the same three settings set. `preen doctor`'s
`[surfaces]` version check reads a Homebrew revision, git `2.56.0_1`, as
the release it rebuilds rather than as a new version.

## v1.0.1

The front page gives every piece past the statusline its install line
alone, each linked to its page, which keeps the piece's dry run; what taking
the setup changes, and the map of the repository, come a screen sooner.
Under Updating, the note on a linked Zed `settings.json` says what made the
link: a bootstrap from before Zed's settings moved to
`global_settings.json`.

## v1.0.0

The first release. Each piece installs with one command, makes every refusal
before its first write, and updates when you run its line from its page
again:

- `prompt/`: Claude Code's statusline, drawn by cship, and starship's prompt
  if you want it;
- `terminal/kitty/` and `terminal/tmux/`;
- `shell/`: zsh and readline, and a hushlogin and atuin's, bat's,
  ripgrep's and ncdu's configs where you have none of your own;
- `git/` and `gh/`;
- `editor/zed/` and `editor/sublime/`, each a layer beneath your own
  settings;
- `macos/apply.sh`: System Settings values, with a script that puts yours
  back.

Or take the whole setup: `bin/bootstrap` deploys every row of
`manifest.tsv`, and `bin/preen doctor` reads each back.
