# ADR-0002 (Working Draft)

# Sprint 1 -- Phase 1 Conclusions

> Status: Draft Project: Lipi Phase: Sprint 1 -- Domain Discovery

------------------------------------------------------------------------

## Objective

Establish the fundamental domain model of Lipi before designing its
software architecture.

------------------------------------------------------------------------

# Question 1 --- Fundamental Domain Entities

The following entities form the vocabulary of Lipi's problem domain.

-   Patient
-   Patient Record
-   Consultation
-   Clinical Note
-   Symptom
-   Investigation
-   Diagnosis
-   Prescription
-   Treatment
-   Follow-up
-   Attachment
-   Template
-   Doctor

These entities were derived from the clinical workflow rather than
implementation details.

------------------------------------------------------------------------

# Question 2 --- High-Level Bounded Contexts

Three high-level domains were identified.

## Patient Domain

Responsible for everything related to the patient's clinical journey.

## Doctor Domain

Responsible for the doctor's professional identity, preferences, and
reusable clinical assets.

> Future Consideration: If Lipi introduces additional user roles (Nurse,
> Receptionist, Administrator, Patient Portal, etc.), this domain may
> evolve into a generalized **Actor Domain**.

## Application Domain

Responsible for the shared capabilities and orchestration required by
the rest of the application.

------------------------------------------------------------------------

# Question 3 --- Domain Responsibilities

## Patient Domain

Responsible for managing the complete clinical record of a patient
throughout their care.

## Doctor Domain

Responsible for managing the professional identity, preferences,
reusable assets, and authorized actions performed by the doctor.

## Application Domain

Responsible for providing shared capabilities, infrastructure, and
orchestration for the Patient and Doctor domains.

------------------------------------------------------------------------

# Question 4 --- Communication Model

The following architectural principles were established:

-   Domains do not directly manipulate another domain's internal state.
-   Every domain exposes well-defined operations.
-   Cross-domain workflows are coordinated by the Application Domain.
-   The Application Domain acts as the orchestrator rather than the
    owner of medical information.

------------------------------------------------------------------------

# Question 5 --- Data Ownership

Every piece of persistent data has exactly one owner.

## Patient Domain owns

-   Patient information
-   Patient records
-   Consultations
-   Clinical notes
-   Diagnoses
-   Prescriptions
-   Treatments
-   Follow-ups
-   Attachments

## Doctor Domain owns

-   Doctor profile
-   Clinic information
-   Signature
-   Templates
-   Professional preferences

## Application Domain owns

Application-specific state only, such as:

-   Search index
-   Cache
-   Workspace state
-   Theme
-   Plugin registry (future)
-   Synchronization queue (future)

The Application Domain is **not** the source of truth for medical
information.

------------------------------------------------------------------------

# Question 6 --- Stable Contracts

Each domain is defined by its responsibility rather than its
implementation.

## Responsibility Invariance Principle

A domain's implementation may evolve indefinitely, but its
responsibility must remain stable.

Therefore:

-   The Patient Domain must always remain responsible for patient
    clinical information.
-   The Doctor Domain must always remain responsible for doctor-related
    information and authorized actions.
-   The Application Domain must always remain responsible for
    orchestration and shared application capabilities.

Internal technologies may change without affecting these
responsibilities.

------------------------------------------------------------------------

# Phase 1 Outcome

Phase 1 successfully established the conceptual foundation of Lipi.

The architecture is centered around three independent domains:

-   Patient Domain
-   Doctor Domain
-   Application Domain

The Patient and Doctor domains remain independent, while the Application
Domain coordinates workflows between them.

This foundation will serve as the basis for Phase 2 (High-Level
Architecture).
