#!/usr/bin/env bash
# Puts the values the GitHub release build needs on the clipboard, one at a
# time, so you can paste each into GitHub → Settings → Environments → release.
# It never prints a password or the key; it clears the clipboard when done.
#
# Run it on the Mac you build Play Store releases on, from the project folder:
#   bash tool/ci/copy_release_secrets.sh
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

props=android/key.properties
if [ ! -f "$props" ]; then
  echo "No $props here. Run this on the Mac you build Play Store releases on."
  exit 1
fi
if ! grep -Eq '^GOOGLE_OAUTH_WEB_CLIENT_ID=.+' .env 2> /dev/null; then
  echo "Your .env has no GOOGLE_OAUTH_WEB_CLIENT_ID value. Put your real .env in the"
  echo "project folder first (the ID is in Google Cloud Console → APIs & Services →"
  echo "Credentials → OAuth 2.0 Client IDs → Web client)."
  exit 1
fi

prop() { sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$props" | tail -n 1; }
store_file=$(prop storeFile)
key_alias=$(prop keyAlias)
store_pass=$(prop storePassword)
key_pass=$(prop keyPassword)
for name in storeFile keyAlias storePassword keyPassword; do
  [ -n "$(prop "$name")" ] || { echo "$props has no $name."; exit 1; }
done
# Gradle resolves a relative storeFile from android/app.
[[ $store_file == /* ]] || store_file="android/app/$store_file"
[ -f "$store_file" ] || { echo "Keystore not found: $store_file (storeFile in $props)."; exit 1; }

fingerprint=$(KS_PASS=$store_pass keytool -list -v -keystore "$store_file" -storepass:env KS_PASS \
  -alias "$key_alias" 2> /dev/null | sed -nE 's/^[[:space:]]*SHA256:[[:space:]]*(.*)$/\1/p') || fingerprint=""
if [ -z "$fingerprint" ]; then
  echo "Couldn't open the key. Check storeFile, storePassword and keyAlias in $props."
  exit 1
fi

trap 'printf "" | pbcopy' EXIT # never leave a secret on the clipboard

step=0
give() { # name, value, button
  step=$((step + 1))
  printf '%s' "$2" | pbcopy
  printf '\n%s/6  Copied. In GitHub click "%s"\n     Name:  %s\n     Value: paste (Cmd+V), then save.\n     Press Enter here when done. ' \
    "$step" "$3" "$1"
  read -r _
}

echo "Open GitHub → your repo → Settings → Environments → release."
echo "(No 'release' yet? Click 'New environment' and name it release.)"
give ANDROID_KEYSTORE_PASSWORD "$store_pass" "Add environment secret"
give ANDROID_KEY_PASSWORD "$key_pass" "Add environment secret"
give ANDROID_KEY_ALIAS "$key_alias" "Add environment secret"
give ANDROID_KEYSTORE_BASE64 "$(base64 -i "$store_file")" "Add environment secret"
give DOTENV "$(cat .env)" "Add environment secret"
give ANDROID_SIGNING_CERT_SHA256 "$fingerprint" "Add environment variable"

echo
echo "Done: the release page should list 5 secrets and 1 variable."
echo "Your key's SHA-256: $fingerprint"
echo "(Optional check: Play Console → App integrity → Upload key certificate shows the same.)"
