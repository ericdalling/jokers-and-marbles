from pathlib import Path
import shutil
import sys
import subprocess

root = Path(__file__).resolve().parents[1]
dest = Path(sys.argv[1])
dest.mkdir(parents=True, exist_ok=True)
# References include mock controls. Keep them separate from live UI.
for name in ("voorhees-host-lobby.png", "voorhees-iphone-ipad-landing.png"):
    source = root / "Assets" / "Branding" / name
    if not source.is_file():
        raise FileNotFoundError(source)
    if source.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Invalid PNG: {source}")
    shutil.copyfile(source, dest / name)
# Optional clean artwork, deliberately not substituted with a screenshot.
for name in ("host-background.jpg", "iphone-background.jpg", "ipad-background.jpg"):
    source = root / "Assets" / "Branding" / name
    if source.is_file():
        shutil.copyfile(source, dest / name)
