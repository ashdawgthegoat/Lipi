# ADR-0002 (Working Draft)

# Sprint 1 -- Phase 3 Conclusions

**Status:** Draft

## Objective

Translate the consultation workflow into the core software capabilities
required for Version 1 while keeping the architecture simple,
maintainable and workflow-driven.

------------------------------------------------------------------------

# Core Principle

The consultation workflow remains the source of truth.

Capabilities exist only because they directly support that workflow.

If a capability does not noticeably improve a normal consultation, it
does not belong in Version 1.

------------------------------------------------------------------------

# Version 1 Core Capabilities

## Workspace

Exists because the doctor needs a natural environment to write
prescriptions and other clinical documents using handwriting.

## Patient Records

Exists because every patient's clinical history must persist across
consultations.

## Doctor Profile

Exists because every generated document should carry the doctor's
professional identity and reusable assets such as clinic information,
signature and prescription template.

## Search

Exists because patient records must be retrieved quickly without
manually browsing hundreds of records.

## Storage

Exists because clinical information must be stored safely and reliably.

## Export

Exists because prescriptions and other clinical documents must be shared
physically or digitally whenever required.

------------------------------------------------------------------------

# Capabilities Deferred

The following were intentionally excluded from Version 1:

-   AI Assistance
-   Plugin System
-   Themes / Appearance customization
-   Analytics
-   Mind Maps
-   Cloud Synchronization
-   Advanced Backup Features

These may be introduced in future releases only if they solve a real
clinical problem.

------------------------------------------------------------------------

# Heart of Lipi

The heart of Lipi is the **Clinical Document Lifecycle**.

Create

↓

Store

↓

Retrieve

↓

Update

↓

Export

Every major capability exists to support one or more stages of this
lifecycle.

------------------------------------------------------------------------

# Stable Core vs Replaceable Infrastructure

## Stable Business Core

-   Patient Records
-   Doctor Profile
-   Clinical Document Lifecycle

These define the business of Lipi and should remain stable.

## Replaceable Infrastructure

The following implementations should be replaceable without affecting
the business logic:

-   Ink Engine
-   Search Engine
-   Storage Engine
-   Export Engine

Technology may evolve.

Responsibilities should not.

------------------------------------------------------------------------

# Primary Navigation Workflow

Authentication

↓

Search Patient

↓

Open Patient Record

↓

Display Consultation History

↓

Doctor chooses the relevant previous consultation or prescription

↓

Workspace

↓

Write

↓

Save

The application must never automatically assume which consultation is
relevant.

Clinical judgment always belongs to the doctor.

------------------------------------------------------------------------

# UX Principles

## Assist, Never Assume

Lipi should present clinical information without deciding what is
medically relevant.

Navigation should be excellent.

Clinical decisions remain entirely with the doctor.

## Doctor Decides

The software exists to support medical expertise, not replace it.

------------------------------------------------------------------------

# Architectural Principles Established

-   Workflow before modules.
-   Stable core, replaceable infrastructure.
-   Capabilities exist because of clinical needs, not technical
    curiosity.
-   Every feature must pass the Clinic Test:
    -   If removing it would not noticeably affect a normal
        consultation, it does not belong in Version 1.

------------------------------------------------------------------------

# Phase 3 Outcome

Phase 3 identified the essential software capabilities required to
implement Lipi Version 1.

The project now has:

-   A workflow-driven architecture
-   Clearly defined core capabilities
-   Stable business responsibilities
-   Replaceable technical infrastructure
-   UX principles that preserve clinical judgment

The next phase will translate these architectural decisions into the
repository structure and implementation blueprint.
