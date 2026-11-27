#!/usr/bin/env python3
"""Extract approved assets without modifying tracked archives."""
from pathlib import Path, PurePosixPath
import hashlib
import tempfile
import zipfile
import shutil

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    staging = Path(tmp)
    seen = set()
    for part in (1, 2):
        archive = root / f"Jokers-Approved-Assets-Part-{part}.zip"
        with zipfile.ZipFile(archive) as z:
            for entry in z.infolist():
                p = PurePosixPath(entry.filename)
                if p.is_absolute() or ".." in p.parts or p.parts[:2] != ("Assets", "Approved"):
                    raise ValueError(f"Unexpected archive path: {p}")
                if entry.is_dir():
                    continue
                if p in seen:
                    raise ValueError(f"Duplicate asset: {p}")
                seen.add(p)
                dest = staging.joinpath(*p.parts)
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(entry))
    manifest = staging / "Assets/Approved/SHA256SUMS.txt"
    verified = set()
    for line in manifest.read_text().splitlines():
        digest, name = line.split(maxsplit=1)
        p = PurePosixPath(name)
        if p not in seen or p in verified:
            raise ValueError(f"Invalid manifest entry: {name}")
        if hashlib.sha256(staging.joinpath(*p.parts).read_bytes()).hexdigest() != digest:
            raise ValueError(f"Checksum mismatch: {name}")
        verified.add(p)
    if seen - verified != {PurePosixPath("Assets/Approved/README.md"), PurePosixPath("Assets/Approved/SHA256SUMS.txt")}:
        raise ValueError("Unexpected unverified files")
    shutil.copytree(staging / "Assets/Approved", root / "Assets/Approved", dirs_exist_ok=True)
    print(f"Verified {len(verified)} approved assets")
