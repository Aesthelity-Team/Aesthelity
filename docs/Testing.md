# Testing pull requests

The iOS CI workflow automatically builds the app and runs AesthelityTests on pull requests and pushes to main. Its Build and unit test check does not include UI validation. The selected simulator is explicitly booted before building, and unit tests run with parallel testing disabled to avoid simulator clone startup overhead.

Before merging, a reviewer should manually exercise the affected flows and record the tested commit, simulator/device, steps and results in the PR. For integration changes, check onboarding, saved profile persistence after relaunch, AM/PM routines, mocked findings and tab navigation. Document known limitations rather than treating unimplemented features as passing.

## Optional automated UI suite

In GitHub Actions, select **iOS UI tests (manual)**, choose **Run workflow**, and select the branch to test. The workflow becomes available in the Actions interface after it lands on the default branch. It builds the app and runs the existing full UI suite with parallel testing disabled. Failed runs upload a UITestResults artifact retained for seven days.

Run this suite before demos/releases and when investigating UI changes. UI failures remain tracked in #84; moving execution to a manual workflow does not resolve the launch/termination failures. Keep DATA-01 dataset checks enabled independently.
