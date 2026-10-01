# kitty's tab title for this HOME, read two ways, `want` choosing which. One
# copy for the two writers of tab-title.conf, bin/bootstrap and this
# directory's install.sh.
#
#   awk -v want=title -v authored=<home> -f tab-title.awk kitty.conf
#
# prints kitty.conf's tab_title_template line with <home> rewritten as HOME.
# The line collapses the working directory to '~' with a Python .replace()
# inside kitty's own config language, which expands no environment variable in
# that option, so the home it names is a literal, authored for one machine.
# index and substr match no pattern at all: a sed expression built from $HOME
# turns a `|` in it into a different command and an `&` into the whole match.
# HOME is read from ENVIRON: `awk -v` turns a `\t` in it into a tab. kitty
# compiles the title as a Python f-string, where `\t` is a tab too, so each
# backslash is written doubled.
#
#   LC_ALL=C awk -v want=local -f tab-title.awk local.conf
#
# prints, of local.conf's tab_title_template lines, the last with a value: its
# line number and, when it is `active_wd.replace('<path>', '~')` for a path
# other than HOME, that path. local.conf is read after tab-title.conf, so that
# line is the title kitty shows. A line has a value when kitty's whitespace
# follows the key — spaces, tabs, \v, \f, \x1c-\x1f; it ends a line at a lone
# \r — and then a byte that is not whitespace. kitty also counts multibyte
# spaces as whitespace; a line led or split by one, or with one for its value,
# is not modelled. LC_ALL=C: under a UTF-8 locale, macOS awk stops at a byte
# that is not UTF-8.

want == "title" && /^tab_title_template / {
  lit = ""; r = ENVIRON["HOME"]
  while ((k = index(r, "\\")) > 0) {
    lit = lit substr(r, 1, k - 1) "\\\\"
    r = substr(r, k + 1)
  }
  lit = lit r
  out = ""; rest = $0
  while ((i = index(rest, authored)) > 0) {
    out = out substr(rest, 1, i - 1) lit
    rest = substr(rest, i + length(authored))
  }
  print out rest
  exit
}

want == "local" && /^[[:space:]\034-\037]*tab_title_template[ \t\v\f\034-\037]+[^[:space:]\034-\037]/ { n = NR; t = $0 }

END {
  if (want != "local" || !n) exit
  p = ""; i = index(t, "active_wd.replace(")
  if (i) {
    s = substr(t, i + 18); q = substr(s, 1, 1); s = substr(s, 2); j = index(s, q)
    if ((q == "\"" || q == "'") && j && substr(s, 1, j - 1) != ENVIRON["HOME"] && substr(s, j + 1) ~ /^, *.~.\)/) p = substr(s, 1, j - 1)
  }
  print n, p
}

# end of tab-title.awk: install.sh refuses a copy whose last line is not this one
