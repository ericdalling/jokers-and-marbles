"""Generate platform app icons from the approved, checked-in master artwork."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets/Branding/JokersAndMarbles-AppIcon-1024.png"
INFO = {"author": "xcode", "version": 1}

def metadata(folder, **entries):
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "Contents.json").write_text(
        json.dumps({**entries, "info": INFO}, indent=2) + "\n", encoding="utf-8"
    )

with Image.open(SOURCE) as source:
    artwork = source.convert("RGB")
assert artwork.size == (1024, 1024), "Expected approved 1024px artwork"

ios = ROOT / "Apps/Controller/Branding.xcassets"
metadata(ios)
icon = ios / "AppIcon.appiconset"
metadata(icon, images=[{"filename": "AppIcon.png", "idiom": "universal",
                       "platform": "ios", "size": "1024x1024"}])
artwork.save(icon / "AppIcon.png")

tv = ROOT / "Apps/TV/Branding.xcassets"
metadata(tv)
brand = tv / "BrandAssets.brandassets"
assets = []

def layers(width, height):
    # Preserve the approved square art without stretching it.
    background = Image.new("RGB", (width, height), (20, 8, 43))
    foreground = Image.new("RGBA", (width, height))
    side = int(height * 0.90)
    art = artwork.resize((side, side), Image.Resampling.LANCZOS)
    mask = Image.new("L", (side, side))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, side-1, side-1),
                                           radius=max(1, side//16), fill=255)
    foreground.paste(art, ((width-side)//2, (height-side)//2), mask)
    return background, foreground

def stack(name, width, height, scales):
    folder = brand / (name + ".imagestack")
    names = ["Front", "Back"]
    metadata(folder, layers=[{"filename": n + ".imagestacklayer"} for n in names])
    for index, layer in enumerate(names):
        parent = folder / (layer + ".imagestacklayer")
        metadata(parent)
        images = parent / "Content.imageset"
        entries = []
        for scale in scales:
            back, front = layers(width*scale, height*scale)
            filename = f"{layer}@{scale}x.png"
            images.mkdir(parents=True, exist_ok=True)
            (front if index == 0 else back).save(images / filename)
            entries.append({"filename": filename, "idiom": "tv", "scale": f"{scale}x"})
        metadata(images, images=entries)
    assets.append({"filename": folder.name, "idiom": "tv",
                   "role": "primary-app-icon", "size": f"{width}x{height}"})

def shelf(name, width, height, role):
    folder = brand / (name + ".imageset")
    entries = []
    for scale in (1, 2):
        back, front = layers(width*scale, height*scale)
        back.paste(front, (0, 0), front)
        filename = f"Shelf@{scale}x.png"
        folder.mkdir(parents=True, exist_ok=True)
        back.save(folder / filename)
        entries.append({"filename": filename, "idiom": "tv", "scale": f"{scale}x"})
    metadata(folder, images=entries)
    assets.append({"filename": folder.name, "idiom": "tv", "role": role,
                   "size": f"{width}x{height}"})

stack("App Icon", 400, 240, (1, 2))
stack("App Icon - App Store", 1280, 768, (1,))
shelf("Top Shelf Image", 1920, 720, "top-shelf-image")
shelf("Top Shelf Image Wide", 2320, 720, "top-shelf-image-wide")
metadata(brand, assets=assets)
print("Generated iOS and tvOS branding catalogs")
