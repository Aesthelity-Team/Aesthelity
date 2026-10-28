# Firestore Database Schema — BE-04

## Implementation status

The shared product catalog is imported and verified.

User profiles, user-added products, routines, and analysis results below
describe proposed storage contracts. Their persistence features and
authorization are implemented under their respective issues.

## Collection paths

| Document path | Purpose | Status |
|---|---|---|
| products/{productId} | Shared curated product catalog | Implemented |
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