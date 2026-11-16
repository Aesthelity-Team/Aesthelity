# Local Firestore-backed analysis API

This is the local demo backend for the approved AN-02 rules and AN-03 Python
engine. It reads the shared `products` collection with Firebase Admin, returns
raw product ingredient strings to the app, and evaluates normalized routine
requests posted by the app.

## Setup on the development Mac

From the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r Backend/requirements.txt
```

Use the authorized local Application Default Credentials described in
`docs/FIRESTORE_SETUP.md`. No credential file belongs in the repository or the
iOS app. The server uses project `aesthelity-2026` and Firestore database
`ogdb` by default; override with `FIREBASE_PROJECT_ID` and
`FIRESTORE_DATABASE_ID` when needed.

Ingredient aliases come from the approved `ingredientAliasCatalogs/active`
document. The API reads it for each analysis and serves it to clients at
`GET /api/v1/ingredient-aliases`. If the document is absent or Firestore is
unavailable, the backend and iOS app use the bundled reviewed catalog. Seed it
with `python3 Backend/seed_ingredient_aliases.py` to preview. Writing requires
`INGREDIENT_ALIAS_EDITOR` and `--apply`; replacing an existing catalog also
requires `--replace`.

## Full ingredient catalog (EU CosIng)

`Backend/data/cosing_ingredients.json.gz` is a snapshot of the full EU CosIng
ingredient inventory (33,642 rows, retrieved 2026-11-15). The API loads it at
startup, so names outside the approved catalog resolve offline too. Approved
catalog matches always win.

```sh
python3 Backend/import_ingredient_catalog.py            # dry run: counts only, no writes
python3 Backend/import_ingredient_catalog.py --fetch    # refresh the snapshot from CosIng
python3 Backend/import_ingredient_catalog.py --source export.csv   # classic CosIng CSV export
INGREDIENT_ALIAS_EDITOR=<team identity> python3 Backend/import_ingredient_catalog.py --apply
```

`--apply` writes `ingredients/{id}`, `ingredientAmbiguousTerms/{termKey}` and,
last, `ingredientCatalogs/reference` in batches of 400. The full import is about
33,600 document writes, which is more than the Firestore free tier's daily write
quota. If the project is on the free tier, split the import with `--limit N` and
continue later with `--start-after <collection/docId>`. The approved
`ingredientAliasCatalogs/active` document is never changed.

## Using with the #99 analysis engine

`Backend/analysis_engine_input.py` turns resolve results into the input of the
#99 AI analysis engine (`analyze_normalized_routine`), so it needs no changes:

| #98 `mapping` | #99 `status` | Row details |
| --- | --- | --- |
| `confirmed` | `matched` | `canonicalName` is the approved catalog name |
| `uncertain` | `uncertain` | `proposedName` is the CosIng name; never analyzed (PD-03) |
| `unmatched` | `unknown` | `reason` is `not_in_catalog` or `empty_input` |
| `ambiguous` | `unknown` | `reason` lists the candidate IDs |

Every row keeps its `index` and exact `originalText`. `listStatus` is whatever
the caller sends; without one, an empty list is `unavailable` and anything else
is `partial`, because a scan alone does not prove the whole label was read.
Send `complete` only when the full list is known.

```python
from Backend.analysis_engine_input import analysis_product, analysis_normalization, canonical_records

product = analysis_product("serum", resolve_rows, approved_catalog, list_status="complete")
normalization = analysis_normalization([product], catalog_version=approved_catalog["version"])
records = canonical_records(approved_catalog)   # pass as canonical_records
```

`canonical_records` defaults to the approved catalog, which covers every
`matched` row and keeps names unique. `include_reference=True` adds the full
CosIng list and drops any name that would clash.

Over HTTP, add `"format": "analysis-input"` (plus optional `productID` and
`listStatus`) to `POST /api/v1/ingredients/resolve`. The response gains an
`analysisInput` field with the normalization envelope; the existing fields do
not change.

## AI fallback for unresolved names

Catalog lookup always runs first. Sending `"ai": true` on
`POST /api/v1/ingredients/resolve` also sends unmatched or ambiguous rows
(and noisy OCR text) to an OpenRouter model. The model can only propose a
name; that name is looked up in the catalog again. An approved hit becomes
`confirmed` with reason `ai-suggested + approved match`. A CosIng-only hit
stays `uncertain`. Anything else stays unmatched. The model never assigns
an ingredient ID.

Set `OPENROUTER_API_KEY` in the gitignored `Backend/.env`. Optional:
`AESTHELITY_NORMALIZATION_MODEL` (default `nvidia/nemotron-3.5-super-vl:free`)
and `AESTHELITY_NORMALIZATION_FALLBACK_MODEL` (default
`google/gemma-4-31b-it:free`). The flag defaults to off, so existing clients
are unchanged. Timeouts, rate limits, and invalid responses leave the
lookup-only rows in place and set `providerStatus` to a sanitized failure
code. The result still goes through `analysis_engine_input` into the #99
engine.

## Start the simulator demo

```sh
AESTHELITY_DEMO_MODE=1 python Backend/analysis_api.py
```

The server binds to `127.0.0.1:8765`. The Xcode app target is configured to use
that local address. Demo mode skips Firebase ID-token verification for the
analysis request because the current app has no Firebase sign-in flow. It is
restricted to loopback and must not be exposed or deployed.

The app's Analysis sheet offers four real API scenarios:

- Caution PM: `serum_retinol` and `treatment_exfoliant`.
- No findings AM: cleanser, vitamin C serum, moisturizer, and mineral sunscreen.
- Recorded-allergy example: fragranced mist and a demo allergy to limonene.
- Partial-data example: `mask_partial`.

For each run, the app gets product documents from `GET /api/v1/products`,
loads the current alias catalog from `GET /api/v1/ingredient-aliases`,
normalizes the original ingredient strings deterministically, then posts the
normalized product objects to `POST /api/v1/analyses`. The server verifies the
catalog version through the active catalog and returns findings for display.
Scenarios are labeled demo data; they are not a saved personal routine or
profile.

## Routes

- `GET /health`: API, rule, catalog, and Firestore database identifiers.
- `GET /api/v1/ingredient-aliases`: current approved alias catalog for deterministic client normalization.
- `POST /api/v1/ingredients/resolve`: `{"contractVersion": 1, "ingredients": [...]}` (max 200 strings). Each row keeps `originalText` and returns `confirmed` (approved catalog), `uncertain` with `suggestedID` (identified in CosIng but not approved for analysis), `ambiguous` with `candidateIDs`, or `unmatched`. Optional `"format": "analysis-input"` adds the #99 envelope. Optional `"ai": true` runs the OpenRouter name fallback on unresolved rows only. Requires the same auth as analyses.
- `GET /api/v1/ingredients/{ingredientID}`: one full-catalog ingredient (CAS, functions, CosIng sources).
- `GET /api/v1/products`: shared catalog records in API camelCase.
- `GET /api/v1/products/{productID}`: one shared product.
- `POST /api/v1/analyses`: evaluate one normalized AM or PM routine.

Outside local demo mode, analysis requests require a valid Firebase ID token.
Production hosting, app sign-in, and user-specific data access need deployment
configuration and security review.
