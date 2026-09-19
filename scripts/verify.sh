#!/usr/bin/env bash
# Full quality gate. The ten gates below always run in this exact order;
# the first failing gate aborts the chain with a non-zero status.
#
#   ./scripts/verify.sh         # every supported Python minor version
#   ./scripts/verify.sh quick   # lowest and highest only, parallel, no coverage
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CHECKFILES="pypika_tortoise tests/ conftest.py"
ALL_PYTHONS=("3.9" "3.10" "3.11" "3.12" "3.13")

if [[ "${1:-}" == "quick" ]]; then
  PYTHONS=("${ALL_PYTHONS[0]}" "${ALL_PYTHONS[$((${#ALL_PYTHONS[@]} - 1))]}")
  TEST_MODE="quick"
else
  PYTHONS=("${ALL_PYTHONS[@]}")
  TEST_MODE="full"
fi

WORK_DIR="${TMPDIR:-/tmp}/pypika-tortoise-verify.$$"
mkdir -p "${WORK_DIR}"

git status --porcelain > "${WORK_DIR}/baseline.status"

# Give subprocesses a well-formed git identity (the poetry test scaffolds a
# new project whose author is derived from the global git configuration).
cat > "${WORK_DIR}/gitconfig" <<'EOF'
[user]
	name = CI Runner
	email = ci@example.com
EOF
export GIT_CONFIG_GLOBAL="${WORK_DIR}/gitconfig"
export GIT_CONFIG_NOSYSTEM=1

gate() {
  printf '\n==> %s\n' "$1"
}

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

# 1. lock -- must work without network access
gate lock
UV_OFFLINE=1 uv lock --check

# 2. format -- check only, never rewrite
gate format
uv run --quiet ruff format --check ${CHECKFILES}

# 3. lint -- check only, never auto-fix
gate lint
uv run --quiet ruff check ${CHECKFILES}

# 4. types
gate types
uv run --quiet mypy ${CHECKFILES}

# 5. security
gate security
uv run --quiet bandit -c pyproject.toml -r ${CHECKFILES}

# 6. tests -- one isolated editable environment per Python version
gate tests
for version in "${PYTHONS[@]}"; do
  venv_dir="${WORK_DIR}/venv-${version//./}"
  UV_PROJECT_ENVIRONMENT="${venv_dir}" uv sync --quiet --frozen \
    --python "${version}" --only-group test
  if [[ "${TEST_MODE}" == "quick" ]]; then
    pytest_opts=("-n" "auto" "-p" "no:cacheprovider" "-q" "--no-header")
  else
    pytest_opts=(
      "-p" "no:cacheprovider" "-q" "--no-header"
      "--cov=pypika_tortoise" "--cov-append" "--cov-branch"
    )
  fi
  output="$(
    PYTHONDEVMODE=1 GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL}" \
      GIT_CONFIG_NOSYSTEM=1 UV_PROJECT_ENVIRONMENT="${venv_dir}" \
      uv run --no-sync pytest "${pytest_opts[@]}"
  )"
  echo "${output}"
  passed="$(
    echo "${output}" | grep -Eo '[0-9]+ passed' | tail -1 | cut -d' ' -f1
  )"
  printf 'Python %s: %s passed\n' "${version}" "${passed:-0}"
done

# 7. build -- artifacts never land in the repository
gate build
build_dir="${WORK_DIR}/build"
mkdir -p "${build_dir}"
SOURCE_DATE_EPOCH=0 uv build --quiet --out-dir "${build_dir}"
echo "artifacts: $(find "${build_dir}" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.whl' \) -exec basename {} \; | paste -sd', ' -)"

# 8. repro -- two sdist builds must have identical contents
gate repro
./scripts/repro_sdist.sh check "${WORK_DIR}/repro"

# 9. package -- required metadata files, no tests in the wheel, valid metadata
gate package
uv run --quiet python scripts/check_artifacts.py "${build_dir}"
uv run --quiet twine check "${build_dir}"/*.tar.gz "${build_dir}"/*.whl

# 10. clean -- no leftovers, working tree identical to before verify
gate clean
if [[ -e dist ]]; then
  echo "build artifacts must not be written into the repository: dist/" >&2
  exit 1
fi

# Remove build intermediates, caches and coverage data from the run.
rm -rf .pdm-build build sdist .ruff_cache .mypy_cache .pytest_cache __pycache__
rm -f .coverage coverage.xml
find pypika_tortoise tests -type d -name '__pycache__' -prune -exec rm -rf {} +
find pypika_tortoise tests -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
find . -maxdepth 1 -name '*.pyc' -delete

for leftover in dist build .pdm-build sdist; do
  if [[ -e "${leftover}" ]]; then
    echo "leftover build path remains in repository: ${leftover}" >&2
    exit 1
  fi
done
for stray_venv in .venv-py* .venv-* venv-py*; do
  if [[ -e "${stray_venv}" ]]; then
    echo "matrix virtual environment remains in repository: ${stray_venv}" >&2
    exit 1
  fi
done
if ! git status --porcelain | cmp -s "${WORK_DIR}/baseline.status" -; then
  echo "working tree changed during verify:" >&2
  diff -u "${WORK_DIR}/baseline.status" <(git status --porcelain) >&2 || true
  exit 1
fi
echo "working tree unchanged"

echo
if [[ "${TEST_MODE}" == "quick" ]]; then
  gate_name="verify-quick"
else
  gate_name="verify"
fi
echo "${gate_name} passed (${#PYTHONS[@]} Python versions)"
