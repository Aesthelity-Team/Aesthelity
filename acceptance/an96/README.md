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
2. Open Demo / Dev Mode. With the local backend running (see Backend/README.md),
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
