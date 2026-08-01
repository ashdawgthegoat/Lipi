# Perfect Freehand Evaluation

An engineering prototype to evaluate the handwriting quality of [Perfect Freehand](https://github.com/steveruizok/perfect-freehand).

## Setup

```bash
npm install
npm run dev
```

Then open the URL shown in the terminal (typically `http://localhost:5173`).

## Tools

| Tool | Description |
|------|-------------|
| **Pen** | Draw with Perfect Freehand. Supports mouse, touch, and pressure-sensitive stylus. |
| **Eraser** | Remove entire strokes by dragging over them. |
| **Undo / Redo** | Stroke-level history. |
| **Clear** | Remove all strokes. |
| **Export SVG** | Download the canvas as a clean SVG file. |

## Controls

| Action | Input |
|--------|-------|
| Draw | Mouse / Touch / Stylus |
| Erase | Select eraser, then draw over strokes |
| Zoom | `Ctrl+Scroll` / Trackpad pinch |
| Pan | Scroll / Trackpad two-finger drag |
| Undo | `Ctrl+Z` |
| Redo | `Ctrl+Shift+Z` or `Ctrl+Y` |
| Pen tool | `P` |
| Eraser tool | `E` |

## Tuning

Stroke parameters can be adjusted in [`src/utils/stroke.ts`](src/utils/stroke.ts) — the `PEN_OPTIONS` object controls size, thinning, smoothing, streamline, and taper.

## Tech Stack

- **Vite** + **React** + **TypeScript**
- **perfect-freehand** for stroke generation
- **SVG** rendering (vector-based throughout)
- All state in memory — no databases, no networking
