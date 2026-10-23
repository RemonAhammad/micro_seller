---
name: sync-docs
description: Keep AGENTS.md accurate after a feature or refactor in Micro Seller — updates the sections covering changed files and fixes statements the code now contradicts. Use when a feature is finished, or when asked to update/audit project docs.
---

# Sync AGENTS.md with the code

AGENTS.md is the project's main context document, so any drift misleads future work.

1. **Scope:** `git diff --name-only main...HEAD` plus any uncommitted changes (`git status --short`). For an audit with no diff, pick the sections the user named.
2. **Map files to sections.** AGENTS.md has an architecture tree (one line per file), a Data Models table, the Order Form UX section, Key Business Flows (one subsection per flow), Navigation, and UI Design. Each changed file usually maps to its tree line and one flow subsection.
3. **For each claim in those sections,** check it against the code with grep, reading the file itself. Fix anything that's wrong, and add anything new: files, fields, routes, flows, collection counts, backup version.
4. **Keep the style.** Keep entries short. Explain *why* for non-obvious choices (the doc already does this, e.g. the MIUI snackbar, the finite `targetSize`). Don't narrate history that git already records.
5. **Report** which sections changed, and list any claims you couldn't verify rather than guessing.

## Known drift (fix on first run)
- Order Creation step 3 says `variantName`/`variantValue`. The model uses `variantCombinationKey` and `variantDisplayLabel`.
- The post-creation invoice sheet says Download confirms with a snackbar. Downloads now use `pdf_saved_sheet.dart`.
- The architecture tree has no entry for `lib/features/scanner/` or for the `/scanner` branch in the router.
