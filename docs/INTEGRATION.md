# Integration and demo walkthrough

## Repository

1. Create branch `1-curated-demo-product-set` from your team's current development base.
2. Copy data/demo, scripts/demo_catalog.py, tests/test_demo_catalog.py, and the documentation into matching repository locations. If those names already exist, compare and merge rather than overwrite. The Python loader assumes its script is one level below the repository root.
3. Add the workflow only if it fits your existing CI setup. Update working-directory/imports if this package lives under a subfolder.
4. Run both README commands. Include results in the PR.

## Swift catalog

1. Add ios/DemoCatalog.swift to the app target in Xcode.
2. Add data/demo/products.json to the app target's resources. Check target membership and Copy Bundle Resources; ensure another products.json is not already present.
3. Load with `let catalog = try DemoCatalog.load()` inside an error-handling path. Display catalog.products in your existing product list. Present fictional labeling in the demo UI.
4. Check that all 17 items load and categories/ingredients are visible. Show provenance in a debug/detail view if applicable. Avoid displaying an SPF badge because spf is null.
5. The Swift adapter loads only products. profiles.json and scenarios.json supply integration/test inputs; their expected_findings may drive mocked Sprint 1 analysis screens. The Python evaluator demonstrates the behavior but does not automatically run inside iOS.

The Swift adapter must be built and exercised in the actual Xcode project. It has not been validated against your app's existing models, file layout, or deployment target.

## Python usage

```python
from scripts.demo_catalog import load, validate, evaluate
catalog = validate(load())
products = {p['id']: p for p in catalog['products']}
profiles = {p['id']: p for p in catalog['profiles']}
scenario = catalog['scenarios'][1]
findings = evaluate([products[i] for i in scenario['product_ids']],
                    profiles[scenario['profile_id']])
assert findings == scenario['expected_findings']
```

## Demo script

| Fixture | Inputs | Expected display |
|---|---|---|
| normal_am | Gel cleanser, hydrating serum, gel moisturizer, mineral sunscreen demo; no recorded allergy | No findings under demo rules |
| caution_pm | Retinol serum + exfoliating treatment | One scripted combination caution |
| allergen_mist | Fragranced mist; profile records Limonene | Exact listed-ingredient allergy match |
| unknown_sunscreen | Sunscreen with unavailable list | Assessment incomplete |
| unknown_mask | Mask with partial list | Assessment incomplete |

Use the documented fixture order for deterministic findings. The sample routine order is a demo input, not evidence of validated layering advice. No live Firebase database import is required by this package. Add persistence separately only if another ticket or your app integration needs it.
