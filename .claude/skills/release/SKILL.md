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
4. **16 KB alignment check.** Every row must be `0x4000` or `0x10000`:
   ```bash
   LREAD=$ANDROID_HOME/ndk/27.0.12077973/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf
   cd build/app/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib/arm64-v8a
   for f in *.so; do
     align=$("$LREAD" -lW "$f" | awk '/^  LOAD/ {print $NF; exit}')
     printf "%-35s %s\n" "$f" "$align"
   done
   ```
   If any library shows `0x1000`, **fail the release** and name the plugin that ships it. Play Store rejects these for Android 15+.
5. **Report:** the new version, the AAB path and size, the alignment table, and the "Play Console Submission Checklist" items from `RELEASE.md` that apply. Don't commit, tag or upload unless the user asks.
