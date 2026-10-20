# Testing pull requests

The iOS CI workflow automatically compiles the app on pull requests and pushes to main. Its **Build app** check uses a generic iOS Simulator destination without booting a simulator. It does not execute tests or establish that app behavior is correct. Failed build result bundles are retained for seven days.

Before merging, a reviewer should manually exercise the affected flows and record the tested commit, simulator/device, steps and results in the PR. For integration changes, check onboarding, saved profile persistence after relaunch, AM/PM routines, mocked findings and tab navigation. Document known limitations rather than treating unimplemented features as passing.

## Manual automated suites

In GitHub Actions, choose **iOS unit tests (manual)** or **iOS UI tests (manual)**, select **Run workflow**, and choose the branch to test. These workflows become available in the Actions interface after they land on the default branch. Both build for testing and run their respective existing suites with parallel testing disabled. The unit workflow explicitly boots the selected simulator and waits for readiness. Failed runs upload TestResults or UITestResults artifacts retained for seven days.

Run relevant suites for logic/UI changes and run both before demos/releases. UI failures remain tracked in #84; changing execution policy does not resolve those failures. DATA-01 dataset checks remain automatic and independent.

## Repository settings

The automatic check is now named **Build app**, replacing **Build and unit test**. A repository admin must update any required-check configuration to the new name. This intentionally changes the original PL-06 (#60) automatic unit-test scope to build-only checks; unit coverage remains available through the manual workflow.
