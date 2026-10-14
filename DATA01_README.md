# DATA-01: Skincare demo dataset

Prepared for Belle Lopez’s Sprint 1 ticket #1. This package provides 17 clearly fictional skincare products, ordered ingredient lists, provenance, two test profiles, five scenario fixtures, a dependency-free Python loader/evaluator/validator, 11 tests, a Swift decoding adapter, and a CI workflow.

**Scope:** skincare only, as requested. Makeup is deferred. The original ticket requires both skincare and makeup; use docs/ISSUE_SCOPE_UPDATE.md to record the revised criteria before closing it.

## Run the checks

From this folder with Python 3.10 or newer:

```bash
python3 scripts/demo_catalog.py
python3 -m unittest discover -s tests -v
```

No Python packages, Firebase account, API key, or network access are needed.

## Contents

- data/demo/products.json: catalog records
- data/demo/profiles.json: synthetic allergy profiles
- data/demo/scenarios.json: routine inputs and expected findings
- scripts/demo_catalog.py: loader, validator, limited demo evaluator
- tests/test_demo_catalog.py: positive and negative tests
- ios/DemoCatalog.swift: Swift product decoder and bundle loader
- docs/DATA_DICTIONARY.md: field contract
- docs/PROVENANCE.md: per-product authoring specification
- docs/INTEGRATION.md: installation and demo walkthrough
- docs/ISSUE_SCOPE_UPDATE.md: suggested issue revision
- docs/PR_DESCRIPTION.md: ready-to-copy PR body
- docs/COMPLETION_CHECKLIST.md: evidence and remaining steps
- docs/VALIDATION_RESULTS.txt: actual Python check output
- .github/workflows/data01.yml: optional repository CI workflow

## Coverage

| Category | Count | Notes |
|---|---:|---|
| Cleanser | 2 | Gel and oil |
| Serum | 4 | Hydrating, niacinamide, retinol, vitamin C |
| Treatment | 2 | Exfoliating and spot |
| Moisturizer | 2 | Gel and cream |
| Sunscreen | 2 | Fictional mineral example and unavailable list |
| Toner | 2 | Hydrating and exfoliating |
| Mist | 2 | Plain and recorded-allergen example |
| Mask | 1 | Intentionally partial list |

These formulas are synthetic software fixtures, not verified market products. No SPF or clinical efficacy is asserted. The caution rule is a scripted test behavior, not researched medical guidance. Retinol alone producing no demo finding does not establish safety. No production recommendation engine is included.

## Handoff

Create branch `1-curated-demo-product-set`, copy the package files into your repository, reconcile existing paths/imports, run the checks, and open a PR for review. Do not overwrite existing files without comparing them. See the integration guide for the Swift setup. This package has not been committed to the remote repository or reviewed by a teammate.
