# BE-03 / #29: authenticated API integration

## Scope and current setup

The branch incorporates `upstream/29-authenticated-api` at `0b41cb3`, including
team main's #27 authentication, #28 backend isolation, and #96 navigation fixes.

The app remains local-first. Explicit account transfers are available from the
profile, routine, and personal-analysis screens. Automatic Firestore sync remains
disabled; signing in does not upload local data. The local product library is not
replaced when downloading routines. Existing local files remain on device at
sign-out. Explicit transfers require a registered Firebase session; local-fallback
and anonymous sessions cannot access the protected API.

No HTTPS backend currently exists. The code is configurable, but live Firebase
acceptance and teammate PR review remain required before closing #29.

## Configuration

- `AesthelityProtectedAPIBaseURL` expands the Xcode build setting
  `AESTHELITY_PROTECTED_API_BASE_URL`. Leave the setting empty until deployment.
- Use a valid HTTPS backend origin, optionally with a path prefix. Do not include
  `/api/v1` in the base. No credentials, query, or fragment belong in that URL.
- `AesthelityAPIBaseURL` remains the token-free loopback HTTP demo address.
- Configure Firebase project `aesthelity-2026` and Firestore database `ogdb` on the
  backend with credentials outside the repository. Production must not enable
  `AESTHELITY_DEMO_MODE`. The local Python server needs HTTPS termination in a
  deployment; the client does not permit insecure protected requests.

Example build-setting override (replace the host with the actual deployment):

```sh
xcodebuild build \
  -project Aesthelity/Aesthelity.xcodeproj -scheme Aesthelity \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO \
  AESTHELITY_PROTECTED_API_BASE_URL=https://your-host
```

## Screens and stored data

All private requests use `/api/v1/users/{verified-session-uid}/{kind}/{recordID}`.
PUT sends `contractVersion: 1` and `data`; GET/PUT responses are checked for
contract version, owner UID, and record ID before any UI or local-store update.
The UID is a route parameter, never a client-controlled ownership field in data.
The backend independently enforces token UID ownership and revocation checks.

| Screen | Action and route | Data inside the private record |
| --- | --- | --- |
| Profile → Profile account storage | Save/load `profile/skinProfile` | Existing version-1 `SkinProfile` Codable representation |
| My Routines → Routine account storage | Save/load `routines/savedRoutines` | Existing `RoutineStorageDocument`: `schemaVersion: 1`, `routines` array, including each step's attached `RoutineProductSnapshot` |
| Home → View analysis | POST `/api/v1/analyses` | Current routine step IDs, period, freshly normalized ingredient rows and catalog version; recorded allergies remain `unknown` |
| Personal routine analysis | Save/load `analyses/{routineUUID}` | `SavedPersonalAnalysis`: schema version, routine ID, request, response, product names, and save date (Swift JSONEncoder Date representation) |

Save explicitly replaces the previous account copy for that record. Load stages
and validates the account profile/routines, then asks before replacing local data.
The local copy must still match the one present when the download started. An
unreadable local store disables transfer actions rather than overwriting its file.
Atomic local persistence publishes only after a successful write.

Routine uploads preserve their embedded product snapshots. Legacy manual steps
are enriched from the device's manual library where a matching product exists.
Other legacy steps remain without ingredient data; the client never invents a
product or silently replaces it with a fictional scenario. Downloading a routine
does not add its products to the separate product library.

Personal analysis uses snapshots attached to the selected routine, normalized
against the active bundled reference. Manual lists have unverified completeness
and are sent as partial; missing lists remain unavailable. Existing avoidance
preferences are not treated as diagnosed/recorded allergies. Fictional catalog
products retain visible fictional labeling. Saved analysis is displayed only
when routine ID, inputs, names, and catalog version match. Findings show their
rule version and limitations, and saved results are labeled as historical.
When allergy status is `unknown`, the analysis request omits `ingredientIDs`
entirely. An empty ID array is only valid when allergy status is `known`.

## Transport and lifecycle

`AuthenticatedAPIClient` implements GET, PUT, and POST with HTTPS-only validated
configuration, fresh Firebase tokens per request, bounded timeout, no cookies or
persistent cache, and no redirect following or automatic request replay.
Authentication, forbidden access, missing records, server errors, malformed
responses, network failures, and cancellation have safe separate handling.
Downloaded records use strict decoding rather than legacy on-device defaults.

`AccountDataAPI` binds token acquisition and response acceptance to the Firebase
UID, user object, and auth-session revision that started the operation. Account
changes, sign-out/re-sign-in to the same UID, input changes, and dismissal cancel
or invalidate work. Screens clear pending downloads/results on account changes,
prompt sign-in on authentication failure, and retain local profile/routine files
on request failures. Private backend storage never inherits the demo bypass.

## Local validation

Install `Backend/requirements.txt` in an isolated virtual environment. No real
Firebase credentials are required for these tests:

```sh
python -m unittest discover -s tests -v
python -m unittest discover -s tests/backend -p 'test_auth*.py' -v
python -m unittest discover -s tests/backend -p 'test_private_data.py' -v
python -m unittest discover -s tests/backend -p 'test_demo_catalog.py' -v
```

Backend auth/storage tests use real loopback HTTP with an injected verifier and
in-memory data. They cover token rejection, production revocation-check wiring,
ownership isolation, validation, and server failures. iOS unit tests cover client
headers/body/routes, private-record round trips, response identity validation,
strict decoding, same-UID session replacement, token-time account changes,
analysis save/retrieval, unavailable data, and unchanged local files on failures.
UI tests exercise personal-analysis/demo navigation and account-storage entry.

Run the shared `Aesthelity` scheme's unit and UI test targets on an available
simulator. The test transport is injected; local tests do not prove a real
Firebase-authenticated HTTPS deployment works.

## Live acceptance still required

- Provision/configure HTTPS and verify project/database alignment.
- With account A, save and retrieve profile, routines, and analysis from their
  actual screens; verify decoded data and visible loading/success states.
- Verify missing, expired, and revoked credentials prompt sign-in without replay.
- Sign out/change accounts while token acquisition or a response is pending;
  check that no stale result or downloaded copy can be applied to the new session.
- Verify account B cannot retrieve A's records, including by modified URLs.
- Stop the backend or return errors; verify local files and typed user input are
  retained. Cancel a download's replacement prompt and verify no local mutation.
- Obtain teammate PR review. Do not close #29 based only on mocked credentials.

## Verification recorded 2026-11-17

- Generic unsigned simulator build-for-testing succeeded.
- Final signed iPhone 18 Pro simulator run: 30 XCTest unit tests and 256 Swift
  Testing cases passed; all four `Sprint1DemoUITests` passed, including personal
  analysis/demo navigation and unavailable-backend account storage.
- All five `ProfileUITests` passed in the preceding affected-screen run.
- Python engine/fixture suite: 17 passed. Full backend discovery with the pinned
  Firebase SDK installed: 43 passed. No live Firestore data was read or written.
- The unset protected build setting expands to an empty Info.plist value, and
  account actions display the configuration error without sending a request.
- Backend auth/isolation checks now run in `.github/workflows/backend-api.yml`;
  the existing iOS workflow continues to run app unit and UI tests.
- Live HTTPS/Firebase acceptance and teammate review remain unverified.
