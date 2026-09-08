# Lipi MVP Specification

**Project:** Lipi
**Sprint:** Sprint 7 — MVP Implementation Planning
**Status:** Implementation Specification
**Authority:** ADR-0001 through ADR-0007

---

## 1. Purpose

This document defines the exact functional and behavioral scope of the Lipi MVP.

It translates the architectural decisions established in ADR-0001 through ADR-0007 into an implementation-facing product specification.

This document defines **what Lipi must do and what guarantees it must provide**.

It does not prescribe unnecessary implementation details. Those belong in the implementation architecture and engineering plan.

If an implementation decision conflicts with this specification or an accepted ADR, the ADR/specification takes precedence.

---

# 2. MVP Definition

The Lipi MVP is a **local-first, offline-first, handwriting-first clinical workspace for doctors**.

The MVP must allow a doctor to:

1. Configure their professional identity.
2. Configure a prescription template.
3. Create patients.
4. Search for existing patients.
5. Open a patient's workspace.
6. Review relevant patient information and clinical history.
7. Create a new prescription/consultation.
8. Write the prescription naturally using a stylus.
9. Navigate the prescription using touch gestures.
10. Automatically save the prescription.
11. Close and later reopen the prescription.
12. Review previous prescriptions.
13. Continue editing an existing prescription when intentionally requested.
14. Export a prescription to PDF.
15. Delete patient records through an explicit user action.
16. Maintain all clinical data locally in a doctor-owned Lipi Vault.

The canonical editable clinical record is the `.lipi` document.

PDF is a derived export representation.

Lipi does not require a remote server, cloud account, or network connection for normal MVP operation.

---

# 3. Core Product Principles

The MVP shall preserve the following principles established by the preceding architecture:

### 3.1 Technology follows workflow

Implementation choices must serve the clinical workflow rather than dictate it.

### 3.2 Clinical continuity is the product

Patient history and previous clinical records must remain accessible as part of the patient's longitudinal record.

### 3.3 Handwriting is the medium

The application must preserve handwriting as genuine editable digital ink rather than treating it as a flattened image.

### 3.4 Doctor decides

Lipi assists the doctor's workflow but does not make clinical decisions.

### 3.5 Local-first / offline-first

Normal clinical operation must not depend on network availability or a remote Lipi service.

### 3.6 Doctor owns the data

The Lipi Vault is user-owned and portable.

### 3.7 Clinical records remain authoritative

The canonical clinical record must not be replaced by UI state, exports, caches, or derived representations.

### 3.8 Fail safely

When Lipi cannot establish that clinical data is valid and accessible, it must not silently fabricate, reconstruct, replace, or present invalid data as valid.

---

# 4. Target Platform

## 4.1 Primary MVP Platform

The primary MVP target is **Android tablets**.

The existing Sprint 4 prototype was physically validated on Android hardware and provides the reference implementation experience for the handwriting/document workflow.

## 4.2 Secondary Platform

iPadOS is a first-class supported target of the application architecture.

Platform-specific behavior may differ where required by:

* filesystem APIs
* secure storage
* application lifecycle
* WebView implementation
* authentication facilities
* file import/export

The clinical/domain architecture must remain platform-independent.

## 4.3 Desktop / Linux

Desktop and Linux support are not required for MVP acceptance.

The architecture should not unnecessarily prevent future support.

---

# 5. Core User

The primary MVP user is a **doctor operating a clinic independently**.

The application must optimize for real clinical use rather than technical users.

The doctor should not need to understand:

* SQLite
* filesystem references
* internal identifiers
* `.lipi` package internals
* encryption
* key management
* Excalidraw
* InkML
* application architecture

The underlying implementation must remain invisible during normal clinical workflow.

---

# 6. Core Clinical Workflow

The MVP workflow is:

```text
First Launch
    ↓
Doctor Setup
    ↓
Prescription Template Setup
    ↓
Patient List / Search
    ↓
Patient Creation or Patient Selection
    ↓
Patient Workspace
    ↓
New Prescription
    ↓
Prescription Workspace
    ↓
Stylus Writing
    ↓
Automatic Save
    ↓
Close / Leave
    ↓
Prescription History
    ↓
Reopen when required
    ↓
Optional PDF Export
```

The broader clinical workflow remains:

```text
Identify patient
    ↓
Listen
    ↓
Review history
    ↓
Examine
    ↓
Diagnose
    ↓
Explain
    ↓
Write prescription
    ↓
Decide follow-up
    ↓
Save consultation
```

Lipi supports the documentation workflow. It does not automate or replace the doctor's clinical reasoning.

---

# 7. Functional Scope

## 7.1 First Launch

On first launch, Lipi must provide the doctor with the required setup flow.

The setup must establish enough information for Lipi to operate as a personalized clinical workspace.

First-launch setup must lead into:

```text
Doctor Setup
    ↓
Prescription Template Setup
    ↓
Main Patient Workspace
```

The doctor must not be required to configure technical storage manually.

---

# 8. Doctor Setup

The Doctor Domain owns the doctor's professional identity, preferences, reusable clinical assets, and prescription template.

The MVP must support configuration of the doctor's required profile information and reusable prescription configuration.

Doctor information used in historical prescriptions must be preserved independently of later profile changes.

A historical prescription must therefore not unexpectedly change merely because the doctor later changes their active profile.

---

# 9. Prescription Template Setup

The doctor must be able to select:

1. A custom prescription template.
2. The default/generic Lipi template.

A custom template is a visual backing for the prescription.

The template must remain separate from the handwritten ink in the canonical editable document.

For a custom template, the template data must be embedded in the `.lipi` document so that the document remains self-contained.

Historical documents must use their own stored template data rather than silently substituting the doctor's current template.

---

# 10. Patient Management

## 10.1 Patient Creation

The MVP must allow creation of a patient record containing at minimum:

* Name
* Age
* Gender
* Height
* Weight

The patient record must also support:

* Previous medical conditions/history
* Previous symptoms
* Medication history
* Allergy information

Allergy information is optional to provide but must be supported.

---

## 10.2 Patient Search

Search is the primary mechanism for finding existing patients.

Search results must allow the doctor to identify the intended patient.

Lipi must not silently assume that a search result is the correct patient when ambiguity exists.

The doctor remains responsible for confirming the patient.

---

## 10.3 Patient Workspace

The Patient Workspace must provide access to:

* Patient information
* Clinical background
* Consultation history
* Previous prescriptions
* Scan/investigation reports
* Creation of a new prescription

Lipi preserves and presents this information.

It does not determine which information is medically significant.

---

## 10.4 Patient Deletion

Patient deletion must be an explicit destructive operation.

The doctor must deliberately confirm the deletion.

Lipi must not automatically delete patient records because of age, inactivity, expiration, or other arbitrary conditions.

---

# 11. Prescription Workspace

The Prescription Workspace is the primary writing environment.

It must provide:

* Patient context
* Doctor/template context
* Finite prescription page
* Handwriting area
* Stylus input
* Zoom
* Pan
* Automatic persistence
* Exit/return workflow
* Optional PDF export

The prescription page is **finite**, not an infinite canvas.

---

# 12. Input Model

The MVP follows:

> **Stylus creates; finger navigates.**

### Stylus

Primary role:

* handwriting
* creating/editing ink

### Finger

Primary role:

* navigation
* panning
* pinch-to-zoom

The interaction model must minimize accidental switching between writing and navigation.

---

# 13. Handwriting Requirements

Lipi uses Excalidraw as the current handwriting/editor foundation.

Excalidraw is an implementation dependency, not the definition of Lipi's clinical document model.

The MVP must preserve handwriting as digital vector ink.

The canonical representation must preserve, at minimum:

* stroke order
* stroke geometry
* pressure where available
* stroke width
* color

The canonical ink representation is a minimal W3C InkML subset.

The mapping is:

```text
Excalidraw freedraw elements
          ↕
         InkML
          ↕
Lipi canonical document model
```

On reopening a prescription, the stored ink must be reconstructed into editable handwriting rather than a flattened image.

---

# 14. Coordinate System

Each prescription has a finite page with explicit dimensions.

The document coordinate system must remain independent of:

* screen resolution
* display DPI
* WebView size
* viewport zoom
* viewport pan

The prescription template and handwriting must share the same document coordinate system.

Zooming and panning are view transformations only.

They must never modify the canonical stored document geometry.

---

# 15. `.lipi` Document Requirements

The `.lipi` format is the canonical editable representation of a prescription.

One `.lipi` document represents one consultation/prescription.

It is a self-contained ZIP-based package.

Canonical structure:

```text
consultation_<uuid>.lipi
├── manifest.json
├── ink/
│   └── page-001.inkml
└── templates/
    └── custom_template.png
```

The `templates/` entry exists when a custom template is used.

The package contains exactly one `manifest.json`.

There is no separate `document.json`.

---

# 16. `.lipi` Manifest

The manifest must contain the minimum metadata necessary to reconstruct the prescription.

Required conceptual fields:

```json
{
  "format": "lipi",
  "version": 1,
  "consultation_id": "...",
  "page": {
    "width": "...",
    "height": "...",
    "unit": "..."
  },
  "patient_snapshot": {},
  "doctor_snapshot": {},
  "ink": "ink/page-001.inkml"
}
```

`patient_id` is not part of the manifest.

The relationship between the document and patient is established by the Lipi Vault/application structure.

The document identifier is sufficient within the package.

---

# 17. Historical Prescription Requirements

A historical prescription is an independent clinical document.

It must preserve the information necessary to reconstruct its historical state.

When reopening a historical prescription:

1. Its embedded template data takes precedence over the current active template.
2. Its stored doctor information takes precedence where required for reconstruction.
3. Its own package contents are used to reconstruct the document.

Historical records must not unexpectedly change because the doctor later modifies their profile or template.

Historical prescriptions must remain editable.

The application must distinguish between:

* viewing an old prescription
* creating a new prescription from the patient's context
* intentionally modifying the old prescription

Accidental modification of historical records must be prevented.

---

# 18. Automatic Saving

Automatic saving is mandatory.

The doctor must not need to perform a separate manual save operation during normal prescription completion.

Closing/leaving a prescription must persist its current state as a `.lipi` document.

The persistence system must preserve the previous valid state until a new valid state has been successfully committed.

Required invariant:

```text
Before successful commit
    → previous valid state remains available

After successful commit
    → new valid state is available
```

An interrupted or partially written document must never silently replace the last known valid document.

---

# 19. Prescription Reopening

A saved prescription must be reopenable.

Reopening must reconstruct:

* patient snapshot
* doctor snapshot
* prescription page
* template
* handwritten ink
* document metadata

The reopened handwriting must remain editable.

The reopened document must represent the same canonical clinical record that was saved.

---

# 20. PDF Export

PDF export is an explicit user action.

The PDF is a **derived representation**.

The `.lipi` document remains the editable source.

The exported PDF must contain:

* prescription template/presentation
* typed patient information
* handwritten prescription

PDF generation must use the canonical finite document representation.

It must not depend on screen coordinates, current viewport zoom, current viewport pan, or arbitrary screen layout.

Export failure must never destroy or modify the canonical `.lipi` document.

---

# 21. Vault Requirements

The Lipi Vault is the fundamental unit of user-owned data.

The Vault is a directory managed through the operating system filesystem.

Conceptually:

```text
Lipi Vault/
├── lipi.db
├── doctor/
├── patient/
├── documents/
└── attachments/
```

The exact physical organization may be determined during implementation provided that the architectural requirements remain intact.

The Vault must contain:

* structured metadata
* relationships
* patient discovery information
* references to clinical documents
* actual clinical documents
* attachments
* doctor information
* required Vault metadata

SQLite is metadata infrastructure.

It is not the authoritative representation of the complete clinical record.

The `.lipi` document remains the canonical clinical document.

---

# 22. Data Ownership

Persistent data must have a clear owner.

### Patient Domain

Owns patient clinical information and clinical records.

### Doctor Domain

Owns:

* doctor profile
* professional information
* templates
* doctor preferences
* reusable doctor-owned assets

### Application Domain

Owns application-specific state such as:

* workspace state
* search/indexing state
* cache
* other application state

The Application Domain must not become the source of truth for clinical information.

Cross-domain workflows are coordinated by the Application Domain.

---

# 23. Offline Requirements

Normal MVP functionality must work without an internet connection.

The following must not require network access:

* first-run setup
* patient creation
* patient search
* patient viewing
* prescription creation
* handwriting
* saving
* reopening
* history
* PDF generation

There is no mandatory Lipi cloud service.

There is no mandatory Lipi account.

There is no mandatory online authentication service.

---

# 24. Security Requirements

The MVP Vault must be:

* encrypted at rest
* integrity-protected
* doctor-owned
* locally accessible
* recoverable without mandatory remote infrastructure

Lipi must use established cryptographic mechanisms rather than custom cryptography.

The Vault encryption key must be randomly generated and must be separate from the doctor's authentication credential.

Platform secure-storage facilities should protect key material where available.

## The operating system remains a fundamental trust boundary. Lipi must not claim protection against a completely compromised operating system.

# 25. Integrity and Failure Requirements

Lipi follows a **fail-closed principle for clinical data**.

If Lipi cannot establish that a clinical record is valid and safely accessible, it must not present that record as valid.

Required behavior includes:

| Condition              | Required behavior                     |
| ---------------------- | ------------------------------------- |
| Valid Vault            | Open normally                         |
| Modified/corrupt Vault | Detect and refuse unsafe access       |
| Corrupt `.lipi`        | Do not silently reconstruct           |
| Missing `.lipi`        | Do not fabricate replacement          |
| Interrupted autosave   | Preserve previous valid state         |
| Interrupted transfer   | Treat destination as incomplete       |
| Invalid backup         | Do not blindly restore                |
| SQLite inconsistency   | Detect and enter safe recovery        |
| Unsupported format     | Refuse safely while preserving source |
| Export failure         | Preserve canonical `.lipi`            |
| Lost device            | Provide migration/recovery path       |
| Forgotten credential   | Provide recovery path                 |

Failure detection must not automatically be presented as proof of malicious activity.

---

# 26. Backup and Transfer

The complete Lipi Vault is the unit of backup and transfer.

The doctor must not need to manually manipulate:

* SQLite databases
* internal identifiers
* document references
* individual internal files

to perform normal backup or transfer.

A transferred Vault must be validated before becoming an active Vault.

Validation should establish, where possible:

* Vault structure
* required components
* integrity
* format compatibility
* document validity
* reference completeness

Recovery should preserve the original Vault whenever possible and operate on a copy rather than destructively modifying the only source.

---

# 27. Temporary and Derived Data

Clinical data may temporarily exist outside the canonical Vault during:

* rendering
* export
* caching
* crash handling
* intermediate operations

The implementation must minimize unnecessary sensitive temporary data.

Clinical information must not be placed in logs unless genuinely necessary.

Temporary and derived data must not become alternative sources of truth.

---

# 28. UI / UX Requirements

The MVP interface must prioritize:

1. Professional appearance
2. Legibility
3. Calm visual hierarchy
4. Clinical usability

Navigation should disappear into intuition.

Writing should disappear into the stylus.

The interface must clearly communicate the current patient and document context.

Destructive operations require explicit user interaction.

The UI must not introduce unnecessary customization merely for the sake of customization.

Themeability is a future-facing product direction, but visual theming must never compromise clinical readability or usability.

---

# 29. Required MVP Screens

The MVP must provide the following functional views:

```text
First Launch
    ↓
Doctor Setup
    ↓
Template Setup
    ↓
Patient List / Search
    ↓
Patient Workspace
    ↓
Prescription History
    ↓
Prescription Workspace
    ↓
PDF Export
```

Settings/security/Vault management may be exposed through the application interface where required by the implementation.

Each screen must provide only the state and controls required to support the defined MVP workflow.

Sprint 7 is not a visual-design sprint.

---

# 30. Explicitly Out of Scope

The following are **not part of the MVP**:

### Intelligence

* AI
* OCR
* handwriting recognition
* clinical summarization
* automated diagnosis
* treatment recommendations
* clinical decision support

### Connectivity

* cloud synchronization
* mandatory online operation
* Lipi remote servers
* centralized identity
* cloud authentication

### Multi-user / Hospital

* hospital workflows
* multi-user hospital access control
* enterprise SSO
* remote administration
* centralized audit infrastructure

### Extensibility

* generalized plugin architecture
* plugin marketplace
* unnecessary customization
* speculative future-scale infrastructure

### Clinical Modelling

* elaborate medical ontology
* complete structured clinical ontology
* speculative additional entities
* automated interpretation of clinical information

### Document Features

* OCR
* revision-history persistence
* undo-history persistence
* cloud document synchronization
* elaborate template-language systems
* advanced document ontologies

### Other

* nonessential analytics
* regulatory certification claims
* compliance certification claims
* production penetration-testing claims

## These capabilities may be considered in future architecture work only when real requirements justify them.

# 31. MVP Invariants

The following must remain true throughout implementation.

### Data

1. The doctor owns the Vault.
2. The Vault is the unit of backup and transfer.
3. `.lipi` is the canonical editable prescription record.
4. PDF is derived from `.lipi`.
5. SQLite is metadata infrastructure, not the authoritative clinical document.
6. Patient discovery is performed through search and confirmed by the doctor.

### Clinical

7. Lipi preserves and presents clinical information.
8. Lipi does not make clinical decisions.
9. Historical prescriptions preserve their historical state.
10. Destructive operations require explicit user action.

### Handwriting

11. Handwriting remains editable digital ink.
12. Excalidraw remains behind a Lipi-owned abstraction.
13. Template and ink share one document coordinate system.
14. Zoom and pan do not alter stored document geometry.

### Persistence

15. Active prescriptions are automatically saved.
16. A failed write must not destroy the previous valid state.
17. Closing a prescription must result in durable persistence.
18. Reopening must reconstruct the saved document faithfully.

### Security

19. Clinical Vault data is protected at rest.
20. Cryptographic secrets are never hard-coded.
21. Vault encryption keys are separate from authentication credentials.
22. Unauthorized modification must be detectable.
23. Corrupt or incomplete clinical data must not be silently reconstructed.
24. Vault access remains recoverable without mandatory remote infrastructure.

### Offline ownership

25. Normal MVP operation does not require the internet.
26. The doctor's data remains portable.
27. Lipi protects the doctor's data without becoming the owner of it.

---

# 32. MVP Acceptance Criteria

The MVP is functionally complete when a doctor can perform the following sequence without requiring technical knowledge of Lipi:

```text
1. Launch Lipi
2. Complete doctor setup
3. Select/configure prescription template
4. Create a patient
5. Enter patient information
6. Open the patient workspace
7. Create a prescription
8. Write naturally with a stylus
9. Zoom the page
10. Pan the page
11. Leave the prescription
12. Return to the patient
13. Find the saved prescription
14. Reopen it
15. Verify the handwriting and template are preserved
16. Continue editing intentionally
17. Export the prescription to PDF
18. Return to the canonical record
19. Search for the patient again
20. Delete the patient intentionally
```

The workflow must function without network connectivity.

Clinical records must survive application restart.

The canonical `.lipi` document must remain the authoritative editable record.

---

# 33. Dad Test / Alpha Gate

The MVP must ultimately be evaluated through real-world doctor use.

The validation tasks are:

1. Find an existing patient.
2. Search for a patient.
3. Open a previous prescription.
4. Start a new prescription.
5. Write naturally using the stylus.
6. Zoom using pinch gestures.
7. Pan using a single finger.
8. Leave the prescription and return later.
9. Find the saved prescription.
10. Export a PDF.
11. Delete a patient intentionally.

Observation must focus on:

* hesitation
* wrong taps
* unclear navigation
* gesture confusion
* writing friction
* uncertainty about saving
* accidental destructive actions
* confusion between historical and current prescriptions

The MVP is not considered UX-complete merely because automated tests pass.

The final acceptance criterion is whether the doctor can perform the normal workflow with minimal instruction and without having to think about the software itself.

---

# 34. MVP Completion Definition

The MVP is complete when:

* all in-scope workflows are implemented;
* all MVP invariants are enforced;
* canonical `.lipi` persistence works reliably;
* handwriting survives save/reopen;
* historical prescriptions remain stable and editable;
* Vault data is encrypted and integrity-protected;
* failure paths fail safely;
* PDF export works without modifying canonical records;
* normal operation works offline;
* automated tests cover the critical domain, persistence, document, security, and workflow behavior;
* the application passes physical-device validation;
* the application passes the Dad Test sufficiently to justify Alpha.

Passing a build or automated test suite alone does not constitute MVP completion.

---

# 35. Specification Authority

This document is subordinate to the accepted architectural decisions.

Authority order:

```text
Accepted ADRs
     ↓
MVP-SPEC.md
     ↓
Implementation Contract
     ↓
Engineering implementation
```

If implementation reveals a genuine contradiction or impossibility in the accepted architecture, implementation must stop at the affected boundary and the contradiction must be resolved through the appropriate architectural process.

Implementation convenience alone is not sufficient reason to alter an accepted architectural decision.

---

# 36. Final MVP Statement

Lipi MVP is a local, offline-capable, doctor-owned clinical workspace centered around handwritten prescriptions.

It provides the doctor with:

```text
Patient
  ↓
Clinical context
  ↓
Handwritten prescription
  ↓
Automatic persistence
  ↓
Historical record
  ↓
Optional PDF export
```

The doctor remains the decision-maker.

The Vault remains the doctor's property.

The `.lipi` document remains the canonical clinical record.

The handwriting remains editable.

The application must preserve clinical continuity without introducing intelligence or infrastructure that the MVP does not require.

**Lipi exists to make the doctor's existing workflow digital without taking control of it.**
