#!/usr/bin/env bash
# Build the sdist and print a deterministic digest of its archive content
# (file list, per-file content and metadata; not the gzip container).
# Output is exactly one line and is stable across runs on the same source.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# pdm-backend normalizes tar entry mtimes to SOURCE_DATE_EPOCH when set.
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1700000000}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pypika-tortoise-repro.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

uv build --sdist --out-dir "$WORK" >/dev/null 2>&1
sdist="$(ls "$WORK"/*.tar.gz)"

if command -v sha256sum >/dev/null 2>&1; then
  digest="$(gzip -dc "$sdist" | sha256sum | cut -d' ' -f1)"
elif command -v shasum >/dev/null 2>&1; then
  digest="$(gzip -dc "$sdist" | shasum -a 256 | cut -d' ' -f1)"
else
  digest="$(gzip -dc "$sdist" | openssl dgst -sha256 -r | cut -d' ' -f1)"
fi

echo "sdist-content-sha256: ${digest}  $(basename "$sdist")"
