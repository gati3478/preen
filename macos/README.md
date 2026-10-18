# macOS · System Settings

The author's System Settings, written with `defaults` for the user who runs
the script: the appearance, the Dock and its hot corners, Finder, the
trackpad, spelling correction, screenshots, the 12-hour clock and what the
menu bar's clock shows, Stage Manager and Siri. `--dry-run` lists each one
that differs on your Mac, from → to. Take it alone: the script is one file
that fetches nothing, and nothing it writes points back here.

## What you need

macOS, and your own user. The script refuses anywhere else, and as root:
these are one user's settings.

## Install

No clone needed. To list each setting that differs and stop, writing
nothing — `bash -s --` hands the flag to the script:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/macos/apply.sh | bash -s -- --dry-run
```

To apply:

```sh
curl -fsSL https://raw.githubusercontent.com/gati3478/preen/main/macos/apply.sh | bash
```

Or from a clone of this repository, `./macos/apply.sh`, with `--dry-run` for
the list alone. It asks nothing.

It

1. reads each setting and writes only one that differs;
2. before the first write, saves the values it replaces as a script,
   `~/.local/state/preen/macos.unpreened.<time>.sh` — under
   `$XDG_STATE_HOME/preen` when that is set;
3. restarts the Dock, Finder and the menu bar only when one of theirs
   changed, and where the appearance changed, switches it at once through
   System Events. macOS can refuse your terminal that; Dark then waits for
   the next login, and the run says so;
4. names the restore script. Trackpad changes take effect at the next login.

A re-run with nothing to change writes nothing and saves no script.

**Refusals**, all before the first write, and `--dry-run` refuses as the run
would: not macOS; root; a symlinked directory between `~` and the restore
script, which would put it wherever the link points; a restore script that
cannot be saved. A write that fails part-way stops the run, which names the
restore script that puts back what changed.

## Updating

Run the script again; from a clone, `git pull`, then `./macos/apply.sh`.
System Settings have no overlay, so a re-run sets back each setting that
differs, one you changed since included, saving what it replaces first:
`--dry-run` lists them.

## Putting it back

`sh` the restore script the run named,
`sh ~/.local/state/preen/macos.unpreened.<time>.sh`. It writes back each
value the run replaced, with its type, deletes each key that was unset,
restarts what the run restarted and switches the appearance back. The
trackpad takes its values back at the next login. After several runs, `sh`
their scripts newest first.

## Leaving

Put the settings back as above, then delete the restore scripts, and
`~/.local/state/preen` where nothing else is in it: they are all the script
leaves on disk.

## License

MIT
