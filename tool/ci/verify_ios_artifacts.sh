#!/usr/bin/env bash
# Checks the unsigned iPhone app (.ipa) before it ships. CI's release job runs
# it on macOS:
#   - a zip holding exactly one Payload/<name>.app, the layout AltStore,
#     SideStore and Sideloadly install from
#   - the bundle ID as given: a sideloaded copy updates in place, keeping its
#     data, only under the same ID, so it must never change
#   - version (CFBundleShortVersionString) and build number (CFBundleVersion)
#     as given
#   - a release build for iPhones (iphoneos): an arm64 executable,
#     Flutter.framework, App.framework (the Dart code) and the .env asset the
#     app loads at startup
#   - Google Sign-In (Drive backup) set up: GIDClientID, and its reversed form
#     as a URL scheme. Without either, tapping Sign In closes the app (a
#     native exception Dart can't catch)
#   - the usage descriptions iOS needs before the app opens the camera or the
#     photo library (else it closes the app) or uses Face ID (else it fails)
#
# Usage: tool/ci/verify_ios_artifacts.sh BUNDLE_ID VERSION BUILD_NUMBER FILE.ipa...
#   VERSION  as Apple sees it: three numbers, no -rc suffix (e.g. 1.0.5)
# Needs macOS (PlistBuddy, plutil, lipo) and unzip.
set -euo pipefail

if [ $# -lt 4 ]; then
  sed -n '2,/^[^#]/{/^#/p;}' "$0" >&2
  exit 2
fi

bundle_id=$1
version=$2
build=$3
shift 3

plistbuddy=/usr/libexec/PlistBuddy
[ -x "$plistbuddy" ] || { echo "no $plistbuddy: run this on macOS" >&2; exit 2; }
for tool in lipo plutil unzip; do
  command -v "$tool" > /dev/null || { echo "$tool not on PATH" >&2; exit 2; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
fail() {
  echo "FAIL $1: $2" >&2
  failures=$((failures + 1))
}

plist() { # file key: the value, or nothing when the key is missing
  "$plistbuddy" -c "Print :$2" "$1" 2> /dev/null || true
}

id="-"
shown_version="-"
min_os="-"
check_app() { # dir label
  local info="$1/Info.plist" short number platform exe archs f gid scheme url_types key
  if [ ! -f "$info" ]; then
    fail "$2" "no Info.plist in the app"
    return
  fi
  id=$(plist "$info" CFBundleIdentifier)
  short=$(plist "$info" CFBundleShortVersionString)
  number=$(plist "$info" CFBundleVersion)
  shown_version="$short ($number)"
  min_os=$(plist "$info" MinimumOSVersion)
  platform=$(plist "$info" DTPlatformName)
  exe=$(plist "$info" CFBundleExecutable)
  [ "$id" = "$bundle_id" ] || fail "$2" "bundle ID ${id:-<none>}, expected $bundle_id"
  [ "$short" = "$version" ] || fail "$2" "version ${short:-<none>}, expected $version"
  [ "$number" = "$build" ] || fail "$2" "build number ${number:-<none>}, expected $build"
  [ "$platform" = iphoneos ] || fail "$2" "built for ${platform:-an unknown platform}, expected iphoneos (devices)"
  [ -n "$min_os" ] || fail "$2" "no MinimumOSVersion"
  if [ -z "$exe" ] || [ ! -f "$1/$exe" ]; then
    fail "$2" "executable '${exe:-<no CFBundleExecutable>}' not found"
  else
    [ -x "$1/$exe" ] || fail "$2" "$exe isn't executable (file modes lost when zipping?)"
    archs=$(lipo -archs "$1/$exe" 2> /dev/null || true)
    case " $archs " in
      *" arm64 "*) ;;
      *) fail "$2" "$exe is built for '${archs:-unknown}', expected arm64" ;;
    esac
  fi
  for f in Frameworks/Flutter.framework/Flutter Frameworks/App.framework/App \
    Frameworks/App.framework/flutter_assets/.env; do
    [ -f "$1/$f" ] || fail "$2" "missing $f"
  done

  gid=$(plist "$info" GIDClientID)
  case $gid in
    ?*.apps.googleusercontent.com)
      scheme="com.googleusercontent.apps.${gid%.apps.googleusercontent.com}"
      url_types=$(plutil -extract CFBundleURLTypes json -o - "$info" 2> /dev/null || true)
      case $url_types in
        *"\"$scheme\""*) ;;
        *) fail "$2" "no URL scheme $scheme (CFBundleURLTypes) for GIDClientID: Google sign-in would close the app" ;;
      esac
      ;;
    '') fail "$2" "no GIDClientID (the iOS OAuth client ID): Google sign-in would close the app" ;;
    *) fail "$2" "GIDClientID '$gid' isn't an iOS OAuth client ID (<id>.apps.googleusercontent.com): Google sign-in would close the app" ;;
  esac
  for key in NSCameraUsageDescription NSPhotoLibraryUsageDescription NSFaceIDUsageDescription; do
    [ -n "$(plist "$info" "$key")" ] || fail "$2" "no $key in Info.plist"
  done
}

table="| File | Bundle ID | Version | Min iOS | Size | Result |"$'\n'
table+="| --- | --- | --- | --- | --- | --- |"$'\n'
for file in "$@"; do
  label=$(basename "$file")
  [ -f "$file" ] || { fail "$label" "file not found"; continue; }
  before=$failures
  id="-"
  shown_version="-"
  min_os="-"
  size=$(awk -v b="$(wc -c < "$file")" 'BEGIN { printf "%.1f MB", b / 1048576 }')
  apps=$( (unzip -Z1 "$file" 2> /dev/null || true) | sed -nE 's|^Payload/([^/]+\.app)/.*|\1|p' | sort -u)
  count=$(printf '%s\n' "$apps" | grep -c . || true)
  if [ "$count" -eq 0 ]; then
    fail "$label" "no Payload/<name>.app inside (not an .ipa?)"
  elif [ "$count" -gt 1 ]; then
    fail "$label" "$count apps in Payload/, expected one"
  else
    rm -rf "$work/x"
    mkdir -p "$work/x"
    if unzip -qq "$file" -d "$work/x"; then
      check_app "$work/x/Payload/$apps" "$label"
    else
      fail "$label" "unzip failed"
    fi
  fi
  result=OK
  [ "$failures" -gt "$before" ] && result=FAIL
  table+="| $label | \`${id:--}\` | $shown_version | ${min_os:--} | $size | $result |"$'\n'
done

printf '%s' "$table"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '### iPhone app\n\n%s\n' "$table" >> "$GITHUB_STEP_SUMMARY"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "All checks passed."
