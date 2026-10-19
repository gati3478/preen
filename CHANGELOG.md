# Changelog

Each release is a tag, and the install lines on the pages at that tag fetch
from it. A major release moves where or how a file lands, or drops a flag; a
minor one adds a piece, a row, a flag or a check; a patch changes values,
fixes and docs.

## v1.3.0

`preen doctor` gains a reader, `lsopen`, that asks LaunchServices for a
content type's default app, whether a handler-table entry pins the type or
LaunchServices ranks the app first. A reader whose tool hangs past its
timeout fails its own row, where it crashed the preference checks and lost
every row.

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
