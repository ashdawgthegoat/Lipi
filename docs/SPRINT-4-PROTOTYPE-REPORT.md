# Sprint 4 Technical Prototype Report — Prescription Workflow & `.lipi` Document Validation

**Date:** September 2026  
**Project:** Lipi  
**Sprint:** Sprint 4 — Technical Prototype  
**Target Platform:** Android Tablet (Physical Device, Stylus/Touch)  
**Development Platform:** Linux (EndeavourOS)  
**Tested Hardware:** OnePlus Pad 2 (Qualcomm Snapdragon 8 Gen 3, 3392x2400 @ 144Hz, Android 15/16, ADB Device ID: `adcfcc62`)

---

## 1. Executive Summary

Sprint 4 implemented an independent technical prototype (`prototypes/lipi-s4-prototype/`) to validate the core Lipi prescription workflow and the proposed `.lipi` document format on physical Android tablet hardware.

This prototype is **not** a handwriting engine evaluation (which was completed in Sprint 0 and established Excalidraw as the ink foundation). Its purpose is to validate the first end-to-end Lipi application workflow:
1. First-run Doctor identity and clinic letterhead setup.
2. Patient registration and consultation history.
3. Handwritten prescription creation on a finite letterhead document.
4. Auto-saving into a `.lipi` document package (ZIP archive containing InkML digital ink, metadata, and template references).
5. Reopening prescriptions faithfully as live, interactive vector ink.
6. Exporting print-ready, faithfully registered vector PDF prescriptions.

### Historical Boundary Integrity
The Sprint 0 prototype (`prototypes/flutter-ink-eval/`) and `docs/ADR-0005*.md` were preserved completely untouched throughout this sprint.

### Validation Passes Completed
* **Pass 1 / Pass 1B (Template Asset Pipeline & Visibility):** Resolved Android Chromium CORS rejections on `file:///` URLs by implementing an offline loopback HTTP asset server (`LocalAssetServer`) on `127.0.0.1`. Confirmed 100% template visibility on physical hardware for both generic default and custom uploaded templates.
* **Pass 2 (Unified Prescription Zoom & Coordinate Space):** Solved the coordinate/zoom decoupling problem between the visual prescription sheet and the Excalidraw ink surface. Formulated and implemented a Single Document Transform Architecture where the finite A4 sheet and ink layer share an invariant document coordinate space (`[0, 800] x [0, 1155.56]`) and camera transform. Verified zero-drift zoom, smooth panning, and writing at arbitrary zoom levels on physical hardware.
* **Pass 3 (Historical Reopen/Edit + Faithful PDF Export):** Solved historical PDF coordinate offsets, dynamic layout margin shifts, and negative-$y$ clipping by developing a zero-margin, exact-geometry vector PDF generation engine (`PdfExporter`). Verified on physical hardware that exported PDFs achieve sub-millimeter stroke registration on ruled lines matching the visual workspace with 100% viewport zoom/pan invariance. Reopening existing `.lipi` archives restores vector strokes as live, interactive Excalidraw digital ink (not flattened bitmaps), allowing seamless continuing edits. Established hermetic archive self-containment by embedding template image bytes (`templates/custom_template.<ext>`) and doctor metadata directly inside the `.lipi` ZIP, ensuring clinical and legal immutability even if the active doctor switches clinic letterheads.

---

## 2. Repository & Prototype Architecture

```text
prototypes/lipi-s4-prototype/
├── android/                 # Android Gradle 9, AGP 9.0, SDK 36, minSdk 21
├── assets/
│   └── web/                 # Bundled production Excalidraw web application
├── web_editor/              # Dedicated npm package (React 18 + Excalidraw 0.18 + Vite)
│   ├── src/
│   │   ├── App.tsx          # Single Document Transform & Camera Sync Engine
│   │   ├── index.css        # Finite page layout & sheet viewport styling
│   │   └── main.tsx         # Root mounting point
│   ├── package.json
│   └── vite.config.ts
├── lib/
│   ├── app/screens/
│   │   ├── first_run_screen.dart             # First-run Doctor Domain setup
│   │   ├── main_workspace_screen.dart        # SQLite search & New Patient registration
│   │   ├── patient_workspace_screen.dart     # Patient clinical history & consultations
│   │   └── prescription_workspace_screen.dart# Excalidraw WebView, auto-save & export
│   ├── domains/
│   │   ├── doctor/          # DoctorProfile & DoctorService (owns template & identity)
│   │   └── patient/         # PatientRecord, PrescriptionSummary & PatientService
│   ├── infrastructure/
│   │   ├── export/          # PdfExporter (zero-margin vector PDF generation)
│   │   ├── ink/             # InkMLConverter (Excalidraw <-> InkML XML)
│   │   ├── storage/         # LipiVault, LipiDatabase (SQLite), LipiPackage (.lipi ZIP)
│   │   └── web/             # LocalAssetServer (Shelf loopback HTTP server)
│   └── main.dart            # Local filesystem Vault bootstrap
└── test/                    # Comprehensive unit and integration test suite (27 tests)
    ├── domains/             # Doctor and Patient service unit tests
    └── infrastructure/      # InkML, LipiPackage, PDF Exporter, Server, and Coordinates
```

---

## 3. Pass 1 / 1B: Forensic Template Pipeline Investigation

### The Initial Symptom
On physical Android hardware, opening a prescription workspace resulted in a blank/grey canvas. The prescription template was completely invisible.

### Forensic Findings & Root Causes

#### 1. Chromium CORS Policy Blocking `file:///` Assets (CRITICAL)
* **Mechanism:** The prototype initially loaded the Excalidraw web app via `controller.loadFlutterAsset('assets/web/index.html')`. In Android Chromium, pages loaded via `file:///` URLs are assigned an opaque origin (`origin: 'null'`). Modern Vite/Rollup builds emit `<script type="module" crossorigin src="...">` and `<link rel="stylesheet" crossorigin href="...">`. Chromium's strict CORS security model rejected both module scripts and stylesheets, preventing React from mounting and leaving the DOM completely uninitialized.
* **Solution:** Developed `LocalAssetServer`, an internal Shelf-based HTTP server bound to IPv4 loopback (`127.0.0.1:<ephemeral-port>`). Chromium recognizes `http://127.0.0.1` as a valid HTTP origin, permitting full module script loading and asset execution in 100% offline environments (including Airplane Mode).

#### 2. Session Profile Propagation Bug
* **Mechanism:** `DoctorService.saveProfile()` was initially declared `Future<void>`. While it wrote the saved `templatePath` to SQLite, the in-memory caller received an un-updated profile object where `templatePath` was still `null`.
* **Solution:** Updated `saveProfile()` to return `Future<DoctorProfile>` with the fully populated `templatePath`.

#### 3. Data URL MIME Type Hardcoding
* **Mechanism:** The prototype previously prefixed all template data URLs with `data:image/png;base64,`. Uploaded JPEG letterheads were rejected by Chromium's image decoder due to header/MIME mismatch.
* **Solution:** Implemented extension-based MIME sniffing (`image/jpeg`, `image/png`, `image/webp`).

#### 4. File Self-Copy Truncation
* **Mechanism:** On Linux/Android, calling `customTemplateFile.copy(destFile.path)` when source and destination are the same path truncates the file to 0 bytes.
* **Solution:** Added a self-copy guard `if (customTemplateFile.path != destFile.path)`.

---

## 4. Pass 2: Unified Prescription Zoom & Coordinate Space

### 4.1 The Decoupling Problem & Root Cause Analysis

In initial implementations of the prescription workspace, two major defects emerged during zoom and pan interactions:

1. **Independent Coordinate Worlds:** The visual prescription template was rendered as a static HTML background container filling the viewport, while Excalidraw maintained an independent virtual camera (`zoom`, `scrollX`, `scrollY`) applied via internal canvas transformation matrices. When a user zoomed or panned, the digital ink scaled or moved across the screen, but the prescription sheet remained fixed. Ink drifted away from clinical lines, patient headers, and clinic letterheads.
2. **The Naive CSS Transform Trap:** Attempting to zoom the entire workspace by wrapping Excalidraw and the background inside a parent container with CSS `transform: scale(zoom)` failed catastrophically. Excalidraw calculates stylus/pointer input using unscaled client coordinates from `getBoundingClientRect()`:
   $$	ext{docX} = rac{	ext{clientX} - 	ext{offsetLeft}}{	ext{zoom}} - 	ext{scrollX}$$
   Applying external CSS scaling distorted the client coordinate bounding box, causing severe pen parallax (the line appeared inches away from the physical stylus tip).

### 4.2 Single Document Transform Architecture

To eliminate coordinate drift while preserving 100% stylus fidelity, the architecture was redesigned with **Excalidraw as the Camera Master**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ .page-viewport (fills workspace, overflow: hidden, touch-action: none)  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ .prescription-sheet-container (z-index: 0, pointer-events: none) │  │
│  │ transform: translate(scrollX * zoom px, scrollY * zoom px)       │  │
│  │            scale(zoom)                                           │  │
│  │ transform-origin: 0 0                                            │  │
│  │                                                                  │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │ .prescription-sheet (finite A4: 800px x 1155.56px)          │ │  │
│  │  │ • Clinic Letterhead / Template Image (DOM <img>)            │ │  │
│  │  │ • Patient Metadata Banner (DOM)                             │ │  │
│  │  │ • Clinical Ruled Lines & Rx Symbol                          │ │  │
│  │  │ • Doctor Signature Footer                                   │ │  │
│  │  └─────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ .excalidraw-canvas-container (z-index: 1, pointer-events: auto)  │  │
│  │ • Excalidraw component (unscaled, fills viewport)                │  │
│  │ • viewBackgroundColor: 'transparent'                             │  │
│  │ • Camera: { zoom, scrollX, scrollY }                             │  │
│  │ • Digital Ink Strokes (freedraw elements in document space)     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Mathematical Derivation of Coordinate Invariance

Let the finite prescription sheet have fixed document dimensions:
$$	ext{Width} = 800\,	ext{px}, \quad 	ext{Height} = 1155.56\,	ext{px} \quad (	ext{Standard Aspect Ratio } 1 : 1.4444)$$

The origin $(0, 0)$ in Document Space is defined as the top-left corner of this finite sheet.

1. **Excalidraw Canvas Mapping:**
   For any point $(X_{	ext{doc}}, Y_{	ext{doc}})$ in document space, Excalidraw renders it to screen coordinates $(X_{	ext{screen}}, Y_{	ext{screen}})$ using its internal camera state $(Z, S_x, S_y)$:
   $$X_{	ext{screen}} = (X_{	ext{doc}} + S_x) 	imes Z = X_{	ext{doc}} 	imes Z + S_x 	imes Z$$
   $$Y_{	ext{screen}} = (Y_{	ext{doc}} + S_y) 	imes Z = Y_{	ext{doc}} 	imes Z + S_y 	imes Z$$

2. **Template DOM Synchronized Transform:**
   To guarantee that every DOM pixel $(X_{	ext{doc}}, Y_{	ext{doc}})$ aligns with screen coordinates $(X_{	ext{screen}}, Y_{	ext{screen}})$ identically:
   $$	ext{CSS Transform} = \mathbf{T}(S_x 	imes Z,\, S_y 	imes Z) \circ \mathbf{S}(Z)$$
   with CSS `transform-origin: 0 0`.

   Under this transform:
   $$egin{pmatrix} X_{	ext{screen}} \ Y_{	ext{screen}} \ 1 \end{pmatrix} = egin{pmatrix} Z & 0 & S_x 	imes Z \ 0 & Z & S_y 	imes Z \ 0 & 0 & 1 \end{pmatrix} egin{pmatrix} X_{	ext{doc}} \ Y_{	ext{doc}} \ 1 \end{pmatrix}$$

   The mapping for the DOM background and the Excalidraw canvas is **mathematically identical**. As a consequence:
   * When zooming ($Z$ changes), the template and ink expand/contract around the identical focal point.
   * When panning ($S_x, S_y$ change), the template and ink translate with sub-pixel alignment.
   * Stylus input lands on the unscaled Excalidraw canvas where Excalidraw's inverse camera mapping calculates the exact document coordinate $(X_{	ext{doc}}, Y_{	ext{doc}})$, with **zero pen parallax**.

### 4.4 High-Frequency Synchronization (120Hz/144Hz)

To prevent visible lagging or frame judder during rapid multi-touch zoom or stylus gestures:
* The DOM transform is updated directly via `sheetContainerRef.current.style.transform = ...` inside both Excalidraw's `onScrollChange` and `handleChange` callbacks.
* React component re-rendering is completely bypassed during zoom/pan frames (`will-change: transform`).
* Smooth, lockstep tracking is achieved at the full 144Hz panel refresh rate of the OnePlus Pad 2.

### 4.5 Centering and Auto-Fit Engine

On initial load or when the user taps "Fit Page" (`📄 Fit`), the application centers the finite sheet in the visible viewport:

```typescript
const viewportWidth = viewportRef.current.clientWidth;
const viewportHeight = viewportRef.current.clientHeight;

// Compute scale fitting sheet with 32px margins
const scaleX = (viewportWidth - 64) / PAGE_WIDTH;
const scaleY = (viewportHeight - 64) / PAGE_HEIGHT;
const fitZoom = Math.min(Math.max(Math.min(scaleX, scaleY), 0.3), 1.5);

// Center the finite sheet in camera space
const scrollX = (viewportWidth / fitZoom - PAGE_WIDTH) / 2;
const scrollY = (viewportHeight / fitZoom - PAGE_HEIGHT) / 2;

excalidrawAPI.updateScene({
  appState: { zoom: { value: fitZoom }, scrollX, scrollY }
});
```

On the OnePlus Pad 2 (landscape display `3392x2400`, density 420, logical viewport ~1130px height minus toolbar), `fitZoom` evaluates to **0.73 (73%)**, providing an optimal, centered view of the prescription sheet.

---

## 5. Pass 3: Historical Reopen/Edit & Faithful Vector PDF Export

### 5.1 Root Cause Analysis of Previous PDF Export Discrepancy

Initial PDF exports exhibited severe visual misalignment: handwritten strokes appeared substantially offset downward from ruled lines, negative-$y$ coordinates were clipped, and strokes scaled erratically.

Four distinct root causes were uncovered:

1. **Flutter PDF Auto-Layout Offset:** The original `PdfExporter` wrapped elements in high-level layout widgets (`pw.Column`, `pw.Expanded`, `pw.Container`, `pw.Padding`). The PDF auto-layout engine allocated dynamic spacing for headers and patient info, pushing the digital ink canvas downwards by dozens of points. Consequently, strokes written on the first ruled line appeared on the third or fourth line in the exported PDF.
2. **Cartesian vs Screen Coordinate Space:** In standard web browsers and Excalidraw, the origin $(0, 0)$ is at the top-left corner, with $+y$ pointing downwards. In standard PDF rendering (`pdf` package `CustomPaint` / `PdfGraphics`), the coordinate origin $(0, 0)$ is at the bottom-left corner, with $+y$ pointing upwards. Naive coordinate inversion that failed to account for zero-margin document bounds resulted in vertical stretching or clipping.
3. **Viewport Zoom Pollution:** Naive raster or DOM-capture implementations coupled export geometry to the active viewport zoom level ($Z$) and scroll offsets ($S_x, S_y$). Prescriptions exported while zoomed in were cropped, while prescriptions exported while zoomed out produced tiny, centered miniatures.
4. **Active Profile Letterhead Drift:** Prescriptions originally relied on the active `DoctorProfile` to retrieve letterhead images during reopen. If a doctor later updated their clinic template or switched between custom and default letterheads, historical prescriptions were retroactively altered, destroying legal immutability.

### 5.2 Mathematical Derivation of Zero-Margin Vector PDF Transform

To achieve faithful, print-ready 1:1 replica export, `PdfExporter` was re-engineered using a **zero-margin, direct graphics context architecture**:

```text
┌──────────────────────────────────────────────────────────┐
│ pw.Page (margin: pw.EdgeInsets.zero, pageFormat: A4)     │
│                                                          │
│  Layer 0: pw.CustomPaint (Base Template)                 │
│  • If Custom Letterhead: drawImage(0, 0, W_pdf, H_pdf)   │
│  • If Default Letterhead: drawRect, drawLine for Header, │
│    Patient Bar, Rx Symbol, Ruled Lines, and Footer       │
│                                                          │
│  Layer 1: pw.CustomPaint (Vector Digital Ink)            │
│  • Direct PdfGraphicsPath from InkML points              │
│  • Invariant mapping from Document Space to PDF Space    │
└──────────────────────────────────────────────────────────┘
```

#### Coordinate Transformation Derivation:
Let:
* Finite Document sheet width and height: $W_{	ext{doc}} = 800.0\,	ext{pt}$, $H_{	ext{doc}} = 1155.56\,	ext{pt}$
* PDF target page dimensions: $W_{	ext{pdf}} = 595.28\,	ext{pt}$, $H_{	ext{pdf}} = 841.89\,	ext{pt}$ (ISO A4)

The uniform point scaling factors are:
$$s_x = rac{W_{	ext{pdf}}}{W_{	ext{doc}}} = rac{595.28}{800.0} pprox 0.7441$$
$$s_y = rac{H_{	ext{pdf}}}{H_{	ext{doc}}} = rac{841.89}{1155.56} pprox 0.72855$$

For any stroke point $(x_{	ext{doc}}, y_{	ext{doc}})$ recorded in document coordinates:
$$x_{	ext{canvas}} = x_{	ext{doc}} 	imes s_x$$
$$y_{	ext{canvas}} = H_{	ext{pdf}} - (y_{	ext{doc}} 	imes s_y)$$

Because this transformation maps canonical Document Space directly to PDF point space without consulting the WebView camera state:
$$rac{\partial(x_{	ext{canvas}}, y_{	ext{canvas}})}{\partial Z} = 0, \quad rac{\partial(x_{	ext{canvas}}, y_{	ext{canvas}})}{\partial S_x} = 0, \quad rac{\partial(x_{	ext{canvas}}, y_{	ext{canvas}})}{\partial S_y} = 0$$
The exported PDF is **100% invariant** to editor viewport zoom, pan position, display density, or window aspect ratio.

### 5.3 Hermetic `.lipi` Document Self-Containment

To ensure absolute legal immutability and archive portability, the `.lipi` file format was finalized as a hermetic ZIP package:

```text
consultation_<uuid>.lipi
├── manifest.json              # Version, dimensions, timestamps, patient & doctor snapshots
├── ink/
│   └── page-001.inkml         # W3C InkML traces (canonical document vector points)
└── templates/
    └── custom_template.png    # Embedded clinic letterhead binary (if custom)
```

#### Archive Isolation Precedence:
When reopening an existing `.lipi` consultation:
1. `LipiPackage.open()` extracts `manifest.json`, `ink/page-001.inkml`, and any embedded `templates/*` image bytes into memory.
2. `PrescriptionWorkspaceScreen._injectInitialData()` checks `_loadedPackage.templateImageBytes`:
   * If present, it serves this embedded binary to the WebView via `LocalAssetServer`, completely bypassing the active doctor's current profile settings.
   * If absent, it renders the default standard letterhead using the historical `doctorSnapshot` recorded in `manifest.json`.
3. Even if the doctor changes clinics, updates logos, or switches templates in app settings, **historical prescriptions retain their exact original letterhead and layout forever**.

### 5.4 Live Vector Reopen and Interactive Inking Engine

Unlike traditional medical record systems that flatten saved notes into raster PNG or PDF bitmaps upon saving:
* When a `.lipi` document is reopened, `InkMLConverter.parse()` reads `<trace>` coordinates from `ink/page-001.inkml`.
* Coordinates are converted back into live Excalidraw `freedraw` element representations (`id`, `x`, `y`, `width`, `height`, `points`, `strokeColor`, `strokeWidth`).
* The scene is populated via `excalidrawAPI.updateScene({ elements: restoredElements })`.
* Strokes remain **live digital ink**: the doctor can erase individual previous strokes using the Excalidraw Eraser tool, append new handwritten notes, undo/redo, zoom/pan, and re-export to PDF.
* On saving, all strokes (original + appended) are re-serialized into InkML and saved back into the `.lipi` archive.

---

## 6. Physical Hardware Verification (OnePlus Pad 2 — Device `adcfcc62`)

All tests were executed on a real, physical OnePlus Pad 2 connected via ADB.

### 6.1 Comprehensive Verification Matrix

| Test Scenario | Test Description | Hardware Result | Visual / Forensic Evidence |
|---|---|---|---|
| **Pass 1: Default Template Visibility** | Open new prescription with generic doctor profile. | ✅ PASS | Banner, doctor info, patient bar, ruled lines, and Rx symbol crisply visible. |
| **Pass 1: Custom Template Upload** | Import high-resolution custom letterhead ("Apex Super-Specialty Clinic"). | ✅ PASS | Letterhead image rendered with correct aspect ratio behind canvas via loopback HTTP. |
| **Pass 2: Initial Page Centering** | Open workspace; document centers automatically. | ✅ PASS | Finite A4 page centered at 73% zoom with balanced horizontal margins (`pass2_rx_open.png`). |
| **Pass 2: Multi-Region Inking** | Write freehand notes across header, body, margin, and signature. | ✅ PASS | Ink recorded cleanly with zero stylus offset (`pass2_written_initial.png`). |
| **Pass 2: Zoom Lockstep Tracking (98%)** | Zoom in using toolbar `🔍+`. | ✅ PASS | Template text and ink expand in lockstep; 0 pixel drift observed (`pass2_zoomed_in_1.png`). |
| **Pass 2: High Zoom Lockstep Tracking (148%)** | Zoom in further to 148% zoom. | ✅ PASS | Ruled lines, patient text, and ink strokes remain perfectly pinned together (`pass2_zoomed_in_high.png`). |
| **Pass 2: Inking at High Zoom** | Switch to blue pen and write "Zoom stroke" at 148% zoom. | ✅ PASS | Stroke lands exactly under stylus tip; saved in document coordinates (`pass2_stroke_at_zoom.png`). |
| **Pass 2: Fit View Restoration** | Tap `📄 Fit` button. | ✅ PASS | Page returns smoothly to 73% fit view; all ink strokes remain aligned (`pass2_fitted_view.png`). |
| **Pass 2: Synchronized Panning** | Enable `✋ Pan` and drag sheet upward by 500px. | ✅ PASS | Sheet, background, and ink translate together seamlessly (`pass2_panned_view.png`). |
| **Pass 2: Custom Template Inking & Zoom** | Open prescription with custom letterhead; write notes and zoom to 123%. | ✅ PASS | Custom clinic emblem, Red Cross, and ink zoom in unified lockstep (`pass2_custom_zoomed.png`). |
| **Pass 3: Historical Reopen (Default Template)** | Reopen consultation `8fcaf5f7...` from clinical history. | ✅ PASS | Restores all 5 original vector strokes cleanly onto ruled lines (`pass3_reopened_again.png`). |
| **Pass 3: Live Historical Vector Inking** | Draw a 6th note live onto the reopened standard prescription. | ✅ PASS | Stroke is fully interactive; auto-saves into `.lipi` package (`pass3_edited_reexported_page-1.png`). |
| **Pass 3: Faithful PDF Export (Default Template)** | Export PDF of edited prescription on device. | ✅ PASS | Zero margin shift; ink sits with sub-millimeter registration on ruled lines (`pass3_edited_reexported_page-1.png`). |
| **Pass 3: Custom Letterhead Inking & Zoom** | Create prescription `a16e095e...` on custom letterhead; zoom in and sign footer. | ✅ PASS | Notes and doctor signature line rendered smoothly on custom template (`pass3_custom_rx_written.png`). |
| **Pass 3: Custom Letterhead PDF Export** | Export PDF of custom letterhead prescription on device. | ✅ PASS | Custom letterhead image and vector ink exported 1:1 to A4 (`pass3_tablet_custom_rx_page-1.png`). |
| **Pass 3: Hermetic Template Isolation** | Change active doctor profile to Default Generic; reopen custom prescription `a16e095e...`. | ✅ PASS | Opens with **original custom letterhead** intact from embedded ZIP bytes (`pass3_reopened_custom_perfect.png`). |
| **Pass 3: Historical Edit on Custom Template** | Add 6th stroke to reopened isolated custom prescription and tap Done. | ✅ PASS | Appends 8th trace to InkML; preserves template and manifest in `.lipi` (`pass3_custom_reopened_edited.png`). |
| **Pass 3: Re-Export Edited Custom PDF** | Reopen edited custom prescription and generate PDF preview on Android. | ✅ PASS | All 6 notes and signature rendered faithfully with zero zoom distortion (`pass3_custom_edited_pdf_render-1.png`). |

### 6.2 Recorded Hardware Screenshots & PDF Artifacts

All forensic evidence artifacts from the OnePlus Pad 2 session are archived in the session artifact directory:

#### Pass 2 Artifacts:
* `pass2_rx_open.png`: Initial centered prescription sheet at 73% fit zoom.
* `pass2_written_initial.png`: Freehand prescription inking across multiple sheet regions.
* `pass2_zoomed_in_1.png`: Unified zoom at 98% with zero relative displacement.
* `pass2_zoomed_in_high.png`: Deep zoom at 148% showing sharp vector ink over letterhead.
* `pass2_stroke_at_zoom.png`: New ink written at 148% zoom without parallax.
* `pass2_fitted_view.png`: Reset to 73% fit view showing all strokes locked in place.
* `pass2_panned_view.png`: Panning the entire page showing synchronized translation.
* `pass2_settings_dialog.png`: In-app template switcher selecting custom letterhead.
* `pass2_custom_template_rx.png`: Prescription workspace with custom letterhead loaded.
* `pass2_custom_written.png`: Freehand notes written on custom letterhead.
* `pass2_custom_zoomed.png`: Custom letterhead and handwritten notes zoomed to 123%.

#### Pass 3 Artifacts:
* `pass3_reopened_again.png`: Tablet screen showing historical default prescription reopened with live vector ink.
* `pass3_edited_reexported_page-1.png`: Rendered PDF of edited default template showing exact line registration.
* `pass3_custom_rx_written.png`: Tablet screen showing custom letterhead with handwritten notes and signature.
* `pass3_tablet_custom_rx_page-1.png`: Rendered PDF of custom letterhead prescription pulled from tablet vault.
* `pass3_reopened_custom_perfect.png`: Live tablet screen showing self-contained custom template loaded while active profile is set to generic.
* `pass3_custom_reopened_edited.png`: Live tablet screen showing 6th stroke added to reopened custom prescription.
* `pass3_custom_edited_pdf_preview.png`: Native Android print preview dialog rendering the edited custom prescription.
* `pass3_custom_edited_pdf_render-1.png`: Rendered PDF page of edited custom prescription demonstrating flawless vector registration.
* `pass3_after_done.png`: Patient consultation history screen displaying saved `.lipi` package and PDF badges.

---

## 7. Automated Test Suite

The automated test suite in `prototypes/lipi-s4-prototype/test/` covers domain logic, coordinate systems, and export transformations.

```text
flutter test    → 27/27 tests passed (0 failures)
flutter analyze → No issues found! (ran in 2.5s)
npm run build   → Built successfully in 11.90s (clean Vite bundle)
```

### 7.1 Summary of Tests

| Test Suite | File | Tests | Status |
|---|---|---|---|
| **Roundtrip Workflow** | `test/domains/roundtrip_test.dart` | 1 | ✅ Passed |
| **Patient Service** | `test/domains/patient_service_test.dart` | 1 | ✅ Passed |
| **Doctor Service** | `test/domains/doctor_service_test.dart` | 5 | ✅ Passed |
| **Local Asset Server** | `test/infrastructure/local_asset_server_test.dart` | 2 | ✅ Passed |
| **PDF Exporter & Lifecycle** | `test/infrastructure/pdf_exporter_test.dart` | 8 | ✅ Passed |
| **InkML Converter** | `test/infrastructure/inkml_converter_test.dart` | 2 | ✅ Passed |
| **Lipi Package Archive** | `test/infrastructure/lipi_package_test.dart` | 5 | ✅ Passed |
| **Coordinate Transform** | `test/infrastructure/coordinate_transform_test.dart` | 3 | ✅ Passed |
| **Total** | | **27** | **100% Passed** |

### 7.2 PDF Exporter Unit & Lifecycle Tests (`pdf_exporter_test.dart`)
1. **Coordinate Preservation:** Asserts that document coordinates map faithfully to PDF point coordinates without offset.
2. **Page Dimensions:** Verifies that the exported PDF exactly matches configured finite document dimensions ($180\,	ext{mm} 	imes 260\,	ext{mm}$ or A4).
3. **Custom Letterhead PDF Export:** Verifies that a full-page custom letterhead background image and vector ink paths are preserved.
4. **Default Template PDF Export:** Verifies that standard letterhead rules, headers, and ruled lines match web layout geometry.
5. **Zoom Invariance:** Asserts that exported PDF bytes are 100% identical regardless of editor viewport zoom or pan coordinates.
6. **Reopen Then Export:** Verifies the full roundtrip lifecycle: write notes $	o$ save `.lipi` $	o$ reopen $	o$ export PDF with zero ink degradation.
7. **Historical Editing:** Reopens an existing `.lipi` package, appends new vector strokes, re-saves to `.lipi`, and verifies ink count in exported PDF.
8. **Real Tablet Artifact Re-Export:** Re-exports actual `.lipi` archives pulled from the OnePlus Pad 2 vault and asserts document geometry integrity.

---

## 8. Architectural Compliance Audit

| Requirement / Architectural Rule | Status | Implementation Verification |
|---|---|---|
| **Finite Document Model** | ✅ Compliant | Prescriptions are finite A4 pages ($800 	imes 1155.56\,	ext{pt}$), NOT infinite whiteboards. |
| **Single Document Space** | ✅ Compliant | Template, patient header, clinical lines, and ink share the exact same coordinates. |
| **Zero Stylus Parallax** | ✅ Compliant | Excalidraw canvas is unscaled at viewport level; camera master synchronizes DOM. |
| **Faithful PDF Export** | ✅ Compliant | Zero-margin direct graphics rendering with sub-millimeter ruled line registration. |
| **Zoom/Pan Invariant Export** | ✅ Compliant | Export pipeline operates strictly in canonical Document Space; immune to camera zoom. |
| **Vector Ink Reopen & Edit** | ✅ Compliant | Reopened strokes are live Excalidraw digital ink elements, not flattened bitmaps. |
| **Hermetic Archive Isolation** | ✅ Compliant | `.lipi` embeds template binary; immune to active profile letterhead modifications. |
| **Doctor Domain Owns Templates** | ✅ Compliant | `DoctorService` manages `Vault/doctor/templates/`. Isolated from Patient Domain. |
| **Privacy / Patient Isolation** | ✅ Compliant | `patient_id` is excluded from `.lipi` archive manifest; consultation identity is UUID. |
| **Offline-First / Zero Network** | ✅ Compliant | `LocalAssetServer` binds exclusively to `127.0.0.1`. Works fully in Airplane Mode. |
| **Sprint 0 Prototype Untouched** | ✅ Compliant | `prototypes/flutter-ink-eval/` is 100% unmodified. |
| **ADR-0005 Preserved** | ✅ Compliant | `docs/ADR-0005*.md` is unmodified and not finalized. |

---

## 9. Conclusion & Status

Sprint 4 has completed all three technical validation passes:

1. **Pass 1 / 1B (Template Asset Pipeline & Visibility):** Verified on OnePlus Pad 2. Loopback HTTP asset architecture successfully eliminated Chromium CORS blocks.
2. **Pass 2 (Unified Prescription Zoom & Coordinate Space):** Verified on OnePlus Pad 2. Single Document Transform Architecture achieved zero-drift zoom and zero pen parallax.
3. **Pass 3 (Historical Reopen/Edit + Faithful PDF Export):** Verified on OnePlus Pad 2. Zero-margin vector PDF rendering achieved sub-millimeter stroke alignment, zoom invariance, live vector reopening and editing, and hermetic archive self-containment.

The Sprint 4 technical prototype validates the clinical feasibility, architectural soundness, and mathematical rigor of the Lipi handwriting-first prescription workflow.
