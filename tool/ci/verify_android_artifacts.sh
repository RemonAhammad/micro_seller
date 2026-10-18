#!/usr/bin/env bash
# Checks Android release artifacts before they ship. CI's release job and the
# local release skill run the same checks:
#   - signed by exactly one certificate: the expected upload key, never the
#     debug key the Gradle build falls back to without android/key.properties
#   - version name / code as in pubspec.yaml (Flutter gives split APKs
#     1000 × ABI + code: armeabi-v7a 1, arm64-v8a 2, x86_64 4)
#   - 16 KB pages (Play requires them for Android 15+): `zipalign -P 16`, and
#     every ELF LOAD segment of every 64-bit .so (arm64-v8a, x86_64) aligned
#     to >= 0x4000
#
# Usage: tool/ci/verify_android_artifacts.sh CERT_SHA256 VERSION_NAME VERSION_CODE FILE...
#   CERT_SHA256  expected signing-certificate SHA-256 (any case, colons optional)
#   FILE         .apk or .aab; a split APK is recognised by the ABI in its name
# Env: ANDROID_HOME (or ANDROID_SDK_ROOT); BUILD_TOOLS (default 36.0.0);
#      NDK_VERSION (optional: use that NDK's llvm-readelf). keytool must be on PATH.
set -euo pipefail

if [ $# -lt 4 ]; then
  sed -n '2,17p' "$0" >&2
  exit 2
fi

norm() { tr -d ': \n\t' | tr '[:upper:]' '[:lower:]'; }
expected=$(printf '%s' "$1" | norm)
version_name=$2
version_code=$3
shift 3

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
[ -n "$sdk" ] || { echo "ANDROID_HOME is not set" >&2; exit 2; }
bt="$sdk/build-tools/${BUILD_TOOLS:-36.0.0}"
for tool in apksigner aapt2 zipalign; do
  [ -x "$bt/$tool" ] || { echo "missing $bt/$tool" >&2; exit 2; }
done
command -v keytool > /dev/null || { echo "keytool not on PATH" >&2; exit 2; }

readelf_bin=""
if [ -n "${NDK_VERSION:-}" ]; then
  for candidate in "$sdk/ndk/$NDK_VERSION"/toolchains/llvm/prebuilt/*/bin/llvm-readelf; do
    [ -x "$candidate" ] && readelf_bin=$candidate
  done
fi
[ -n "$readelf_bin" ] || readelf_bin=$(command -v llvm-readelf || command -v readelf || true)
[ -n "$readelf_bin" ] || { echo "no readelf: set NDK_VERSION or install binutils" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
fail() {
  echo "FAIL $1: $2" >&2
  failures=$((failures + 1))
}

abi_offset() {
  case $1 in
    *armeabi-v7a*) echo 1 ;;
    *arm64-v8a*) echo 2 ;;
    *x86_64*) echo 4 ;;
    *) echo 0 ;;
  esac
}

signer=""
check_signer() { # file label
  local digests count
  if [[ $1 == *.aab ]]; then
    if ! keytool -printcert -jarfile "$1" > "$work/certs.txt" 2>&1; then
      fail "$2" "keytool can't read its signature"
      return
    fi
    digests=$(sed -nE 's/^[[:space:]]*SHA256:[[:space:]]*(.*)$/\1/p' "$work/certs.txt")
  else
    if ! "$bt/apksigner" verify --print-certs "$1" > "$work/certs.txt" 2>&1; then
      fail "$2" "apksigner verify failed: $(tail -n 3 "$work/certs.txt")"
      return
    fi
    digests=$(sed -nE 's/^Signer #[0-9]+ certificate SHA-256 digest:[[:space:]]*(.*)$/\1/p' "$work/certs.txt")
  fi
  count=$(printf '%s\n' "$digests" | grep -c . || true)
  if [ "$count" -ne 1 ]; then
    fail "$2" "expected exactly 1 signer, found $count"
    return
  fi
  signer=$(printf '%s' "$digests" | norm)
  [ "$signer" = "$expected" ] || fail "$2" "signed by $signer, expected $expected"
}

version=""
check_version() { # apk label
  local want vc vn
  want=$(( $(abi_offset "$1") * 1000 + version_code ))
  "$bt/aapt2" dump badging "$1" > "$work/badging.txt"
  vc=$(sed -nE "1s/.* versionCode='([0-9]+)'.*/\1/p" "$work/badging.txt")
  vn=$(sed -nE "1s/.* versionName='([^']*)'.*/\1/p" "$work/badging.txt")
  version="$vn ($vc)"
  [ "$vn" = "$version_name" ] || fail "$2" "versionName $vn, expected $version_name"
  [ "$vc" = "$want" ] || fail "$2" "versionCode $vc, expected $want"
}

libs=0
check_alignment() { # file label
  local prefix=lib so align
  [[ $1 == *.aab ]] && prefix=base/lib
  if [[ $1 == *.apk ]] && ! "$bt/zipalign" -c -P 16 4 "$1" > "$work/zipalign.txt" 2>&1; then
    fail "$2" "zipalign -c -P 16 4: $(tail -n 3 "$work/zipalign.txt")"
  fi
  rm -rf "$work/x"
  mkdir -p "$work/x"
  unzip -qq -o "$1" "$prefix/arm64-v8a/*" "$prefix/x86_64/*" -d "$work/x" 2> /dev/null || true
  libs=0
  while IFS= read -r -d '' so; do
    libs=$((libs + 1))
    while read -r align; do
      if (( align < 0x4000 )); then
        fail "$2" "$(basename "$so") has a LOAD segment aligned to $align (< 0x4000)"
      fi
    done < <("$readelf_bin" -lW "$so" | awk '$1 == "LOAD" {print $NF}')
  done < <(find "$work/x" -name '*.so' -print0)
  # Only the 32-bit split has no 64-bit libraries.
  if [ "$libs" -eq 0 ] && [[ $1 != *armeabi-v7a* ]]; then
    fail "$2" "no 64-bit native libraries found"
  fi
}

table="| File | Signer SHA-256 | Version | 64-bit .so (all LOAD ≥ 16 KB) | Result |"$'\n'
table+="| --- | --- | --- | --- | --- |"$'\n'
for file in "$@"; do
  label=$(basename "$file")
  [ -f "$file" ] || { fail "$label" "file not found"; continue; }
  before=$failures
  signer="-"; version="-"; libs=0
  check_signer "$file" "$label"
  [[ $file == *.apk ]] && check_version "$file" "$label"
  check_alignment "$file" "$label"
  result=OK
  [ "$failures" -gt "$before" ] && result=FAIL
  table+="| $label | \`${signer:0:16}…\` | $version | $libs | $result |"$'\n'
done

printf '%s' "$table"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '### Android artifacts\n\n%s\n' "$table" >> "$GITHUB_STEP_SUMMARY"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "All checks passed."
