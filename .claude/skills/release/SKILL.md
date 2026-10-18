---
name: release
description: Build a Play Store release of Micro Seller — bump version, build the obfuscated AAB, and verify 16 KB native-library alignment.
disable-model-invocation: true
---

# Release build

Only run this when the user asks for it. It changes `pubspec.yaml` and builds for several minutes.

1. **Pre-flight:** `git status` should be clean apart from build output. Warn the user if it isn't. `android/key.properties` must exist (it's gitignored, and it points to the upload keystore at `/Users/remon/Documents/upload-keystore.jks`). Run the `verify` skill and stop on errors.
2. **Version:** read `version:` in `pubspec.yaml` (`name+code`). Ask the user for the new version name, default to a patch bump, and **always increment the build code by 1**. Play Store rejects a code it has seen before. Edit the line.
3. **Build:**
   ```bash
   flutter build appbundle --release --obfuscate \
     --split-debug-info=build/debug-info --tree-shake-icons
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`. Keep `build/debug-info` because it's needed to decode obfuscated crash stack traces for this version.
4. **Verify the AAB** with the same script CI's release job runs. It checks that exactly one certificate signed it and that it's the expected upload key (not the debug fallback), and that every LOAD segment of every 64-bit `.so` is aligned to 16 KB:
   ```bash
   NDK_VERSION=27.0.12077973 tool/ci/verify_android_artifacts.sh \
     "<upload cert SHA-256>" <version-name> <build-number> build/app/outputs/bundle/release/app-release.aab
   ```
   The fingerprint is in Play Console → App integrity → Upload key certificate, or `keytool -list -v -keystore … -alias <alias>`. If a library is misaligned, **fail the release** and name the plugin that ships it. Play Store rejects these for Android 15+.
5. **Report:** the new version, the AAB path and size, the verification table, and the "Play Console Submission Checklist" items from `RELEASE.md` that apply. Don't commit, tag or upload unless the user asks. For a **GitHub Release**, the user pushes tag `v<version-name>` after committing the bump: `.github/workflows/release.yml` builds and verifies the signed APKs and drafts the release (RELEASE.md → GitHub Releases).
