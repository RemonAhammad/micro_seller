---
name: l10n
description: Add or change a user-visible string in Micro Seller. Use whenever UI text is added, renamed or reworded — every visible string must exist in all 12 translation files plus an AppStrings getter. Also use to check or repair translation parity.
---

# Adding a localized string

The app has 12 locales (en, bn, ar, es, fr, pt, tr, id, th, vi, ur, ms). `translations_en.dart` is the source of truth. `AppLocalizations.tr` falls back to English and then to the raw key, so a key missing from a locale shows English text instead of that language. Parity is still required.

## Steps

1. **Pick a key.** Use lowerCamelCase, and check it doesn't already exist:
   `grep -n "'<key>'" lib/core/l10n/translations_en.dart`. Reuse an existing key when the English text matches.
2. **Add it to `lib/core/l10n/translations_en.dart`** under the section comment for its feature (`// Navigation`, `// Dashboard`, …). Add a new `// <Feature>` section when there isn't one.
3. **Add an accessor to `_L10nStrings`** in `lib/core/constants/app_strings.dart`:
   - Plain: `String get dueBook => _l10n.tr('dueBook');`
   - Parameterized: write `{count}` / `{name}` placeholders in the text and add a helper in the style of `productsFoundToImport`:
     `String daysOverdue(int n) => _l10n.tr('daysOverdue').replaceAll('{count}', '$n');`
   - For one-off strings, `s.tr('key')` at the call site is acceptable, but prefer a getter.
4. **Translate into the other 11 files.** Delegate to the `translator` agent and pass it the keys plus their English values. Doing it inline is fine for one or two keys. Keep placeholders exactly as written, and leave brand and payment names (bKash, Nagad, WhatsApp) untranslated.
5. **Use it:** `final s = AppStrings.of(context); Text(s.dueBook)`. Never hardcode a visible string in a widget.
6. **Check parity:** `.Codex/skills/l10n/scripts/l10n_parity.sh` must exit 0.

## Notes
- The `static const` block at the top of `AppStrings` is legacy (English-only). Don't add to it.
- Text sent to customers (WhatsApp messages, PDFs) is also localized. It's rendered in the seller's chosen app language.
- Arabic and Urdu are right-to-left. Strings containing numbers or currency should read correctly when mirrored, so avoid building sentences by concatenation. Use one template with placeholders instead.
