"""Content digest of an sdist archive.

The digest covers exactly the things inside the archive container:
the ordered file list and, for every member, its type, permission
bits, recorded mtime, owner/group ids and the content payload.
The .tar.gz container itself (gzip framing) is not part of the digest.
"""

from __future__ import annotations

import hashlib
import sys
import tarfile


def digest(path: str) -> str:
    hasher = hashlib.sha256()
    count = 0
    with tarfile.open(path, mode="r:gz") as archive:
        for member in archive.getmembers():
            hasher.update(repr(member.name).encode())
            hasher.update(member.type)
            hasher.update(
                repr(
                    (
                        member.mode,
                        member.mtime,
                        member.uid,
                        member.gid,
                        member.size,
                        member.uname,
                        member.gname,
                    )
                ).encode()
            )
            if member.isfile():
                extracted = archive.extractfile(member)
                assert extracted is not None
                hasher.update(extracted.read())
            count += 1
    return f"sha256:{hasher.hexdigest()} files:{count}"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: python sdist_content.py <dist.tar.gz>")
    print(digest(sys.argv[1]))
