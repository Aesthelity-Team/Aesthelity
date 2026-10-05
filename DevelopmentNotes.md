Aesthelity

Skincare Routine Optimizer
CECS 491B Senior Project II - Section 05

Aesthelity is an iOS application that helps users understand skincare products, identify potential ingredient interactions, and build routines tailored to their skin concerns and past reactions.
Branch naming quick reference

Use the pattern issue-number-short-description for development branches.

Example: 15-welcome-first-use

    15 = the GitHub issue number
    welcome-first-use = a short description of the work

Project status

Our team is currently executing Sprint 1. The Sprint 1 goal is to launch the iOS app with a five-tab shell, support optional skin-profile setup, display sample AM/PM routines, and show a mocked explanatory analysis finding.

Sprint window: September 30, 2026 - October 14, 2026
Sprint review/demo: Wednesday, October 14, 2026
Team: Gaurav Pandey, Belle Lopez, Mia Carter, Najih Sherif, and Liza Grande
Core product areas

    Onboarding and first-use setup
    Optional skin profile and personalization
    Product catalog and ingredient normalization
    Routine creation, scheduling, and completion tracking
    Ingredient compatibility and plain-language analysis
    Product library, label scanning, journal, and Explore features

| GitHub Issue | Story ID | Story | Owner | Points |
|---:|---|---|---|---:|
| #1 | DATA-01 | Build curated demo product set | Belle Lopez | 5 |
| #2 | DATA-02 | Normalize ingredient names | Gaurav Pandey | 3 |
| #3 | ON-01 | Welcome and first-use entry | Mia Carter | 3 |
| #4 | PF-01 | Optional sample skin profile | Najih Sherif | 3 |
| #5 | UI-01 | Five-tab app shell | Liza Grande | 3 |
| #10 | RT-01 | View sample AM/PM routines | Mia and Liza | 5 |
| #11 | AN-01 | Inspect mocked explanatory analysis finding | Belle and Gaurav | 5 |

The original planning document lists a 27-point Sprint 1 roadmap target, while the explicitly committed stories total 17 points. The team should confirm whether the remaining roadmap stories are planned, stretch work, or intentionally excluded from the commitment before the demo.
Semester roadmap
Sprint 	Focus 	Demo
Sprint 0 	Planning, contracts, repository, board, and device setup 	-
Sprint 1 	iOS shell, onboarding, sample profile, and mock routine analysis 	Wed, Oct 14, 2026
Sprint 2 	Product input, routine persistence, protected API analysis 	Wed, Oct 28, 2026
Sprint 3 	Routine journeys, personalization, makeup, and integration 	Wed, Nov 18, 2026
Sprint 4 	Library, scanner, journal, Explore, settings, accessibility, and handoff 	Wed, Dec 9, 2026
Development workflow

    Create a branch from main for each issue, using a name such as 14-normalize-ingredients.
    Link the pull request to its GitHub issue with Closes #<issue-number>.
    Add tests and screenshots or a short verification note when applicable.
    Request at least one teammate review before merging.
    Merge only through a pull request after checks pass.

Repository structure

The repository structure will follow the implementation choices selected by the team. Recommended top-level areas are:

Aesthelity/
├── App/             # Application entry point and app-level configuration
├── Features/        # Feature screens and view models
├── Models/          # Shared domain models
├── Services/        # API, persistence, and analysis services
├── Resources/       # Assets, sample data, and configuration
└── Tests/           # Unit and UI tests

Team

    Gaurav Pandey
    Belle Lopez
    Mia Carter
    Najih Sherif
    Liza Grande

Course

CECS 491B Senior Project II, Section 05
