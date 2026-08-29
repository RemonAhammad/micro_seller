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
<h1 align="center">Hi,  <img src="https://raw.githubusercontent.com/MartinHeinz/MartinHeinz/master/wave.gif" width="70px"> I'm Remon Ahammad</h1>
<h3 align="center">Flutter App developer</h3>

|  Followers | ![GitHub followers](https://img.shields.io/github/followers/remonahammad?logo=GitHub&style=for-the-badge) | Profile views  |<img src="https://komarev.com/ghpvc/?username=remonahammad&label=Profile%20views&color=0e75b6&style=flat" alt="remonahammad" />|
|:-------------:|:-------------:|:-------------:|:-------------:|

| ----------- | ----------- |
|:-------------------:|:-------------:|
| [![Check out remonahammad's profile on stardev.io](https://stardev.io/developers/remonahammad/badge/languages/global.svg)](https://stardev.io/developers/remonahammad) |  <p align="left"><img src="https://i.giphy.com/RThN0hOS2GO4M.gif" /></p> |

-------------------------------

<h3 align="left">About me:</h3>

- 🖥️💻📱 I’m currently working on **Flutter App Development**

- 🖥️💻🌐 I’m currently learning **Flutter Web and App**

- 🎃 I regularly publish my video on **[YouTube](https://www.youtube.com/channel/UCo7eZmGvKyGsIpVPtkLxfjA)**

- 📬 How to reach me **remonahammad@gmail.com**

- 🏸 I love playing **Badminton**

- 🤭 Fun fact **I am not only funny. I am seriously funny.**

<h3 align="left">Connect with me:</h3>
<a href="https://www.linkedin.com/in/remonahammad/">
    <img src="https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white" />
<a href="https://www.facebook.com/remonahammad.personal/">
    <img src="https://img.shields.io/badge/Facebook-1877F2?style=for-the-badge&logo=facebook&logoColor=white" />
<a href="https://www.youtube.com/channel/UCo7eZmGvKyGsIpVPtkLxfjA">
    <img src="https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white" />
 <a href="https://stackoverflow.com/users/18158216/blackshadow">
    <img src="https://img.shields.io/badge/Stack_Overflow-FE7A16?style=for-the-badge&logo=stack-overflow&logoColor=white" />   	 	

### Status & Languages

|   Used Languages    | I have known Languages & Tools   |
|:-------------------:|:-------------:|
|  [![Blackshadow's Top Langs](https://github-readme-stats.vercel.app/api/top-langs/?count_private=true&username=remonahammad&langs_count=10&layout=compact&hide=html,css,c,c%2B%2B,Makefile,java,javascript,cmake,kotlin,ruby,shell,batchfile,powershell,swift,objective-c&theme=dark)](https://github.com/remonahammad?tab=repositories)  | <p align="left"> <a href="https://developer.android.com" target="_blank"> <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/android/android-original-wordmark.svg" alt="android" width="40" height="40"/> </a> <a href="https://dart.dev" target="_blank"> <img src="https://www.vectorlogo.zone/logos/dartlang/dartlang-icon.svg" alt="dart" width="40" height="40"/> </a> <a href="https://firebase.google.com/" target="_blank"> <img src="https://www.vectorlogo.zone/logos/firebase/firebase-icon.svg" alt="firebase" width="40" height="40"/> </a> <a href="https://flutter.dev" target="_blank"> <img src="https://www.vectorlogo.zone/logos/flutterio/flutterio-icon.svg" alt="flutter" width="40" height="40"/> </a> <a href="https://git-scm.com/" target="_blank"> <img src="https://www.vectorlogo.zone/logos/git-scm/git-scm-icon.svg" alt="git" width="40" height="40"/> </a> <a href="https://www.adobe.com/in/products/illustrator.html" target="_blank"> <img src="https://www.vectorlogo.zone/logos/adobe_illustrator/adobe_illustrator-icon.svg" alt="illustrator" width="40" height="40"/> </a> <a href="https://www.java.com" target="_blank"> <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/java/java-original.svg" alt="java" width="40" height="40"/> </a> <a href="https://www.photoshop.com/en" target="_blank"> <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/photoshop/photoshop-line.svg" alt="photoshop" width="40" height="40"/> </a> <a href="https://www.sqlite.org/" target="_blank"> <img src="https://www.vectorlogo.zone/logos/sqlite/sqlite-icon.svg" alt="sqlite" width="40" height="40"/> </a> </p> |

|  Stats      |  Streak  |
|:-------------:|:-------------:| 
| ![Blackshadow's github stats](https://github-readme-stats.vercel.app/api?username=remonahammad&show_icons=true&theme=dark)  | [![Blackshadow's GitHub Streak](https://github-readme-streak-stats.herokuapp.com/?user=remonahammad&theme=dark)](https://github.com/remonahammad?tab=repositories) |

<img src="https://activity-graph.herokuapp.com/graph?username=remonahammad&theme=react-dark&bg_color=20232a&hide_border=true" width="100%"/>

--------------

<img height="120" alt="Thanks for visiting my profile" width="100%" src="https://raw.githubusercontent.com/BrunnerLivio/brunnerlivio/master/images/marquee.svg" />
