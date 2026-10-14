# DATA-01: Skincare demo dataset

Sprint 1 ticket #1. 17 clearly fictional skincare products with ordered ingredient lists and provenance, two test profiles, five scenario fixtures with expected findings, a dependency-free Python loader/evaluator/validator with tests, a Swift loader used by the app, and a CI workflow.

**Scope:** skincare only. Makeup is deferred. The original ticket requires both skincare and makeup; use docs/ISSUE_SCOPE_UPDATE.md to record the revised criteria before closing it.

## Run the checks

From the repository root with Python 3.10 or newer:

```bash
python3 scripts/demo_catalog.py
python3 -m unittest discover -s tests -v
```

The Swift side is covered by `DemoCatalogTests` in the Xcode unit tests. No Python packages, Firebase account, API key, or network access are needed.

## Contents

- Aesthelity/Aesthelity/Resources/DemoData/products.json: catalog records
- Aesthelity/Aesthelity/Resources/DemoData/profiles.json: synthetic allergy profiles
- Aesthelity/Aesthelity/Resources/DemoData/scenarios.json: routine inputs and expected findings
- Aesthelity/Aesthelity/Models/DemoCatalog.swift: Swift loader for products, profiles, and scenarios
- Aesthelity/Aesthelity/Tests/AesthelityTests/DemoCatalogTests.swift: Swift load tests
- scripts/demo_catalog.py: loader, validator, limited demo evaluator
- tests/test_demo_catalog.py: positive and negative tests
- docs/DATA_DICTIONARY.md: field contract
- docs/PROVENANCE.md: per-product authoring specification
- docs/INTEGRATION.md: Swift usage and demo walkthrough
- docs/ISSUE_SCOPE_UPDATE.md: suggested issue revision
- .github/workflows/data01.yml: dataset CI checks

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
