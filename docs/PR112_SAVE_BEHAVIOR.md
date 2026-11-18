# #112: Manual product Save response reconciliation

Implemented against PR #112 head `ea9b52f` on November 17, 2026 (Pacific).

## Problem

Review calls ingredient resolution without persistence. Signed-in Save calls it again with persistence, so AI matching can change. The form previously ignored the Save rows and coverage and saved the earlier Review product locally. This could leave Firestore, the local product, and displayed coverage inconsistent.

## Behavior

`ManualProductSaving.save` coordinates cloud matching/persistence and the local write. The form uses this function, and tests inject its two operations directly.

| Save result | Device product and displayed review | User feedback |
| --- | --- | --- |
| Signed out | Save the reviewed copy locally | Dismiss after the local write succeeds |
| Valid cloud success, unchanged matches/coverage | Save the returned ordered matches locally | Dismiss after the local write succeeds |
| Valid cloud success, changed matches or coverage | Save and display the returned matches/coverage | Keep the form open and explain that the latest saved matches changed since Review |
| Cloud transport, matching, or response validation failure | Save the reviewed copy locally; preserve its coverage | Keep the form open; say that the device copy uses reviewed matches and cloud save could not be confirmed; offer Save again |
| Local write fails after cloud success | Retain the latest cloud matches/coverage in the form | Say the cloud write succeeded but the device write failed; keep entries available for retry |
| Local write fails without confirmed cloud success | Retain reviewed entries | Report local failure and, for a signed-in attempt, unconfirmed cloud save |
| Cloud operation is cancelled | Do not start the local write; retain entries | Report cancellation and unconfirmed cloud save |

Cloud and device writes are not an atomic transaction. A transport failure can occur after a server write, and a matching-failed payload can still contain a receipt for stored unresolved rows. The client therefore says **unconfirmed**, rather than promising the cloud record was unchanged. Repeating Save uses the same product ID; no automatic retry occurs.

## Successful response validation

Before replacing the Review product, require:

- Contract version 1, `status: ok`, and no failure code.
- A persistence receipt whose `productPath` is exactly `productIngredients/<submitted UUID>`.
- Exactly one result per submitted ingredient; indexes are precisely `0..<count`, without duplicates or gaps. Transport array order can differ; rows are sorted by index.
- Original text at each index matches the submitted text exactly, including repeated ingredients.
- Recognized mapping values. A confirmed mapping must retain a valid confirmed ingredient ID after conversion.
- Coverage agrees with the converted confirmed rows: none confirmed means unknown, all confirmed means complete, otherwise partial.

Tentative results without a catalog ID remain unresolved with their best-guess warning; they are not promoted to confirmed. Product ID, name, brand, category, source, schema version and raw label are retained by copying the reviewed product and replacing only its ingredient rows. Coverage is display state derived from the response; this change adds no persisted ManualProduct schema field.

The response model now decodes the optional persistence receipt. Non-persisting Review responses still decode without it. Response validation for this change applies to Save; it does not redesign the Review request lifecycle.

## Form behavior

While Save is pending, product fields, ingredient text, Review, Save, Cancel, and interactive sheet dismissal are disabled. This avoids changing or dismissing the submitted form during its two writes. After completion, the form uses the coordinator's product, coverage, note and error. Changed results and all failures remain visible for review/retry.

## Regression coverage

Tests exercise the production coordinator and include:

- Different Review/Save matches and coverage, out-of-order response rows, real local save/reload, retained metadata and raw label.
- Unchanged success and signed-out local saving.
- Tentative results without canonical IDs, repeated ingredient text and order.
- Cloud request failure, failed matching payload, cancellation, device write failure, cloud success followed by device failure, and a successful retry.
- Missing rows, duplicate/negative indexes, altered text, wrong/missing receipt, inconsistent coverage, wrong contract version, unknown mapping and invalid confirmed IDs.

Existing resolver request/decoding tests run alongside these cases. Tests use temporary device files and injected responses; they do not call a live model or Firestore.

## Verification record

- Xcode 27.2 (`27B52`), iOS 27.0 iPhone 17e simulator, serial execution.
- App and test targets compiled successfully. Focused simulator run: **14 Swift Testing tests in two suites passed**, including the ten invalid-response parameter cases. The XCTest header's zero count refers to XCTest; the Swift Testing summary confirms these tests executed.
- Focused result bundle: `/private/tmp/aesthelity-save112-focused.xcresult`; console log: `/private/tmp/aesthelity-save112-xcode.log`.
- A second run passed all **six existing ManualProductStoreTests** (real temporary file persistence, identity/order/warning round trips, updates, failed writes, corrupt archives and unsupported records).
- The same run selected `ManualProductUITests.testSaveWarningsAndRelaunch`, `testSaveFailureRetainsReviewAndAllowsRetry`, and `testCancelDoesNotSave`. **These UI cases did not execute**: the UI runner failed with `Timed out while preparing execution worker` (XCTFuture Code 1000; xcodebuild exit 65). This is not passing UI evidence and is not an assertion failure in a Save test. No blind rerun or infrastructure change was made.
- Second result bundle: `/private/tmp/aesthelity-save112-ui.xcresult`; console log: `/private/tmp/aesthelity-save112-ui.log`.
- `git diff --check` passed. Total executed Swift Testing declarations across the two runs: 20, all passed; the invalid-response declaration additionally exercised ten parameter cases.

Reproduce the focused test selection with:

```sh
xcodebuild test \
  -project Aesthelity/Aesthelity.xcodeproj \
  -scheme Aesthelity \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -parallel-testing-enabled NO \
  -only-testing:AesthelityTests/IngredientResolveAPITests \
  -only-testing:AesthelityTests/ManualProductSavingTests
```

The local run used an isolated derived-data directory and cached package checkout. Backend behavior was unchanged, so backend suites were not repeated for this Swift-only change. A broad UI suite was not used as proof for unrelated existing failures.

Affected storage/UI selection (same project, scheme and simulator):

```sh
xcodebuild test \
  -project Aesthelity/Aesthelity.xcodeproj \
  -scheme Aesthelity \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -parallel-testing-enabled NO \
  -only-testing:AesthelityTests/ManualProductStoreTests \
  -only-testing:AesthelityUITests/ManualProductUITests/testSaveWarningsAndRelaunch \
  -only-testing:AesthelityUITests/ManualProductUITests/testSaveFailureRetainsReviewAndAllowsRetry \
  -only-testing:AesthelityUITests/ManualProductUITests/testCancelDoesNotSave
```

The second local run used `test-without-building` against the artifacts compiled by the first run and `CODE_SIGNING_ALLOWED=NO`; a fresh environment can use the command above to build first.

## Scope and remaining acceptance

This fixes the local Save/response divergence. Hosted HTTPS/Firebase acceptance, cross-account/session lifecycle work, the separate #115/#112 API conflicts, and the existing CI UI failures remain separate integration work. A passing injected-response test does not establish live model accuracy or deployed persistence acceptance.

PR: https://github.com/Aesthelity-Team/Aesthelity/pull/112
