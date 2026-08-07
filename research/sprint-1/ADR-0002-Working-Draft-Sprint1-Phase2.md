# ADR-0002 (Working Draft)

# Sprint 1 -- Phase 2 Conclusions

**Status:** Draft

## Objective

Translate the domain model into a product-centric workflow without
prematurely designing implementation details.

------------------------------------------------------------------------

## Key Realization

The architecture of Lipi should emerge from the doctor's consultation
workflow rather than from software engineering abstractions.

The workflow dictates the architecture---not the other way around.

------------------------------------------------------------------------

## Observed Clinical Workflow

1.  Patient enters.
2.  Doctor identifies the patient.
3.  Doctor listens to symptoms.
4.  Reviews previous history when required.
5.  Performs examination/investigation.
6.  Reaches a diagnosis.
7.  Explains the diagnosis.
8.  Writes the prescription (or referral / leave letter / scan request).
9.  Decides follow-up.
10. Consultation ends.

Lipi mainly participates during documentation after the diagnosis has
been formed.

------------------------------------------------------------------------

## Product Definition

Lipi is **not** merely a note-taking application.

Lipi is a **consultation workspace** that preserves clinical continuity
while allowing doctors to continue their natural handwriting workflow.

Handwriting is the medium.

Clinical continuity is the product.

------------------------------------------------------------------------

## Clinical Context First

Opening a patient should immediately show:

-   Previous prescription
-   Relevant history
-   Timeline of consultations (future)

The goal is to reconstruct context before new information is created.

------------------------------------------------------------------------

## Context Before Creation

The workflow should be:

Open Patient

↓

Understand Context

↓

Write Today's Prescription

↓

Save

Today's consultation becomes tomorrow's context.

------------------------------------------------------------------------

## Workflow Before Modules

Architectural modules must emerge from the consultation workflow.

Features exist only if they support the doctor's natural practice.

------------------------------------------------------------------------

## Reliability Principle

The doctor's expectation is simple:

> Whatever is written must be saved.

This implies:

-   Offline-first
-   Autosave
-   Reliable persistence
-   Crash recovery

------------------------------------------------------------------------

## UX Principle

Reduce thinking about the software.

Increase thinking about the patient.

The software should disappear into the consultation.

------------------------------------------------------------------------

## Phase 2 Outcome

Phase 2 established that Lipi should be designed around the consultation
workflow rather than software abstractions.

Future architectural diagrams and implementation decisions must derive
from this workflow.
