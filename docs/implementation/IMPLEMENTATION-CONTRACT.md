# Lipi Implementation Contract

**Project:** Lipi
**Sprint:** Sprint 7 — MVP Implementation Planning
**Status:** Implementation Contract
**Authority:** ADR-0001 through ADR-0007 + `MVP-SPEC.md`

---

# 1. Purpose

This document defines the engineering rules that implementation must follow.

It establishes:

* module boundaries;
* dependency direction;
* ownership boundaries;
* interface responsibilities;
* persistence rules;
* document handling rules;
* handwriting integration rules;
* security boundaries;
* error-handling requirements;
* testing expectations;
* implementation constraints.

This document does **not** redefine product scope or accepted architecture.

The MVP specification defines **what Lipi must do**.

This document defines **how the implementation must be structured so that it remains faithful to that architecture**.

---

# 2. Governing Rule

Implementation must follow:

```text
Accepted ADRs
      ↓
MVP-SPEC.md
      ↓
IMPLEMENTATION-CONTRACT.md
      ↓
Implementation
```

Implementation convenience is not sufficient justification for violating an architectural invariant.

If implementation reveals a genuine architectural contradiction, the contradiction must be documented and resolved through an ADR rather than silently patched around.

---

# 3. Architectural Shape

Lipi shall use the following high-level dependency structure:

```text
┌───────────────────────────────┐
│         Presentation          │
│       Flutter UI / UX         │
└───────────────┬───────────────┘
                ↓
┌───────────────────────────────┐
│      Application / Workflow   │
│       orchestration only      │
└───────────────┬───────────────┘
                ↓
┌───────────────────────────────┐
│            Domain             │
│ Patient / Doctor / Consultation│
└───────────────┬───────────────┘
                ↓
       Domain-defined ports
                ↑
┌───────────────┴───────────────┐
│        Infrastructure         │
│ Vault / DB / Ink / Security   │
│ Export / Platform / Filesystem│
└───────────────────────────────┘
```

The dependency direction is:

```text
Presentation
    ↓
Application
    ↓
Domain interfaces
    ↑
Infrastructure implementations
```

Infrastructure implements contracts required by the application/domain.

The domain does not depend on infrastructure.

---

# 4. Domain Purity

Domain code must not directly depend on:

* Flutter widgets;
* Flutter navigation;
* SQLite;
* SQLCipher;
* filesystem APIs;
* Android APIs;
* iOS APIs;
* WebView;
* Excalidraw;
* InkML parsing libraries;
* PDF libraries;
* platform secure storage;
* network APIs.

The domain must be testable independently of Flutter and platform infrastructure.

---

# 5. Domain Boundaries

## 5.1 Patient Domain

Owns:

* Patient;
* patient information;
* clinical background;
* consultations;
* prescriptions;
* investigation/report references;
* patient-related attachments.

The Patient Domain is the authority for patient clinical information.

It must not contain UI concerns or storage implementation.

---

## 5.2 Doctor Domain

Owns:

* Doctor profile;
* professional information;
* prescription template configuration;
* reusable doctor-owned assets;
* doctor preferences required by the MVP.

Historical document snapshots are immutable document data once persisted.

Changing the current Doctor Domain state must not mutate historical prescriptions.

---

## 5.3 Consultation Domain

Owns the lifecycle and domain representation of a consultation/prescription.

It must represent the clinical document independently of the handwriting editor.

It must not contain Excalidraw-specific structures.

---

## 5.4 Application Domain

The Application layer coordinates workflows across domains.

Examples:

```text
CreatePatient
StartConsultation
OpenPrescription
SavePrescription
ClosePrescription
ExportPrescription
DeletePatient
```

Application workflows may depend on domain interfaces.

They must not become the owner of clinical data.

---

# 6. Infrastructure Boundaries

Infrastructure is divided into explicit capabilities.

```text
infrastructure/
├── vault/
├── database/
├── documents/
├── ink/
├── export/
├── security/
├── filesystem/
└── platform/
```

Each infrastructure component must have one primary responsibility.

---

# 7. Filesystem Boundary

Application/domain code must not directly instantiate arbitrary `File`, `Directory`, or filesystem paths for Vault operations.

All Vault filesystem access must pass through a dedicated abstraction.

Conceptually:

```text
VaultFilesystem
├── exists
├── createDirectory
├── read
├── write
├── rename
├── delete
└── atomicReplace
```

The actual implementation may use Dart/platform filesystem APIs.

The rest of Lipi must not need to know which filesystem API is being used.

---

# 8. Vault Boundary

The Vault subsystem is responsible for:

* Vault initialization;
* Vault opening;
* Vault validation;
* Vault version detection;
* Vault locking/unlocking;
* Vault filesystem layout;
* database lifecycle;
* document storage;
* attachment storage;
* Vault integrity;
* backup/transfer validation;
* migration coordination.

The Vault subsystem must not implement clinical business rules.

---

# 9. Database Boundary

SQLite is metadata infrastructure.

The database layer may store:

* internal identifiers;
* patient discovery data;
* relationships;
* document references;
* search metadata;
* timestamps;
* Vault/schema metadata.

The database must not become the canonical storage location for handwritten prescription content.

The database must never be used to reconstruct an unavailable or corrupted `.lipi` document.

---

# 10. Document Repository Boundary

A document repository provides access to canonical clinical documents.

Conceptually:

```text
DocumentRepository
├── create
├── read
├── replace
├── validate
└── delete
```

The repository must operate on Lipi's document abstraction rather than Excalidraw state.

The repository is responsible for ensuring that a requested document is:

* present;
* readable;
* supported;
* structurally valid;
* integrity-valid.

A failure to satisfy these conditions is an error, not an invitation to reconstruct the document from SQLite.

---

# 11. `.lipi` Serialization Boundary

The `.lipi` serializer is responsible for converting between:

```text
Lipi Clinical Document
        ↕
ZIP-based .lipi package
```

It must own:

* package creation;
* package reading;
* manifest serialization;
* manifest validation;
* version validation;
* InkML resource handling;
* template resource handling;
* package integrity checks;
* migration dispatch.

It must not own:

* patient search;
* patient business logic;
* doctor profile management;
* UI state;
* Excalidraw camera state;
* PDF presentation logic.

---

# 12. Canonical Document Rule

The canonical editable representation is always the Lipi document.

The following are **not** canonical clinical representations:

* Excalidraw JSON;
* WebView state;
* Flutter widget state;
* SQLite prescription reconstruction;
* PDF;
* PNG;
* cached rendering;
* temporary files.

Excalidraw is an editing mechanism.

InkML is the canonical digital-ink representation within the `.lipi` document.

---

# 13. Ink Engine Boundary

The handwriting subsystem must expose a Lipi-owned abstraction.

Conceptually:

```text
InkEngine
├── initialize
├── createDocument
├── loadDocument
├── observeChanges
├── exportInk
├── importInk
├── setTemplate
├── getDocumentState
└── dispose
```

The exact interface may evolve during implementation.

The critical rule is:

> No application/domain component may depend directly on Excalidraw's internal document model.

The adapter owns translation between:

```text
Lipi canonical ink
        ↕
Excalidraw editor state
```

---

# 14. Excalidraw Boundary

Excalidraw-specific concepts must terminate at the Ink infrastructure boundary.

Allowed:

```text
Ink infrastructure
    ↔
Excalidraw
```

Not allowed:

```text
Patient Domain
    → Excalidraw

Consultation Domain
    → Excalidraw

Application Workflow
    → Excalidraw API
```

If Excalidraw were replaced in the future, the domain model and clinical workflow should not require redesign.

---

# 15. WebView Boundary

The editor is embedded inside Flutter through a WebView.

The WebView bridge must be treated as a platform/infrastructure boundary.

Conceptually:

```text
Flutter
   │
   │ Lipi-owned bridge messages
   ▼
WebView
   │
   ▼
Excalidraw editor
```

The bridge must exchange Lipi-defined commands/data rather than exposing arbitrary Excalidraw application state to Flutter.

---

# 16. Bundled Editor Runtime

The Excalidraw editor/runtime is a bundled offline asset.

The implementation must retain the validated local loopback HTTP serving approach for the bundled editor/runtime where required by the WebView environment.

The application must not depend on:

* CDN assets;
* remote JavaScript;
* remote fonts;
* remote API calls;
* online Excalidraw services.

Normal prescription writing must remain functional offline.

---

# 17. Coordinate Contract

There is exactly one canonical document coordinate system.

The template and handwriting operate within that coordinate system.

The following are view concerns:

* zoom;
* pan;
* viewport size;
* screen resolution;
* WebView dimensions.

View transformations must never be serialized as document geometry.

The ink adapter must therefore distinguish:

```text
Document coordinates
        ≠
Viewport coordinates
```

---

# 18. Template Contract

The Doctor Domain owns the active prescription template configuration.

The prescription document owns the historical template representation required to reconstruct itself.

Therefore:

```text
Doctor Domain
    ↓
Active template selection

Prescription
    ↓
Historical template snapshot
```

Changing the active template must not modify existing prescriptions.

A custom template used by a prescription must be embedded in that `.lipi` document.

---

# 19. Snapshot Contract

When a prescription is created, required historical information must be captured into the document.

At minimum, the document contains the required:

* patient snapshot;
* doctor snapshot;
* page metadata;
* document identifier;
* ink reference;
* template representation where applicable.

The snapshot is document data.

It is not a live reference to the current Doctor or Patient object.

---

# 20. Persistence Contract

The persistence layer must distinguish:

```text
Editing state
    ↓
Canonical document state
    ↓
Durable Vault state
```

Only the durable canonical document is considered persisted clinical state.

UI state is never considered saved merely because the UI currently displays it.

---

# 21. Autosave Contract

Autosave must be automatic.

The implementation may debounce or coalesce frequent editor changes, but it must not sacrifice clinical durability merely to minimize writes.

The persistence invariant is:

```text
Before commit:
    previous valid document remains intact.

After commit:
    new valid document exists and is valid.
```

A failed save must leave the previous valid document available.

---

# 22. Atomic Document Replacement

A canonical document must never be replaced directly by a potentially incomplete write.

The implementation must use an atomic or equivalent safe-replacement strategy.

Conceptually:

```text
Current valid document
        │
        ├── remains untouched
        │
        ▼
Temporary new document
        │
        ├── write completely
        ├── validate
        └── commit
               │
               ▼
        New valid document
```

If any step before commit fails, the previous document remains authoritative.

---

# 23. SQLite Transaction Contract

Database metadata and filesystem documents have different persistence mechanisms.

The implementation must explicitly define ordering when both must change.

The canonical clinical document must never depend solely on a database transaction.

A document write must be validated before metadata is allowed to reference it as the new valid state.

If database and filesystem state disagree, Lipi must detect the inconsistency and enter a safe recovery path.

---

# 24. Security Storage Contract

Clinical Vault data must be encrypted at rest.

The security architecture must use established cryptographic primitives and maintained implementations.

No custom encryption scheme is permitted.

The implementation must separate:

```text
Authentication credential
        ≠
Vault encryption key
```

The Vault encryption key must be randomly generated.

Key material must be protected through platform secure storage where available.

---

# 25. Security Abstraction

Application code must not directly depend on Android Keystore or iOS Keychain APIs.

Conceptually:

```text
SecureKeyStore
├── storeKey
├── retrieveKey
├── deleteKey
└── keyExists
```

Platform implementations provide the actual mechanism.

The application operates against the abstraction.

---

# 26. Vault Encryption Model

The exact storage representation must preserve the distinction between:

1. the logical `.lipi` document format;
2. the protected Vault storage representation.

The `.lipi` specification remains a ZIP-based canonical document.

Vault-at-rest protection must not redefine the logical `.lipi` specification.

The implementation may therefore use a storage-layer encryption envelope around canonical document bytes when required to satisfy Vault encryption requirements.

The important invariant is:

```text
Logical document:
    valid ZIP-based .lipi

Vault storage:
    protected at rest

Read:
    protected storage
        ↓
    decrypt
        ↓
    validate .lipi
        ↓
    reconstruct document
```

Plaintext clinical documents should exist outside protected storage only for the minimum time necessary to perform an operation.

---

# 27. Database Encryption

The Vault database must be protected at rest.

The selected database implementation must support the required encrypted SQLite architecture.

The application must not assume that ordinary application-sandbox filesystem protection alone satisfies the Vault security requirement.

---

# 28. Error Model

Infrastructure failures must not leak into domain logic as arbitrary exceptions or platform-specific error objects.

The application should expose meaningful Lipi-level failure categories.

Conceptually:

```text
LipiError
├── VaultError
├── StorageError
├── DocumentError
├── IntegrityError
├── SecurityError
├── ImportError
├── ExportError
├── ValidationError
└── RecoveryError
```

The final implementation may refine these categories.

Errors must preserve enough information for appropriate UI handling without exposing unnecessary sensitive data.

---

# 29. Fail-Closed Contract

The implementation must distinguish between:

```text
Data unavailable
Data invalid
Data unsupported
Data corrupted
Data incomplete
```

These conditions must not be silently converted into a successful result.

Examples:

```text
Missing .lipi
    → error

Corrupt .lipi
    → error

Unsupported version
    → error / migration path

Missing referenced attachment
    → incomplete-data error

Invalid integrity check
    → integrity error
```

Never:

```text
missing document
    ↓
reconstruct from SQLite
    ↓
pretend everything is fine
```

---

# 30. Clinical Data Logging Rule

Clinical data must not be written to logs unnecessarily.

Logs must avoid:

* patient names;
* clinical notes;
* prescription contents;
* handwritten data;
* credentials;
* encryption keys;
* recovery secrets.

Errors should expose diagnostic information without unnecessarily exposing protected clinical content.

---

# 31. Export Contract

PDF export must consume canonical document data.

Conceptually:

```text
.lipi
  ↓
Canonical Document Model
  ↓
PDF Renderer
  ↓
PDF
```

Not:

```text
WebView screenshot
  ↓
PDF
```

and not:

```text
Current viewport
  ↓
PDF
```

PDF generation must not mutate the canonical document.

Export failure must leave the canonical document unchanged.

---

# 32. Application Workflow Contract

Application workflows coordinate operations but do not own domain state.

Example:

```text
StartPrescriptionWorkflow
    1. Confirm patient
    2. Obtain doctor/template context
    3. Create consultation identity
    4. Create canonical document
    5. Persist initial document
    6. Open editing workspace
```

Example:

```text
SavePrescriptionWorkflow
    1. Obtain canonical editor state
    2. Convert editor state to Lipi representation
    3. Serialize .lipi
    4. Validate package
    5. Safely replace previous document
    6. Update metadata/reference state
```

Workflows must explicitly define failure behavior.

---

# 33. Patient Search Contract

Search is a discovery mechanism.

A search result is not automatically proof of patient identity.

The UI/application layer must allow the doctor to confirm the intended patient before clinical action is performed.

Search implementation details may change without changing the Patient Domain contract.

---

# 34. Historical Editing Contract

Opening an old prescription for viewing must not automatically enter modification mode.

The implementation must distinguish:

```text
View historical prescription
        ↓
Create new prescription from patient context
```

from:

```text
View historical prescription
        ↓
Explicitly modify historical prescription
```

The UI must make intentional historical modification clear.

The underlying persistence system must not accidentally overwrite a historical record merely because it was opened.

---

# 35. Patient Deletion Contract

Patient deletion is destructive.

It must require explicit confirmation.

The implementation must ensure that related clinical data is handled consistently.

A deletion operation must not leave silently dangling references.

If deletion cannot be completed safely, the operation must fail without pretending that the patient was successfully removed.

---

# 36. Vault Lifecycle

The Vault lifecycle must be explicit:

```text
Uninitialized
     ↓
Initializing
     ↓
Created
     ↓
Locked
     ↓
Unlocked
     ↓
Validated
     ↓
Active
```

Invalid or corrupted Vaults must enter an error/recovery state rather than being treated as normal active Vaults.

---

# 37. Startup Contract

Application startup must not assume that a valid Vault exists.

Startup must determine:

1. whether a Vault exists;
2. whether it is structurally valid;
3. whether required security material exists;
4. whether the database is usable;
5. whether the schema is supported;
6. whether migration is required;
7. whether the Vault can safely be opened.

Only after successful validation may the Vault become active.

---

# 38. Migration Contract

Persistent formats must be versioned.

Migration must be:

* explicit;
* deterministic;
* testable;
* non-destructive where practical;
* recoverable.

Migration must not silently discard clinical information.

Unsupported future versions must be refused safely rather than guessed.

The `.lipi` format and Vault schema are independently versioned concepts.

---

# 39. Backup / Transfer Contract

Backup and transfer operate on the complete Vault.

A backup/transfer workflow must preserve:

```text
Database
+
Clinical documents
+
Attachments
+
Doctor data
+
Required Vault metadata
+
Required security metadata
```

The destination must be validated before activation.

An incomplete transfer must not become the active Vault.

---

# 40. Platform Contract

Platform-specific code belongs under infrastructure/platform.

The application may define platform abstractions for:

* secure storage;
* application lifecycle;
* file import/export;
* WebView;
* authentication;
* platform directories;
* sharing.

Domain code must remain unaware of the target platform.

---

# 41. Testing Contract

Every architectural boundary must be testable.

Testing must cover at least:

```text
Domain
    ↓
Application workflows
    ↓
Persistence
    ↓
Document format
    ↓
Security
    ↓
Integration
    ↓
Physical device
```

---

# 42. Unit Tests

Unit tests must cover:

* domain entities;
* domain invariants;
* application workflows;
* document model;
* manifest validation;
* InkML conversion;
* document serialization;
* document deserialization;
* coordinate transformations;
* error mapping;
* search behavior;
* historical snapshot behavior.

Unit tests must not require a physical device.

---

# 43. Persistence Tests

Persistence tests must cover:

* Vault initialization;
* Vault reopening;
* database creation;
* document creation;
* document replacement;
* atomic replacement;
* crash/interruption scenarios;
* corrupted documents;
* missing documents;
* inconsistent metadata;
* schema versions;
* migration behavior.

Critical persistence tests must verify the **previous-valid-state invariant**.

---

# 44. Security Tests

Security testing must verify:

* Vault encryption;
* encrypted database access;
* encrypted document storage;
* key generation;
* key retrieval;
* authentication/key separation;
* integrity validation;
* tamper detection;
* invalid-key behavior;
* corrupted-data behavior;
* backup/restore validation;
* migration/recovery behavior.

Tests must never embed production secrets.

---

# 45. Document Round-Trip Tests

The following round trip must remain valid:

```text
Create document
      ↓
Write ink
      ↓
Serialize .lipi
      ↓
Read .lipi
      ↓
Validate
      ↓
Reconstruct editor state
      ↓
Serialize again
```

The reconstructed document must preserve the required canonical information.

The test suite must specifically verify:

* stroke geometry;
* stroke order;
* pressure where available;
* width;
* color;
* template;
* page dimensions;
* patient snapshot;
* doctor snapshot.

---

# 46. End-to-End Workflow Test

At minimum, an automated integration test must exercise:

```text
Doctor setup
    ↓
Template setup
    ↓
Patient creation
    ↓
Patient search
    ↓
Patient selection
    ↓
Prescription creation
    ↓
Ink input
    ↓
Autosave
    ↓
Close
    ↓
Reopen
    ↓
Historical verification
    ↓
PDF export
```

The exact mechanism of simulated stylus input may differ from physical-device validation.

---

# 47. Physical Device Contract

Automated tests are insufficient for handwriting UX.

At least one supported Android tablet must validate:

* WebView startup;
* bundled editor loading;
* stylus input;
* pressure where supported;
* writing latency;
* zoom;
* pan;
* save;
* close/reopen;
* template rendering;
* PDF export.

The existing physical prototype validation on the OnePlus Pad 2 is the baseline reference for this workflow.

---

# 48. Code Organization Contract

The repository should follow:

```text
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
```

The exact filenames may change during implementation.

The architectural boundaries must not.

---

# 49. Dependency Rules

The following dependencies are prohibited:

```text
Domain → Flutter
Domain → SQLite
Domain → Excalidraw
Domain → WebView
Domain → filesystem
Domain → platform APIs

Presentation → SQLite
Presentation → Excalidraw internals
Presentation → filesystem

Application → Android APIs
Application → iOS APIs
Application → raw SQLite

Patient Domain → Doctor Domain internals
Doctor Domain → Patient Domain internals
```

Cross-domain operations must pass through application workflows.

---

# 50. Replaceability Contract

The following are explicitly replaceable infrastructure:

* handwriting engine;
* SQLite implementation;
* filesystem implementation;
* secure-storage implementation;
* PDF renderer;
* platform integration.

Replacing one must not require redesigning the clinical domain.

The following are stable product concepts:

* Patient;
* Doctor;
* Consultation;
* clinical document;
* Vault;
* canonical `.lipi` representation;
* doctor-owned data.

---

# 51. No Premature Abstraction

The implementation must not introduce abstractions solely because they might be useful someday.

Do not build:

* plugin systems;
* generalized event buses;
* generalized repository frameworks;
* speculative dependency-injection frameworks;
* distributed synchronization infrastructure;
* hospital role systems;
* AI interfaces;
* unnecessary domain entities.

Abstractions are justified when they protect an actual architectural boundary.

---

# 52. No Architecture Leakage

A lower-level implementation detail must not become a product-level assumption.

Examples:

```text
"Excalidraw has X"
```

must not become:

```text
"Lipi documents contain X because Excalidraw does."
```

Likewise:

```text
"SQLite stores X"
```

must not become:

```text
"The clinical model requires X because SQLite does."
```

Implementation technology must remain subordinate to the Lipi model.

---

# 53. Source-of-Truth Contract

For any piece of data, implementation must be able to answer:

> What is authoritative?

The expected pattern is:

```text
Patient information
    → Patient Domain / Vault metadata

Doctor profile
    → Doctor Domain / Vault data

Historical prescription
    → .lipi document

Handwritten ink
    → InkML inside .lipi

Search index
    → derived metadata

PDF
    → derived export

UI state
    → ephemeral
```

Derived data must never silently become authoritative.

---

# 54. Implementation Discipline

Before adding a component, determine:

1. Who owns this data?
2. Which layer owns this behavior?
3. Is this canonical or derived?
4. What is the persistence boundary?
5. What happens if it fails?
6. Can it be tested independently?
7. Does it introduce a dependency in the wrong direction?
8. Is the abstraction required now?

If these questions cannot be answered, the component is not ready to be implemented.

---

# 55. Definition of an Acceptable Implementation

An implementation is acceptable only if it satisfies all applicable requirements of:

```text
ADR-0001
ADR-0002
ADR-0003
ADR-0004
ADR-0005
ADR-0006
ADR-0007
MVP-SPEC.md
IMPLEMENTATION-CONTRACT.md
```

The implementation must preserve:

```text
Doctor ownership
       +
Offline operation
       +
Clinical continuity
       +
Canonical .lipi records
       +
Editable handwriting
       +
Safe persistence
       +
Encrypted Vault
       +
Fail-closed behavior
```

---

# 56. Final Engineering Rule

When in doubt:

> **Keep the domain simple, keep the boundaries explicit, keep the clinical record authoritative, and make infrastructure replaceable.**

Lipi should be easy to implement **without becoming easy to break**.

The implementation exists to realize the architecture—not quietly redesign it.
