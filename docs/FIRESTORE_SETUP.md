# Firestore Development Setup — BE-04

## Database configuration

- Firebase project ID: `aesthelity-2026`
- Firestore database ID: `ogdb`
- Location: `us-west2`
- Initial access mode: Production mode
- Catalog collection: `products`

This development catalog uses the fictional skincare dataset from DATA-01.
Preserve fictional labels, ingredient-list status, and provenance.

## Local Python setup

Run from the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r Backend/requirements.txt
```

## Credentials and environment configuration

Use an authorized development service-account credential stored outside
the repository. Never commit the credential JSON file.

Set these variables in the terminal used to run the scripts:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/outside/repo/credential.json"
export FIREBASE_PROJECT_ID="aesthelity-2026"
export FIRESTORE_DATABASE_ID="ogdb"
```

## Verify the connection

```bash
python tests/backend/check_firestore_connection.py
```

Expected: a synthetic document is written, retrieved with matching values,
deleted, and confirmed absent.

## Import the catalog

```bash
python tests/backend/import_catalog.py
```

The importer validates the dataset before writing. Each product is stored
at `products/{id}` using its existing dataset ID.

Running the importer again overwrites those same documents without creating
new IDs. It does not remove products that have been removed from the source
dataset.

## Verify catalog retrieval

```bash
python tests/backend/verify_catalog.py
```

Expected: retrieval by ID and catalog listing pass, and stored records match
the source dataset. This exact comparison assumes the collection contains
only the curated demo catalog.

## Verify invalid-data rejection

```bash
python tests/backend/test_invalid_import.py
python tests/backend/test_invalid_catalog.py
```

Expected: missing-name and invalid-category cases are rejected before
database writes; the stored catalog still matches afterward.

## Restricted client access

The verified development rules are recorded in `firestore.rules`.

Unauthenticated get and create requests were denied in Rules Playground
for the custom database. The Python Admin SDK uses privileged credentials;
its successful access does not verify client security rules.

The local rules file documents the configuration. It is not automatically
deployed by running these Python scripts.

## Scope and handoff

BE-04 establishes storage, imports products, and verifies connectivity.
Private collection structures are documented in FIRESTORE_SCHEMA.md.

Authentication, user authorization, routine persistence, manual product
entry, and saved analysis history are implemented by their respective
feature issues.

## iOS app: local-only routines and profile (current PR path)

The iOS client keeps routines and skin profile on-device
(`Application Support/Routines/routines.json` and
`Application Support/SkinProfile/profile.json`).

**Cloud routine/profile sync is disabled** via
`CloudSyncConfiguration.isEnabled == false` until the team agrees and
verifies:

1. Account isolation for local files (sign-out / account change policy)
2. Safe reconciliation (no silent upload of guest data; no blind overwrite)
3. Client security rules for `users/{uid}/…` (the checked-in
   `firestore.rules` currently denies all client access; that file is
   **not** proof of what is deployed)
4. Database ID alignment: setup docs and Python tooling target `ogdb`,
   while `Firestore.firestore()` in the app uses the **default** database
   unless explicitly configured otherwise

While sync is disabled, Firebase Auth UI may still be present for sign-in
experiments, but the app must not start routine listeners or write
routines/profiles to Firestore. Settings copy states that data stays on
this device and that cloud sync is not enabled.

Do not enable `CloudSyncConfiguration.isEnabled` without emulator or
staging verification of the items above.