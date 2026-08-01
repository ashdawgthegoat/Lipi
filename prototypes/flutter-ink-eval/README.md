# Flutter Ink Eval

Minimal native Flutter handwriting prototype for performance evaluation.

## Package Selection

**[perfect_freehand](https://pub.dev/packages/perfect_freehand)** v2.5.2+1

Selected because:

- **Purpose-built for natural handwriting** — generates pressure-sensitive freehand
  stroke outlines from raw pointer input, which is exactly what this evaluation needs.
- **Actively maintained** — by Steve Ruiz (creator of tldraw), with consistent
  releases through 2026.
- **Minimal and composable** — provides a pure algorithm (`getStroke`) without
  imposing UI opinions. We retain full control over the rendering pipeline and
  input handling, which is critical for a fair performance evaluation.
- **Pressure-aware** — natively accepts pressure values and gracefully simulates
  pressure when hardware doesn't provide it.
- **Zero platform dependencies** — pure Dart computation. Stroke generation runs
  entirely on the main isolate with no platform channel overhead.

## Architecture

```
lib/
├── main.dart              # App entry point
├── canvas_screen.dart     # Main screen: toolbar, zoom/pan, pointer handling
├── canvas_controller.dart # State: strokes, undo/redo, tool mode, eraser
├── stroke.dart            # Stroke data model wrapping perfect_freehand
├── ink_painter.dart       # CustomPainter rendering stroke outlines
└── svg_exporter.dart      # SVG vector export
```

## Features

| Feature                | Implementation                                        |
|------------------------|-------------------------------------------------------|
| Infinite canvas        | `InteractiveViewer` with 8000×8000 surface             |
| Freehand writing       | `Listener` → raw `PointerEvent` → `perfect_freehand`  |
| Pressure sensitivity   | Native `PointerEvent.pressure` passthrough             |
| Eraser                 | Point-distance hit test against stroke points          |
| Undo / Redo            | Stack-based with full stroke granularity               |
| Two-finger pan         | `InteractiveViewer` multi-touch gesture                |
| Zoom                   | Pinch zoom + button controls                           |
| SVG export             | Stroke outlines → SVG `<path>` elements                |

## Setup

```bash
# Ensure Flutter SDK is on PATH
export PATH="$HOME/.flutter-sdk/bin:$PATH"

# Install dependencies
cd flutter-ink-eval
flutter pub get

# Run on connected Android device
flutter run
```

## Export

SVG files are saved to `/storage/emulated/0/Download/ink_eval_<timestamp>.svg`.

If file access fails, the SVG content is copied to the clipboard.

## Evaluation Notes

This prototype is intentionally minimal. It prioritizes:

1. **Raw input latency** — pointer events are processed directly via `Listener`,
   bypassing `GestureDetector` overhead.
2. **Rendering performance** — `CustomPainter` with filled polygon paths.
3. **Pressure fidelity** — real device pressure is passed through unmodified;
   simulated pressure is used only when hardware reports no pressure data.
4. **Fair comparison** — no framework abstractions beyond what's strictly needed.
   The rendering pipeline is: pointer → stroke model → perfect_freehand → Canvas.drawPath.
