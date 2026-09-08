# Lipi (लिपि)

Lipi is an open-source, local-first, handwriting-first clinical workspace for doctors.

Designed strictly around the doctor-patient encounter, Lipi replaces physical prescription pads with a low-friction digital stylus experience that guarantees complete data ownership, tamper-evident security, and zero cloud dependency.

---

## Architectural Principles (ADRs 0001–0008)

1. **Handwriting & Coordinate Fidelity (ADR-0001 & ADR-0005)**: The digital ink canvas preserves exact vector stroke ordering, coordinates (1mm = 3.78px), and pressure dynamics. The canonical document is owned by Lipi—never WebView, Excalidraw, or SQLite.
2. **Local-First & Offline-Always (ADR-0002 & ADR-0004)**: Zero network calls required for any clinical function. Canonical documents live in the doctor-owned Lipi Vault filesystem as encrypted `.lipi` packages with local SQLite metadata indexing.
3. **Fail-Closed Clinical Safety (ADR-0003 & ADR-0008)**: No fake data, no unvalidated documents, no silent save drops. Corrupted files or failed invariants block cleanly rather than corrupting clinical history.
4. **Crash-Safe Non-Concurrent Persistence (ADR-0008)**: 800ms debounced autosave with explicit flush on exit, atomic replacement (`.tmp` → swap), and strict serial write coordination.
5. **Storage Envelope Encryption at Rest (ADR-0007)**: AES-256-GCM authenticated encryption with HKDF-SHA256 key separation (Master Key → Document Key / Database Key) in a portable envelope (`LIPIENC1`).
6. **Deliberate PDF Export (ADR-0006)**: Dual-layer vector PDF export with zero coordinate displacement and strict separation from autosave.
7. **Portable Vault Backup & Recovery (ADR-0008)**: Validated backup packages with SHA-256 manifests and non-destructive staging (`Validate → Verify → Activate`).

---

## Clinical Workflow

```text
First Launch
    ↓
Doctor Profile & Letterhead Setup
    ↓
Main Workspace (Search / Register Patient)
    ↓
Patient Workspace (Longitudinal Summary & History)
    ↓
Prescription Workspace (Interactive Stylus Canvas / WebView Excalidraw)
    ↓
Debounced Atomic Autosave (Real-time Status Pill)
    ↓
Save & Exit / Reopen Prescription History
    ↓
Deliberate PDF Export (Print / Share)
```

---

## Verification & Testing

The entire application stack is verified with a comprehensive automated test suite across 14 test modules:

```bash
# Analyze repository (0 errors, 0 warnings)
flutter analyze

# Run complete test suite (58+ automated tests)
flutter test
```

### Key Test Suites:
- `test/integration/end_to_end_mvp_integration_test.dart`: Complete 17-step MVP clinical lifecycle.
- `test/ui/clinical_ui_test.dart`: Flutter widget tests for all four production clinical screens.
- `test/vault/vault_backup_test.dart`: Backup archive creation, integrity verification, and non-destructive rollback.
- `test/documents/autosave_test.dart`: Autosave controller, debounce timing, and atomic crash recovery.
- `test/security/vault_security_test.dart`: Master Key derivation, envelope encryption/decryption, and tamper detection.
- `test/documents/pdf_export_test.dart`: Layered vector PDF rendering and coordinate fidelity.
- `test/documents/canonical_document_test.dart` & `lipi_serialization_test.dart`: `.lipi` ZIP manifest round-tripping.
- `test/unit/ink_engine_test.dart`: Loopback server runtime and InkML/Excalidraw conversion.