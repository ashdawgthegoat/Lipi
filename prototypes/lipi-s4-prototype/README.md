# Lipi Sprint 4 Technical Prototype

## Overview

This is the Sprint 4 technical prototype for **Project Lipi**, implementing the core consultation and prescription workflow:
- **Doctor Domain**: First-run doctor setup, profile persistence, prescription template ownership (custom image or clinic letterhead).
- **Patient Domain**: New patient creation, SQLite discovery, Vault filesystem directory creation, returning patient workflow, and immutable recorded patient age.
- **Application Domain**: Coordinates workflows without domain cross-contamination.
- **Excalidraw WebView Integration**: WebView-based Excalidraw foundation configured for handwritten prescriptions on Android tablets with stylus.
- **`.lipi` Document Packaging**: ZIP-based file package containing a single minimal `manifest.json` and `ink/page-001.inkml`.
- **InkML Subset Engine**: Bi-directional conversion between Excalidraw freedraw strokes and W3C InkML XML traces preserving geometry, stroke order, pressure, and styling.
- **Auto-Save & Reopen**: Automatic `.lipi` persistence upon prescription completion and faithful reconstruction upon reopening.
- **PDF Export**: Deliberate vector PDF generation with clinic letterhead, patient demographics, and handwritten prescription strokes.
- **Local-First & Offline**: Operates fully on the local OS filesystem and SQLite without internet connectivity.

---

## Directory Structure

```text
prototypes/lipi-s4-prototype/
├── android/                 # Android Gradle and manifest configuration (minSdk 21, compileSdk 36)
├── assets/
│   └── web/                 # Bundled standalone Excalidraw web application
├── web_editor/              # Isolated npm package for Excalidraw React frontend
│   ├── package.json         # Dedicated dependency tree (React 18, Excalidraw 0.18, Vite)
│   ├── src/                 # Prescription layout & Excalidraw imperative bridge
│   └── vite.config.ts       # Bundles directly into ../assets/web/
├── lib/
│   ├── app/
│   │   ├── app.dart         # Root MaterialApp with medical theme
│   │   └── screens/
│   │       ├── first_run_screen.dart             # Doctor Domain profile & template setup
│   │       ├── main_workspace_screen.dart        # Search & New Patient registration
│   │       ├── patient_workspace_screen.dart     # Patient history & prescription list
│   │       └── prescription_workspace_screen.dart# Excalidraw handwriting, auto-save & export
│   ├── domains/
│   │   ├── doctor/          # DoctorProfile and DoctorService
│   │   └── patient/         # PatientRecord, PrescriptionSummary and PatientService
│   ├── infrastructure/
│   │   ├── export/          # PdfExporter (vector PDF generation)
│   │   ├── ink/             # InkMLConverter (Excalidraw <-> InkML XML)
│   │   └── storage/         # LipiVault & LipiDatabase (SQLite) & LipiPackage (.lipi ZIP)
│   └── main.dart            # Application entry point & Vault bootstrap
├── test/
│   ├── domains/             # Doctor and Patient service unit tests
│   ├── infrastructure/      # LipiPackage, InkML, and PDF exporter tests
│   └── integration/         # Full end-to-end workflow roundtrip test
└── pubspec.yaml             # Dedicated Flutter dependencies
```

---

## Build and Run Instructions

### 1. Build the Web Editor (Excalidraw)
The web editor frontend has its own isolated npm dependency tree:
```bash
cd web_editor
npm install
npm run build
cd ..
```
The output is automatically generated in `assets/web/`.

### 2. Run Automated Verification Tests
Run the automated test suite covering `.lipi` packaging, InkML conversion, SQLite discovery, doctor/patient services, and the full end-to-end roundtrip:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

### 3. Build Android Debug APK
Build the APK for Android tablets:
```bash
flutter build apk --debug
```
Output binary:
`build/app/outputs/flutter-apk/app-debug.apk`

### 4. Install on Physical Android Tablet
Connect the tablet via USB with USB Debugging enabled:
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Or launch directly with live logging:
```bash
flutter run -d <device-id>
```

---

## Physical Device Validation Checklist

1. **First-run setup**: Launches `FirstRunScreen` on first start, creates Vault directory in application documents.
2. **Template import**: Saves doctor profile and custom template image/PDF to `Lipi Vault/doctor/templates/`.
3. **New patient creation**: Collects Name, Age, Gender, City. Creates patient record in SQLite.
4. **Patient folder creation**: Verifies filesystem folder `Lipi Vault/patient/<patient_id>/prescriptions/` is created.
5. **SQLite search**: Search bar instantly filters patients by name or city using SQLite `LIKE` queries.
6. **Returning patient selection**: Selecting an existing patient opens `PatientWorkspaceScreen` without showing the new patient form.
7. **Prescription creation**: Generates new `consultation_id` UUID and opens finite prescription page.
8. **Template rendering**: Displays doctor/clinic letterhead at the top.
9. **Patient fields**: Displays Name, Age, Gender, City, and consultation Date.
10. **Stylus handwriting**: Writes with active stylus on Excalidraw canvas inside Android WebView.
11. **Fast handwriting**: Validates latency and stroke responsiveness under rapid cursive writing.
12. **Palm rejection**: Validates interaction when resting hand on screen.
13. **Closing prescription**: Exiting workspace automatically serializes elements to InkML and packages into `.lipi`.
14. **`.lipi` file creation**: Verifies ZIP file at `Lipi Vault/patient/<patient_id>/prescriptions/consultation_<id>.lipi`.
15. **Reopening `.lipi`**: Tapping "Reopen" parses `.lipi` manifest and InkML, restoring the exact strokes, dimensions, and metadata.
16. **PDF export**: Tapping "Export PDF" renders vector strokes and clinic template into `.pdf` in the patient folder.
17. **Offline behavior**: Disabling Wi-Fi/cellular confirms 100% functionality without internet.
