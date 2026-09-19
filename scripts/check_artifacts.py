"""Validate sdist/wheel layout before publication."""

from __future__ import annotations

import sys
import tarfile
import zipfile
from pathlib import Path


def main(dist_dir: str) -> None:
    paths = list(Path(dist_dir).iterdir())
    sdist_paths = [path for path in paths if path.name.endswith(".tar.gz")]
    wheel_paths = [path for path in paths if path.name.endswith(".whl")]
    if len(sdist_paths) != 1 or len(wheel_paths) != 1:
        raise SystemExit(f"expected one sdist and one wheel in {dist_dir}")

    sdist_path = sdist_paths[0]
    wheel_path = wheel_paths[0]

    required = {"README.md", "LICENSE", "CHANGELOG.md"}
    with tarfile.open(sdist_path, mode="r:gz") as archive:
        sdist_names = [member.name.split("/", 1)[1] for member in archive.getmembers()]
    present = {name for name in sdist_names if name in required}
    missing = required - present
    if missing:
        raise SystemExit(f"sdist missing required files: {sorted(missing)}")
    print(f"sdist contains: {', '.join(sorted(required))}")

    with zipfile.ZipFile(wheel_path) as archive:
        wheel_names = archive.namelist()
    leaked = [name for name in wheel_names if name == "tests/" or name.startswith("tests/")]
    if leaked:
        raise SystemExit(f"wheel must not contain tests/: {leaked}")
    print("wheel contains no tests/")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: python check_artifacts.py <dist-dir>")
    main(sys.argv[1])
