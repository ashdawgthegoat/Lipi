# Excalidraw Handwriting Evaluation (Prototype B)

Engineering prototype to evaluate Excalidraw as a handwriting engine.

## Quick Start

```bash
npm install
npm run dev -- --host
```

## Features

- Infinite canvas with freehand drawing
- Eraser tool
- Undo / Redo
- Zoom controls (built-in)
- Two-finger pan (built-in)
- SVG export (top-right button)

## Architecture

This prototype uses Excalidraw as-is, with minimal configuration:

- `App.tsx` — Wraps the Excalidraw component with handwriting-focused defaults
- `components/ExportButton.tsx` — SVG export via Excalidraw's `exportToSvg`
- `utils/export.ts` — Export utility and file download logic
- `index.css` — Hides shape tools and non-handwriting UI via CSS overrides

## Comparison with Prototype A

| Aspect | Prototype A (Perfect Freehand) | Prototype B (Excalidraw) |
|---|---|---|
| Drawing engine | Perfect Freehand | Excalidraw built-in |
| Rendering | SVG `<path>` | Canvas (HTML5) |
| Pressure support | Real pen pressure | Simulated |
| Canvas navigation | Custom (two-finger pan + zoom buttons) | Built-in (pan, zoom, scroll) |
| Export | Custom SVG serialization | Excalidraw `exportToSvg` |
