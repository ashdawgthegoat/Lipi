# M14 Pre-M15 Code Review

## Executive Summary
This independent code review focuses on the Lipi application's readiness for the M15 milestone. The review assessed the codebase for structural integrity, clinical data safety, and adherence to the Lipi product philosophy (local-first, offline-first, handwriting-first). The investigation confirmed the presence of a critical data-loss bug related to Excalidraw's Undo functionality. Apart from this issue, the recent M14 UI changes were implemented elegantly, and the application architecture strictly enforces security and domain boundaries.

## M15 Blockers
- **Critical Data Loss Bug (Excalidraw Undo):** A sequence of loading an existing prescription, making an edit, and executing an Undo command results in the total erasure of the prescription, which is subsequently saved to disk. This is a definitive blocker for M15.

## Findings
- **Critical (1):** Data loss bug triggered by Excalidraw's history stack initialization (Detailed below).
- **Informational (4):** Validation of canonical atomic writes, secure envelope encryption, robust M14 long-press interactions, and adherence to architectural constraints.

## Known Bug
**Title:** Existing prescription → edit → Undo → entire prescription disappears.
**Severity:** Critical (M15 Blocker)

**Root Cause Analysis:**
In the web editor (`prototypes/lipi-s4-prototype/web_editor/src/App.tsx`), the `initPrescription` function loads an existing prescription by calling `apiRef.current.updateScene({ elements: data.elements })`. However, it fails to clear Excalidraw's history stack after this initialization operation.
1. When Excalidraw initializes, its history stack begins with a blank canvas state.
2. `updateScene` injects the loaded elements but does not wipe the history.
3. The user draws a new stroke, adding a new entry to the history stack.
4. The user hits `Undo`. Excalidraw reverts the state. It reverts the canvas back to its original *empty* state (the state before the elements were loaded via `initPrescription`).
5. This empty canvas state immediately triggers an `INK_CHANGED` event back to Flutter over the JavaScript bridge.
6. The `AutosaveController` debounces this change and subsequently executes a save of the empty document over the canonical `.lipi` file.
7. The user irreversibly loses the entire prescription.

**Recommended Fix (For M15):**
In `prototypes/lipi-s4-prototype/web_editor/src/App.tsx`, explicitly clear the history stack immediately after injecting elements in `initPrescription`:
```javascript
if (apiRef.current) {
  apiRef.current.updateScene({
    appState: { viewBackgroundColor: 'transparent' },
    ...(data.elements && data.elements.length > 0 ? { elements: data.elements } : {}),
  });
  apiRef.current.history.clear(); // Flushes history to prevent reverting to an empty canvas
}
```

## Regression Gaps
- **M14 Deletion Implementation:** No regressions found. The long-press interactions added in `PatientFolderItem` and `PrescriptionFileItem` elegantly handle deletions and rollback without interfering with standard single-tap behaviors.
- **UI Safety:** Zero internal IDs (UUIDs) were found exposed in the doctor-facing UI.

## Architecture/Security Observations
- **Canonical Persistence:** `AtomicDocumentWriter` successfully guarantees atomic replacement of `.lipi` files using a temporary-file flush-and-rename mechanism, eliminating partial-write corruption risks. It correctly fails closed.
- **Autosave / Crash Safety:** The `AutosaveController` handles continuous changes efficiently by coalescing frequent handwriting edits into a single debounced disk write.
- **Security Sandbox:** The system safely verifies vault unlocks before persisting data. Envelope encryption appropriately ensures that `.lipi` packages remain fully encrypted at rest.
- **Architecture Constraints:** The codebase flawlessly adheres to the required `Presentation → Application → Domain ← Infrastructure` constraint. Domain logic remains decoupled from the Flutter framework.

## M15 Readiness Assessment
The Lipi codebase is structurally robust, secure, and heavily compliant with its architectural philosophy. However, the application is **NOT READY** for the M15 release solely due to the critical Excalidraw Undo bug. The risk of unrecoverable clinical data loss upon a standard "Undo" interaction violates the core product philosophy of reliability.

Once the straightforward history-clearing fix is implemented and verified, the codebase will be fully cleared for the M15 release.
