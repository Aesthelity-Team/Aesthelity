<div align="center">

# Aesthelity

**Skincare Routine Optimizer**  
CECS 491B Senior Project II - Section 05

### Understand your ingredients. Build a routine with clarity.

**iOS Skincare App · Research-Driven Design · CSULB Senior Project**

[Explore the Prototype](https://www.figma.com/proto/ywIYImESR8acfQFFtR4RV1/Aesthelity-Scrollable-Prototype---Fresh-Start?node-id=82-55&starting-point-node-id=82%3A55) · [View the Design File](https://www.figma.com/design/ywIYImESR8acfQFFtR4RV1/Aesthelity-Scrollable-Prototype---Fresh-Start?node-id=0-1) · [Development Roadmap](#development-roadmap)

</div>

---

Aesthelity is an iOS skincare application in development that helps users understand product ingredients, review how products fit into their AM and PM routines, and make more informed skincare decisions.

Developed as a Computer Science senior project at California State University, Long Beach, Aesthelity combines user research, an accessible interface, and a planned routine-analysis system to reduce skincare research fatigue.

## Project Status

Our team is currently executing **Sprint 1**. The Sprint 1 goal is to launch the iOS app with a five-tab shell, support optional skin-profile setup, display sample AM/PM routines, and show a mocked explanatory analysis finding.

| Milestone | Schedule |
| --- | --- |
| **Sprint window** | September 30, 2026 - October 14, 2026 |
| **Sprint review/demo** | Wednesday, October 14, 2026 |

> [!NOTE]
> Sprint 1 uses sample routines and mocked analysis. These demonstrate the intended experience and do not represent validated ingredient analysis or a production release. Features below describe the broader product plan unless explicitly identified as Sprint 1 targets.

## Contents

[Status](#project-status) · [Overview](#why-aesthelity) · [Research](#research-and-design-foundation) · [Features](#intended-features) · [Navigation](#app-navigation) · [Tech Stack](#planned-technology-stack) · [Design](#design-resources) · [Roadmap](#development-roadmap) · [Getting Started](#getting-started) · [Team](#team-and-collaboration) · [Branch Naming](#branch-naming-quick-reference)

---

## Why Aesthelity?

Building a skincare routine often means navigating unfamiliar ingredient names, conflicting recommendations, and uncertainty about product combinations. Users may spend substantial time researching a single product and still struggle to understand whether it fits their existing routine.

Aesthelity is designed to bring ingredient explanations, routine context, and personal skin information into one experience. Its focus extends beyond an isolated product rating: users should be able to understand **why** a combination warrants attention and **how** layering guidance relates to their routine.

## Research and Design Foundation

The team's Milestone 2 research included **15 semi-structured interviews**. Recurring findings included ingredient confusion, time-consuming research, trial-and-error routines, concern about adverse reactions, and difficulty identifying trustworthy guidance.

<details>
<summary><strong>How research shaped the product</strong></summary>

| Research finding | Intended product response |
| --- | --- |
| Complex ingredient labels overwhelm users. | Explain ingredient functions in plain language. |
| Users struggle to understand combinations and layering. | Provide AM/PM routine views and contextual compatibility explanations. |
| Research spans several platforms and takes too much time. | Bring product information and routine review into one workflow. |
| Users are uncertain about products for their individual skin needs. | Consider user-provided skin type, concerns, and sensitivities. |
| Opaque ratings undermine trust. | Explain the basis and limitations of guidance instead of relying on an unexplained score. |

</details>

These findings guide the product's emphasis on clarity, transparency, and beginner-friendly navigation.

## Intended Features

The following capabilities are part of the product design or development plan. Implementation status should be tracked through repository issues and the project board.

| Capability | Intended experience |
| --- | --- |
| **Personal skin profile** | Record skin type, concerns, sensitivities, and preferences to inform routine guidance. |
| **AM/PM routine builder** | Organize products and review their intended order of use. |
| **Routine compatibility review** | Surface potential ingredient conflicts and explain layering considerations in the context of the user's routine. |
| **Ingredient explanations** | Translate unfamiliar ingredient names into understandable descriptions of their functions and relevant cautions. |
| **Product scanning and image upload** | Help users identify products and review ingredient information from a captured or uploaded image. |
| **Personal product library** | Organize products into “Want to Try,” “Love,” and “Avoid” collections, with search and filters. |
| **Skin journal** | Record daily observations and revisit entries through a calendar view. |
| **Explore hub** | Browse educational guides and discover products relevant to skincare interests. |
| **Profile and settings** | Review personal information and manage preferences and privacy controls. |

<details>
<summary><strong>MVP scope and deferred features</strong></summary>

Advanced AI-generated full-routine optimization, long-term adaptive skin-profile learning, detailed overexposure models, social/review integrations, and monetization were deferred during MVP scoping. Makeup-related collection and matching flows remain proposed and require scope confirmation.

Compatibility labels and explanations are intended as educational guidance, not guarantees of safety or predicted clinical outcomes.

</details>

## App Navigation

The information architecture organizes the experience into five primary destinations:

| Destination | Primary responsibilities |
| --- | --- |
| **Home** | AM/PM routines, routine-step details, and access to the skin journal. |
| **Library** | Saved collections, product search, filters, and product details. |
| **Scan** | Product capture/upload, processing, results, and save confirmation. |
| **Explore** | Educational guides, guide search, and links to relevant products. |
| **Profile** | Skin-profile overview, routine and journal access, and settings. |

The latest design diagrams also specify intended recovery paths for unreadable images, empty results, network failures, invalid input, and unsuccessful saves. These paths are design requirements to implement and verify.

## Planned Technology Stack

| Layer | Technology | Intended responsibility |
| --- | --- | --- |
| iOS application | Swift and SwiftUI | Native interface, navigation, and application state. |
| Backend services | Firebase | Authentication and persistence for profiles, routines, saved products, and journal entries. |
| Analysis API | Python and FastAPI | Ingredient-processing and routine-analysis endpoints. |
| Analysis approach | Rule-based logic; OpenAI API integration under consideration | Structured compatibility checks and readable explanations, subject to source grounding and validation. |
| Design | Figma | Wireframes, interactive prototypes, and information architecture. |
| Collaboration | GitHub and GitHub Projects | Version control, issue tracking, task ownership, and peer review. |

The intended architecture connects the SwiftUI app to Firebase for account and application data, and to a FastAPI service for analysis. Final service choices, API contracts, and analysis methods may evolve during implementation.

## Design Resources

The following links are recorded in the team's Milestone 4 submission. Availability depends on the Figma sharing settings.

- [Interactive prototype](https://www.figma.com/proto/ywIYImESR8acfQFFtR4RV1/Aesthelity-Scrollable-Prototype---Fresh-Start?node-id=82-55&starting-point-node-id=82%3A55)
- [Wireframes and design file](https://www.figma.com/design/ywIYImESR8acfQFFtR4RV1/Aesthelity-Scrollable-Prototype---Fresh-Start?node-id=0-1)
- [Original information architecture board](https://www.figma.com/board/ODZdxPK6gCR61gKwZWeakT/Untitled?node-id=1-2)

Supporting project materials include the team charter, user-research and persona documentation, market analysis, and information-architecture diagrams. Earlier documents may use the working name **IngredientIQ** or **IngredientsIQ**.

## Sprint 1 Targets

- [ ] Launch the iOS application with a five-tab shell.
- [ ] Support optional skin-profile setup.
- [ ] Display sample AM/PM routines.
- [ ] Show a mocked analysis finding with an understandable explanation.

These checkboxes represent sprint targets, not verified completion. Track acceptance criteria and implementation progress in the project board.

## Development Roadmap

- [ ] Refine onboarding and confirm authentication scope.
- [ ] Replace vague compatibility scores with actionable explanations and layering guidance.
- [ ] Build and connect the core profile, product-library, and AM/PM routine workflows.
- [ ] Establish ingredient-data sources and validate the analysis rules and their limitations.
- [ ] Implement scan results, journal persistence, and relevant empty/error states.
- [ ] Verify navigation, save behavior, accessibility, and usability across the primary journeys.

Sprint commitments and completed work should be maintained in GitHub Issues and GitHub Projects.

## Getting Started

A verified installation and run guide is not yet included. Repository-specific commands, required versions, configuration names, and test instructions should be documented when the runnable application and services are available.

The planned development environment includes a Mac with Xcode for the iOS app, a Python environment for the analysis service, and access to the team's Firebase project.

Keep private credentials, service-account files, and analysis-provider API keys out of version control. Provider secrets should remain in the backend environment rather than being embedded in the iOS app. Use synthetic or de-identified data for shared examples.

## Team and Collaboration

Aesthelity is developed by **Team 2** at California State University, Long Beach:

| Team Member |
| --- |
| Isabel Lopez |
| Gaurav Pandey |
| Mia Carter |
| Liza Grande |
| Najih Sherif |

The team uses GitHub Projects for task ownership and progress tracking. Changes should connect to an issue or user story, meet the agreed acceptance criteria, and receive peer review before merging when appropriate. Report bugs through repository issues with reproduction steps, expected behavior, and relevant screenshots that exclude personal data.

---

## Educational Use

Aesthelity is a student project intended to support skincare education and informed decision-making. It does not diagnose skin conditions or replace advice from a qualified healthcare professional. Ingredient information alone cannot establish how a complete formulation will affect an individual user.
