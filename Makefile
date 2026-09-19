src_dir = pypika_tortoise
checkfiles = $(src_dir) tests/ conftest.py
py_warn = PYTHONDEVMODE=1
pytest_opts = -n auto --cov=$(src_dir) --cov-append --cov-branch --tb=native -q

up:
	@uv lock --upgrade

deps:
	uv sync --inexact --all-groups --all-extras

.PHONY: verify verify-quick repro-digest
verify:
	@./scripts/verify.sh

verify-quick:
	@./scripts/verify.sh quick

repro-digest:
	@./scripts/repro_sdist.sh digest

codeqc:
	mypy $(checkfiles)
	bandit -c pyproject.toml -r $(checkfiles)
	twine check dist/*

check: build _check
_check:
	ruff format --check $(checkfiles) || (echo "Please run 'make style' to auto-fix style issues" && false)
	ruff check $(checkfiles)
	$(MAKE) codeqc

test: deps _test
_test:
	$(py_warn) pytest $(pytest_opts)

ci: build _check _test

style: deps _style
_style:
	ruff format $(checkfiles)
	ruff check --fix $(checkfiles)

lint: build _style codeqc

build: deps
	rm -fR dist/
	uv build

publish: build
	twine upload dist/*
