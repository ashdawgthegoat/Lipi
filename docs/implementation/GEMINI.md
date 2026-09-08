# Lipi — Gemini Development Instructions

## 1. Purpose

Lipi is a local-first, offline-first clinical workspace for doctors.

The MVP is a handwriting-first clinical workflow that allows a doctor to:

* configure their profile and prescription template;
* create and search patients;
* view patient history;
* create handwritten prescriptions/consultations;
* automatically save them;
* reopen and edit historical prescriptions;
* export prescriptions to PDF;
* retain ownership of all clinical data locally.

Lipi is being developed under The Wanderer Project.

The MVP does **not** include:

* AI;
* cloud synchronization;
* mandatory internet connectivity;
* hospital multi-user workflows;
* advanced clinical decision support;
* generalized plugin infrastructure;
* unnecessary analytics;
* future-scale infrastructure that is not required by the MVP.

---

# 2. Read Before Making Changes

Before implementing anything, read the relevant project documentation.

At minimum:

```text
docs/implementation/MVP-SPEC.md
docs/implementation/IMPLEMENTATION-CONTRACT.md
docs/implementation/BUILD-PLAN.md
docs/implementation/DEFINITION-OF-DONE.md
```

For architectural decisions, also consult:

```text
docs/adr/
```

Do not treat this file as a replacement for those documents.

The documents have different authority:

1. ADRs — architectural decisions already accepted.
2. MVP-SPEC.md — what the MVP must do.
3. IMPLEMENTATION-CONTRACT.md — implementation boundaries and invariants.
4. BUILD-PLAN.md — current implementation sequence.
5. DEFINITION-OF-DONE.md — acceptance criteria.
6. GEMINI.md — instructions for working as the coding agent.

If two documents appear to conflict, **stop and surface the conflict**. Do not silently choose a new architecture.

---

# 3. Core Engineering Principles

These principles apply to every implementation decision.

### 3.1 The clinical record is authoritative

The clinical record must never become a disposable rendering artifact.

The canonical clinical document is represented by Lipi's own document model and `.lipi` format.

UI state, viewport state, Excalidraw state, cached state, and database indexes are not authoritative representations of the clinical document.

### 3.2 Local-first means local-first

Lipi must remain useful without:

* an account;
* a Lipi server;
* cloud connectivity;
* an internet connection.

Do not introduce a network dependency into the MVP unless explicitly authorized by an architectural decision.

### 3.3 The doctor decides

Lipi preserves and presents clinical information.

The MVP must not:

* diagnose;
* recommend treatment;
* interpret handwriting;
* summarize clinical history using AI;
* make clinical decisions.

Do not add medical intelligence simply because it appears technically convenient.

### 3.4 No silent data loss

If Lipi cannot establish that a write succeeded, it must not claim that it succeeded.

If data is corrupt, incomplete, unreadable, or inconsistent:

* report the failure;
* preserve recoverable data;
* do not fabricate missing information;
* do not silently reconstruct authoritative clinical records from incomplete secondary data.

### 3.5 Infrastructure is replaceable

SQLite, SQLCipher, filesystem APIs, WebView, Excalidraw, PDF libraries, and platform-specific APIs are infrastructure.

They must not become the domain model.

---

# 4. Architectural Dependency Direction

The intended dependency direction is:

```text
Presentation
     ↓
Application
     ↓
Domain
     ↑
Infrastructure
```

More precisely:

```text
Presentation
    ↓
Application / Workflows
    ↓
Domain Interfaces + Domain Models
    ↑
Infrastructure Implementations
```

Infrastructure may implement interfaces required by the application/domain.

Domain code must remain independent of infrastructure.

Do not create dependency chains such as:

```text
Domain → SQLite
Domain → Flutter
Domain → WebView
Domain → Excalidraw
Domain → dart:io
Domain → platform APIs
```

These are architectural violations.

---

# 5. Domain Boundaries

The MVP has three primary domains.

## Patient Domain

Owns:

* patient identity;
* patient information;
* clinical history;
* medication history;
* allergy information;
* relationships to consultations/prescriptions.

The Patient Domain does not own:

* database connections;
* filesystem paths;
* encryption;
* UI state;
* WebView state;
* Excalidraw state.

## Doctor Domain

Owns:

* doctor identity;
* doctor profile;
* active prescription template;
* doctor preferences;
* template configuration.

Historical prescription snapshots belong to the historical document, not to mutable current configuration.

## Consultation Domain

Owns:

* consultation/prescription lifecycle;
* clinical document state;
* creation;
* persistence coordination;
* historical editing semantics.

The Application layer orchestrates interactions between these domains.

Domains must not directly modify each other.

---

# 6. Canonical Data Rules

The following hierarchy must be preserved:

```text
Canonical clinical document
        ↓
      .lipi
        ↓
Derived representations
        ↓
PDF / previews / indexes / caches
```

SQLite metadata is not a replacement for a missing `.lipi` document.

The application must not reconstruct a supposedly valid historical prescription from incomplete database metadata when its canonical `.lipi` document is missing or unreadable.

---

# 7. `.lipi` Rules

`.lipi` is Lipi's canonical editable clinical document format.

It is a ZIP-based package containing the document manifest and canonical document resources.

At minimum, a consultation package contains:

```text
manifest.json
ink/page-001.inkml
```

and may contain resources such as:

```text
templates/custom_template.png
```

Important rules:

* exactly one manifest;
* explicit format/version information;
* finite document dimensions;
* canonical document coordinates;
* vector ink;
* historical patient snapshot;
* historical doctor snapshot;
* historical template resources where required;
* self-contained historical appearance.

The serializer/deserializer must be isolated behind a document boundary.

Do not allow UI code to manually construct ZIP packages.

Do not allow Excalidraw to define the `.lipi` schema.

---

# 8. Coordinate System

Lipi has a canonical document coordinate system.

The distinction is:

```text
Document coordinates
        ↑
   canonical
        ↓
Viewport transform
        ↓
zoom / pan / camera
```

Zooming and panning are view operations.

They must never mutate the canonical clinical document coordinates.

PDF export must use canonical document coordinates.

Do not export based on:

* screen coordinates;
* current zoom;
* current camera position;
* arbitrary widget dimensions;
* screenshots.

---

# 9. Ink / Excalidraw Boundary

Excalidraw is an implementation component of the handwriting editor.

It is not the owner of Lipi's clinical document model.

All interaction with the editor must pass through a Lipi-owned boundary.

The intended conceptual boundary is:

```text
Lipi Document
     ↕
 InkEngine
     ↕
Excalidraw/WebView
```

Do not expose arbitrary Excalidraw state throughout the application.

Do not make domain objects depend on Excalidraw data structures.

If Excalidraw were replaced in the future, the domain and `.lipi` representation should remain conceptually intact.

---

# 10. WebView Rules

The bundled editor is hosted inside a platform WebView.

The validated runtime architecture uses an internal loopback HTTP server rather than:

```text
file:///android_asset/...
```

Do not revert to the file URL approach without an explicit architectural reason.

The bundled editor must remain fully offline.

The WebView bridge should exchange Lipi-owned commands/data rather than allowing arbitrary editor state to become application state.

---

# 11. Vault Rules

The Vault is Lipi's fundamental user-owned data boundary.

Conceptually:

```text
Lipi Vault/
├── lipi.db
├── patient/
├── doctor/
├── documents/
└── attachments/
```

The exact physical representation may use opaque UUID-based paths and encrypted storage envelopes.

All Vault filesystem access must pass through the filesystem/Vault abstraction.

Do not scatter direct `File` operations throughout the application.

Do not assume that the application's working directory is the Vault.

Do not hard-code user-specific filesystem paths.

---

# 12. Database Rules

SQLite is infrastructure.

SQLCipher protects the Vault database at rest.

Database access must occur through the database infrastructure boundary.

Do not:

* put SQL inside widgets;
* query SQLite directly from domain objects;
* use SQLite as the canonical clinical document;
* rely on unencrypted database storage;
* silently regenerate authoritative documents from indexes.

Database transactions must be used where multiple related metadata changes must succeed together.

---

# 13. Security Rules

Security is not optional cleanup work.

The MVP security model includes:

* encrypted Vault storage;
* encrypted SQLite database;
* authenticated encryption for protected file content;
* platform secure storage for key material;
* separation of authentication credentials from encryption keys;
* safe device migration/recovery;
* integrity validation;
* fail-closed behavior.

Do not implement custom cryptography.

Use established cryptographic primitives and maintained libraries.

Never log:

* patient names;
* clinical history;
* prescriptions;
* handwriting contents;
* encryption keys;
* authentication credentials;
* sensitive file contents.

Debug logging must not become a clinical data leak.

---

# 14. Persistence and Autosave

Autosave is a correctness requirement.

The application must prioritize:

```text
No silent loss
      >
Convenience
```

A save operation must preserve the previous valid state until the replacement is safely committed.

Prefer atomic or equivalent safe replacement semantics.

A failed save must not destroy the last known-good document.

The application must distinguish:

* modified;
* save in progress;
* saved;
* save failed.

Do not display a false "saved" state.

---

# 15. Historical Records

Historical prescriptions are immutable in their historical meaning.

A historical prescription contains the snapshots/resources necessary to preserve what was true when it was created.

In particular, changing the current:

* patient information;
* doctor profile;
* prescription template;

must not silently alter the historical representation.

Historical editing is an explicit operation.

The UI must distinguish:

```text
View previous prescription
        ≠
Create new prescription from previous context
        ≠
Modify existing prescription
```

Do not collapse these operations into one ambiguous action.

---

# 16. Patient Deletion

Patient deletion is destructive.

It must:

* require explicit user intent;
* provide confirmation;
* handle associated clinical data according to the defined deletion policy;
* never happen because of accidental navigation or a generic swipe gesture.

Do not add automatic deletion or expiration behavior.

---

# 17. PDF Export

PDF is a derived representation.

The pipeline is:

```text
.lipi / canonical document
        ↓
Canonical document model
        ↓
PDF renderer
        ↓
PDF
```

Never use a screenshot of the editor as the source of truth.

Never use current viewport state as the export coordinate system.

Export failures must not modify or invalidate the `.lipi` document.

---

# 18. Error Handling

Errors should be represented at the Lipi/application boundary rather than leaking raw infrastructure exceptions everywhere.

Examples include:

```text
VaultError
StorageError
DocumentError
SerializationError
SecurityError
ExportError
EditorError
MigrationError
```

Use more specific error types where they improve correctness.

Do not catch an exception and silently ignore it merely to keep the UI running.

Every failure path should answer:

1. What failed?
2. Is existing data still safe?
3. Can the user retry?
4. Can the operation be recovered?
5. Does the application need to enter a safe state?

---

# 19. Fail-Closed Behavior

When validity cannot be established, Lipi must prefer refusing an operation over presenting potentially invalid clinical data as valid.

Examples:

* unreadable `.lipi`;
* invalid manifest;
* corrupt encrypted content;
* failed integrity check;
* incomplete Vault transfer;
* incompatible document version;
* failed migration.

Never fabricate missing clinical information.

Never silently discard corruption.

---

# 20. Coding Style

Prefer:

* small focused classes;
* explicit interfaces;
* immutable value objects where appropriate;
* dependency injection at infrastructure/application boundaries;
* clear names;
* straightforward control flow;
* testable logic;
* explicit failure handling.

Avoid:

* god classes;
* global mutable state;
* hidden service locators;
* unnecessary singleton patterns;
* speculative plugin systems;
* speculative abstractions;
* premature generic frameworks;
* architecture introduced solely "for future scalability."

Abstraction is justified when it protects an existing architectural boundary or replaceability requirement.

Do not abstract code merely because it might someday be useful.

---

# 21. UI Rules

The primary interaction model is:

```text
Stylus → Create / Write
Finger → Navigate
```

The UI should prioritize:

* readable clinical information;
* obvious navigation;
* minimal friction;
* reliable writing;
* clear save state;
* explicit destructive actions.

Do not add visual complexity without a workflow benefit.

Do not make the doctor understand Lipi's architecture in order to use Lipi.

The final usability standard is the Dad Test.

---

# 22. Dependencies

Before adding a dependency:

1. Determine whether the existing stack already provides the capability.
2. Check whether the dependency is necessary for the current milestone.
3. Check whether it violates an architectural boundary.
4. Consider maintenance and platform support.
5. Add it only when justified.

Do not add dependencies simply because they make a local implementation slightly shorter.

Do not replace an established project dependency without a concrete reason.

---

# 23. Implementation Workflow

When implementing a task:

### Step 1 — Establish context

Read:

* the current milestone in `BUILD-PLAN.md`;
* relevant MVP requirements;
* relevant implementation-contract sections;
* relevant ADRs;
* existing code surrounding the change.

### Step 2 — Identify the boundary

Determine:

* which layer owns the behavior;
* which domain owns the data;
* whether persistence is required;
* whether an interface already exists;
* whether the operation affects canonical data.

### Step 3 — Implement the smallest correct change

Do not implement future milestones prematurely.

Do not redesign settled architecture because another approach appears cleaner.

### Step 4 — Test

Add or update tests appropriate to the behavior.

At minimum, consider:

* unit behavior;
* persistence behavior;
* failure behavior;
* serialization round-trip;
* workflow behavior;
* security implications.

### Step 5 — Verify

Run the project's appropriate:

```text
flutter analyze
flutter test
```

and any milestone-specific integration/device tests.

Do not claim a test passed unless it actually passed.

### Step 6 — Report

Report:

* what changed;
* what tests ran;
* what passed;
* what failed;
* any unresolved issue;
* whether the milestone gate is satisfied.

---

# 24. Working With Existing Code

Before modifying existing code, inspect it.

Do not assume:

* a class does what its name suggests;
* an old implementation follows the latest contract;
* a TODO is still relevant;
* a dependency is unused;
* an architectural boundary already exists correctly.

Preserve working behavior unless the current milestone explicitly requires changing it.

If existing code conflicts with the current accepted architecture, identify the conflict before performing a broad refactor.

---

# 25. Architecture Changes

Do not make architectural changes silently.

An architectural change includes, but is not limited to:

* changing the canonical document format;
* changing domain ownership;
* changing dependency direction;
* replacing Excalidraw;
* changing the Vault security model;
* changing encryption primitives;
* introducing cloud infrastructure;
* changing the persistence authority;
* introducing a new major platform abstraction.

If implementation reveals that an accepted decision is technically invalid, stop and explain:

```text
1. Existing decision
2. Newly discovered problem
3. Evidence
4. Proposed alternative
5. Consequences
6. Required ADR/change
```

Do not quietly update the architecture while implementing an unrelated task.

---

# 26. No Feature Creep

During MVP implementation, reject requests that implicitly introduce:

* AI;
* cloud sync;
* online accounts;
* hospital-scale multi-user architecture;
* generalized plugins;
* advanced analytics;
* unnecessary customization;
* speculative scalability infrastructure.

If such functionality becomes necessary to satisfy an existing MVP requirement, surface it as an architectural/product decision rather than implementing it opportunistically.

---

# 27. Source of Truth

Use this hierarchy when deciding where information belongs:

```text
Clinical document
    → .lipi

Structured application metadata
    → SQLite

Current application state
    → Application state

Current UI/editor state
    → Presentation / Ink infrastructure

Derived output
    → PDF / preview / cache
```

Do not reverse these relationships.

For example:

```text
Correct:
.lipi → PDF

Incorrect:
screen → PDF

Correct:
.lipi → historical clinical record

Incorrect:
SQLite index → reconstructed prescription
```

---

# 28. Testing Philosophy

Tests should prove invariants, not merely increase line coverage.

Important properties include:

* data survives restart;
* `.lipi` round-trips;
* historical snapshots remain stable;
* templates remain historically correct;
* failed writes preserve the previous valid state;
* corrupted documents fail safely;
* encrypted Vault data cannot be treated as plaintext;
* PDF export does not mutate canonical data;
* offline operation works;
* patient search retrieves the correct patient;
* destructive operations require explicit intent.

When a bug violates an invariant, add a regression test for that invariant.

---

# 29. Milestone Discipline

Only implement the work assigned to the current milestone.

The build plan is intentionally ordered because later components depend on earlier contracts.

Do not jump ahead simply because a later feature is interesting.

If a later milestone requires a missing primitive, implement only the smallest prerequisite needed to unblock the current milestone, and record the dependency.

---

# 30. Physical Device Validation

Lipi is a tablet application.

Simulator/emulator success is not sufficient for handwriting-critical behavior.

Where the build plan specifies physical validation, test on real hardware.

Pay particular attention to:

* stylus input;
* pressure behavior where supported;
* palm rejection;
* zoom;
* pan;
* WebView behavior;
* editor loading;
* save/reopen;
* performance;
* orientation/layout;
* filesystem permissions;
* secure storage;
* PDF generation.

The validated Excalidraw/WebView architecture was physically tested on an Android tablet during architectural prototyping.

---

# 31. Before Declaring Work Complete

Do not say "done" merely because the code compiles.

Check:

```text
[ ] Requirement implemented
[ ] Architectural boundary preserved
[ ] Relevant tests added/updated
[ ] Existing tests still pass
[ ] flutter analyze passes
[ ] Persistence behavior verified where applicable
[ ] Failure paths considered
[ ] Security implications considered
[ ] No unintended feature creep
[ ] Milestone acceptance gate satisfied
```

For MVP completion, use:

```text
docs/implementation/DEFINITION-OF-DONE.md
```

as the authoritative acceptance checklist.

---

# 32. Final Rule

When uncertain, prefer:

```text
simple
explicit
local
durable
testable
recoverable
```

over:

```text
clever
implicit
distributed
fragile
speculative
```

The goal is not to build the largest system.

The goal is to build the smallest system that can be trusted with a doctor's clinical workflow.

**Keep the domain simple. Keep the boundaries explicit. Keep the clinical record authoritative. Keep infrastructure replaceable.**
