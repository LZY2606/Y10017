# pypika-tortoise

[![image](https://img.shields.io/pypi/v/pypika-tortoise.svg?style=flat)](https://pypi.python.org/pypi/pypika-tortoise)
[![image](https://img.shields.io/github/license/tortoise/pypika-tortoise)](https://github.com/tortoise/pypika-tortoise)
[![image](https://github.com/tortoise/pypika-tortoise/workflows/pypi/badge.svg)](https://github.com/tortoise/pypika-tortoise/actions?query=workflow:pypi)
[![image](https://github.com/tortoise/pypika-tortoise/workflows/ci/badge.svg)](https://github.com/tortoise/pypika-tortoise/actions?query=workflow:ci)

Forked from [pypika](https://github.com/kayak/pypika) and adapted just for tortoise-orm.

## Why forked?

The original repository includes many databases that Tortoise ORM doesn’t require. It aims to be a comprehensive SQL builder with broad compatibility, but that’s not the goal for Tortoise ORM. Having it forked makes it easier to add new features for Tortoise.

## What changed?

Deleted unnecessary code that Tortoise ORM doesn’t require, added features tailored specifically for Tortoise ORM,
and modified to improve query generation performance.

## ThanksTo

- [pypika](https://github.com/kayak/pypika), a Python SQL query builder that exposes the full expressiveness of SQL,
using a syntax that mirrors the resulting query structure.

## Development

On a clean machine with only [uv](https://docs.astral.sh/uv/) installed, create the
development environment and run the complete quality gate with two commands:

```shell
uv sync --all-groups
make verify
```

`make verify` runs the same gate chain CI runs — lock check, formatting, lint, types,
security scan, the test matrix for every Python version allowed by `requires-python`
(3.9–3.13), build, reproducible sdist, package checks and cleanup — and stops at the
first failing gate. For a fast local pass use `make verify-quick`, which only tests the
lowest and highest supported Python versions, in parallel and without coverage.
`make repro-digest` prints one line with the content digest of the sdist; identical
source always yields the same line.

## License

This project is licensed under the [Apache-2.0](./LICENSE) License.
