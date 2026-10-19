# Changelog

Each release is a tag, and the install lines on the pages at that tag fetch
from it. A major release moves where or how a file lands, or drops a flag; a
minor one adds a piece, a row, a flag or a check; a patch changes values,
fixes and docs.

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
