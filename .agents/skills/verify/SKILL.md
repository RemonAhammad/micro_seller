---
name: verify
description: Verify a Micro Seller change compiles and is consistent — runs build_runner when models/providers changed, flutter analyze, and the translation parity check, then reports pass/fail. Use after any code change and before saying work is done.
---

# Verify

Run from the repo root. Report each step's result honestly. If something fails, show the relevant output and don't summarise it away.

1. **Codegen, only if needed.** Check whether anything annotated changed:
   `git diff --name-only HEAD | grep -E 'lib/(data/models|.*providers|data/services/isar_service)'`
   If so, run `dart run build_runner build --delete-conflicting-outputs`.
2. **Analyze:** `flutter analyze`. Compare against `main` if needed: the repo has some existing infos and warnings, so only **new** issues in touched files count against the change. Errors always count.
3. **Translations:** `.Codex/skills/l10n/scripts/l10n_parity.sh` must exit 0.
4. **Unit tests:** `flutter test`. `test/dues_test.dart` covers the dues and statement money logic, so run it whenever orders, payments or returns change.
5. **Stray hardcoded strings (heuristic):** for changed presentation files, check
   `git diff -U0 -- 'lib/**/presentation/*.dart' | grep -E "^\+.*Text\('[A-Z]"`. Any hit is probably an unlocalized string.
6. **Optional, when asked or when a flow changed:** `flutter test integration_test` (needs a connected device or emulator), or the `run` skill to launch the app.

## Output
A short table showing each step as ✅, ❌ or skipped, with one line of detail, followed by the failing output if there is any.
