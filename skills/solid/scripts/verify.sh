#!/usr/bin/env bash
# Run the Solid (build_runner) code generator and report PASS/FAIL.
# Run from the package root (the directory with pubspec.yaml).
# Exits 0 on success, non-zero on failure. On failure, prints the first
# [SEVERE] line so the agent can act on it without parsing the full log.

set -u

if [[ ! -f pubspec.yaml ]]; then
  echo "verify.sh: must be run from a package root (no pubspec.yaml here)" >&2
  exit 2
fi

log="$(mktemp -t solid-verify.XXXXXX)"
trap 'rm -f "$log"' EXIT

if dart run build_runner build --delete-conflicting-outputs >"$log" 2>&1; then
  echo "PASS: build_runner generated lib/ from source/."
  exit 0
fi

echo "FAIL: build_runner returned non-zero." >&2
first_severe="$(grep -m1 '\[SEVERE\]' "$log" || true)"
if [[ -n "$first_severe" ]]; then
  echo "First error: $first_severe" >&2
else
  echo "Last 20 lines of output:" >&2
  tail -n 20 "$log" >&2
fi
exit 1
