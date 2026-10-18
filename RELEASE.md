# Release Guide — Publishing Micro Seller to Google Play Store

## ✅ Already Configured

- ✅ **Application ID:** `com.blackshadowsoftware.micro_seller`
- ✅ **App name:** Micro Seller
- ✅ **Release signing:** Uses shared keystore at `/Users/remon/Documents/upload-keystore.jks`
- ✅ **key.properties** configured (same keystore as Fuel Cost app)
- ✅ **R8/ProGuard** enabled with minification + shrink resources
- ✅ **Subprojects compileSdk fix** for isar_flutter_libs (matches Fuel Cost pattern)
- ✅ **Core library desugaring** enabled (for flutter_local_notifications)
- ✅ **NDK version** pinned: `27.0.12077973`
- ✅ **enableOnBackInvokedCallback** for predictive back gesture
- ✅ **Kotlin package:** `com.blackshadowsoftware.micro_seller`
- ✅ **Release build verified:** APK (86.9 MB) + AAB (62.3 MB) both build and sign correctly
- ✅ **Signing verified:** CN=Rimon Ahammad

---

## Before Publishing

### 1. Add Launcher Icon

Place your icon files at:

- `assets/icons/app_icon.png` (1024×1024 PNG, main icon)
- `assets/icons/app_icon_foreground.png` (optional, for adaptive icon foreground — use transparent background, keep content in inner 66%)

Then run:

```bash
flutter pub get
dart run flutter_launcher_icons
```

### 2. Bump Version Before Each Release

`pubspec.yaml`:

```yaml
version: 1.0.0+1
#         ^      ^
#         |      versionCode (must increase every upload to Play Store)
#         versionName (what users see)
```

### 3. Privacy Policy (REQUIRED)

Host a privacy policy at a public URL. Minimum content:

> **Micro Seller Privacy Policy**
>
> Micro Seller is an offline-first inventory and order management app. All business data is stored locally on your device.
>
> **Data Collection:** We do not collect any personal data, analytics, or telemetry.
>
> **Google Drive Backup (Optional):** If enabled, data is uploaded to your own Google Drive account. We never access this data.
>
> **Permissions:** Internet (Google Drive only), Camera (QR scanner), Photos/Storage (product images).
>
> **Contact:** [your-email]
>
> Last updated: [date]

You can create a `privacy_policy.html` file (like Fuel Cost has) and host it on GitHub Pages.

### 4. Google Drive OAuth (if using backup feature)

Add the release keystore SHA-1 to your Google Cloud project's OAuth credentials:

```bash
keytool -list -v -keystore /Users/remon/Documents/upload-keystore.jks -alias upload
```

Copy the SHA-1 fingerprint and add it in Google Cloud Console → APIs & Services → Credentials → your OAuth client.

---

## Build & Upload

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.

---

## Play Console Submission Checklist

### Store Listing

- [ ] **Short description** (80 chars): `Offline inventory & order management for small sellers`
- [ ] **Full description** (4000 chars)
- [ ] **App icon** (512×512 PNG)
- [ ] **Feature graphic** (1024×500 PNG)
- [ ] **Phone screenshots** (min 2)
- [ ] **Category:** Business
- [ ] **Privacy policy URL**

### Content Rating

- [ ] Fill questionnaire (no violence, no ads → "Everyone")

### Data Safety

- [ ] Data collected: **No**
- [ ] Data shared: **None**
- [ ] If using Drive backup: "User data backed up to user's own Drive"
- [ ] Encryption in transit: **Yes**

### Other Declarations

- [ ] Target age: 18+
- [ ] Contains ads: **No**
- [ ] App access: All features available without login

---

## Recommended Release Path

1. Upload to **Internal testing** first (instant, no review)
2. Install on your phone via the Play Console test link
3. Test all features (orders, purchases, Drive backup, etc.)
4. Promote to **Production** when satisfied

---

## Future Updates

Each release:

1. Bump version in `pubspec.yaml` (e.g. `1.0.0+1` → `1.0.1+2`)
2. `flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs`
3. `flutter build appbundle --release`
4. Upload AAB to Play Console → Production → Create new release
5. Write release notes (max 500 chars)

CI can build the same AAB for you: see **GitHub Releases (CI/CD)** below.

---

## GitHub Releases (CI/CD)

GitHub Actions checks every change and publishes signed APKs as GitHub Releases, so anyone can download Micro Seller from the repo's Releases page. Play Store uploads stay manual, but you can upload the AAB that CI builds.

### What runs when

| Trigger | Workflow | Result |
| --- | --- | --- |
| Pull request, push to `main` | `.github/workflows/ci.yml` | Checks: dependencies match `pubspec.lock`, generated code is committed, translation parity, `flutter analyze` (errors and warnings fail), `flutter test` with no skipped tests |
| Tag `vX.Y.Z` | `.github/workflows/release.yml` | The checks, then a signed AAB and APKs (universal, arm64-v8a, armeabi-v7a, x86_64) with `SHA256SUMS.txt`, verified, then a **draft** release that you publish by hand |
| Actions → Release → Run workflow (on `main`) | `.github/workflows/release.yml` | The same signed build as artifacts only, kept 3 days; no release |

CI uses Flutter **3.44.9**, pinned in `.github/actions/setup-flutter/action.yml`, and the committed `pubspec.lock`. If you move to another Flutter version, change it there too.

### One-time setup

1. **Settings → Actions → General**:
   - Workflow permissions: "Read repository contents". Untick "Allow GitHub Actions to create and approve pull requests".
   - Actions permissions: allow GitHub-created actions plus `subosito/flutter-action@*`.
   - Fork pull requests: "Require approval for all external contributors".
2. **Settings → Environments → New environment `release`**:
   - Required reviewers: yourself.
   - Deployment branches and tags: "Selected branches and tags", then add branch `main` and tag `v*`.
3. **Environment secrets and variable**, from the Mac that has the keystore (`brew install gh`, then `gh auth login`). Check the key alias first with `keytool -list -keystore /Users/remon/Documents/upload-keystore.jks`.

   ```bash
   R=RemonAhammad/micro_seller
   base64 -i /Users/remon/Documents/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64 --env release -R $R
   gh secret set ANDROID_KEYSTORE_PASSWORD --env release -R $R   # prompts for the value
   gh secret set ANDROID_KEY_PASSWORD --env release -R $R
   gh secret set ANDROID_KEY_ALIAS --env release -R $R --body "<alias>"
   gh secret set DOTENV --env release -R $R < .env               # the real .env
   gh variable set ANDROID_SIGNING_CERT_SHA256 --env release -R $R --body "<SHA-256>"
   ```

   - **`ANDROID_SIGNING_CERT_SHA256`:** the upload key's certificate fingerprint, from Play Console → App integrity → App signing → **Upload key certificate**, or `keytool -list -v … -alias <alias>`. Colons and case don't matter. CI refuses to build with, or ship anything signed by, any other key.
   - **`DOTENV`:** must contain `GOOGLE_OAUTH_WEB_CLIENT_ID`, or the release fails (Drive sign-in needs it). Like a local build's `.env`, it ends up as plain text inside the APK.
   - **Passwords:** they go into `key.properties` exactly as stored, so avoid a backslash in them (a Java-properties escape).
4. **Settings → Rules → Rulesets → New tag ruleset**: target `v*`; restrict creations, updates and deletions; block force pushes; bypass list: Repository admin.
5. Optional: **Settings → General → Releases**, turn on release immutability.

### Cutting a release

1. **Bump the version.** Change `version:` in `pubspec.yaml` (the `release` skill does it), e.g. `1.0.4+9` → `1.0.5+10`; the build number must always grow. Commit, push, and wait for CI to pass.
2. **Tag and push.** Tag the commit on `main` and push the tag, one tag at a time:

   ```bash
   git tag -a v1.0.5 -m "Micro Seller 1.0.5"
   git push origin v1.0.5
   ```

   The tag must equal `v` plus the version name in `pubspec.yaml` (the part before `+`). A name with a `-`, like `1.0.5-rc.1+10` tagged `v1.0.5-rc.1`, becomes a pre-release.
3. **Approve.** Open the run under **Actions** and approve the `release` environment when asked.
4. **Publish.** When the run finishes, a **draft** release waits on the Releases page with the four APKs and `SHA256SUMS.txt`. Review it, then click **Publish release**. Re-running the workflow refreshes a draft; a published release never changes.
5. **Collect the artifacts.** From the run's **Artifacts**:
   - **`play-bundle`:** the AAB, signed with the upload key. Upload it to Play Console as usual.
   - **`symbols`:** each build's `--split-debug-info` output and R8 `mapping.txt`. You need them to decode obfuscated crash stack traces (`flutter symbolize`). Artifacts expire after 90 days, so **download and archive** them.

### Installing a GitHub APK

- **Which APK:** `micro-seller-vX-universal.apk` runs on every phone. `-arm64-v8a` is smaller and fits most phones; `armeabi-v7a` is for old 32-bit phones and `x86_64` for emulators and Chromebooks.
- **Stay on one file type.** Flutter numbers split APKs `1000 × ABI + build number`, so a phone on the arm64 APK can't move to the universal one: Android sees it as a downgrade.
- **Play installs.** The Play Store version is signed by Google's key, so a GitHub APK can't update a Play install, or the other way round. To switch: back up (Drive or local backup), uninstall, then install.
- **Updates.** Play in-app updates and in-app review don't work for GitHub installs; both fail silently. Users update by downloading the next release.

### Troubleshooting

| Failure | Fix |
| --- | --- |
| `Generated files are out of date` | Run `dart run build_runner build --delete-conflicting-outputs` and commit the result. |
| `pub get --enforce-lockfile` fails | `pubspec.lock` doesn't match `pubspec.yaml`. Run `flutter pub get` with Flutter 3.44.9 and commit both files. |
| `N test(s) skipped` | The real-Isar tests couldn't load the Isar core library, and they must run in CI. |
| `Tag vX doesn't match pubspec.yaml` | Delete the tag (`git push --delete origin vX`, which needs the ruleset bypass), fix the version, and tag again. |
| `Alias … holds certificate …, expected …` | Wrong keystore or alias secret, or a wrong `ANDROID_SIGNING_CERT_SHA256`. |
| `REQUIRE_RELEASE_SIGNING=true but android/key.properties is missing` | The signing step didn't run; check the environment secrets. |
| `vX is already published` | Releases are final: bump the version and push a new tag. |

To check a local build with the same checks as CI (signer, version, 16 KB alignment), run `tool/ci/verify_android_artifacts.sh <cert-sha256> <version-name> <build-number> <apk-or-aab>...`.
