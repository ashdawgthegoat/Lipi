# Lipi — MVP Build Plan

## 1. Purpose

This document defines the implementation sequence for the Lipi MVP.

It converts:

* `MVP-SPEC.md` — what must be built;
* `IMPLEMENTATION-CONTRACT.md` — how it must be built;
* the accepted ADRs — why the architecture is shaped this way;

into an ordered engineering plan.

This document is implementation-sequenced.

It does not redefine the product or replace accepted architectural decisions.

---

# 2. Build Strategy

Lipi will be built from the inside outward.

The implementation order is:

```text
Project Bootstrap
      ↓
Domain Models
      ↓
Vault + Database
      ↓
Clinical Document Model
      ↓
.lipi Serialization
      ↓
Application Workflows
      ↓
Editor / Ink Integration
      ↓
Autosave / Recovery
      ↓
Security Hardening
      ↓
PDF Export
      ↓
Integration
      ↓
Physical Device Validation
      ↓
Alpha / Dad Test
```

The ordering exists to prevent UI code from becoming the accidental foundation of the application.

The canonical document model, persistence boundaries, and workflow contracts must exist before the UI is allowed to depend heavily on them.

---

# 3. Implementation Rules

## 3.1 One milestone at a time

Only implement the current milestone unless a small prerequisite is required to unblock it.

Do not begin later features merely because their infrastructure is available.

## 3.2 Tests are part of implementation

A milestone is not complete when the code exists.

It is complete when:

1. implementation exists;
2. required tests exist;
3. tests pass;
4. architectural boundaries remain intact;
5. the milestone exit gate is satisfied.

## 3.3 No silent architectural changes

If implementation reveals that an accepted decision is invalid, stop and surface the issue.

Do not silently replace:

* the document format;
* the storage model;
* the editor;
* the encryption model;
* domain ownership;
* dependency direction.

Architectural changes require an explicit decision/ADR.

---

# 4. Milestone 1 — Repository and Flutter Bootstrap

## Goal

Create the implementation skeleton and establish a clean, analyzable Flutter application.

## Prerequisites

* Sprint 7 planning complete.
* `MVP-SPEC.md` exists.
* `IMPLEMENTATION-CONTRACT.md` exists.
* `GEMINI.md` exists.

## Implementation

Create the project structure:

```text
assets/
├── templates/
└── editor/

docs/
├── adr/
└── implementation/

lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   ├── app_state.dart
│   └── workflows/
│
├── domains/
│   ├── patient/
│   ├── doctor/
│   └── consultation/
│
├── infrastructure/
│   ├── vault/
│   ├── database/
│   ├── documents/
│   ├── ink/
│   ├── export/
│   ├── security/
│   ├── filesystem/
│   └── platform/
│
├── presentation/
│   ├── first_launch/
│   ├── doctor_setup/
│   ├── patients/
│   ├── patient/
│   ├── prescription/
│   ├── history/
│   ├── export/
│   └── settings/
│
├── shared/
│   ├── errors/
│   ├── result/
│   ├── ids/
│   ├── time/
│   └── utilities/
│
└── main.dart

test/
├── unit/
├── integration/
├── persistence/
├── security/
├── documents/
└── workflows/

integration_test/
```

Configure the baseline Flutter/Dart environment.

Establish:

* linting;
* test structure;
* asset declarations;
* application entry point;
* basic routing/application shell.

Do not implement clinical workflows yet.

## Tests

* project builds;
* `flutter analyze` passes;
* `flutter test` passes;
* application launches.

## Exit Gate

A clean Flutter application exists with the intended repository boundaries and no architectural dependency violations.

## Explicitly Deferred

* database;
* Vault;
* patient model;
* editor;
* security;
* PDF;
* clinical UI.

---

# 5. Milestone 2 — Core Domain Models

## Goal

Implement the technology-independent clinical domain model.

## Prerequisites

* Milestone 1 complete.

## Implementation

Create domain models/value objects for:

### Patient

* patient identity;
* patient information;
* clinical history;
* medication history;
* allergy information;
* patient/consultation relationships.

### Doctor

* doctor identity;
* doctor profile;
* template configuration;
* preferences.

### Consultation

* consultation identity;
* patient association;
* doctor snapshot;
* patient snapshot;
* document metadata;
* clinical document state.

### Shared

Create strongly typed identifiers where useful:

```text
PatientId
DoctorId
ConsultationId
```

Create domain-level validation and errors.

Do not add database annotations or Flutter-specific behavior to domain objects.

## Tests

Test:

* construction;
* validation;
* equality/value semantics where applicable;
* required vs optional fields;
* invalid input handling;
* snapshot independence.

## Exit Gate

The core clinical concepts can be created, validated, and tested without Flutter, SQLite, filesystem APIs, or Excalidraw.

## Explicitly Deferred

* persistence;
* serialization;
* UI;
* encryption.

---

# 6. Milestone 3 — Vault and Database Infrastructure

## Goal

Create the user-owned Vault and structured metadata persistence layer.

## Prerequisites

* Milestone 2 complete.

## Implementation

Create:

```text
Vault
VaultFilesystem
Database
DatabaseTransaction
VaultLifecycle
```

Implement:

* Vault creation;
* Vault discovery/opening;
* Vault metadata;
* database initialization;
* schema version;
* SQLite access;
* SQLCipher integration;
* transaction boundary;
* safe database close/reopen.

Define tables only for structured metadata required by the MVP.

The database must contain references to clinical documents rather than replacing them.

Create repositories/interfaces for:

* patient metadata;
* doctor metadata;
* consultation metadata.

Do not expose SQL to presentation/domain layers.

## Tests

Test:

* fresh Vault creation;
* reopening an existing Vault;
* database initialization;
* schema version;
* CRUD operations;
* transaction rollback;
* transaction commit;
* corrupted/invalid initialization behavior;
* offline operation.

## Exit Gate

A fresh Vault can be created, opened, written to, closed, and reopened with structured metadata intact.

## Explicitly Deferred

* full Vault encryption;
* recovery/migration;
* `.lipi` storage;
* editor integration.

---

# 7. Milestone 4 — Canonical Clinical Document Model

## Goal

Create the in-memory representation that becomes the source for `.lipi` and PDF.

## Prerequisites

* Milestone 2 complete.

## Implementation

Define the canonical document representation.

It must represent:

* finite page dimensions;
* document coordinate system;
* patient snapshot;
* doctor snapshot;
* template reference/resource;
* vector ink;
* consultation metadata;
* document format/version information.

Define the minimal InkML-compatible internal representation:

```text
Stroke
StrokePoint
InkDocument
```

where supported:

* x/y;
* pressure;
* width;
* color;
* stroke ordering.

The model must not depend on Excalidraw.

## Tests

Test:

* valid document construction;
* coordinate invariants;
* stroke ordering;
* optional pressure;
* page dimensions;
* snapshot independence;
* invalid document rejection.

## Exit Gate

A complete consultation can exist as a canonical in-memory document without any UI/editor dependency.

## Explicitly Deferred

* ZIP serialization;
* Excalidraw;
* PDF rendering.

---

# 8. Milestone 5 — `.lipi` Serialization

## Goal

Implement durable canonical document serialization.

## Prerequisites

* Milestone 3;
* Milestone 4.

## Implementation

Create:

```text
LipiDocumentSerializer
LipiDocumentDeserializer
LipiManifest
LipiPackageValidator
```

Implement the version-1 package structure.

Conceptually:

```text
consultation_<uuid>.lipi
├── manifest.json
├── ink/
│   └── page-001.inkml
└── templates/
    └── custom_template.png
```

Implement:

* manifest generation;
* manifest parsing;
* InkML generation;
* InkML parsing;
* package validation;
* version validation;
* required-resource validation;
* round-trip reconstruction.

The serializer must not depend on the editor.

## Tests

Mandatory tests:

### Round-trip

```text
Document
  ↓
.lipi
  ↓
Document
```

must preserve canonical information.

### Validation

Reject:

* missing manifest;
* duplicate manifest;
* invalid manifest;
* unsupported version;
* missing required ink;
* malformed InkML;
* invalid dimensions;
* malformed package structure.

### Historical snapshots

Verify that changing current doctor/patient/template data does not alter a previously serialized document.

## Exit Gate

A consultation can be serialized to `.lipi`, closed, reopened, and reconstructed without loss of canonical clinical information.

## Explicitly Deferred

* encrypted Vault representation;
* UI;
* Excalidraw.

---

# 9. Milestone 6 — Application Workflows

## Goal

Implement the application-level orchestration of clinical workflows without the handwriting editor.

## Prerequisites

* Milestone 3;
* Milestone 5.

## Implementation

Create workflow/application services for:

```text
InitializeApplication
ConfigureDoctor
ConfigureTemplate
CreatePatient
SearchPatients
OpenPatient
StartConsultation
LoadConsultation
SaveConsultation
DeletePatient
ListConsultationHistory
```

Application workflows coordinate domains and infrastructure through interfaces.

Implement:

```text
First Launch
    ↓
Doctor Setup
    ↓
Template Setup
    ↓
Patient Creation/Search
    ↓
Patient Workspace
    ↓
New Prescription
    ↓
History
```

Use real persistence.

Do not build a fake in-memory-only workflow.

## Tests

Test complete workflow sequences:

* first launch;
* doctor setup;
* template setup;
* patient creation;
* patient search;
* patient retrieval;
* consultation creation;
* consultation persistence;
* history retrieval;
* explicit patient deletion.

## Exit Gate

The complete non-handwriting clinical workflow functions against the real Vault and database.

## Explicitly Deferred

* actual Excalidraw editor;
* PDF export;
* final security hardening.

---

# 10. Milestone 7 — Ink Engine and Excalidraw Integration

## Goal

Connect the canonical document model to the validated handwriting editor architecture.

## Prerequisites

* Milestone 5;
* Milestone 6.

## Implementation

Create:

```text
InkEngine
InkSession
EditorBridge
EditorRuntimeServer
```

Implement the WebView-hosted bundled editor.

Use:

```text
127.0.0.1:<ephemeral-port>
```

for serving bundled editor assets/runtime.

Do not use `file:///android_asset`.

Implement the bridge required to:

* initialize a document;
* load canonical ink;
* receive strokes;
* update document ink;
* apply template;
* report editor state;
* save/flush current document state.

The editor bridge must not become the canonical storage layer.

## Coordinate Validation

Verify:

```text
stroke document coordinates
        ≠
viewport coordinates
```

Zoom and pan must not modify canonical coordinates.

## Tests

Automated:

* editor initialization;
* document load;
* stroke conversion;
* canonical ink reconstruction;
* coordinate preservation;
* bridge error handling.

Physical device:

* editor loads;
* stylus writes;
* finger pans;
* pinch zoom works;
* writing remains correctly positioned after zoom/pan.

## Exit Gate

A real stylus-written consultation can be represented in Lipi's canonical document model.

## Explicitly Deferred

* production autosave;
* final PDF;
* complete security validation.

---

# 11. Milestone 8 — Autosave and Crash Safety

## Goal

Make clinical document persistence durable during normal editing.

## Prerequisites

* Milestone 7.

## Implementation

Implement:

```text
AutosaveController
DocumentWriteCoordinator
AtomicDocumentWriter
SaveState
```

Required behavior:

```text
Editor change
    ↓
Canonical document update
    ↓
Autosave scheduling
    ↓
Serialization
    ↓
Safe document replacement
    ↓
Saved state
```

A failed replacement must preserve the previous valid document.

Implement appropriate debouncing/coalescing so continuous handwriting does not cause pathological write behavior.

The exact timing is an implementation detail; correctness takes priority over a particular interval.

## Tests

Test:

* repeated edits;
* autosave;
* save failure;
* interrupted replacement;
* reopen after save;
* process restart;
* previous-valid-state preservation;
* no false "saved" state.

## Exit Gate

A doctor can write, leave the prescription, reopen Lipi, and recover the latest successfully saved clinical document.

## Explicitly Deferred

* advanced background optimization;
* cloud sync;
* multi-device synchronization.

---

# 12. Milestone 9 — Security Implementation

## Goal

Implement the MVP security architecture against the real storage system.

## Prerequisites

* Milestone 3;
* Milestone 8.

## Implementation

Create:

```text
VaultKeyStore
VaultCrypto
SecureStorage
Authentication
IntegrityValidator
```

Implement:

* Vault key generation;
* secure key storage;
* SQLCipher database encryption;
* encrypted file/document storage envelope;
* authenticated encryption;
* integrity validation;
* safe unlock/lock behavior;
* key separation from authentication credentials.

Use established cryptographic libraries.

Do not implement cryptographic primitives manually.

The logical `.lipi` format remains a ZIP-based canonical document.

Protected Vault storage may wrap canonical `.lipi` bytes in an encrypted storage representation.

## Tests

Security tests must cover:

* fresh encrypted Vault;
* reopen;
* incorrect credentials;
* inaccessible key material;
* encrypted database;
* encrypted document/file content;
* integrity failure;
* corrupted encrypted content;
* key lifecycle;
* safe failure.

Verify that plaintext clinical content is not unnecessarily persisted outside the protected Vault.

## Exit Gate

The MVP Vault provides the defined at-rest confidentiality/integrity guarantees without requiring an online service.

## Explicitly Deferred

* cloud key management;
* enterprise identity;
* multi-user access control;
* server-side security.

---

# 13. Milestone 10 — Production Clinical UI

## Goal

Complete the user-facing workflows around the working application core.

## Prerequisites

* Milestone 6;
* Milestone 7;
* Milestone 8.

## Screens

Implement:

```text
First Launch
Doctor Setup
Template Setup
Patient List/Search
Patient Workspace
Prescription History
Prescription Workspace
PDF Export
Settings / Vault / Security
```

Prioritize:

* large touch targets;
* clear hierarchy;
* stylus-first writing;
* finger-first navigation;
* obvious save state;
* minimal navigation friction;
* explicit destructive actions.

## Tests

Widget/integration tests for:

* navigation;
* patient creation;
* patient search;
* patient workspace;
* prescription creation;
* history;
* save state;
* deletion confirmation;
* export flow.

## Exit Gate

A doctor can navigate the complete MVP without test-only shortcuts.

---

# 14. Milestone 11 — PDF Export

## Goal

Generate a faithful PDF from the canonical clinical document.

## Prerequisites

* Milestone 5;
* Milestone 7.

## Implementation

Create:

```text
PdfExporter
```

Pipeline:

```text
Canonical Lipi Document
        ↓
PDF Renderer
        ↓
PDF
```

Render:

* page dimensions;
* template;
* typed information;
* vector ink;
* relevant document content.

Use canonical coordinates.

Do not use the WebView screenshot as the rendering source.

PDF generation must not modify `.lipi`.

## Tests

Test:

* blank document;
* template;
* handwritten content;
* typed content;
* page dimensions;
* coordinate fidelity;
* export failure;
* canonical document unchanged after export.

## Exit Gate

Every valid MVP consultation can be exported to a readable PDF without changing its canonical source.

---

# 15. Milestone 12 — Backup, Transfer, Migration, and Recovery

## Goal

Make the Vault safely portable.

## Prerequisites

* Milestone 9.

## Implementation

Implement:

* Vault backup;
* Vault validation;
* transfer/import;
* migration detection;
* schema migration;
* non-destructive recovery behavior.

The Vault is the backup/transfer unit.

Do not make individual PDFs the backup mechanism.

Before activating an imported/migrated Vault:

```text
Validate
   ↓
Verify
   ↓
Activate
```

A failed import must not destroy the existing Vault.

## Tests

Test:

* backup;
* restore;
* incomplete transfer;
* corrupted backup;
* version migration;
* failed migration;
* rollback/recovery.

## Exit Gate

A complete Vault can be backed up and restored without losing valid clinical records.

---

# 16. Milestone 13 — End-to-End Integration

## Goal

Prove the complete MVP workflow using real implementations.

## Prerequisites

* all previous milestones.

## End-to-End Workflow

The test must execute:

```text
Fresh Launch
    ↓
Doctor Setup
    ↓
Template Setup
    ↓
Create Patient
    ↓
Enter Patient Information
    ↓
Open Patient Workspace
    ↓
Create Prescription
    ↓
Write With Stylus
    ↓
Zoom
    ↓
Pan
    ↓
Autosave
    ↓
Leave Prescription
    ↓
Reopen
    ↓
Verify Handwriting
    ↓
Open History
    ↓
Edit Intentionally
    ↓
Verify Persistence
    ↓
Export PDF
    ↓
Search Patient
    ↓
Delete Patient Intentionally
```

## Tests

Run:

```text
flutter analyze
flutter test
flutter integration_test
```

plus milestone-specific security/document/device tests.

## Exit Gate

The complete workflow succeeds against the real application stack.

---

# 17. Milestone 14 — Physical Device Validation

## Goal

Validate behavior that cannot be trusted solely to automated tests.

## Primary Platform

Android tablet.

## First-Class Platform

iPadOS.

## Validation

Test on physical devices:

### Input

* stylus writing;
* pressure where supported;
* palm interaction;
* finger navigation.

### Viewport

* zoom;
* pan;
* writing after zoom;
* writing after pan;
* navigation after writing.

### Persistence

* autosave;
* app backgrounding;
* app termination;
* reopen;
* history;
* export.

### Storage

* Vault creation;
* reopen;
* encryption;
* backup/restore.

### WebView

* bundled runtime;
* loopback server;
* offline startup;
* bridge stability.

### Performance

Observe:

* startup;
* editor load;
* handwriting latency;
* scrolling;
* zoom;
* save latency;
* export latency;
* memory behavior.

## Exit Gate

No blocking physical-device issue remains in the core clinical workflow.

---

# 18. Milestone 15 — Alpha / Dad Test

## Goal

Determine whether Lipi is actually usable by its intended first real-world user.

The Dad Test is not merely a demonstration.

It is a usability and workflow acceptance test.

## Scenario

The doctor must be able to independently:

1. launch Lipi;
2. configure their profile;
3. configure the prescription template;
4. create a patient;
5. find the patient;
6. open the patient workspace;
7. create a prescription;
8. write naturally;
9. zoom and pan;
10. leave the prescription;
11. reopen it;
12. verify the writing is intact;
13. open previous history;
14. intentionally create/edit as appropriate;
15. export PDF;
16. return to patient search;
17. intentionally delete a patient.

## Observe

Record:

* hesitation;
* incorrect taps;
* navigation confusion;
* gesture confusion;
* handwriting friction;
* uncertainty about saving;
* difficulty finding history;
* destructive-action confusion;
* unexpected behavior;
* places where explanation from the developer was required.

Do not teach the workflow while testing it unless necessary to recover from a blocking failure.

## Exit Gate

The intended user can complete the core workflow naturally enough that the product is ready for Alpha iteration.

Failures discovered here become implementation tasks or product decisions.

They do not automatically justify architectural changes.

---

# 19. Cross-Milestone Test Gates

Every milestone must maintain:

```text
flutter analyze
flutter test
```

as applicable.

No milestone may knowingly leave the project in a failing baseline state unless the failure is explicitly documented and is itself the current task.

Higher-level gates:

```text
Milestone 2
→ Domain tests

Milestone 3
→ Persistence tests

Milestone 5
→ .lipi round-trip tests

Milestone 7
→ Physical handwriting validation

Milestone 8
→ Crash/persistence tests

Milestone 9
→ Security tests

Milestone 11
→ PDF fidelity tests

Milestone 12
→ Backup/recovery tests

Milestone 13
→ End-to-end workflow

Milestone 14
→ Physical device

Milestone 15
→ Dad Test
```

---

# 20. Implementation Dependency Map

The critical dependencies are:

```text
M1 Bootstrap
 │
 ├── M2 Domain
 │    │
 │    └── M4 Canonical Document
 │
 └── M3 Vault / Database
       │
       ├── M5 .lipi
       │     │
       │     └── M7 Ink Integration
       │              │
       │              └── M8 Autosave
       │
       ├── M6 Application Workflows
       │     │
       │     └── M10 Clinical UI
       │
       └── M9 Security
              │
              └── M12 Backup / Recovery

M5 + M7
   ↓
M11 PDF

All
   ↓
M13 Integration
   ↓
M14 Device Validation
   ↓
M15 Dad Test
```

---

# 21. What We Do Not Optimize Yet

Do not optimize for:

* large patient databases;
* hospital-scale concurrency;
* cloud synchronization;
* multi-device synchronization;
* distributed storage;
* AI workloads;
* generalized plugin ecosystems;
* enterprise administration;
* analytics infrastructure;
* premature performance tuning.

Optimize first for:

1. correctness;
2. data durability;
3. clinical workflow clarity;
4. offline reliability;
5. security;
6. handwriting quality;
7. maintainability.

---

# 22. Implementation Completion Order

The implementation should reach these intermediate states:

### State A — Skeleton

The application builds and has the intended structure.

### State B — Clinical Core

Patient, doctor, and consultation models work.

### State C — Durable Storage

Vault and database work.

### State D — Durable Documents

`.lipi` round-trip works.

### State E — Clinical Workflow

Patients and consultations work end-to-end without real handwriting.

### State F — Handwriting

Real stylus input becomes canonical Lipi ink.

### State G — Durable Handwriting

Autosave and reopen work reliably.

### State H — Protected Data

Vault encryption and integrity protections work.

### State I — Export

Canonical documents produce PDFs.

### State J — Real Device

The workflow works on physical tablets.

### State K — Alpha

The intended doctor can actually use it.

---

# 23. Stop Conditions

Implementation must stop and escalate rather than continue when:

* an accepted ADR becomes impossible to satisfy;
* the canonical document model must change;
* `.lipi` format semantics must change;
* domain ownership becomes ambiguous;
* security requirements cannot be met;
* data-loss behavior is discovered;
* the editor cannot preserve canonical coordinates;
* a required platform capability contradicts the current architecture.

The escalation should state:

```text
Problem
Evidence
Affected decision
Proposed options
Recommended option
Required architectural change
```

---

# 24. Final Build Rule

Build Lipi in the order that protects the clinical record.

Do not start with the prettiest screen.

Do not start with the editor.

Do not start with PDF export.

Start with the foundations that make those features trustworthy.

The implementation sequence is:

```text
Structure
→ Domain
→ Persistence
→ Canonical Document
→ Serialization
→ Workflow
→ Ink
→ Autosave
→ Security
→ UI
→ Export
→ Recovery
→ Integration
→ Device
→ Dad Test
```

**Every later layer must consume the contracts established by the earlier layers, never redefine them.**
