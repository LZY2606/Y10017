#!/usr/bin/env bash
# Quality-gate chain for pypika-tortoise.
#
#   scripts/verify.sh full   # all supported Python versions, with coverage
#   scripts/verify.sh quick  # lowest+highest Python versions, no coverage
#
# Gates run in a fixed order; the first failing gate aborts the chain with a
# non-zero exit code. Every gate prints "==> <name>" to stdout before it runs.
set -euo pipefail

MODE="${1:-full}"
case "$MODE" in
  full)
    PY_VERSIONS=(3.9 3.10 3.11 3.12 3.13)
    COV_OPTS=(--cov=pypika_tortoise --cov-append --cov-branch)
    ;;
  quick)
    PY_VERSIONS=(3.9 3.13)
    COV_OPTS=()
    ;;
  *)
    echo "usage: $0 [full|quick]" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CHECKFILES=${CHECKFILES:-"pypika_tortoise tests/ conftest.py"}
read -ra CHECKFILES_ARR <<< "$CHECKFILES"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pypika-tortoise-verify.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

GIT_SNAPSHOT="$(git status --porcelain)"

LOG="$WORK/gate.log"
quietly() {
  if ! "$@" >"$LOG" 2>&1; then
    cat "$LOG" >&2
    return 1
  fi
}

gate_lock() {
  quietly uv lock --check --offline
}

# Not a gate: make sure the tool environment exists (no-op after `make deps`).
setup_env() {
  quietly uv sync --frozen --active --inexact --all-groups --all-extras
}

gate_format() {
  uv run --no-sync ruff format --check "${CHECKFILES_ARR[@]}"
}

gate_lint() {
  uv run --no-sync ruff check "${CHECKFILES_ARR[@]}"
}

gate_types() {
  uv run --no-sync mypy "${CHECKFILES_ARR[@]}"
}

gate_security() {
  quietly uv run --no-sync bandit -c pyproject.toml -r "${CHECKFILES_ARR[@]}"
}

gate_tests() {
  local v venv log passed
  for v in "${PY_VERSIONS[@]}"; do
    venv="$WORK/venv-$v"
    log="$WORK/pytest-$v.log"
    # Independent environment per version, editable install, locked deps.
    quietly env -u VIRTUAL_ENV UV_PROJECT_ENVIRONMENT="$venv" \
      uv sync --frozen --python "$v" --all-groups --inexact
    # GIT_CONFIG_* gives `poetry new` (used by one test) a valid author
    # identity without touching the user's git configuration.
    if ! env PYTHONDEVMODE=1 PATH="$venv/bin:$PATH" \
        GIT_CONFIG_COUNT=2 \
        GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0="pypika-tortoise ci" \
        GIT_CONFIG_KEY_1=user.email GIT_CONFIG_VALUE_1=ci@example.com \
        "$venv/bin/python" -m pytest -n auto --tb=native -q ${COV_OPTS[@]+"${COV_OPTS[@]}"} \
        >"$log" 2>&1; then
      cat "$log" >&2
      return 1
    fi
    passed="$(grep -Eo '[0-9]+ passed' "$log" | tail -n1 | grep -Eo '^[0-9]+' || true)"
    if [ -z "$passed" ]; then
      echo "could not determine the passed count for Python $v" >&2
      cat "$log" >&2
      return 1
    fi
    echo "Python $v: $passed passed"
  done
}

gate_build() {
  quietly uv build --out-dir "$WORK/dist"
  if [ -e dist ]; then
    echo "dist/ must not be created inside the repository" >&2
    return 1
  fi
  ls -1 "$WORK/dist"
}

gate_repro() {
  local line1 line2
  line1="$("$REPO_ROOT/scripts/repro-digest.sh")"
  line2="$("$REPO_ROOT/scripts/repro-digest.sh")"
  if [ "$line1" != "$line2" ]; then
    echo "sdist is not reproducible:" >&2
    echo "  first build:  $line1" >&2
    echo "  second build: $line2" >&2
    return 1
  fi
  echo "$line1"
}

gate_package() {
  local sdist wheel f listing
  sdist="$(ls "$WORK"/dist/*.tar.gz)"
  wheel="$(ls "$WORK"/dist/*.whl)"
  listing="$(tar -tzf "$sdist")"
  for f in README.md LICENSE CHANGELOG.md; do
    if ! grep -q "/${f}\$" <<< "$listing"; then
      echo "sdist is missing $f" >&2
      return 1
    fi
  done
  listing="$(uv run --no-sync python -m zipfile -l "$wheel")"
  if awk '{print $1}' <<< "$listing" | grep -q '^tests/'; then
    echo "wheel must not contain tests/" >&2
    return 1
  fi
  uv run --no-sync twine check "$sdist" "$wheel"
}

gate_clean() {
  rm -rf dist build .pdm-build .pytest_cache
  rm -f .coverage .coverage.* coverage.xml
  local stray now
  stray="$(find . -maxdepth 1 -type d \( -name '.venv-verify*' -o -name 'venv-3.*' \) -print)"
  if [ -n "$stray" ]; then
    echo "matrix virtualenv directories left in the repository:" >&2
    echo "$stray" >&2
    return 1
  fi
  now="$(git status --porcelain)"
  if [ "$now" != "$GIT_SNAPSHOT" ]; then
    echo "git status --porcelain changed during verify:" >&2
    diff <(printf '%s\n' "$GIT_SNAPSHOT") <(printf '%s\n' "$now") >&2 || true
    return 1
  fi
}

run_gate() {
  echo "==> $1"
  shift
  "$@"
}

run_gate lock gate_lock
setup_env
run_gate format gate_format
run_gate lint gate_lint
run_gate types gate_types
run_gate security gate_security
run_gate tests gate_tests
run_gate build gate_build
run_gate repro gate_repro
run_gate package gate_package
run_gate clean gate_clean
