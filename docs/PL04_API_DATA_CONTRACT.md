# PL-04 API and Data Contract

**Status:** Draft for review
**Contract version:** 1
**Implementation:** The endpoints below are proposed; this document does not implement them.

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

`POST /api/v1/analyses` requires a Firebase ID token. The request is:

    {
      "contractVersion": 1,
      "period": "pm",
      "recordedAllergies": {
        "status": "known",
        "ingredientIDs": ["limonene"]
      },
      "coapplication": "unknown",
      "products": [
        {
          "productID": "retinol_product",
          "listStatus": "complete",
          "catalogVersion": 2,
          "ingredients": [
            {
              "originalText": "Retinol",
              "status": {
                "matched": {
                  "ingredientID": "retinol"
                }
              }
            }
          ]
        }
      ]
    }

Each product contains a stable `productID`, `listStatus` (`complete`, `partial`, or `unavailable`), the `catalogVersion` used for normalization (or `null`), and normalized ingredient rows in original order.

A row preserves `originalText`. Its `status` is exactly one of:

    {"matched": {"ingredientID": "retinol"}}
    {"uncertain": {"suggestedID": "retinol"}}
    {"ambiguous": {"candidateIDs": ["retinol", "tretinoin"]}}
    {"unmatched": {}}

Only `matched` provides an ingredient ID eligible for rule matching. Suggested and candidate IDs are not confirmed matches. This is intended to match the Swift `NormalizedIngredient.Status` encoding.

`recordedAllergies` is either `{"status": "known", "ingredientIDs": []}` or `{"status": "unknown"}`. A known empty list means no allergies are recorded. Unknown must not be treated as an empty list.

`coapplication` may be `mixed`, `not-mixed`, or `unknown`; omission means unknown. Formulation details may be included when available and must not be guessed.

A `200` response contains `contractVersion`, `ruleVersion`, `period`, `activeCatalogVersion`, `outcome`, `completeness`, `productIDs`, `findings`, and `limitations`. Findings preserve affected product and ingredient IDs. Caution and conflict findings include severity and an explanation; unknown findings have no severity.

If there are no findings and the analysis is complete, the response uses `outcome: "noFindings"` and `displayLabel: "No recorded conflicts"`. This is not a safety guarantee. Recommended layering sequence belongs to AN-06.

The v1 endpoint returns analysis results but does not save analysis history.

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
| 500 | `INTERNAL_ERROR` | Unexpected server error; response contains no secrets |

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

The response `outcome` is `noFindings` or `findings`; `completeness` is `complete` or `incomplete`. Each finding contains `ruleID`, `ruleStatus`, `outcome`, `categoryID`, `productIDs`, `ingredientIDs`, `explanation`, `reason`, and `limitations`.

Finding `outcome` is `caution`, `conflict`, `allergen`, or `unknown`. `severity` is present for caution, conflict, and allergen findings; unknown findings omit it. `matchedClassIDs`, `reasonCode`, `originalText`, and `rowIndex` are included only when applicable. The API layer supplies `ruleVersion` so results identify the rules used.

Product-list endpoints are proposed as public, read-only access to shared catalog data only. They return no profile or routine data.

## Optional formulation context

When verified product metadata provides it, a normalized ingredient row may include:

    "formulation": {
      "vehicle": "conventional-gel",
      "concentrationPercent": 0.025
    }

Supported vehicles are `conventional-gel`, `lotion`, `optimized-aqueous-gel`, `microsphere-gel`, and `unknown`. Concentration is a non-negative number or `null`. The normalizer does not infer formulation from an ingredient name; the caller includes this field only when the source provides it.

For the approved tretinoin/benzoyl peroxide conflict, the request must also state `coapplication: "mixed"`. If formulation or mixing context is missing, the engine reports incomplete context rather than that conflict.
