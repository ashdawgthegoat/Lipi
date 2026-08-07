# ADR-0002 (Working Draft)

# Sprint 1 -- Phase 4 Conclusions

**Status:** Draft

## Objective

Translate the approved software architecture into a repository structure
that is easy to understand, maintain and extend.

------------------------------------------------------------------------

## Core Philosophy

The repository should mirror the architecture.

Clinical Workflow

↓

Domains

↓

Capabilities

↓

Repository Structure

Technology choices must never dictate the organization of the project.

------------------------------------------------------------------------

## Repository Blueprint

``` text
lipi/

├── assets/
├── docs/
├── lib/
│   ├── app/
│   ├── domains/
│   │   ├── patient/
│   │   ├── doctor/
│   │   └── application/
│   ├── infrastructure/
│   │   ├── ink/
│   │   ├── storage/
│   │   ├── search/
│   │   └── export/
│   ├── shared/
│   └── main.dart
├── test/
└── pubspec.yaml
```

------------------------------------------------------------------------

## Folder Responsibilities

### app/

Application startup, routing, dependency injection and bootstrap.

### domains/

Stable business logic.

-   patient/: patient records and consultations.
-   doctor/: doctor profile, templates, signature and preferences.
-   application/: orchestration between domains.

### infrastructure/

Replaceable implementations.

-   ink/
-   storage/
-   search/
-   export/

### shared/

Only truly shared resources such as design system, typography, colors,
common widgets and constants.

Rule:

> If something can belong somewhere else, it must not be placed in
> shared.

### docs/

Architecture records, sprint reports and project philosophy.

### assets/

Fonts, icons, templates and images.

### test/

Should mirror the structure of lib/.

------------------------------------------------------------------------

## Architectural Principles

-   Organize by responsibility, not by file type.
-   Repository mirrors architecture.
-   Stable business core, replaceable infrastructure.
-   Flutter is a toolkit, not the architecture.
-   Technologies may change; responsibilities should remain stable.

------------------------------------------------------------------------

## Future Direction

A shared Wanderer SDK may emerge after multiple mature projects share
common engineering patterns.

It should be extracted from experience rather than designed in advance.

------------------------------------------------------------------------

## Phase 4 Outcome

Phase 4 freezes the Version 1 repository structure.

The repository is organized around Lipi's business responsibilities
instead of its implementation technologies, making it easier for future
contributors to understand and extend.
