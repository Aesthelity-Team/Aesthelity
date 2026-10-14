# Integration and demo walkthrough

## Swift catalog

The JSON files live in `Aesthelity/Aesthelity/Resources/DemoData/` and are bundled with the app automatically. `Aesthelity/Aesthelity/Models/DemoCatalog.swift` loads all three:

```swift
let catalog = try DemoCatalog.load()
let scenario = catalog.scenarios.first { $0.id == "caution_pm" }
let names = scenario?.productIds.compactMap { catalog.product(id: $0)?.name }
```

- Show fictional labeling in the UI, and don't show an SPF badge (spf is null).
- `expectedFindings` on each scenario carry user-facing `category`, `explanation`, and `reason` text for the Sprint 1 mocked analysis screen. The Python evaluator generates the same findings but does not run inside iOS.
- `DemoCatalogTests` checks that the bundled data loads and that scenario references resolve.

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
