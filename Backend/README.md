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
normalizes the original ingredient strings with the bundled alias catalog,
then posts the normalized product objects to `POST /api/v1/analyses`. The
server verifies the catalog version through the active catalog and returns
findings for display. Scenarios are labeled demo data; they are not a saved
personal routine or profile.

## Routes

- `GET /health`: API, rule, catalog, and Firestore database identifiers.
- `GET /api/v1/products`: shared catalog records in API camelCase.
- `GET /api/v1/products/{productID}`: one shared product.
- `POST /api/v1/analyses`: evaluate one normalized AM or PM routine.

Outside local demo mode, analysis requests require a valid Firebase ID token.
Production hosting, app sign-in, and user-specific data access need deployment
configuration and security review.
