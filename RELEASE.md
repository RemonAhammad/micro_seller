# Release Guide — Publishing MicroSeller to Google Play Store

## ✅ Already Configured

- ✅ **Application ID:** `com.blackshadowsoftwareltd.micro_seller`
- ✅ **App name:** MicroSeller
- ✅ **Release signing:** Uses shared keystore at `/Users/remon/Documents/upload-keystore.jks`
- ✅ **key.properties** configured (same keystore as Fuel Cost app)
- ✅ **R8/ProGuard** enabled with minification + shrink resources
- ✅ **Subprojects compileSdk fix** for isar_flutter_libs (matches Fuel Cost pattern)
- ✅ **Core library desugaring** enabled (for flutter_local_notifications)
- ✅ **NDK version** pinned: `27.0.12077973`
- ✅ **enableOnBackInvokedCallback** for predictive back gesture
- ✅ **Kotlin package:** `com.blackshadowsoftwareltd.micro_seller`
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

> **MicroSeller Privacy Policy**
>
> MicroSeller is an offline-first inventory and order management app. All business data is stored locally on your device.
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
