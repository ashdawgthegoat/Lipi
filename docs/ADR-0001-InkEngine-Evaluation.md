# Sprint 0 Report — Handwriting Engine Evaluation

## Objective

Determine the most suitable open-source handwriting foundation for Project Lipi by building and evaluating working prototypes instead of relying solely on documentation or community opinion.

---

## Prototypes Evaluated

### Prototype A
**Technology:** Perfect Freehand (React + TypeScript + Vite)

**Summary**

- Excellent handwriting experience.
- Best pressure sensitivity among all evaluated candidates.
- Stable implementation.
- SVG export works reliably.
- Required significant custom engineering for navigation, gestures and tooling.

---

### Prototype B
**Technology:** Excalidraw (React + TypeScript + Vite)

**Summary**

- Excellent handwriting experience.
- Mature navigation system.
- Rich built-in tooling.
- Stable implementation.
- SVG export works reliably.
- Required minimal engineering effort compared to Prototype A.

---

### Prototype C
**Technology:** Flutter (Native)

**Summary**

- Smooth handwriting.
- Best zooming and panning experience.
- Stable export.
- Pressure sensitivity weaker than Prototype A.
- Native implementation did not provide a significant handwriting advantage over the web-based approaches.

---

## Major Observations

### 1. Handwriting latency

A small writing latency was observed in **all three prototypes**.

**Conclusion**

The latency is unlikely to be caused by any individual handwriting engine.

---

### 2. Pressure sensitivity

Prototype A demonstrated the strongest pressure response.

Prototype B was slightly weaker but remained suitable.

Prototype C provided the weakest pressure response.

---

### 3. Navigation

Prototype C offered the best navigation experience.

Prototype B was a close second.

Prototype A required custom implementation.

---

### 4. Engineering effort

Prototype A required considerably more custom code.

Prototype B delivered comparable functionality with significantly less engineering effort.

Prototype C introduced additional platform and tooling complexity without providing a proportionate improvement in handwriting quality.

---

## Decision

**Selected handwriting foundation: Excalidraw**

### Rationale

- Excellent handwriting quality.
- Mature and battle-tested codebase.
- Minimal engineering effort.
- Reliable export.
- Excellent navigation.
- Large open-source ecosystem.
- Long-term maintainability.

Although Prototype A achieved slightly better pressure sensitivity, the improvement was not sufficient to justify maintaining a substantially larger custom implementation.

Prototype C demonstrated that a native implementation alone does not guarantee a meaningfully better handwriting experience.

---

## Architectural Decisions

### Native document format

Lipi will define its own editable document format.

Proposed extension:

```
.lipi
```

The `.lipi` file will serve as the canonical editable representation of handwritten notes.

Standard formats such as PDF, SVG and PNG will be treated strictly as export formats.

---

## Future Investigation

- Design the `.lipi` file specification.
- Implement PDF export.
- Investigate improving handwriting latency.
- Evaluate precise (point) eraser support.
- Investigate handwriting texture and stroke rendering.

---

## Sprint Outcome

Sprint 0 successfully established the handwriting foundation for Lipi.

Future development will proceed using Excalidraw as the underlying handwriting engine while Lipi develops its own document model, export pipeline and clinical workflow.