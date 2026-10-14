# Data contract, version 1

JSON files are UTF-8 objects with schema_version = 1 and a named array.

| Field | Type / rule |
|---|---|
| id | Nonempty unique string; stable across revisions |
| name, brand | Nonempty display strings; names explicitly mark fictional products |
| category | cleanser, serum, treatment, moisturizer, sunscreen, toner, mist, mask |
| subtype | Nonempty string; retinol and vitamin_c are serum subtypes |
| ingredients | Ordered array of nonempty ingredient strings; no inferred concentrations |
| ingredient_list_status | complete, partial, unavailable; unavailable requires empty array |
| is_fictional | true in this release |
| source_url | HTTPS authoring-specification URL; not a manufacturer source |
| source_ref | Local provenance document plus product anchor |
| verified_on | ISO date; fixture verification date |
| provenance | kind, verification_method, note; identifies synthetic origin |
| spf | null; no tested sun-protection claim |

Profiles contain id and recorded_allergens (strings). Scenarios contain id, scenario_type (normal/caution/allergen/unknown), product_ids, profile_id, routine_time (am/pm), and expected_findings. Findings contain kind (caution/allergen/unknown), product_ids, ingredient (string or null), message (developer-facing rule note), category (short user-facing label), explanation (plain-language text shown to users), and reason (why the finding was generated).

In Swift (`Models/DemoCatalog.swift`), category, ingredient_list_status, scenario_type, routine_time, and finding kind decode into enums. Adding a new value to the JSON requires adding the matching enum case, the Python rules, and tests in the same change, or loading fails.

A product is never assigned a universal safety rating. Normal means no findings under these limited demo rules. Partial lists can match known allergens but cannot exclude other allergens. Scenario expectation data belongs to test/demo assets, not to authoritative product facts.
