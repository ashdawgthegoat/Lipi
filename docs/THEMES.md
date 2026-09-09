# Lipi Theme Specification & Customization Guide

## 1. Architectural Philosophy & Boundaries

Lipi is a mission-critical clinical digital ink workspace. In accordance with **ADR-0001 through ADR-0008**, user themes are strictly **presentation-only**.

### Non-Negotiable Guarantees
- **Zero Clinical Semantic Impact**: Themes never modify prescription data, ink coordinates, stroke fidelity, patient records, or metadata.
- **Data Integrity Preservation**: Themes have zero access to the encrypted Vault, SQLite database, cryptographic key stores, or `.lipi` bundle serialization.
- **Fail-Closed Security**: Any invalid, malformed, or hostile theme package is rejected immediately, safely falling back to the default `vista-light` theme without crashing.
- **Execution Sandboxing**: Themes are pure declarative configuration. Executable scripts (`.js`, `.dart`, `.sh`, `.exe`), bytecode, and external network requests are strictly forbidden.

---

## 2. Built-in Themes

Lipi ships with two carefully crafted, light-oriented themes:

### 1. `vista-light` (Default)
- **Aesthetic**: Vista/Aero-inspired styling with soft slate blues, gently rounded cards and controls, subtle border definitions, and clean modern clinical typography.
- **Prescription Sheet**: Renders on a cool grey desk background (`#D6E2EE`) with a pure white paper sheet.
- **Ideal For**: Everyday clinical consultations on high-resolution tablet screens.

### 2. `sixteen-bit-light`
- **Aesthetic**: Retro 16-bit OS styling featuring warm light grey surfaces (`#ECECEC`), dark chunky pixel/beveled borders (`#262626`, 2px width), classic window titlebars, and crisp 90s OS accents.
- **Prescription Sheet**: Sits on a classic desk grey viewport (`#B8BCC0`) while ensuring the clinical paper surface remains immaculate white (`#FFFFFF`) for legibility.
- **Ideal For**: Nostalgic, distraction-free clinical writing with high contrast and sharp window boundaries.

---

## 3. Sandboxed Storage Directory

Custom themes are isolated in the application's sandboxed document storage:

```text
<appDocumentsDirectory>/themes/
├── active_theme.json               # Persisted user choice (e.g. {"activeThemeId": "vista-light"})
└── custom/
    ├── retro-paper/
    │   └── theme.json
    └── emerald-clinic/
        └── theme.json
```

---

## 4. `theme.json` Schema (v1.0)

Every theme package is defined by a `theme.json` root manifest:

```json
{
  "$schema": "https://lipi.app/schemas/theme-v1.json",
  "id": "my-custom-theme",
  "name": "My Custom Theme",
  "version": "1.0",
  "author": "Dr. Jane Doe",
  "description": "A soft mint and cream clinical workspace theme.",
  "styleType": "modern",
  "colors": {
    "primary": "#0D9488",
    "primaryContainer": "#CCFBF1",
    "surface": "#FFFFFF",
    "surfaceVariant": "#F0FDF4",
    "background": "#F5F7FA",
    "onPrimary": "#FFFFFF",
    "onSurface": "#134E4A",
    "border": "#CBD5E1",
    "appBarBg": "#115E59",
    "appBarFg": "#FFFFFF",
    "accent": "#F59E0B",
    "canvasBg": "#E6F4EA",
    "paperBg": "#FFFFFF",
    "sliderBg": "#E0F2FE",
    "error": "#D93025",
    "success": "#107C10",
    "warning": "#FBBC04",
    "mutedText": "#7B8FA4",
    "inputBg": "#F7F9FC",
    "selectedBg": "#D6E8F7"
  },
  "shapes": {
    "borderRadius": 8.0,
    "cardBorderRadius": 8.0,
    "buttonBorderRadius": 6.0,
    "borderWidth": 1.0
  }
}
```

### Property Reference

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `id` | string | Yes | Unique identifier containing only alphanumeric characters, underscores, and hyphens (`^[a-zA-Z0-9_-]+$`). Cannot overwrite `vista-light` or `sixteen-bit-light`. |
| `name` | string | Yes | Human-readable title displayed in the Theme Selector. |
| `version` | string | Yes | Must be `"1.0"`. |
| `author` | string | No | Creator name or organization. |
| `description` | string | No | Short overview of the theme's visual aesthetic. |
| `styleType` | string | No | `"vista"`, `"retro16bit"`, or `"modern"`. Governs elevation and button corners. |
| `colors.primary` | string | Yes | Main clinical action and active tool color (`#RRGGBB` or `#AARRGGBB`). |
| `colors.surface` | string | Yes | Surface color for toolbars, dialogs, and workspace cards. |
| `colors.background` | string | Yes | Outer background of Flutter application screens. |
| `colors.onPrimary` | string | Yes | Text/icon color placed on top of `primary`. |
| `colors.onSurface` | string | Yes | Primary body text color. |
| `colors.border` | string | Yes | Divider, toolbar border, and card outline color. |
| `colors.appBarBg` | string | Yes | Top navigation app bar background. |
| `colors.appBarFg` | string | Yes | Top navigation app bar title and icon color. |
| `colors.canvasBg` | string | Yes | Prescription page viewport desk background surrounding the document. |
| `colors.paperBg` | string | Yes | Background of the prescription page sheet (must remain light/white). |
| `colors.error` | string | No | Color for destructive/error states. |
| `colors.success` | string | No | Color for success states. |
| `colors.warning` | string | No | Color for warning states. |
| `colors.mutedText` | string | No | Color for secondary/muted text. |
| `colors.inputBg` | string | No | Background color for input fields. |
| `colors.selectedBg` | string | No | Background color for selected items. |
| `colors.folderBg` | string | No | Interior background color for patient record folders. |
| `colors.folderTabBg` | string | No | Tab header background color for patient folders. |
| `colors.folderBorder` | string | No | Outline border color for patient folders. |
| `shapes.borderRadius` | number | Yes | Corner radius for input fields, dialogs, and widgets. |
| `shapes.borderWidth` | number | Yes | Stroke width for card and toolbar outlines (e.g. `1.0` for modern, `2.0` for retro). |

---

## 5. Security & Validation Rules

Theme validation is enforced by `ThemeValidator`:
1. **Schema Check**: All required color keys must exist and match valid 6-hex or 8-hex format.
2. **Prohibited Executables**: Theme packages cannot contain any `.exe`, `.sh`, `.bat`, `.cmd`, `.js`, `.mjs`, `.dart`, `.so`, `.dll`, `.apk`, `.jar`, `.py`, or `.bin` files.
3. **Path Traversal Protection**: Any file entries with `..`, absolute root paths, or directory escapes are rejected.
4. **Protected Built-ins**: Built-in themes (`vista-light` and `sixteen-bit-light`) cannot be overwritten, replaced, or deleted.

---

## 6. Step-by-Step Creation Guide

### Method A: Import via Lipi UI
1. Copy the template below into a text editor.
2. Customize your hex colors and shape radii.
3. Save the file as `my_theme.json`.
4. In Lipi, tap the **Palette Icon** (🎨) in the top right of the Main Workspace.
5. Tap **Import Theme (.json)** and pick your file.
6. The theme is validated, sandboxed, and applied immediately!

### Method B: Copy-Paste Template for Users & AI Models

```json
{
  "id": "warm-parchment",
  "name": "Warm Parchment",
  "version": "1.0",
  "author": "Clinical Designer",
  "description": "A warm, sepia-tinted clinical aesthetic with softened contrast.",
  "styleType": "modern",
  "colors": {
    "primary": "#8C5E3C",
    "primaryContainer": "#F3E9DF",
    "surface": "#FFFDF9",
    "surfaceVariant": "#F7F2EA",
    "background": "#EFE8DC",
    "onPrimary": "#FFFFFF",
    "onSurface": "#2D241E",
    "border": "#D8CDBC",
    "appBarBg": "#3E2E20",
    "appBarFg": "#FAF7F2",
    "accent": "#C47C48",
    "canvasBg": "#E5DDD0",
    "paperBg": "#FFFFFF",
    "sliderBg": "#E8DFD3"
  },
  "shapes": {
    "borderRadius": 6.0,
    "cardBorderRadius": 6.0,
    "buttonBorderRadius": 4.0,
    "borderWidth": 1.0
  }
}
```
