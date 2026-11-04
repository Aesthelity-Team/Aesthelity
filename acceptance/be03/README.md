# BE-03 / #29: authenticated iOS API groundwork

## Implemented

- `AuthenticatedAPIClient`: injected token source and transport, HTTPS-only base
  URL, JSON POST encoding/decoding, bounded timeout, cancellation, safe typed
  errors, and no automatic POST replay. It obtains a token for every request.
- The production transport uses an ephemeral session without disk cache/cookies
  and refuses redirects so bearer tokens cannot be forwarded to another host.
- `FirebaseAPITokenProvider`: uses the current registered Firebase user, lets the
  SDK refresh expired ID tokens, rejects missing/anonymous sessions, and checks
  the user has not changed while awaiting the token. It never signs in silently.
- `BackendAnalysisAPI.analyzeAuthenticated`: submits caller-provided normalized
  products to the existing protected POST /api/v1/analyses, validates contract and
  catalog versions, and confirms the response period/product IDs match the input.
- The existing loopback fictional demo remains separate and receives no tokens.

## Calling from the personal analysis feature

Once its inputs and deployment URL are agreed:

```swift
let response = try await BackendAnalysisAPI.analyzeAuthenticated(
    payload: payload,
    expectedCatalogVersion: catalogVersion,
    baseURL: deploymentURL
)
```

`deploymentURL` must be the HTTPS backend origin, optionally including its path
prefix. Do not pass the loopback demo URL or a Firebase database URL. No deployed
protected backend URL is currently configured in this repository.

The screen should set loading before awaiting the request, clear loading on all
completion paths, and handle `APIClientError.signInRequired` with a sign-in action.
Handle `.forbidden` separately from expired credentials; retain locally saved
profile/routine data when requests fail. Invalidate in-flight screen requests on
selection changes, sign-out, or account changes (the #96 lifecycle pattern).
Never store a result from a previous account into the newly selected account.

## Remaining integration dependencies

The checked-in backend exposes GET products, GET product, and POST analyses only.
There are no profile or routine HTTP endpoints to call. Do not invent their
schemas or send user IDs as an ownership override. Agree those routes/models with
the #27/#28 backend owners, including verified Firebase identity and ownership.

Personal analysis screen integration is intentionally pending: the team's
#97–#99 contract/fixtures, a configured HTTPS backend, and the #27/#28 auth/data
isolation handoff are needed. Existing stores remain authoritative for local
profile/routine data. This branch does not enable Firestore synchronization.

## Validation

`AuthenticatedAPIClientTests` (in the existing unit-test source) covers fresh
per-request tokens, Authorization header/body encoding, response decoding, missing
sessions sending no request, 401/403/500/redirect statuses without POST replay,
network/decode failures, insecure configuration, and cancellation. Transport is
injected, so no real credentials or external user data are used.

Before closing #29, run the actual signed-in screen flow against protected HTTPS
endpoints, test expired/revoked credentials and account changes, verify ownership
isolation, and confirm server failures preserve local data. Mocked tests alone do
not establish that end-to-end acceptance criteria are complete.

Recorded 2026-11-04: the isolated macOS Swift package ran the unchanged client
source and regression suite successfully (5 tests, with 4 HTTP-status cases).
Unsigned generic iOS build-for-testing passed for the app and test targets.
No live Firebase-authenticated HTTPS endpoint or UI integration was exercised.
