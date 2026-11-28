#!/usr/bin/env bash
set -euo pipefail
mkdir -p visual-review
xcrun simctl list devices available -j > visual-review/devices.json
UDID=$(python3 - "$DEVICE" <<'PY'
import json,sys
kind=sys.argv[1]
devices=json.load(open("visual-review/devices.json"))["devices"]
prefix={"iphone":"iPhone","ipad":"iPad","tv":"Apple TV"}[kind]
matches=[d for runtime,ds in devices.items() for d in ds if d["name"].startswith(prefix) and d.get("isAvailable")]
if not matches: raise SystemExit("No available simulator for "+kind)
print(matches[-1]["udid"])
PY
)
if [[ "$DEVICE" == tv ]]; then
  SCHEME=JokersTV
  BUNDLE=com.ericdalling.jokersandmarbles.tv
else
  SCHEME=JokersController
  BUNDLE=com.ericdalling.jokersandmarbles.controller
fi
xcrun simctl boot "$UDID" || xcrun simctl list devices booted | grep -F "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcodebuild -project JokersAndMarbles.xcodeproj -scheme "$SCHEME" -configuration Debug -destination "id=$UDID" -derivedDataPath /tmp/visual-build CODE_SIGNING_ALLOWED=NO build 2>&1 | tee visual-review/build.log
APP=$(find /tmp/visual-build/Build/Products -name "$SCHEME.app" -type d | head -1)
test -n "$APP"
xcrun simctl install "$UDID" "$APP"
for N in 3 4 5 6; do
  xcrun simctl launch "$UDID" "$BUNDLE" --visual-review --players "$N"
  sleep 8
  xcrun simctl io "$UDID" screenshot "visual-review/$DEVICE-gameplay-$N.png"
  xcrun simctl terminate "$UDID" "$BUNDLE"
done
xcrun simctl launch "$UDID" "$BUNDLE"
sleep 8
xcrun simctl io "$UDID" screenshot "visual-review/$DEVICE-landing.png"
xcrun simctl terminate "$UDID" "$BUNDLE"
printf '%s\n' "$GITHUB_SHA" > visual-review/commit.txt
