# ADR-0002 --- Overall Architecture

**Status:** Accepted\
**Project:** Lipi

## Executive Summary

Sprint 1 establishes the architectural foundation of Lipi. Lipi is a
consultation workspace built around the workflow of doctors, not a
generic note-taking application. Every architectural decision is derived
from clinical workflow rather than technology.

## Product Philosophy

-   Technology follows workflow.
-   Clinical continuity is the product.
-   Handwriting is the medium.
-   Context before creation.
-   Doctor decides.
-   Assist, never assume.

## Clinical Workflow

1.  Identify patient.
2.  Listen.
3.  Review history.
4.  Examine.
5.  Diagnose.
6.  Explain.
7.  Write prescription.
8.  Decide follow-up.
9.  Save consultation.

## Architectural Constitution

-   Local-first
-   Offline-first
-   Workflow-first
-   Doctor owns data
-   Stable core, replaceable infrastructure
-   Repository mirrors architecture
-   Organize by responsibility

## Domains

### Patient Domain

Owns patient records and clinical history.

### Doctor Domain

Owns doctor identity, templates, signature and preferences.

### Application Domain

Coordinates workflows and owns only application state.

## Communication

Domains never modify each other directly. The Application Domain
orchestrates cross-domain workflows.

## Version 1 Capabilities

-   Workspace
-   Patient Records
-   Doctor Profile
-   Search
-   Storage
-   Export

## Clinical Document Lifecycle

Create → Store → Retrieve → Update → Export

## Stable Core

-   Patient Records
-   Doctor Profile
-   Clinical Document Lifecycle

## Replaceable Infrastructure

-   Ink Engine
-   Search Engine
-   Storage Engine
-   Export Engine

## Repository Blueprint

``` text
lipi/
├── assets/
├── docs/
├── lib/
│   ├── app/
│   ├── domains/
│   ├── infrastructure/
│   ├── shared/
│   └── main.dart
├── test/
└── pubspec.yaml
```

## Deferred Decisions

-   AI
-   Plugins
-   Cloud Sync
-   Hospital Mode
-   Actor Domain
-   Wanderer SDK
-   Mind Maps

These are intentionally postponed.

## Conclusion

Sprint 1 freezes the architectural direction of Lipi. Future work should
extend this architecture rather than replace it.

**Technology should adapt to the doctor's workflow, not the other way
around.**
