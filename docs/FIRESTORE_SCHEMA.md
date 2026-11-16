# Firestore Database Schema — BE-04

## Implementation status

The shared product catalog is imported and verified.

User profiles, user-added products, routines, and analysis results below
describe proposed storage contracts. The iOS app currently persists
routines and skin profile **locally only**; Firestore user-document sync
is gated off until account isolation, reconciliation, rules, and database
ID are verified (see FIRESTORE_SETUP.md).

## Collection paths

| Document path | Purpose | Status |
|---|---|---|
| products/{productId} | Shared curated product catalog | Implemented |
| ingredientAliasCatalogs/active | Hand-approved alias catalog used by AN-02 analysis | Implemented |
| ingredients/{ingredientId} | Full canonical ingredient catalog (EU CosIng inventory + approved entries) | Implemented; import is dry-run until `--apply` |
| ingredientAmbiguousTerms/{termKey} | Names that map to two or more canonical IDs | Implemented with the import |
| ingredientCatalogs/reference | Version, source, and counts of the last full import | Implemented with the import |
| users/{uid} | Personal skin profile | Proposed |
| users/{uid}/products/{productId} | User-added products | Proposed |
| users/{uid}/routines/{routineId} | Ordered AM/PM routines | Proposed |
| users/{uid}/analyses/{analysisId} | Saved analysis results | Proposed |
| _connectionChecks/{testId} | Temporary synthetic connectivity checks | Verified; records removed after testing |

## Shared catalog: products/{productId}

The document ID equals the existing dataset product ID.
Example: products/cleanser_gel.

| Field | Type | Requirement |
|---|---|---|
| id | string | Required; matches document ID |
| name | string | Required; fictional products visibly labeled |
| brand | string | Required |
| category | string | Required; allowed values in DATA_DICTIONARY.md |
| subtype | string | Required |
| ingredients | array of strings | Required; preserves original order |
| ingredient_list_status | string | complete, partial, or unavailable |
| is_fictional | boolean | true for current demo products |
| source_url | string | Required HTTPS source/specification URL |
| source_ref | string | Required provenance-document reference |
| verified_on | string | Required ISO date: YYYY-MM-DD |
| provenance | map | Required; kind, verification_method, note |
| spf | null | Current dataset makes no verified SPF claim |

An unavailable ingredient list requires an empty ingredients array.
Partial and unavailable data must remain explicitly labeled.

Catalog records are shared and are not owned by an individual app user.
Only authorized catalog-management operations should change them.

Imports use existing stable document IDs. Repeating an import replaces
the same records without generating duplicate IDs. Imports do not delete
records absent from the source dataset.

## Approved ingredient aliases: ingredientAliasCatalogs/active

This shared document is the current reviewed alias catalog used by the app and
backend. Its document ID is `active`; increment `version` whenever a reviewed
name, alias, class, or ambiguous term changes. The backend reads it for every
analysis request and serves it through `GET /api/v1/ingredient-aliases`, so a
valid update is available on the next request.

| Field | Type | Requirement |
|---|---|---|
| version | integer | Required; non-negative content version |
| reviewStatus | string | Required; must be `approved` to be served |
| ingredients | array of maps | Required; `id`, `name`, `aliases`, `classes`, and optional reviewed references |
| ambiguousTerms | array of maps | Required; terms, at least two known `candidateIDs`, and a note |
| updatedAt | Firestore timestamp | Required; written by the seed/update operation |
| updatedBy | string | Required; authorized editor's team identity |

The `ingredients` and `ambiguousTerms` fields use the same shape as
`Aesthelity/Aesthelity/Resources/SampleData/ingredient-aliases.json`. Exact
names must not map to multiple canonical IDs or conflict with an ambiguous
term. Unreviewed names stay out of `aliases`. The app retains the original
ingredient text and only writes `ingredientID` for a confirmed match; uncertain,
ambiguous, and unmatched rows remain ineligible for analysis.

If the document is missing or Firestore cannot be read, the app and backend
use the bundled approved catalog and report `catalogSource` as
`bundled-fallback`. The seed command is dry-run by default. Use `--apply` for
the initial write; replacing an existing active catalog also requires
`--replace` and an authorized `INGREDIENT_ALIAS_EDITOR` identity.

## Full ingredient catalog: ingredients/{ingredientId}

The complete EU CosIng ingredient inventory, imported by
`Backend/import_ingredient_catalog.py` from the committed snapshot
`Backend/data/cosing_ingredients.json.gz` (source, retrieval date, and license
are stored inside the snapshot). It sits underneath the approved alias catalog;
it never edits `ingredientAliasCatalogs/active`.

IDs are deterministic. An ingredient that is already in the approved catalog
(same name, an approved alias, or exactly one approved name among its CosIng
synonyms) keeps its approved ID, name, aliases, and classes. Every other INCI
name gets a slug of the INCI name (`centella-asiatica-extract`). If two names
produce the same slug, the lowest CosIng reference number keeps the plain slug
and the others get an 8-character hash suffix; slugs longer than 100
characters are shortened the same way. Rows with the same INCI name are merged
into one ingredient with several sources.

| Field | Type | Requirement |
|---|---|---|
| id | string | Required; matches document ID |
| canonicalName | string | Required; approved name, otherwise the CosIng INCI name |
| inciNames | array of strings | CosIng INCI names merged into this ingredient |
| aliases | array of strings | Approved aliases first, then CosIng INCI-USA, INN, and Ph. Eur. names this ingredient owns |
| aliasKeys | array of strings | Lowercase exact-match keys owned by this ingredient (queried with `array-contains`) |
| classes | array of strings | Approved AN-02 classes; empty for reference-tier ingredients |
| tier | string | `approved` or `reference` |
| casNumbers, ecNumbers | array of strings | From CosIng; may be empty |
| functions | array of strings | CosIng cosmetic functions |
| description | string | CosIng chemical/botanical description |
| restrictions | array of strings | CosIng annex references, such as `III/71` |
| sources | array of maps | `source`, CosIng `refNo`, and detail `url` |
| references | array of maps | Optional; reviewed references copied from the approved catalog |
| catalogVersion | string | `cosing-YYYY-MM-DD` from the snapshot |
| updatedAt, updatedBy | timestamp, string | Written by the import |

Lookup priority, highest first: approved names and aliases, approved ambiguous
terms, CosIng INCI names, then CosIng synonyms. A synonym shared by 2 to 10
ingredients becomes an `ingredientAmbiguousTerms/{termKey}` document
(`term`, `termKey`, `candidateIDs`, `note`, `source`); one shared by more is
dropped. A bare CAS number resolves only when exactly one ingredient has it.

Resolution never guesses. The backend's
`POST /api/v1/ingredients/resolve` returns `confirmed` only for
approved-catalog IDs. A reference-tier match is returned as `uncertain` with a
`suggestedID`, so under PD-03 the product stays out of analysis until that
ingredient is approved into `ingredientAliasCatalogs/active`. Unknown text is
`unmatched`, and the original text is always kept.

`ingredientCatalogs/reference` is written last and records `version`,
`source`, `sourceUrl`, `retrievedOn`, `license`, `ingredientCount`,
`ambiguousTermCount`, and the import `stats`.

## Proposed profile: users/{uid}

The document ID is the Firebase Authentication UID.

| Field | Type | Requirement |
|---|---|---|
| skin_type | string or null | Optional; vocabulary agreed with frontend |
| concerns | array of strings | Required; may be empty |
| recorded_allergens | array of strings | Required; may be empty |
| preferences | map | Required; may be empty; keys require agreement |
| created_at | Firestore timestamp | Required |
| updated_at | Firestore timestamp | Required |

An incomplete profile must not be treated as confirmation that the user
has no sensitivities. Align these fields with the existing Swift profile
model and PL-04 before implementation.

## Proposed user-added products: users/{uid}/products/{productId}

Use a generated stable document ID when the product is first saved.
Reuse that ID for later updates.

| Field | Type | Requirement |
|---|---|---|
| name | string | Required |
| brand | string or null | Optional |
| category | string | Required; agreed vocabulary |
| ingredients | array of strings | Required; preserves input order |
| ingredient_list_status | string | Required |
| created_at | Firestore timestamp | Required |
| updated_at | Firestore timestamp | Required |

User-entered information must be distinguished from verified catalog data.
Do not invent source URLs or verification dates.

PD-02 implements manual-entry persistence.

## Proposed routines: users/{uid}/routines/{routineId}

| Field | Type | Requirement |
|---|---|---|
| name | string | Required |
| routine_time | string | Required; am or pm |
| steps | ordered array of maps | Required; may be empty while editing |
| created_at | Firestore timestamp | Required |
| updated_at | Firestore timestamp | Required |

Each step contains:

| Field | Type | Requirement |
|---|---|---|
| step_id | string | Required; stable within the routine |
| product_path | string | Required; full relative product document path |

The steps array order is the routine order.

Example product paths:
- products/cleanser_gel
- users/{uid}/products/{productId}

A user-owned product reference must belong to the same user as the routine.
Missing or deleted product references must be handled explicitly.

RT-03 implements routine persistence and preserves step order.

## Proposed analysis results: users/{uid}/analyses/{analysisId}

| Field | Type | Requirement |
|---|---|---|
| routine_id | string or null | Optional; routine being analyzed |
| input_snapshot | map | Required; inputs used for that analysis |
| findings | array of maps | Required; AN-02 defines finding structure |
| rule_version | string | Required; identifies analysis rules used |
| created_at | Firestore timestamp | Required |

The input snapshot preserves the product and relevant profile information
used at analysis time so later edits do not change the meaning of history.

Mia's AN-02 contract defines outcomes, severity, explanations, affected
ingredients/products, missing-data handling, and layering guidance.
Must agree on exact finding fields before implementing saved analysis history.

BE-04 plans this structure; it does not implement history persistence.

## IDs and relationships

- Catalog product IDs come from the curated dataset.
- User IDs come from Firebase Authentication.
- Private product, routine, and analysis IDs are generated once and reused.
- Product references distinguish shared and user-owned document paths.
- Original ingredient strings remain preserved.
- Canonical ingredient IDs and normalization metadata follow DATA-02;
  they are not invented by the database importer.

## Ownership and access

Private records inherit ownership from users/{uid} in their document path.

The path convention alone does not enforce authorization. BE-02 must
verify the authenticated UID for protected operations and validate
references to other private documents.

Current development client access is denied by the verified rules.
Privileged Admin SDK operations use IAM permissions and require their
own authorization checks when exposed through backend endpoints.

## Required team review

- Confirm profile fields against the existing frontend model.
- Confirm paths, field names, and types with PL-04.
- Confirm analysis findings and input snapshots with AN-02.
- Confirm normalized ingredient representation with DATA-02.
- Record agreed changes before implementing private persistence.
