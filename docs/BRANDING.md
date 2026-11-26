# App branding

The approved master is Assets/Branding/JokersAndMarbles-AppIcon-1024.png. Keep it unchanged.
Before running XcodeGen locally, generate the catalogs:

```sh
python3 -m venv /tmp/jokers-branding-venv
/tmp/jokers-branding-venv/bin/pip install Pillow==11.3.0
/tmp/jokers-branding-venv/bin/python scripts/generate_branding.py
xcodegen generate
```

CI runs the same generator before building either target. The iOS icon uses the full original artwork with opaque RGB encoding. tvOS uses the square art on a purple background in a two-layer stack, including standard and App Store sizes and both top-shelf formats. This is an initial adaptation, not independently approved final TV artwork. Verify asset compilation and Home Screen appearance on devices before release.
