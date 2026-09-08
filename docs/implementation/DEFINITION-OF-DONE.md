# Lipi — MVP Definition of Done

## 1. Purpose

This document defines the evidence required before the Lipi MVP may be declared complete.

"Implemented" does not mean "done."

A requirement is done only when:

1. the required behavior exists;
2. it follows the accepted architecture;
3. failure behavior is defined and tested;
4. relevant automated tests pass;
5. required physical-device validation passes;
6. no known blocking defect remains.

The MVP is complete only when all mandatory gates in this document are satisfied.

---

# 2. MVP Completion Rule

Lipi MVP may be declared complete only when all of the following are true:

```text
Architecture
    +
Clinical workflow
    +
Durable persistence
    +
Canonical .lipi documents
    +
Handwriting
    +
Autosave/recovery
    +
Security
    +
PDF export
    +
Automated tests
    +
Android tablet validation
    +
Dad Test
    =
MVP COMPLETE
```

A feature that merely works in a happy-path demonstration does not satisfy this definition.

---

# 3. Requirement Status Convention

Use these states:

```text
[ ] Not complete
[~] Implemented but not fully verified
[x] Complete and verified
[!] Blocked / requires investigation
[-] Explicitly deferred
```

Do not mark a requirement `[x]` without evidence.

---

# 4. Project Foundation

## Repository

* [ ] Flutter project builds from a clean checkout.
* [ ] Intended repository structure exists.
* [ ] `docs/adr/` contains accepted ADRs.
* [ ] `docs/implementation/` contains:

  * [ ] `MVP-SPEC.md`
  * [ ] `IMPLEMENTATION-CONTRACT.md`
  * [ ] `GEMINI.md`
  * [ ] `BUILD-PLAN.md`
  * [ ] `DEFINITION-OF-DONE.md`
* [ ] No generated/build artifacts are incorrectly committed.

## Static Quality

* [ ] `flutter analyze` passes.
* [ ] No analyzer errors remain.
* [ ] No known architecture-breaking lint suppressions are used.
* [ ] No temporary debug code remains in production paths.
* [ ] No clinical data is written to debug logs.

---

# 5. Architecture

## Dependency Direction

The implemented dependency direction is:

```text
Presentation
     ↓
Application
     ↓
Domain
     ↑
Infrastructure
```

* [ ] Domain code has no Flutter dependency.
* [ ] Domain code has no SQLite dependency.
* [ ] Domain code has no filesystem dependency.
* [ ] Domain code has no WebView dependency.
* [ ] Domain code has no Excalidraw dependency.
* [ ] Domain code has no platform-specific dependency.

## Domain Ownership

* [ ] Patient Domain owns patient information and clinical history.
* [ ] Doctor Domain owns doctor profile and active template configuration.
* [ ] Consultation Domain owns consultation/prescription lifecycle.
* [ ] Application layer orchestrates cross-domain workflows.
* [ ] Domains do not directly modify one another.

## Infrastructure

* [ ] Filesystem access is behind the filesystem/Vault boundary.
* [ ] Database access is behind the database boundary.
* [ ] `.lipi` serialization is behind the document boundary.
* [ ] Ink/editor access is behind the InkEngine boundary.
* [ ] PDF generation is behind the export boundary.
* [ ] Security/key storage is behind the security boundary.

---

# 6. Local-First / Offline-First

* [ ] Lipi launches without internet access.
* [ ] Doctor setup works without internet access.
* [ ] Patient creation works without internet access.
* [ ] Patient search works without internet access.
* [ ] Patient history works without internet access.
* [ ] Prescription creation works without internet access.
* [ ] Handwriting works without internet access.
* [ ] Autosave works without internet access.
* [ ] Historical prescriptions can be reopened offline.
* [ ] PDF export works offline.
* [ ] No MVP workflow requires a Lipi server.
* [ ] No MVP workflow requires an online account.

The absence of network connectivity must not prevent normal clinical use.

---

# 7. Vault

## Creation

* [ ] Fresh installation can create a Vault.
* [ ] Vault initialization creates required storage structures.
* [ ] Vault metadata is initialized correctly.
* [ ] Database initialization succeeds.

## Opening

* [ ] Existing Vault can be reopened.
* [ ] Invalid/incomplete Vault is detected.
* [ ] Lipi does not silently replace an invalid Vault with a new empty Vault.
* [ ] Existing valid data remains accessible after normal restart.

## Ownership

* [ ] Vault remains a user-owned data boundary.
* [ ] Application code does not depend on a remote service to interpret the Vault.
* [ ] Vault contents are sufficient for the supported backup/transfer workflow.

---

# 8. Database

* [ ] SQLite is used only for structured metadata/infrastructure.
* [ ] SQLCipher protection is enabled for the Vault database.
* [ ] Database schema version is explicit.
* [ ] Database initialization is deterministic.
* [ ] Transactions are used for operations requiring atomic metadata changes.
* [ ] Transaction rollback works.
* [ ] Transaction commit works.
* [ ] Database reopen preserves valid metadata.
* [ ] Database failure does not cause fabricated clinical records.
* [ ] Database is not treated as the canonical prescription document.

---

# 9. Patient Workflow

## Patient Creation

* [ ] Doctor can create a patient.
* [ ] Required patient information can be entered.
* [ ] Optional clinical background fields can be stored.
* [ ] Invalid required data is rejected.
* [ ] Successful patient creation persists across restart.

## Patient Search

* [ ] Doctor can search existing patients.
* [ ] Search returns matching patients.
* [ ] Search does not silently modify patient data.
* [ ] Search results allow the doctor to confirm the intended patient.

## Patient Workspace

* [ ] Doctor can open a patient.
* [ ] Patient information is visible.
* [ ] Clinical history is accessible.
* [ ] Consultation history is accessible.
* [ ] New prescription can be started from the patient workspace.

## Patient Deletion

* [ ] Deletion requires explicit user intent.
* [ ] Confirmation is shown.
* [ ] Accidental navigation cannot delete a patient.
* [ ] Deletion follows the defined associated-data policy.
* [ ] Deletion behavior is tested.
* [ ] No automatic expiration/deletion exists.

---

# 10. Doctor Setup

* [ ] First launch detects that doctor setup is incomplete.
* [ ] Doctor profile can be configured.
* [ ] Doctor profile persists across restart.
* [ ] Doctor profile can be retrieved later.
* [ ] Current profile changes do not silently modify historical prescriptions.

---

# 11. Template Workflow

* [ ] Doctor can select/configure the prescription template.
* [ ] Supported template input formats work.
* [ ] Default template works.
* [ ] Custom template import works where specified.
* [ ] Active template persists.
* [ ] Template appears correctly in a new prescription.
* [ ] Historical prescriptions retain their required template snapshot/resource.
* [ ] Changing the active template does not silently modify historical prescriptions.

---

# 12. Canonical Clinical Document

A consultation/prescription must have a Lipi-owned canonical representation.

* [ ] Canonical document model exists independently of Excalidraw.
* [ ] Page dimensions are explicit.
* [ ] Document coordinate system is explicit.
* [ ] Patient snapshot exists where required.
* [ ] Doctor snapshot exists where required.
* [ ] Historical template information is preserved where required.
* [ ] Vector ink is represented canonically.
* [ ] Stroke order is preserved.
* [ ] Supported pressure information is preserved.
* [ ] Stroke width/color information is preserved where applicable.

---

# 13. `.lipi` Format

## Serialization

* [ ] Valid consultation can be serialized into `.lipi`.
* [ ] Package contains exactly one manifest.
* [ ] Manifest contains required format/version information.
* [ ] Manifest identifies the consultation.
* [ ] Manifest contains required page information.
* [ ] Manifest references canonical ink.
* [ ] Required historical snapshots are preserved.
* [ ] Required embedded resources are included.

## Deserialization

* [ ] Valid `.lipi` can be reopened.
* [ ] Canonical document is reconstructed.
* [ ] Ink is reconstructed.
* [ ] Page dimensions are preserved.
* [ ] Snapshots are preserved.
* [ ] Historical template resources are preserved.

## Round Trip

The following must succeed:

```text
Canonical Document
       ↓
     .lipi
       ↓
Canonical Document
```

* [ ] Clinical information survives.
* [ ] Ink survives.
* [ ] Coordinates survive.
* [ ] Page dimensions survive.
* [ ] Historical snapshots survive.
* [ ] Required template resources survive.

## Invalid Documents

The following must fail safely:

* [ ] missing manifest;
* [ ] malformed manifest;
* [ ] unsupported document version;
* [ ] missing required ink;
* [ ] malformed InkML;
* [ ] invalid dimensions;
* [ ] corrupt package;
* [ ] incomplete package.

Lipi must not silently reconstruct an invalid historical prescription from incomplete SQLite metadata.

---

# 14. Coordinate System

* [ ] Canonical document coordinates are independent of viewport coordinates.
* [ ] Zoom does not modify document coordinates.
* [ ] Pan does not modify document coordinates.
* [ ] Editor reload preserves stroke positions.
* [ ] Export uses canonical coordinates.
* [ ] Saving after zoom/pan does not corrupt geometry.

A test must explicitly prove that:

```text
write
→ zoom
→ pan
→ save
→ reopen
```

does not alter the intended stroke geometry.

---

# 15. Handwriting / Ink

## Editor

* [ ] Bundled editor loads offline.
* [ ] WebView loads the editor through the validated loopback architecture.
* [ ] Editor does not require internet access.
* [ ] Editor initialization succeeds on the target Android tablet.

## Input

* [ ] Stylus produces strokes.
* [ ] Writing feels continuous under normal use.
* [ ] Finger navigation works.
* [ ] Pinch zoom works.
* [ ] Single-finger pan works as designed.
* [ ] Stylus/finger interaction does not create unacceptable accidental navigation or drawing.

## Canonical Conversion

* [ ] Editor strokes can be converted to Lipi canonical ink.
* [ ] Canonical ink can be loaded back into the editor.
* [ ] Stroke order is preserved.
* [ ] Position is preserved.
* [ ] Supported pressure is preserved.
* [ ] Supported visual properties are preserved.

---

# 16. Autosave

Autosave is mandatory.

* [ ] Prescription changes trigger persistence.
* [ ] Autosave does not require manual save interaction.
* [ ] Save state is accurately represented.
* [ ] Failed saves are detectable.
* [ ] Failed saves do not destroy the previous valid document.
* [ ] Reopening after successful autosave restores the latest saved state.
* [ ] App restart does not lose the latest successfully persisted document.
* [ ] Continuous writing does not cause pathological write behavior.
* [ ] Autosave does not corrupt `.lipi`.

Required failure test:

```text id="eb1xzw"
Valid Document A
       ↓
Edit → Document B
       ↓
Save fails
       ↓
Document A remains valid
```

---

# 17. Historical Prescription Behavior

The application must distinguish:

```text
View old prescription
        ≠
Create new prescription from context
        ≠
Modify old prescription
```

* [ ] Opening history is readably distinguishable from creating a new prescription.
* [ ] Creating a new prescription from a patient does not mutate history.
* [ ] Intentional historical editing is explicit.
* [ ] Historical snapshots remain stable.
* [ ] Historical template remains stable.
* [ ] Historical doctor information remains stable.
* [ ] Historical patient snapshot remains stable unless the defined editing behavior explicitly changes the document.
* [ ] Reopened historical documents remain editable when supported.

---

# 18. PDF Export

* [ ] Valid `.lipi` can be exported to PDF.
* [ ] PDF contains the correct page dimensions.
* [ ] Template is rendered correctly.
* [ ] Typed content is rendered correctly.
* [ ] Handwritten ink is rendered.
* [ ] Coordinates are faithful to the canonical document.
* [ ] Export does not depend on current viewport.
* [ ] Export does not require internet.
* [ ] Export does not modify the `.lipi`.
* [ ] Export failure leaves the canonical document intact.

---

# 19. Security

## At Rest

* [ ] Vault database is encrypted.
* [ ] Protected non-database content is encrypted according to the security architecture.
* [ ] Authenticated encryption/integrity protection is used.
* [ ] Encryption keys are not stored as ordinary plaintext files.
* [ ] Platform secure storage is used for protected key material.

## Key Separation

* [ ] Authentication credential and Vault encryption key are conceptually separate.
* [ ] Application authentication does not directly become the Vault encryption key.
* [ ] Key derivation follows the defined cryptographic architecture.

## Failure

* [ ] Incorrect authentication does not expose the Vault.
* [ ] Missing key material fails safely.
* [ ] Integrity failure fails safely.
* [ ] Corrupt encrypted content is not presented as valid.
* [ ] Recovery does not silently overwrite valid data.

## Logging

* [ ] Patient information is not logged.
* [ ] Clinical history is not logged.
* [ ] Prescription content is not logged.
* [ ] Encryption keys are not logged.
* [ ] Credentials are not logged.
* [ ] Sensitive document contents are not logged.

---

# 20. Backup and Transfer

* [ ] Entire Vault can be backed up.
* [ ] Backup contains required user-owned data.
* [ ] Backup can be validated.
* [ ] Backup can be restored.
* [ ] Restore preserves valid clinical documents.
* [ ] Incomplete backup is detected.
* [ ] Corrupt backup is detected.
* [ ] Failed restore does not destroy the existing Vault.
* [ ] Migration is version-aware.
* [ ] Migration is deterministic.
* [ ] Failed migration is non-destructive.

---

# 21. Error Handling

For every major failure path:

* [ ] Failure is detected.
* [ ] User receives an understandable error state.
* [ ] Existing valid data is protected.
* [ ] Retry is possible where appropriate.
* [ ] Recovery is possible where appropriate.
* [ ] Application does not claim success when the operation failed.
* [ ] Raw infrastructure exceptions are not unnecessarily exposed as the application's public error model.

---

# 22. Fail-Closed Verification

The following conditions must never result in fabricated or falsely valid clinical records:

* [ ] unreadable `.lipi`;
* [ ] corrupt `.lipi`;
* [ ] invalid manifest;
* [ ] failed integrity check;
* [ ] incomplete Vault;
* [ ] incompatible document version;
* [ ] failed migration;
* [ ] missing required resource;
* [ ] failed decryption.

When validity cannot be established:

```text
Refuse
→ Explain
→ Preserve
→ Recover where possible
```

---

# 23. Automated Testing

## Unit Tests

* [ ] Domain models.
* [ ] Domain validation.
* [ ] Value objects/IDs.
* [ ] Canonical document model.
* [ ] Ink representation.
* [ ] Manifest validation.
* [ ] Serialization.
* [ ] Deserialization.
* [ ] Error mapping.
* [ ] Application workflows.

## Persistence Tests

* [ ] Vault creation.
* [ ] Vault reopen.
* [ ] Database initialization.
* [ ] Database transactions.
* [ ] Patient persistence.
* [ ] Doctor persistence.
* [ ] Consultation metadata persistence.
* [ ] `.lipi` persistence.
* [ ] Restart recovery.

## Document Tests

* [ ] `.lipi` round trip.
* [ ] Invalid package rejection.
* [ ] Version rejection.
* [ ] InkML round trip.
* [ ] Snapshot preservation.
* [ ] Coordinate preservation.

## Security Tests

* [ ] Encryption.
* [ ] Decryption.
* [ ] Wrong-key failure.
* [ ] Integrity failure.
* [ ] Secure key storage integration.
* [ ] Corrupted encrypted data.
* [ ] Safe failure.

## Workflow Tests

* [ ] First launch.
* [ ] Doctor setup.
* [ ] Template setup.
* [ ] Patient creation.
* [ ] Patient search.
* [ ] Patient workspace.
* [ ] Prescription creation.
* [ ] Prescription persistence.
* [ ] History.
* [ ] Historical editing.
* [ ] Patient deletion.
* [ ] PDF export.

---

# 24. End-to-End Acceptance Test

The complete workflow must succeed:

```text id="3m9z6w"
Fresh Installation
      ↓
First Launch
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
Reopen Prescription
      ↓
Verify Writing
      ↓
Open Previous History
      ↓
Perform Intentional Historical Operation
      ↓
Verify Persistence
      ↓
Export PDF
      ↓
Search Patient
      ↓
Delete Patient Intentionally
```

* [ ] Entire workflow passes.
* [ ] No test-only shortcut is used.
* [ ] No internet connection is required.
* [ ] Clinical data remains intact throughout the workflow.

---

# 25. Android Tablet Validation

## Current Hardware Gate

**Android tablet validation is mandatory for MVP.**

The currently available physical test platform is an Android tablet.

iPad hardware is not currently available.

Therefore:

* [ ] Android tablet validation passes.
* [-] Physical iPad validation is deferred until compatible hardware is available.

The MVP must **not** claim that iPadOS has been physically validated.

## Android Hardware Tests

* [ ] Fresh installation.
* [ ] First launch.
* [ ] Doctor setup.
* [ ] Template setup.
* [ ] Patient creation.
* [ ] Patient search.
* [ ] Patient workspace.
* [ ] Prescription creation.
* [ ] Stylus handwriting.
* [ ] Finger navigation.
* [ ] Pinch zoom.
* [ ] Pan.
* [ ] Autosave.
* [ ] Background/reopen.
* [ ] Process restart/recovery.
* [ ] Historical prescription reopen.
* [ ] Historical editing.
* [ ] PDF export.
* [ ] Vault reopen.
* [ ] Security behavior.
* [ ] Backup/restore where implemented.

## Performance Observations

Record whether the device exhibits blocking problems with:

* [ ] application startup;
* [ ] editor startup;
* [ ] handwriting latency;
* [ ] zoom;
* [ ] pan;
* [ ] save latency;
* [ ] history navigation;
* [ ] PDF export;
* [ ] memory usage;
* [ ] prolonged editing sessions.

No specific performance number is required unless a later product decision establishes one.

The criterion is whether performance creates a blocking clinical workflow problem.

---

# 26. iPadOS Compatibility Requirement

Physical iPad validation is **not an MVP completion gate at present** because no iPad hardware is currently available.

However:

* [ ] Flutter implementation does not deliberately introduce Android-only application-layer dependencies.
* [ ] Domain code remains platform-independent.
* [ ] Platform-specific code is isolated.
* [ ] WebView integration remains conceptually compatible with the supported iOS WebView architecture.
* [ ] File/storage abstractions do not expose Android-specific assumptions to the application/domain.
* [ ] Known iPad-specific issues are documented if discovered through code inspection or automated checks.

When iPad hardware becomes available, the deferred validation must include:

```text
iPad installation
→ Vault
→ doctor setup
→ patient workflow
→ stylus writing
→ zoom/pan
→ autosave
→ reopen
→ history
→ PDF
→ security
```

Until then, the project should report:

> **iPadOS: architecturally targeted, physical validation pending hardware availability.**

---

# 27. Regression Gate

Before MVP declaration:

* [ ] Full unit test suite passes.
* [ ] Full integration test suite passes.
* [ ] Security tests pass.
* [ ] Document round-trip tests pass.
* [ ] End-to-end workflow passes.
* [ ] Android physical-device validation passes.
* [ ] No known data-loss defect remains.
* [ ] No known security-blocking defect remains.
* [ ] No known canonical-document corruption defect remains.
* [ ] No known blocking handwriting defect remains.

---

# 28. Documentation Gate

* [ ] MVP specification matches the implemented behavior.
* [ ] Implementation contract matches the actual architecture.
* [ ] Build plan reflects completed milestones.
* [ ] Relevant ADRs exist for accepted architectural decisions.
* [ ] Known limitations are documented.
* [ ] Deferred iPad physical validation is explicitly documented.
* [ ] No documentation claims unperformed tests as passed.

---

# 29. Dad Test

The MVP must be tested by the intended first real-world user.

The user should be able to complete the core workflow without developer assistance.

## Required Scenario

* [ ] Find/create patient.
* [ ] Open patient.
* [ ] Create prescription.
* [ ] Write naturally.
* [ ] Navigate while writing.
* [ ] Leave the prescription.
* [ ] Reopen it.
* [ ] Verify handwriting.
* [ ] Find previous prescription.
* [ ] Understand the difference between old history and new prescription.
* [ ] Export PDF.
* [ ] Perform an intentional destructive action.

## Observation

Record:

* [ ] hesitation;
* [ ] wrong taps;
* [ ] navigation confusion;
* [ ] gesture confusion;
* [ ] writing friction;
* [ ] save uncertainty;
* [ ] history confusion;
* [ ] destructive-action confusion;
* [ ] unexpected behavior.

The developer must not interpret "the user completed it after being told what to press" as proof that the workflow is intuitive.

---

# 30. MVP Blockers

Any of the following blocks MVP completion:

### Data

* silent data loss;
* corrupted clinical document;
* inability to reopen saved prescriptions;
* incorrect historical data;
* broken patient/consultation association.

### Security

* plaintext sensitive data persisted contrary to the security architecture;
* exposed encryption keys;
* broken Vault protection;
* unsafe integrity failure;
* unsafe recovery behavior.

### Clinical Workflow

* patient cannot reliably be found;
* prescription cannot reliably be created;
* prescription cannot reliably be reopened;
* historical records are ambiguous or silently modified;
* deletion can happen accidentally.

### Handwriting

* stylus input is unusable;
* strokes are lost;
* coordinates are corrupted;
* zoom/pan corrupts document geometry;
* saved handwriting cannot be reconstructed.

### Platform

* Android tablet cannot complete the core workflow;
* WebView/editor cannot reliably load;
* app crashes during normal clinical workflow;
* persistence fails on physical device.

### Export

* PDF omits important canonical content;
* PDF geometry is materially incorrect;
* export corrupts or changes the source document.

---

# 31. Non-Blockers

The following do not block MVP unless they directly affect the clinical workflow:

* future cloud sync;
* AI;
* hospital mode;
* advanced analytics;
* enterprise administration;
* multi-device synchronization;
* advanced customization;
* iPad physical validation before hardware is available;
* speculative scalability work;
* nonessential visual polish.

---

# 32. Final MVP Sign-Off

Before declaring MVP complete, verify:

```text id="0t8qpy"
[ ] All mandatory requirements are [x]
[ ] No MVP blocker remains
[ ] Full automated test suite passes
[ ] Android tablet validation passes
[ ] Security validation passes
[ ] .lipi round-trip passes
[ ] Autosave/recovery passes
[ ] PDF export passes
[ ] Backup/recovery passes
[ ] End-to-end workflow passes
[ ] Dad Test passes
[ ] Documentation is current
[ ] Known limitations are documented
[ ] iPad physical validation is explicitly marked deferred
```

The final status should be one of:

```text
MVP COMPLETE
```

or:

```text
MVP NOT COMPLETE
```

There is no "mostly complete" state for the final gate.

---

# 33. Final Definition

Lipi MVP is done when a doctor can use the application as a reliable offline clinical workspace on the available target hardware, with patient records and handwritten prescriptions remaining durable, editable, secure, recoverable, and exportable.

The architecture must remain intact while doing so.

The clinical record must remain authoritative.

The application must not require the doctor to understand the implementation in order to trust or operate it.

**If the record is not safe, Lipi is not done.**
