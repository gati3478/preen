# publish_fingerprint: hash of everything preen publish actually ships.
#
# preen doctor's currency check used to hash only `HEAD:public`, but
# preen publish also stages LICENSE, docs/public-README.md, bin/preen,
# bin/preen-apply, bin/preen-doctor, the preference checker, and
# manifest.tsv (the source manifest.tsv drives the generated, public-only
# one preen publish writes into the mirror). A change
# to any of those changes what ships without touching public/ at all, so
# hashing HEAD:public alone can say "current" while the mirror is stale.
# Single-sourced so the writer (preen publish) and the reader (preen doctor)
# cannot drift apart on which files count — the exact failure class the
# manifest.tsv split exists to prevent, one layer further in.
#
# Usage: publish_fingerprint <repo-path>
publish_fingerprint() {
  local repo="$1"
  {
    git -C "$repo" rev-parse HEAD:public              2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:LICENSE              2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:docs/public-README.md 2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:bin/preen            2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:bin/preen-apply      2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:bin/preen-doctor     2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:manifest.tsv         2>/dev/null || echo none
    # This file is itself staged into the mirror (preen publish, the bin/lib copy).
    # Omitting it meant editing this very function changed what the mirror ships
    # while leaving the fingerprint identical — so preen doctor reported "public
    # mirror is current" against a mirror that was not. Found 14-08-2026. The
    # self-reference is safe: this hashes the file's git blob, not its output.
    git -C "$repo" rev-parse HEAD:bin/lib/publish-fingerprint.sh 2>/dev/null || echo none
    # The preference checker ships too; its spec is inside HEAD:public.
    git -C "$repo" rev-parse HEAD:bin/lib/pref-check.py 2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:bin/lib/pref-check.sh 2>/dev/null || echo none
    git -C "$repo" rev-parse HEAD:bin/lib/zcap.sh 2>/dev/null || echo none
  } | shasum -a 256 | awk '{print $1}'
}
