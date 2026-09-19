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

## Development

Only [uv](https://docs.astral.sh/uv/) is required. On a clean machine, two commands set up
the environment and run the full quality gate chain (the same one CI runs):

```bash
make deps    # create the environment and install all dev dependencies
make verify  # run the full gate chain: lock, format, lint, types, security,
             # tests (every supported Python version), build, repro, package, clean
```

`make verify-quick` runs the same chain but only tests the lowest and highest supported
Python versions, without coverage. `make repro-digest` prints the reproducible content
digest of the sdist.

## ThanksTo

- [pypika](https://github.com/kayak/pypika), a Python SQL query builder that exposes the full expressiveness of SQL,
using a syntax that mirrors the resulting query structure.

## License

This project is licensed under the [Apache-2.0](./LICENSE) License.
