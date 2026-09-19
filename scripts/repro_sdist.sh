#!/usr/bin/env bash
# Build the sdist out-of-tree and operate on its content digest.
#   ./scripts/repro_sdist.sh digest           print one deterministic content line
#   ./scripts/repro_sdist.sh check <dir>      build twice, compare the contents
#
# SOURCE_DATE_EPOCH=0 pins all timestamps recorded inside the archive,
# so the digest is independent of when or where the build is run.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SOURCE_DATE_EPOCH=0

mode="${1:-}"

if [[ "${mode}" == "digest" ]]; then
  work_dir="$(mktemp -d)"
  trap 'rm -rf "${work_dir}"' EXIT
  uv build --quiet --sdist --out-dir "${work_dir}" --project "${ROOT_DIR}" >&2
  sdist="$(find "${work_dir}" -maxdepth 1 -name '*.tar.gz' -print -quit)"
  uv run --quiet --project "${ROOT_DIR}" python "${ROOT_DIR}/scripts/sdist_content.py" "${sdist}"
  exit 0
fi

if [[ "${mode}" == "check" && $# -eq 2 ]]; then
  work_dir="$2"
  first_dir="${work_dir}/first"
  second_dir="${work_dir}/second"
  mkdir -p "${first_dir}" "${second_dir}"
  uv build --quiet --sdist --out-dir "${first_dir}" --project "${ROOT_DIR}"
  uv build --quiet --sdist --out-dir "${second_dir}" --project "${ROOT_DIR}"
  first_sdist="$(find "${first_dir}" -maxdepth 1 -name '*.tar.gz' -print -quit)"
  second_sdist="$(find "${second_dir}" -maxdepth 1 -name '*.tar.gz' -print -quit)"
  first_digest="$(uv run --quiet --project "${ROOT_DIR}" python "${ROOT_DIR}/scripts/sdist_content.py" "${first_sdist}")"
  second_digest="$(uv run --quiet --project "${ROOT_DIR}" python "${ROOT_DIR}/scripts/sdist_content.py" "${second_sdist}")"
  echo "${first_digest}"
  if [[ "${first_digest}" != "${second_digest}" ]]; then
    echo "sdist content differs between builds:" >&2
    echo "  first:  ${first_digest}" >&2
    echo "  second: ${second_digest}" >&2
    exit 1
  fi
  exit 0
fi

echo "usage: $0 digest | check <work-dir>" >&2
exit 2
