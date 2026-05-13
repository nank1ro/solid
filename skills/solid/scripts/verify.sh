#!/usr/bin/env bash
# Verify a Solid package: regenerate lib/ from source/, then apply lint-driven
# fixes. Run from the package root (the directory with pubspec.yaml).
#
# Exit code:
#   0 = build_runner succeeded (dart fix failure is non-fatal, reported as WARN)
#   1 = build_runner failed
#   2 = misuse (not a package root)
#
# On build_runner failure, prints the first [SEVERE] line so the caller can act
# on it without parsing the full log.

set -u

if [[ ! -f pubspec.yaml ]]; then
  echo "verify.sh: must be run from a package root (no pubspec.yaml here)" >&2
  exit 2
fi

log="$(mktemp -t solid-verify.XXXXXX)"
trap 'rm -f "$log"' EXIT

# Step 1: build_runner. This is the hard requirement.
if ! dart run build_runner build --delete-conflicting-outputs >"$log" 2>&1; then
  echo "FAIL: build_runner returned non-zero." >&2
  first_severe="$(grep -m1 '\[SEVERE\]' "$log" || true)"
  if [[ -n "$first_severe" ]]; then
    echo "First error: $first_severe" >&2
  else
    echo "Last 20 lines of output:" >&2
    tail -n 20 "$log" >&2
  fi
  exit 1
fi

# Step 2: dart fix. This is polish; failure here doesn't fail the script.
if dart fix --apply >>"$log" 2>&1; then
  echo "PASS: build_runner generated lib/ from source/, dart fix applied."
  exit 0
fi

echo "PASS: build_runner generated lib/ from source/."
echo "WARN: dart fix --apply failed (non-fatal). Last 10 lines of log:" >&2
tail -n 10 "$log" >&2
exit 0
