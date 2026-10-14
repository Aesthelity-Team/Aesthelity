# Suggested DATA-01 issue revision

Title: DATA-01: Build curated skincare demo product set

Scope update: Sprint 1 is skincare only. Makeup is deferred to a future catalog expansion. Clearly fictional products are permitted and must be visibly labeled. Source URLs for fictional records identify the authoring specification; source_ref and provenance identify the local fixture specification. Verification means matching the authored fixture, not external formulation verification.

Revised acceptance criteria:

1. Given the demo dataset is loaded, when the catalog is opened, then it contains representative cleansers, serums (including retinol and vitamin C), treatments, moisturizers, sunscreens, toners, and mists. A partial mask fixture is also included.
2. Given the product, profile, and routine fixtures, when scenarios are evaluated, then normal, caution, recorded-allergen-match, and unknown outcomes are represented.
3. Given a product record is inspected, then its ordered ingredient list or explicit missing-data status, category, source URL, source reference, verification date, and fictional provenance are documented.

Definition of done: dataset and fixture validation pass; product assets load in the app; mocked findings reproduce fixture outcomes; scope update is recorded; PR receives teammate review. Do not close issue #1 against its original makeup requirement without recording this revision.
