#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <Developer-ID-signed Cue.app> <output.dmg>" >&2
  exit 2
fi

app_path="$1"
dmg_path="$2"
: "${CUE_MACOS_TEAM_ID:?Set CUE_MACOS_TEAM_ID}"
: "${CUE_MACOS_CODESIGN_IDENTITY:?Set CUE_MACOS_CODESIGN_IDENTITY}"
: "${CUE_MACOS_NOTARY_API_KEY_PATH:?Set CUE_MACOS_NOTARY_API_KEY_PATH}"
: "${CUE_MACOS_NOTARY_KEY_ID:?Set CUE_MACOS_NOTARY_KEY_ID}"
: "${CUE_MACOS_NOTARY_ISSUER_ID:?Set CUE_MACOS_NOTARY_ISSUER_ID}"

[[ -d "$app_path" && -f "$app_path/Contents/MacOS/Cue" ]] || {
  echo "Expected a built Cue.app at $app_path" >&2
  exit 1
}
[[ -f "$CUE_MACOS_NOTARY_API_KEY_PATH" && "$dmg_path" == *.dmg ]] || {
  echo "Expected a notary API key file and a .dmg output path" >&2
  exit 1
}

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")"
[[ "$bundle_id" == 'top.hylcreative.cue' ]] || {
  echo "Unexpected macOS bundle identifier: $bundle_id" >&2
  exit 1
}

architectures="$(lipo -archs "$app_path/Contents/MacOS/Cue")"
[[ " $architectures " == *' arm64 '* && " $architectures " == *' x86_64 '* ]] || {
  echo "The release app must contain both arm64 and x86_64" >&2
  exit 1
}

codesign --verify --deep --strict --verbose=2 "$app_path"
signature="$(codesign -dv --verbose=4 "$app_path" 2>&1)"
[[ "$signature" == *'Authority=Developer ID Application:'* &&
   "$signature" == *"TeamIdentifier=$CUE_MACOS_TEAM_ID"* &&
   "$signature" == *'runtime'* ]] || {
  echo 'Cue.app needs a Developer ID Application signature with hardened runtime' >&2
  exit 1
}

temp_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/cue-macos-dmg.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/staging" "$(dirname "$dmg_path")"
ditto "$app_path" "$temp_dir/staging/Cue.app"
ln -s /Applications "$temp_dir/staging/Applications"

hdiutil create -srcfolder "$temp_dir/staging" -volname Cue -format UDZO -ov "$dmg_path"
codesign --force --sign "$CUE_MACOS_CODESIGN_IDENTITY" --timestamp \
  --identifier top.hylcreative.cue.dmg "$dmg_path"
codesign --verify --verbose=2 "$dmg_path"

xcrun notarytool submit "$dmg_path" \
  --key "$CUE_MACOS_NOTARY_API_KEY_PATH" \
  --key-id "$CUE_MACOS_NOTARY_KEY_ID" \
  --issuer "$CUE_MACOS_NOTARY_ISSUER_ID" \
  --wait --timeout 1h --output-format json > "$temp_dir/notary-result.json"
python3 - "$temp_dir/notary-result.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as result_file:
    result = json.load(result_file)
status = result.get('status')
print(f"Apple notarization: {status} ({result.get('id', 'no submission ID')})")
if status != 'Accepted':
    raise SystemExit('Apple did not accept this DMG for notarization')
PY

xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
hdiutil verify "$dmg_path" > /dev/null
echo "Ready to publish: $dmg_path"
