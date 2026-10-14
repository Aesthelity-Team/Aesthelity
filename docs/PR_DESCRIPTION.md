# Add curated skincare demo dataset and scenario coverage

Provides 17 clearly fictional skincare product records for the Sprint 1 catalog, including cleansers, serums, retinol, vitamin C, treatments, moisturizers, sunscreens, toners, mists, and a mask. Ordered ingredient lists, missing-data status, and per-product provenance make the demo inputs inspectable.

Adds two synthetic user profiles and five fixtures for normal, scripted caution, recorded-allergen match, unavailable ingredients, and partial ingredients. Product facts remain separate from scenario expectations. Includes a dependency-free Python evaluator/validator, 11 tests, an optional CI workflow, a Swift catalog decoder, and integration documentation.

Validation: Python dataset validation passes (17 products, 2 profiles, 5 scenarios); all 11 unittest cases pass. Actual Xcode build and in-app catalog/analysis verification remain pending.

Scope: skincare only at Belle’s request; makeup deferred. Record docs/ISSUE_SCOPE_UPDATE.md in issue #1 before closure. Formulas are synthetic test inputs and no clinical efficacy/SPF claims are made. Source URLs identify the authoring ticket, not manufacturer evidence.

Refs #1. Do not add a closing keyword until app integration, scope revision, and teammate review are complete.
