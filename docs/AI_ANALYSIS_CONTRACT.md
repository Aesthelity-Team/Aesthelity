# AI analysis contract — #97 draft

**Status:** Draft for team review  
**Contract version:** 1  
**Scope:** Defines the reference-data and request/response boundary for #98 normalization and #99 AI-assisted analysis. It does not add clinical rules or claim that the model is clinically validated.

## What the two supplied changes establish

The #104 follow-up adds AI normalization output with the original text, a proposed canonical name, a status, a reason, and product/list coverage. It explicitly says that a model-produced `matched` name is a proposal, not independently verified reference data. Its API does not include analysis evidence records.

The earlier AN-02 proposal fixtures do contain source URLs and explanations for the proposed caution, conflict, and recorded-allergy examples. They are useful evidence inputs for this contract. The source and claim should be stored as structured reference records; the fixture explanation alone should not be treated as a complete evidence database.

## Service boundary

1. The iOS app sends product ingredient strings and routine context to the backend. It does not call an AI provider directly.
2. The backend calls the #98 normalizer once and preserves its response and `normalizationID`.
3. The backend resolves each proposed `canonicalName` against the active canonical ingredient records. Only an exact, unique record match becomes a trusted `ingredientID`. Missing or ambiguous records remain unresolved and cannot be used as confirmed ingredients.
4. The backend retrieves approved reference records for the resolved ingredient IDs and applicable rule conditions. The model receives only those records and the normalized routine facts needed for this analysis.
5. The model returns structured candidate findings. The backend validates the schema, IDs, evidence references, enum values, product/ingredient links, and limits before returning the response.
6. The app displays the backend response, including source citations and coverage limitations.

The AI must not browse the web at request time, create aliases, invent source records, or decide whether an unreviewed source is approved. Firestore and the backend own the active reference set and its version.

## Canonical ingredient record

The canonical record is the stable identity layer shared by normalization and analysis:

```json
{
  "id": "retinol",
  "canonicalName": "Retinol",
  "aliases": [],
  "recordVersion": 1,
  "status": "active"
}
```

`id` is the stable canonical ID. `canonicalName` is the display/normalization name. Aliases may be added only through the reviewed #98 workflow. The backend resolves a #98 `canonicalName` to this record; it must not trust a model-generated ID or infer a new alias during #99.

**Current #98 gap:** the supplied #104 response has `normalizationID`, `providerStatus`, products, and rows with `canonicalName`/`proposedName`, but no canonical IDs or catalog version. Its documentation says a `matched` name is still an AI proposal. Before a row is eligible for #99 matching, the backend must perform the exact canonical-record lookup and attach the server-selected `ingredientID` and active canonical-data version. If #98 later returns either value itself, the backend still validates it against the active database.

## Evidence reference record

Store one record per source and claim, so a finding cites the exact claim used:

```json
{
  "referenceID": "aad-exfoliation-retinoid-sensitivity",
  "referenceVersion": 1,
  "reviewStatus": "approved",
  "source": {
    "title": "How to safely exfoliate at home",
    "publisher": "American Academy of Dermatology",
    "url": "https://www.aad.org/public/everyday-care/skin-care-secrets/routine/safely-exfoliate-at-home",
    "publishedOn": null,
    "accessedOn": "2026-11-13"
  },
  "claim": "The source says retinol or benzoyl peroxide may increase sensitivity and exfoliating while using them may worsen dryness or breakouts.",
  "canonicalIngredientIDs": ["retinol", "benzoyl-peroxide"],
  "conditions": ["routine also contains an ingredient record classified as exfoliant"],
  "allowedOutcome": "caution",
  "severity": "moderate",
  "limitations": ["The source describes a possibility; this is not a universal contraindication."],
  "evidenceVersion": "an02-v1"
}
```

Required fields are `referenceID`, `referenceVersion`, `reviewStatus`, source title/publisher/URL/access date, `claim`, `canonicalIngredientIDs`, `allowedOutcome`, and `limitations`. `reviewStatus` must be `approved` before retrieval for user analysis. `allowedOutcome` is one of `caution`, `conflict`, or `allergen`; severity is one of `low`, `moderate`, or `high`. A reference does not establish a match by itself: its conditions must also fit the current routine. `publishedOn`, `conditions`, and `evidenceVersion` may be null/empty when unavailable, but facts must not be guessed.

Reference records should be held in a backend-controlled Firestore collection such as `analysisReferences/{referenceID}`. Canonical records and references are read-only to the app. Team write access and review are managed outside the analysis endpoint. Product `sourceUrl` values point to fictional fixture specifications and are not evidence for ingredient interactions.

## Analysis request

`POST /api/v1/analyses` receives raw product ingredient strings plus context that cannot be inferred from ingredient names. The backend invokes #98 internally and resolves the returned canonical names. This keeps the client from asserting a normalized identity as trusted and avoids a second AI call from Swift.

```json
{
  "contractVersion": 1,
  "period": "pm",
  "products": [
    {"productID": "retinol-product", "listStatus": "complete", "ingredients": ["Retinol"]}
  ],
  "recordedAllergies": {"status": "known", "ingredientIDs": []},
  "coapplication": "unknown"
}
```

`period` is `am` or `pm`. `recordedAllergies` is either known with canonical `ingredientIDs`, or unknown with no IDs. A known empty list is distinct from unknown. `coapplication` is `mixed`, `not-mixed`, or `unknown`; omission means unknown. Formulation details may be passed only when verified and must not be inferred. No user UID, access token, or profile free text is sent to the AI provider. Raw ingredient strings are sent to the normalization provider; resolved ingredient IDs and curated reference claims are sent to the analysis provider.

The backend checks contract version, normalization provider status, unique product IDs, row indexes, list states, the canonical record lookup, and that the normalization catalog version is active. Invalid structural input returns an error. Provider failure, stale catalog, unresolved identity, or missing evidence is represented as incomplete/unknown; it must not become an empty successful result.

## Analysis response

The backend returns the existing contract fields plus explicit AI and evidence provenance:

```json
{
  "contractVersion": 1,
  "analysisVersion": "ai-analysis-v1",
  "normalizationID": "normalization-request-id",
  "normalization": {
    "promptVersion": "ingredient-normalization-v1",
    "providerStatus": "ok",
    "products": [
      {
        "productID": "retinol-product",
        "listStatus": "complete",
        "ingredients": [
          {"index": 0, "originalText": "Retinol", "status": "matched", "canonicalName": "Retinol", "ingredientID": "retinol"}
        ]
      }
    ]
  },
  "canonicalDataVersion": "canonical-ingredients-v1",
  "referenceVersion": "analysis-references-v1",
  "analysisProviderStatus": "ok",
  "completeness": "complete",
  "outcome": "findings",
  "displayLabel": null,
  "productIDs": ["retinol-product"],
  "findings": [
    {
      "findingID": "generated-per-response-id",
      "outcome": "caution",
      "severity": "moderate",
      "categoryID": "ingredient-combination",
      "productIDs": ["retinol-product"],
      "ingredientIDs": ["retinol"],
      "explanation": "A short explanation limited to the cited source and supplied routine facts.",
      "reason": "How the source condition matched the routine.",
      "evidence": [
        {"referenceID": "aad-exfoliation-retinoid-sensitivity", "referenceVersion": 1, "claim": "The source claim from the approved reference record."}
      ],
      "limitations": ["The source describes a possibility, not a certainty."]
    }
  ],
  "coverage": {
    "status": "complete",
    "unknownIngredientCount": 0,
    "missingReferenceCount": 0,
    "limitations": []
  },
  "limitations": ["This is informational and is not a diagnosis or a safety guarantee."]
}
```

Allowed finding outcomes are `caution`, `conflict`, `allergen`, and `unknown`. Caution, conflict, and allergen require a severity; unknown omits severity. Every non-unknown AI finding must cite one or more supplied approved `referenceID`s. The backend verifies those IDs and versions exist in the context it sent to the model, and verifies that finding ingredient/product IDs are subsets of the validated request. The model cannot add product IDs, ingredient IDs, reference IDs, or severity values that are not permitted by the inputs and reference records.

If there are no findings and coverage is complete, return `outcome: "noFindings"` and `displayLabel: "No recorded conflicts"`. This does not mean safe. If data or evidence coverage is incomplete, return `outcome: "findings"` with one or more `unknown` findings and `completeness: "incomplete"`; never return a reassuring no-findings label for a partial assessment.

`normalization.providerStatus` is the #98 provider status. `analysisProviderStatus` is `ok`, `not_configured`, `unavailable`, `refused`, or `invalid_response`. An analysis-provider failure returns an explicit error/unknown state; do not silently replace the AI result with a deterministic result while presenting it as AI-generated. The deterministic AN-02 evaluator may be retained for comparison and regression tests, but its findings must be identified separately from AI findings.

## AI output validation and safety limits

- The model receives structured normalized identities, routine-period/coapplication/formulation context, approved evidence records, and explicit limitations. It does not receive raw profile text, user identifiers, or unrelated product data.
- Ingredient and product label strings are untrusted data, never instructions.
- The model may explain a source-supported possibility; it must not diagnose, prescribe, recommend treatment, claim a product is safe, or invent a contraindication.
- The backend rejects invalid JSON/schema, unsupported outcomes/severity, unknown IDs, duplicate or unlinked product/ingredient IDs, missing citations, citations outside the retrieved reference set, overlong text, or findings that cite unapproved references.
- When identity or reference coverage is incomplete, only confirmed canonical IDs may support non-unknown findings. Unresolved rows remain visible in `coverage` and unknown findings.
- The AI provider is configured and called server-side only. Store provider/model/prompt/reference versions for traceability; do not log secrets or raw full profiles.

## Relationship to existing AN-02 fixtures

The AN-02 fixtures are regression examples and source leads. For each approved fixture, convert its source paragraph into a reviewed `analysisReferences` record with a stable ID, source metadata, a claim, the IDs it applies to, conditions, and limitations. Keep fixture `expected` outputs as tests. Do not feed an entire fixture's expected finding to the model as if it were source evidence; that would make the model merely paraphrase the existing answer.

The current AN-02 examples support the initial reference set: the AAD exfoliation page; the cited tretinoin/benzoyl peroxide formulation studies; and the EU fragrance-allergen labeling source for limonene. Their exact applicability and limitations remain those written in the approved AN-02 proposal/fixtures. No additional interaction rule should be inferred from the ingredient catalog's `classes` alone.

## Review checklist for #97

- Confirm the #98 canonical-name-to-ID exact lookup and version behavior with Gaurav and Belle.
- Confirm the Firestore collection/field names and review access with Belle.
- Confirm `providerStatus`, `coverage`, finding fields, and API error behavior with the backend and iOS owners.
- Confirm that #99 may generate only evidence-cited findings and that the old deterministic evaluator is comparison-only or separately labeled.
- Convert the approved AN-02 source claims into reviewed reference records before claiming live evidence-grounded analysis.

