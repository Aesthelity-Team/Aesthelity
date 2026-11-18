# PL-04 API and Data Contract

**Status:** Contract version 1. The `POST /api/v1/analyses` section below is the #114 body Najih should decode (`ruleVersion` `ai-analysis-v1`). An AI failure returns `outcome` `unknown` / `completeness` `incomplete` and does not fall back to AN-02.
**Contract version:** 1
**Scope:** #26 layering is out of this response. There is no recommended order field.

## Proposed architecture

The iOS app gets shared products through a backend API. It normalizes ingredient strings using the versioned alias catalog and sends a normalized routine to the analysis API. The backend validates the request and runs the analysis engine.

The app does not access Firestore directly. The backend owns Firestore access and keeps Firebase Admin credentials off the client. This draft assumes the Python analysis engine runs behind the backend API. If the team chooses to run analysis in Swift, keep the JSON contract and revise the runtime plan.

All API payloads use UTF-8 JSON and camelCase keys. The backend maps Firestore snake_case fields to API fields.

## Authentication

- `GET /api/v1/products` and `GET /api/v1/products/{productID}` are read-only and return shared catalog data only.
- `POST /api/v1/analyses` requires `Authorization: Bearer <Firebase ID token>`.
- The backend verifies the token and gets the user UID from it. Requests must not supply a trusted UID in the body.
- Future private profile, routine, or saved-analysis endpoints must verify that records belong to the authenticated UID.

## Product endpoints

`GET /api/v1/products` returns `200` with:

    {
      "contractVersion": 1,
      "products": [
        {
          "id": "cleanser_gel",
          "name": "Fictional Gel Cleanser",
          "brand": "Aesthelity Demo",
          "category": "cleanser",
          "subtype": "cleanser",
          "ingredients": ["Water", "Glycerin"],
          "ingredientListStatus": "complete",
          "isFictional": true,
          "sourceUrl": "https://example.invalid/product-spec",
          "sourceRef": "docs/PROVENANCE.md#cleanser_gel",
          "verifiedOn": "2026-10-01",
          "provenance": {
            "kind": "team_authored_fixture",
            "verificationMethod": "synthetic",
            "note": "Example fixture"
          },
          "spf": null
        }
      ]
    }

`GET /api/v1/products/{productID}` returns `200` with the same product shape under `product`. A missing product returns `404 PRODUCT_NOT_FOUND`.

`ingredients` preserves original text and label order. Product responses do not claim ingredient names have been normalized.

## Analysis endpoint

`POST /api/v1/analyses` requires `Authorization: Bearer <Firebase ID token>`, `Content-Type: application/json`, and a UTF-8 JSON object. `contractVersion` must be the number `1`. The body must be from 1 to 1,000,000 bytes. The wired endpoint accepts at most 50 products and 200 ingredient rows. Over those limits, or any malformed field, the response is `400` `INVALID_REQUEST`. Missing, invalid, or revoked tokens are `401`. Another user's private data is `403`. Provider and reference-store failures are `500` or `503` with a generic message and no provider text.

The request the iOS client sends today (`NormalizedIngredient.encode`) is:

    {
      "contractVersion": 1,
      "period": "pm",
      "recordedAllergies": {
        "status": "known",
        "ingredientIDs": ["limonene"]
      },
      "products": [
        {
          "productID": "fictional_retinol_serum",
          "listStatus": "complete",
          "catalogVersion": 3,
          "ingredients": [
            {
              "originalText": "Retinol",
              "mapping": "confirmed",
              "ingredientID": "retinol"
            }
          ]
        }
      ]
    }

`period` is exactly `am` or `pm`. Any other string, including `AM` or `PM`, is `400`. The response `period` is that same string.

`recordedAllergies.status` is `known` or `unknown`.

- `known` requires `ingredientIDs`, an array of unique canonical slugs. `[]` means no allergies are recorded.
- `unknown` must omit `ingredientIDs`. A present key, including `[]` or `null`, is `400`. Unknown is not an empty allergy list.

`coapplication` is optional. Allowed values are `mixed`, `not-mixed`, and `unknown`. Omitting the key or sending `null` means `unknown`. Formulation is included only when the source provides it. The server does not guess it.

Each product requires:

| Field | Type | Required | Values |
|---|---|---|---|
| `productID` | string | yes | Non-empty, unique in `products` |
| `listStatus` | string | yes | `complete`, `partial`, `unavailable` |
| `catalogVersion` | integer or `null` | no | Omitted and `null` are the same. A present number must be an integer `>= 0`, not a boolean or string. |
| `ingredients` | array | yes | Original order. `unavailable` must be `[]`. `complete` and `partial` must be non-empty. |

A row needs `originalText` (string). It uses either `mapping` or the legacy `status` object, never both.

`mapping` values:

| `mapping` | Required sibling | Forbidden siblings |
|---|---|---|
| `confirmed` | `ingredientID` string | `suggestedID`, `candidateIDs` |
| `uncertain` | `suggestedID` string | `ingredientID`, `candidateIDs` |
| `ambiguous` | `candidateIDs` string array, at least two | `ingredientID`, `suggestedID` |
| `unmatched` | none | `ingredientID`, `suggestedID`, `candidateIDs` |

Only `confirmed` with an ID in the active catalog is eligible for a supported finding. `suggestedID` and `candidateIDs` are not confirmed matches.

The legacy `status` object is still accepted, and it is not what the current Swift encoder writes:

    {"matched": {"ingredientID": "retinol"}}
    {"uncertain": {"suggestedID": "retinol"}}
    {"ambiguous": {"candidateIDs": ["retinol", "tretinoin"]}}
    {"unmatched": {}}

### Request echo

| Validated request | Response | Rule |
|---|---|---|
| `period` | `period` | Exact `am` or `pm` from the request. |
| `products[].productID`, in order | `productIDs` | Same IDs, same order, same count. |
| `products[].catalogVersion` | `activeCatalogVersion` | Not copied from the client. This is the approved alias-catalog version the server loaded, an integer, never `null`. |

A product whose `catalogVersion` is omitted, `null`, or a different integer is not eligible. That response is `unknown` or `findings` with `completeness` `incomplete`. It is never `noFindings`. The client already requires `activeCatalogVersion` to equal the catalog version it normalized with.

### `200` response

Every successful body keeps these public fields:

| Field | Type | Null | Required | Values |
|---|---|---|---|---|
| `contractVersion` | integer | no | yes | `1` |
| `ruleVersion` | string | no | yes | `ai-analysis-v1` (historical saved AN-02 records use `AN-02-v1`). |
| `catalogSource` | string | no | yes | `firestore` or `bundled-fallback`. The current Swift decoder ignores it. |
| `period` | string | no | yes | Echo of `am` or `pm`. |
| `activeCatalogVersion` | integer | no | yes | Server catalog version. |
| `outcome` | string | no | yes | `noFindings`, `findings`, or `unknown`. |
| `completeness` | string | no | yes | `complete` or `incomplete`. |
| `productIDs` | string array | no | yes | Echoed request IDs. |
| `findings` | array | no | yes | May be empty only for `noFindings`. |
| `limitations` | string array | no | yes | Always present. Not a safety guarantee. |
| `displayLabel` | string | no | only for a clean result | The string `No recorded conflicts`, and only when `outcome` is `noFindings` and `completeness` is `complete`. Otherwise the key is omitted. |

`noFindings` means no supported finding and `completeness` `complete`. It is not a safety guarantee. `findings` means at least one finding whose `outcome` is `caution`, `conflict`, or `allergen`. `completeness` may still be `incomplete` when a coverage gap sits beside that finding. `unknown` means fail closed: partial, unresolved, unverified, or stale input; allergy status `unknown`; no usable approved reference; a provider error; or model output that fails server validation. `completeness` is `incomplete`, `findings` is non-empty, every finding `outcome` is `unknown`, and `displayLabel` is omitted. The server never turns that case into `noFindings`.

Older AN-02 fixtures in `docs/fixtures/an02/` still use response `outcome` `findings` when every finding is a coverage gap. #114 responses use `unknown` for that case. `docs/fixtures/analyses/` is the body to decode.

The model does not supply trusted IDs, severity, category, or source URLs. The server copies those from the validated request and the approved reference records.

Fields added by the wired engine, all ignored by today's decoder:

| Field | Type | Null | When |
|---|---|---|---|
| `analysisVersion` | string | no | Always. Same value as `ruleVersion` (`ai-analysis-v1`). |
| `normalizationID` | string | no | Always. Server-generated. Not a stable client key. |
| `normalization` | object | no | Always. See below. |
| `canonicalDataVersion` | integer | yes | The shared request catalog version, or `null` when the products do not agree. |
| `referenceVersion` | integer | yes | Approved reference set version, or `null` when the server has no single version. |
| `analysisProviderStatus` | string | no | Sanitized code. `ok` does not mean the routine is clear. |
| `summary` | string | no | Always. Not a safety claim. |
| `coverage` | object | no | Always. |

`analysisProviderStatus` is one of `ok`, `normalization_unavailable`, `no_relevant_references`, `not_configured`, `rate_limited`, `refused`, `invalid_response`, `unavailable`, `unsupported_outcome`, `reference_conditions_not_met`, `conflicting_reference_metadata`, `unsupported_ingredient_link`, `unsupported_product_link`, `unsupported_claim`. Any other string is still a failure. The value is a code, not provider response text.

`coverage`:

| Field | Type | Null | Values |
|---|---|---|---|
| `status` | string | no | `complete` or `incomplete`. Same value as top-level `completeness`. |
| `unknownIngredientCount` | integer | no | `>= 0`. Rows that could not be resolved. |
| `missingReferenceCount` | integer | no | `0`, or `1` when no approved reference applied. |
| `limitations` | string array | no | Non-empty. |

`normalization` carries `contractVersion` (`1`), `promptVersion` (string), `providerStatus` (string), `model` (string or `null`), and `products`. Each product has `productID`, `listStatus`, and `ingredients`. Each ingredient has `index` (integer), `originalText` (string), `status` (`matched`, `uncertain`, or `unknown`), `canonicalName` (string or `null`), `proposedName` (string or `null`), and `reason` (string or `null`). The client does not need to decode this object.

### Finding object

| Field | Type | Null | Required | Values |
|---|---|---|---|---|
| `ruleID` | string | no | yes | Server-chosen. For a supported finding, the approved reference ID. |
| `ruleStatus` | string | no | yes | `ai-assisted` or `system-coverage`. Saved AN-02 results use `approved`. |
| `outcome` | string | no | yes | `caution`, `conflict`, `allergen`, or `unknown`. |
| `categoryID` | string | no | yes | Server-derived. Coverage findings use `coverage-gap`. |
| `severity` | string | no | only for supported findings | `low`, `moderate`, or `high`. Omitted when `outcome` is `unknown`. |
| `productIDs` | string array | no | yes | Subset of the response `productIDs`. May be `[]` for an allergy ID that is not on a product. |
| `ingredientIDs` | string array | no | yes | Canonical IDs the server accepted. May be `[]`. |
| `explanation` | string | no | yes | Server-held text. |
| `reason` | string | no | yes | Server-held text or a coverage reason code. |
| `limitations` | string array | no | yes | Always an array. |
| `matchedClassIDs` | string array | no | no | Omitted when the server has no class IDs to attach. |
| `reasonCode` | string | no | no | Present for coverage rows that have a code. |
| `originalText` | string | no | no | Present for an unresolved ingredient row. |
| `rowIndex` | integer | no | no | Zero-based index in that product. Present with `originalText`. |
| `findingID` | string | no | yes | Server-generated. Not stable across calls. Today's decoder ignores it. |
| `evidence` | array | no | on supported and reference-backed coverage findings | Today's decoder ignores it. |

`evidence` items are server copies of approved references, not model output:

| Field | Type | Null |
|---|---|---|
| `referenceID` | string | no |
| `referenceVersion` | integer `>= 1` | no |
| `claim` | string | no |
| `source.title` | string | no |
| `source.publisher` | string | no |
| `source.url` | string, `https://` | no |
| `source.accessedOn` | string, `YYYY-MM-DD` | no |

Supported findings use `ruleStatus` `ai-assisted` and include `severity`. Coverage findings use `ruleStatus` `system-coverage`, `outcome` `unknown`, and `categoryID` `coverage-gap`, and they omit `severity`.

The v1 endpoint returns the result and does not save analysis history.

## Data mapping and validation

| Source | API or analysis field | Rule |
|---|---|---|
| Firestore product `id` | Product `id` or analysis `productID` | Preserve the stable ID |
| Firestore `ingredients` | Normalizer input | Preserve original text and order |
| Firestore `ingredient_list_status` | API `ingredientListStatus` or analysis `listStatus` | Do not infer completeness |
| Alias catalog `version` | Product `catalogVersion` | Use the version that produced the normalized rows |
| Alias catalog ingredient `id` and `classes` | Analysis catalog | Use the same version as the normalizer |
| Profile allergies | `recordedAllergies` | Use canonical IDs and retain known versus unknown |

The backend validates required fields, unique product IDs, supported statuses, and canonical IDs against the active catalog. Missing or stale catalog versions and unresolved rows produce unknown or incomplete results, never a safe result.

The current proposed Firestore profile field `recorded_allergens` is a string array. Before implementation, the team must agree how it maps to canonical IDs and how “known empty” differs from “not recorded.”

## Error format

Errors use this shape:

    {
      "error": {
        "code": "INVALID_REQUEST",
        "message": "The analysis request is invalid.",
        "fieldErrors": [
          {"field": "period", "issue": "Must be am or pm."}
        ],
        "requestID": "server-generated-id"
      }
    }

| HTTP status | Code | Meaning |
|---|---|---|
| 400 | `INVALID_REQUEST` | Malformed JSON or invalid field shape |
| 401 | `UNAUTHENTICATED` | Missing or invalid Firebase ID token |
| 403 | `FORBIDDEN` | Authenticated user is not allowed to access the resource |
| 404 | `PRODUCT_NOT_FOUND` | Requested product does not exist |
| 500 | `INTERNAL_ERROR` | Unexpected server error; response contains no secrets or provider text |
| 503 | `SERVICE_UNAVAILABLE` | Analysis provider or approved reference data is unavailable; message is generic |

## Review required before approval

- Frontend and backend agree whether analysis runs in the Python backend or in Swift.
- Belle reviews Firestore field mapping and authentication assumptions.
- The normalizer owner reviews the normalized-row format and catalog version.
- The analysis owner reviews the request, response, validation, and error formats.
- Record any changes here before implementation.

## Profile and routine data shapes

These are API representations. Firestore storage may use snake_case field names.

Profile:

    {
      "skinType": null,
      "concerns": [],
      "recordedAllergies": {
        "status": "known",
        "ingredientIDs": []
      },
      "preferences": {}
    }

The authenticated UID identifies the profile and is not accepted from the request body. `recordedAllergies.status` distinguishes a known empty allergy list from allergy information that has not been recorded. The current proposed Firestore `recorded_allergens` string array needs an agreed mapping to canonical IDs and this status.

Routine:

    {
      "routineID": "evening_routine",
      "name": "Evening routine",
      "period": "pm",
      "steps": [
        {
          "stepID": "step-1",
          "productPath": "products/cleanser_gel"
        }
      ]
    }

The `steps` array preserves routine order. A `productPath` identifies either a shared catalog product or a user-owned product. The backend validates access to user-owned product paths.

## Analysis result fields

Shape, enums, and nullability for `POST /api/v1/analyses` are in the Analysis endpoint section. Short form: response `outcome` is `noFindings`, `findings`, or `unknown`; `completeness` and `coverage.status` are `complete` or `incomplete`. A finding `outcome` is `caution`, `conflict`, `allergen`, or `unknown`. `severity` is `low`, `moderate`, or `high` and is omitted for `unknown`. `ruleStatus` is `ai-assisted` or `system-coverage`.

`docs/fixtures/analyses/supported_finding.json` and `docs/fixtures/analyses/incomplete_unknown.json` are exact `200` bodies. Decode the file itself. IDs, URLs, and finding IDs in those files are fictional and fixed for the fixture.

Product-list endpoints are public, read-only shared catalog data. They return no profile or routine data.

## Swift compatibility

Checked against the client on `5699bd9`. No Swift file is changed in the #114 backend branch.

`JSONDecoder` in `AuthenticatedAPIClient` (`Aesthelity/Aesthelity/Services/AuthenticatedAPIClient.swift`, decode at lines 101-106) and `BackendAnalysisAPI` (line 144) uses the default strategy. Unknown keys are ignored. A missing required key, a `null` required key, or a wrong JSON type fails the decode.

`AnalysisResponsePayload` (`BackendAnalysisAPI.swift` lines 30-41) requires `contractVersion`, `ruleVersion`, `period`, `activeCatalogVersion`, `outcome`, `completeness`, `productIDs`, `findings`, and `limitations`. `displayLabel` is optional. `AnalysisFindingPayload` (lines 43-55) requires `ruleID`, `ruleStatus`, `outcome`, `categoryID`, `productIDs`, `ingredientIDs`, `explanation`, `reason`, and `limitations`. `severity` and `matchedClassIDs` are optional. `coverage`, `summary`, `analysisVersion`, `normalization`, `evidence`, `findingID`, `reasonCode`, `originalText`, and `rowIndex` are ignored.

What the current client does with the new body:

- The signed-in path decodes it, then `AccountDataAPI.validate` (`AccountDataAPI.swift` lines 104-113) throws `APIClientError.invalidResponse` when `outcome` is `unknown`. The unknown result never reaches the screen. `RoutineAnalysisView` analyzes through that path (line 142) and validates again on load (line 157).
- The loopback demo path (`BackendAnalysisAPI.analyze`, lines 189-196) does not call `validate`. It checks `contractVersion == 1` and `activeCatalogVersion` against the catalog it loaded. An `unknown` body would decode, and `LiveAnalysisView` (lines 143-161) would show one card per finding.
- `PersonalAnalysisResultView` (`RoutineAnalysisView.swift` lines 189-203) titles the screen from `completeness` and, when `findings` is empty, prints `displayLabel` or "No findings under the current rules". An `unknown` body must not arrive with an empty `findings` array.

Must land in the app before the backend switch:

1. `AccountDataAPI.validate` must accept `outcome` `unknown` only with `completeness` `incomplete`, a non-empty `findings` array, every finding `outcome` equal to `unknown`, and no `displayLabel`. Keep rejecting every other outcome string.
2. The results UI must show that `unknown` case as not checked. Do not reuse the empty-findings "No findings" copy.
3. Do not add required JSON keys. `ruleVersion` and `activeCatalogVersion` stay required. `ruleVersion` changes from `AN-02-v1` to `ai-analysis-v1`; the type stays `String`.
4. Keep ignoring `coverage`, `evidence`, and `normalization`. Read them only after a decoder is added on purpose.

Both fixtures decode as `AnalysisResponsePayload` on the current types. `supported_finding.json` also passes `AccountDataAPI.validate` for period `pm`, those two product IDs, and catalog version `3`. `incomplete_unknown.json` decodes and then fails `validate` until change 1 ships.

## Optional formulation context

When verified product metadata provides it, a normalized ingredient row may include:

    "formulation": {
      "vehicle": "conventional-gel",
      "concentrationPercent": 0.025
    }

Supported vehicles are `conventional-gel`, `lotion`, `optimized-aqueous-gel`, `microsphere-gel`, and `unknown`. Concentration is a non-negative number or `null`. The normalizer does not infer formulation from an ingredient name; the caller includes this field only when the source provides it.

For the approved tretinoin/benzoyl peroxide conflict, the request must also state `coapplication: "mixed"`. If formulation or mixing context is missing, the engine reports incomplete context rather than that conflict.
