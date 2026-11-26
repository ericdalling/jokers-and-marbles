#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
for name in ASC_API_PRIVATE_KEY ASC_KEY_ID ASC_ISSUER_ID TEAM_ID SCHEME PLATFORM BUNDLE_ID RUN_NUMBER RUN_ATTEMPT; do
  [[ -n "${!name:-}" ]] || { echo "Missing required configuration: $name" >&2; exit 1; }
done
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "Invalid Team ID" >&2; exit 1; }
[[ "$ASC_KEY_ID" =~ ^[A-Za-z0-9]+$ ]] || exit 1
[[ "$ASC_ISSUER_ID" =~ ^[A-Fa-f0-9-]{36}$ ]] || exit 1
[[ "$RUN_NUMBER" =~ ^[1-9][0-9]{0,3}$ && "$RUN_ATTEMPT" =~ ^[1-9][0-9]?$ ]] || { echo "Build number exceeds Apple component limits" >&2; exit 1; }
build_number="$RUN_NUMBER.0.$RUN_ATTEMPT"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
key="$tmp/AuthKey_$ASC_KEY_ID.p8"
printf '%s\n' "$ASC_API_PRIVATE_KEY" > "$key"
openssl pkey -in "$key" -noout >/dev/null
unset ASC_API_PRIVATE_KEY
archive="$tmp/$SCHEME.xcarchive"
# Match the unsigned-archive/cloud-signing approach used by CPAP Sync.
xcodebuild -project JokersAndMarbles.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination "generic/platform=$PLATFORM" \
  -archivePath "$archive" DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$build_number" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive
app="$archive/Products/Applications/$SCHEME.app"
[[ -d "$app" ]] || { echo "Archive app missing" >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")" == "$BUNDLE_ID" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Info.plist")" == "$build_number" ]]
[[ ! -d "$app/_CodeSignature" ]]
python3 - "$tmp/export.plist" "$TEAM_ID" <<'PY'
import plistlib, sys
with open(sys.argv[1], "wb") as f:
    plistlib.dump({"method": "app-store-connect", "destination": "upload",
                   "teamID": sys.argv[2], "signingStyle": "automatic",
                   "manageAppVersionAndBuildNumber": False}, f)
PY
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$tmp/export" \
  -exportOptionsPlist "$tmp/export.plist" -allowProvisioningUpdates \
  -authenticationKeyPath "$key" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
echo "Upload command succeeded for $SCHEME build $build_number; Apple processing and tester access remain to be verified."
