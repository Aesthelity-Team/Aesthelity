# AN-96: Analysis entry point and request lifecycle

Home and Profile open the personal routine sheet for the selected AM/PM routine.
The sheet lists its current steps and explicitly reports that personal analysis is
not yet available. It does not display a fictional compatibility score or use a
fictional scenario as a substitute. “Demo / Dev Mode” opens a separate sheet with
the local backend scenario picker and clearly labeled bundled reference findings.
Closing the demo returns to the personal sheet.

A scenario change clears the result and error synchronously, invalidates request
ownership, cancels the old task, and permits a new request. Only the current
request can publish success, failure, or a loading transition. Dismissal uses the
same invalidation, including swipe dismissal. Cancellation is an optimization;
the request identity check also rejects non-cooperative late responses.

## Verification

- `DemoAnalysisRequestStateTests` in `DemoAnalysisTests.swift` exercises delayed
  success across selection changes, a newer request remaining loading when an old
  request completes, dismissal during delayed failure, retry, and clearing states.
- `testPersonalAnalysisAndExplicitDemoAreReachableFromHome` checks that the normal
  entry point has no backend demo action, explicitly opens the demo, exercises a
  bundled caution finding, and returns through both sheets to Home.

## Simulator/local API rehearsal

1. Open Home analysis with AM selected, then PM. Confirm the sheet names/lists the
   selected routine and makes no personal assessment. Try an empty routine too.
2. Open Demo / Dev Mode. For live requests, sign in with a real Firebase account
   and run the backend using the current authentication configuration (see
   Backend/README.md). Main now attaches a Firebase ID token even for the demo;
   guest users can still inspect the bundled sample findings. With the backend running,
   run every scenario and verify the named products and missing-data limitations.
3. Delay an API response, start Caution PM, change to No findings AM. Confirm old
   output disappears immediately. Start the AM request and verify the late PM
   response cannot overwrite it or end its loading indicator.
4. Repeat with a delayed API failure and with switching away then back to the
   original scenario. Old successes/errors must remain discarded.
5. Close or swipe-dismiss the demo while loading; reopen it. Confirm no old result,
   error, or loading state appears. Stop the backend and verify failure/retry.
6. Rehearse simulator → local API → Firestore → normalization → Python analysis
   separately. Bundled examples are fixtures and do not prove that live path works.

Personal backend integration and revised result/coverage contracts remain in
#29, #24/#25, and #97–#99. This change does not claim to complete those features.

## Recorded automated validation (2026-11-03)

- Unsigned generic iOS app build: passed.
- Unsigned generic iOS build-for-testing (app, unit, and UI test targets): passed.
- Isolated macOS Swift package using the unchanged request-state source and the
  two regression tests above, with network dependencies stubbed: 2 tests passed.
- Focused iPhone simulator test attempt: app/test runners compiled, but the
  simulator would not remain booted after a CoreSimulator/Xcode version mismatch.
  The stalled run was stopped; UI execution and the live-backend rehearsal above
  remain pending on a working simulator/device.

## Update against team main (2026-11-15)

Applied the existing #96 fix to team main `066ae69`, retaining the new Back-button
accessibility identifier/label, authentication flow, and authenticated demo
transport. No personal-analysis API integration or cloud-sync enablement is
included. The existing local Xcode development-team setting is outside this change.

Validation with Xcode 27.2 on 2026-11-15:

- Unsigned generic iOS Simulator build-for-testing: passed for app, unit, and UI targets.
- Focused iPhone 18 Pro simulator run: 2 request-state tests and 1 Home → personal
  routine → explicit demo → Home UI test passed.
- Isolated macOS package: the unchanged request-state source and the same 2
  regression tests passed with stubbed transport dependencies.
- `git diff --check`: passed.
- Live Firebase/backend scenario rehearsal remains pending; the UI test uses
  bundled reference findings and does not submit personal or demo API requests.

Result bundle: `/tmp/an96-focused.xcresult` (local, not committed).
