# Aesthelity

**Skincare Routine Optimizer**  
CECS 491B Senior Project II - Section 05

Aesthelity is an iOS application that helps users understand skincare products, identify potential ingredient interactions, and build routines tailored to their skin concerns and past reactions.

## Project status

The team is currently executing Sprint 1. The Sprint 1 goal is to launch the iOS app with a five-tab shell, support optional skin-profile setup, display sample AM/PM routines, and show a mocked explanatory analysis finding.

**Sprint window:** September 30, 2026 - October 14, 2026  
**Sprint review/demo:** Wednesday, October 14, 2026  
**Team:** Gaurav Pandey, Belle Lopez, Mia Carter, Najih Sherif, and Liza Grande

## Core product areas

- Onboarding and first-use setup
- Optional skin profile and personalization
- Product catalog and ingredient normalization
- Routine creation, scheduling, and completion tracking
- Ingredient compatibility and plain-language analysis
- Product library, label scanning, journal, and Explore features

## Sprint 1 scope

| Issue | Story | Owner | Points |
|---|---|---|---:|
| #12 | Build curated demo product set | Belle Lopez | 5 |
| #14 | Normalize ingredient names | Gaurav Pandey | 3 |
| #15 | Welcome and first-use entry | Mia Carter | 3 |
| #16 | Optional sample skin profile | Najih Sherif | 3 |
| #17 | Five-tab app shell | Liza Grande | 3 |

The original planning document lists a 27-point Sprint 1 roadmap target, while the explicitly committed stories total 17 points. The team should confirm whether the remaining roadmap stories are planned, stretch work, or intentionally excluded from the commitment before the demo.

## Semester roadmap

| Sprint | Focus | Demo |
|---|---|---|
| Sprint 0 | Planning, contracts, repository, board, and device setup | - |
| Sprint 1 | iOS shell, onboarding, sample profile, and mock routine analysis | Wed, Oct 14, 2026 |
| Sprint 2 | Product input, routine persistence, protected API analysis | Wed, Oct 28, 2026 |
| Sprint 3 | Routine journeys, personalization, makeup, and integration | Wed, Nov 18, 2026 |
| Sprint 4 | Library, scanner, journal, Explore, settings, accessibility, and handoff | Wed, Dec 9, 2026 |

## Development workflow

1. Create a branch from `main` for each issue, using a name such as `14-normalize-ingredients`.
2. Link the pull request to its GitHub issue with `Closes #<issue-number>`.
3. Add tests and screenshots or a short verification note when applicable.
4. Request at least one teammate review before merging.
5. Merge only through a pull request after checks pass.

## Repository structure

The repository structure will follow the implementation choices selected by the team. Recommended top-level areas are:

```text
Aesthelity/
├── App/             # Application entry point and app-level configuration
├── Features/        # Feature screens and view models
├── Models/          # Shared domain models
├── Services/        # API, persistence, and analysis services
├── Resources/       # Assets, sample data, and configuration
└── Tests/           # Unit and UI tests
```

## Team

- Gaurav Pandey
- Belle Lopez
- Mia Carter
- Najih Sherif
- Liza Grande

## Course

CECS 491B Senior Project II, Section 05
