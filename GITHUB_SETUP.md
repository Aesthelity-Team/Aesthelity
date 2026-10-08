# Aesthelity GitHub setup

This checklist converts the Milestone 2 plan into a GitHub operating setup.

## Branch naming quick reference

Use the pattern:

```text
issue-number-short-description
```

## Organization and repository

- Organization: create or confirm the team organization name.
- Repository: `Aesthelity`
- Visibility: use the course team's agreed visibility setting.
- Transfer or fork the current repository `Belleairr/Aesthelity` only after confirming where the canonical repository should live.
- Add `fahd.albinali@csulb.edu` with the required administrator/maintainer access, subject to the instructor's GitHub account and course policy.

## Project board

Create a GitHub Project named `Aesthelity - Semester Roadmap` with these columns/statuses:

1. Product Backlog
2. Sprint Backlog
3. In Progress
4. In Review / PR
5. Done

Add custom fields:

- Sprint: Sprint 0, Sprint 1, Sprint 2, Sprint 3, Sprint 4, Later Queue
- Priority: P0, P1, P2
- Story Points: 1, 2, 3, 5, 8
- Epic/Module: Onboarding, Skin Profile, Navigation, Data & Catalog, Routine, Analysis, Backend, Library, Scanner, Journal, Explore, QA

## Sprint 1 labels

Create these labels before importing the issues:

- `sprint-1`
- `priority-p0`
- `epic:data-catalog`
- `epic:onboarding`
- `epic:skin-profile`
- `epic:navigation`
- `type:user-story`

## Sprint 1 issue import

Create these five issues and add each to the Project's Sprint 1 view.

### #1 - Build curated demo product set (DATA-01)

- **Owner:** Belle Lopez
- **Module:** Data & Catalog
- **Priority:** P0 / High
- **Points:** 5
- **Labels:** `sprint-1`, `priority-p0`, `epic:data-catalog`, `type:user-story`
- **Story:** As a developer, I want to select permitted real or clearly fictional products, transcribe ingredient lists, and categorize them so that we have a foundational dataset.

Technical tasks:

- Define the sample product model and required fields.
- Add representative skincare and makeup products.
- Store ingredient lists, categories, URLs, provenance, and verification dates.
- Add normal, caution, allergen, and unknown test scenarios.
- Add fixture tests for dataset coverage.

Acceptance criteria:

- Given the demo dataset is loaded, when the catalog is opened, then skincare and makeup products are available.
- Given a product has a scenario classification, when it is inspected, then normal, caution, allergen, and unknown cases are represented.
- Given a product record is stored, when its metadata is inspected, then source URL, verification date, provenance, and coverage information are present.

### #2 - Normalize ingredient names (DATA-02)

- **Owner:** Gaurav Pandey
- **Module:** Data & Catalog
- **Priority:** P0 / High
- **Points:** 3
- **Labels:** `sprint-1`, `priority-p0`, `epic:data-catalog`, `type:user-story`
- **Story:** As a developer, I want to build canonical IDs and alias mapping for ingredient strings so that ambiguous inputs are properly handled.

Technical tasks:

- Define canonical ingredient IDs and normalized display names.
- Add alias and spelling-variant mappings.
- Define unmatched and uncertain states.
- Record normalization warnings for auditability.
- Add normalization fixtures and unit tests.

Acceptance criteria:

- Given spelling or alias variants, when they are normalized, then they converge on the correct canonical ingredient ID.
- Given an unmatched or uncertain value, when analysis runs, then it is not silently treated as safe.
- Given an ambiguous input, when normalization completes, then the input and warning are recorded.

### #3 - Welcome and first-use entry (ON-01)

- **Owner:** Mia Carter
- **Module:** Onboarding
- **Priority:** P0 / High
- **Points:** 3
- **Labels:** `sprint-1`, `priority-p0`, `epic:onboarding`, `type:user-story`
- **Story:** As a first-time user, I want a welcome screen that explains the app and starts setup so that I know how to begin.

Technical tasks:

- Build the welcome screen from the approved prototype.
- Add the Get Started navigation action.
- Persist first-use/returning-user state.
- Add a returning-user route on relaunch.
- Add UI tests for first launch, relaunch, and repeated taps.

Acceptance criteria:

- Given a first launch, when the app opens, then the welcome screen is displayed.
- Given the welcome screen is displayed, when Get Started is tapped, then setup opens.
- Given Get Started is tapped repeatedly, when navigation completes, then only one setup view is presented.

### #4 - Optional sample skin profile (PF-01)

- **Owner:** Najih Sherif
- **Module:** Skin Profile
- **Priority:** P0 / High
- **Points:** 3
- **Labels:** `sprint-1`, `priority-p0`, `epic:skin-profile`, `type:user-story`
- **Story:** As a user, I want to enter or skip basic skin type, concerns, and ingredients I avoid so that later guidance can reflect information I choose to provide.

Technical tasks:

- Build skin type, concern, and avoided-ingredient controls.
- Add profile summary state.
- Implement the skip path with an explicit incomplete-profile state.
- Validate free-text input inline.
- Add UI and state tests for complete, skipped, and invalid input flows.

Acceptance criteria:

- Given valid profile choices, when the user continues, then the summary accurately displays the selected values.
- Given the user skips setup, when setup completes, then the profile is marked explicitly incomplete.
- Given invalid free text, when the user submits it, then an inline error is shown and the entered value is retained.

### #5 - Five-tab app shell (UI-01)

- **Owner:** Liza Grande
- **Module:** Navigation
- **Priority:** P0 / High
- **Points:** 3
- **Labels:** `sprint-1`, `priority-p0`, `epic:navigation`, `type:user-story`
- **Story:** As a user, I want to move among Home, Library, Scan, Explore, and Profile so that I can find each main part of Aesthelity.

Technical tasks:

- Build the five-tab root navigation.
- Add selected/unselected tab states.
- Add root placeholder views for unfinished features.
- Preserve each tab's navigation context when switching.
- Add navigation tests for all tabs and return behavior.

Acceptance criteria:

- Given the app shell is open, when each tab is tapped, then that tab is highlighted and its root view appears.
- Given a user returns from a detail route, when the prior tab is selected, then its navigation context is preserved.
- Given a feature is not yet implemented, when its root view opens, then it clearly describes the planned function.

## Branch protection for `main`

Enable these rules after the first team members are added:

- Require a pull request before merging.
- Require at least one approving review.
- Dismiss stale approvals when new commits are pushed.
- Require status checks to pass when CI is available.
- Require conversation resolution.
- Restrict direct pushes to `main`.
- Allow administrators to bypass only if course policy requires it.

## Access checklist

- [ ] Confirm canonical organization name.
- [ ] Confirm repository owner and visibility.
- [ ] Add all five student engineers.
- [ ] Add `fahd.albinali@csulb.edu` with the requested instructor access.
- [ ] Create the Project board and add the repository.
- [ ] Create labels and custom fields.
- [ ] Create/import Sprint 1 issues.
- [ ] Enable branch protection on `main`.
- [ ] Verify that every Sprint 1 issue appears in the Sprint Backlog view.
