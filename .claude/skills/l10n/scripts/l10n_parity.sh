#!/usr/bin/env bash
# Compares every translations_<lang>.dart against translations_en.dart (the
# source of truth). Prints missing/extra keys per locale; exits 1 on any gap.
# A missing key renders as the raw key name for that locale's users.
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
DIR="$ROOT/lib/core/l10n"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

keys() { grep -oE "^\s*'[A-Za-z0-9_]+':" "$1" | tr -d " ':" | sort -u; }

keys "$DIR/translations_en.dart" > "$TMP/en"
status=0
for f in "$DIR"/translations_*.dart; do
  lang="$(basename "$f" .dart)"; lang="${lang#translations_}"
  [ "$lang" = en ] && continue
  keys "$f" > "$TMP/$lang"
  missing="$(comm -23 "$TMP/en" "$TMP/$lang" | tr '\n' ' ')"
  extra="$(comm -13 "$TMP/en" "$TMP/$lang" | tr '\n' ' ')"
  if [ -n "$missing$extra" ]; then
    status=1
    echo "[$lang]"
    [ -n "$missing" ] && echo "  missing: $missing"
    [ -n "$extra" ] && echo "  extra:   $extra"
  fi
done

[ $status -eq 0 ] && echo "l10n parity OK ($(wc -l < "$TMP/en" | tr -d ' ') keys x 12 locales)"
exit $status
