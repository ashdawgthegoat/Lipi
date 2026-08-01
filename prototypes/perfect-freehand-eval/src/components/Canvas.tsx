import { useRef, useCallback, useEffect, memo } from 'react';
import type { Stroke, Tool, Camera } from '../types';
import { computePathData, generateStrokeId } from '../utils/stroke';
import { findStrokeAtPoint } from '../utils/hit-test';

interface CanvasProps {
  strokes: Stroke[];
  tool: Tool;
  camera: Camera;
  onAddStroke: (stroke: Stroke) => void;
  onEraseStrokes: (ids: string[]) => void;
  onCameraChange: (camera: Camera) => void;
}

const ERASER_RADIUS = 12;

/** Memoized path element — only rerenders when its path data changes. */
const StrokePath = memo(function StrokePath({
  id,
  pathData,
}: {
  id: string;
  pathData: string;
}) {
  return <path data-stroke-id={id} d={pathData} fill="black" />;
});

/**
 * Full-screen SVG canvas with drawing, erasing, and two-finger pan.
 *
 * Performance strategy:
 *  - Completed strokes are rendered as memoized <path> elements.
 *  - The active (in-progress) stroke is updated via direct DOM manipulation
 *    on a dedicated <path> ref, bypassing React's reconciler entirely.
 *  - Drawing updates are batched per animation frame to avoid redundant
 *    path recomputation when multiple pointermove events fire within one frame.
 *  - The eraser hides strokes via direct style mutation during the gesture,
 *    then commits the batch removal on pointer-up.
 *
 * Gesture model:
 *  - Pen (stylus) always drives draw/erase. Touch pointers are ignored
 *    while a pen gesture is active, preventing finger/palm interference.
 *  - Touch: single finger → draw/erase; two fingers → pan only.
 *  - Zoom is controlled exclusively via UI buttons (no gesture zoom).
 */
export function Canvas({
  strokes,
  tool,
  camera,
  onAddStroke,
  onEraseStrokes,
  onCameraChange,
}: CanvasProps) {
  const svgRef = useRef<SVGSVGElement>(null);
  const activePathRef = useRef<SVGPathElement>(null);
  const eraserCursorRef = useRef<SVGCircleElement>(null);

  // ── Drawing state (refs to avoid rerenders during input) ──
  const isDrawingRef = useRef(false);
  const currentPointsRef = useRef<number[][]>([]);
  const simPressureRef = useRef(true);

  // ── Eraser state ──
  const isErasingRef = useRef(false);
  const erasedIdsRef = useRef(new Set<string>());
  const workingStrokesRef = useRef<Stroke[]>([]);

  // ── Active gesture type (tracks what started, so onUp always matches) ──
  const activeGestureRef = useRef<'draw' | 'erase' | null>(null);
  /** Pointer type ('pen' | 'touch' | 'mouse') that owns the active gesture. */
  const gesturePointerTypeRef = useRef<string | null>(null);

  // ── Multi-touch / pan state ──
  const pointersRef = useRef(
    new Map<number, { x: number; y: number; type: string }>(),
  );
  const isPanningRef = useRef(false);
  const lastPanRef = useRef<{ cx: number; cy: number } | null>(null);

  // ── rAF batching for drawing ──
  const drawRafRef = useRef(0);
  const drawDirtyRef = useRef(false);

  // ── Stable refs so event handlers never go stale ──
  const cameraRef = useRef(camera);
  cameraRef.current = camera;
  const strokesRef = useRef(strokes);
  strokesRef.current = strokes;
  const toolRef = useRef(tool);
  toolRef.current = tool;
  const onAddRef = useRef(onAddStroke);
  onAddRef.current = onAddStroke;
  const onEraseRef = useRef(onEraseStrokes);
  onEraseRef.current = onEraseStrokes;
  const onCamRef = useRef(onCameraChange);
  onCamRef.current = onCameraChange;

  // ── Coordinate conversion ──

  const screenToCanvas = useCallback((sx: number, sy: number) => {
    const c = cameraRef.current;
    return { x: (sx - c.x) / c.zoom, y: (sy - c.y) / c.zoom };
  }, []);

  // ── rAF flush: compute path data and update the DOM path element ──

  const flushDraw = useCallback(() => {
    drawRafRef.current = 0;
    if (!drawDirtyRef.current) return;
    drawDirtyRef.current = false;
    const d = computePathData(
      currentPointsRef.current,
      simPressureRef.current,
    );
    activePathRef.current?.setAttribute('d', d);
  }, []);

  const scheduleDraw = useCallback(() => {
    drawDirtyRef.current = true;
    if (!drawRafRef.current) {
      drawRafRef.current = requestAnimationFrame(flushDraw);
    }
  }, [flushDraw]);

  // ── Drawing ──

  const startDraw = useCallback(
    (e: PointerEvent) => {
      const { x, y } = screenToCanvas(e.clientX, e.clientY);
      const real = e.pointerType === 'pen';
      simPressureRef.current = !real;
      currentPointsRef.current = [[x, y, real ? e.pressure : 0.5]];
      isDrawingRef.current = true;
      activeGestureRef.current = 'draw';
      gesturePointerTypeRef.current = e.pointerType;
      // Immediately flush the first point so there's zero startup delay.
      const d = computePathData(
        currentPointsRef.current,
        simPressureRef.current,
      );
      activePathRef.current?.setAttribute('d', d);
    },
    [screenToCanvas],
  );

  const moveDraw = useCallback(
    (e: PointerEvent) => {
      if (!isDrawingRef.current) return;
      // Use coalesced events to capture all intermediate points the browser
      // batched into this single pointermove. This gives us higher-fidelity
      // input without additional event handler overhead.
      const coalesced = e.getCoalescedEvents?.() ?? [e];
      const events = coalesced.length > 0 ? coalesced : [e];
      const real = e.pointerType === 'pen';
      for (const ce of events) {
        const { x, y } = screenToCanvas(ce.clientX, ce.clientY);
        currentPointsRef.current.push([x, y, real ? ce.pressure : 0.5]);
      }
      scheduleDraw();
    },
    [screenToCanvas, scheduleDraw],
  );

  const endDraw = useCallback(() => {
    if (!isDrawingRef.current) return;
    isDrawingRef.current = false;
    activeGestureRef.current = null;
    gesturePointerTypeRef.current = null;
    // Cancel any pending rAF so we don't double-update.
    if (drawRafRef.current) {
      cancelAnimationFrame(drawRafRef.current);
      drawRafRef.current = 0;
    }
    drawDirtyRef.current = false;
    const points = currentPointsRef.current;
    if (points.length >= 2) {
      const pathData = computePathData(points, simPressureRef.current, true);
      onAddRef.current({
        id: generateStrokeId(),
        points: [...points],
        pathData,
        simulatePressure: simPressureRef.current,
      });
    }
    activePathRef.current?.setAttribute('d', '');
    currentPointsRef.current = [];
  }, []);

  const cancelDraw = useCallback(() => {
    isDrawingRef.current = false;
    activeGestureRef.current = null;
    gesturePointerTypeRef.current = null;
    if (drawRafRef.current) {
      cancelAnimationFrame(drawRafRef.current);
      drawRafRef.current = 0;
    }
    drawDirtyRef.current = false;
    currentPointsRef.current = [];
    activePathRef.current?.setAttribute('d', '');
  }, []);

  // ── Erasing ──

  const startErase = useCallback(
    (e: PointerEvent) => {
      isErasingRef.current = true;
      activeGestureRef.current = 'erase';
      gesturePointerTypeRef.current = e.pointerType;
      erasedIdsRef.current = new Set();
      workingStrokesRef.current = [...strokesRef.current];

      const { x, y } = screenToCanvas(e.clientX, e.clientY);
      const threshold = ERASER_RADIUS / cameraRef.current.zoom;
      const hit = findStrokeAtPoint(workingStrokesRef.current, x, y, threshold);
      if (hit) {
        erasedIdsRef.current.add(hit);
        workingStrokesRef.current = workingStrokesRef.current.filter(
          (s) => s.id !== hit,
        );
        const el = svgRef.current?.querySelector(
          `[data-stroke-id="${hit}"]`,
        ) as SVGElement | null;
        if (el) el.style.opacity = '0';
      }
    },
    [screenToCanvas],
  );

  const moveErase = useCallback(
    (e: PointerEvent) => {
      if (!isErasingRef.current) return;
      const { x, y } = screenToCanvas(e.clientX, e.clientY);
      const threshold = ERASER_RADIUS / cameraRef.current.zoom;
      const hit = findStrokeAtPoint(workingStrokesRef.current, x, y, threshold);
      if (hit && !erasedIdsRef.current.has(hit)) {
        erasedIdsRef.current.add(hit);
        workingStrokesRef.current = workingStrokesRef.current.filter(
          (s) => s.id !== hit,
        );
        const el = svgRef.current?.querySelector(
          `[data-stroke-id="${hit}"]`,
        ) as SVGElement | null;
        if (el) el.style.opacity = '0';
      }
    },
    [screenToCanvas],
  );

  const endErase = useCallback(() => {
    if (!isErasingRef.current) return;
    isErasingRef.current = false;
    activeGestureRef.current = null;
    gesturePointerTypeRef.current = null;
    const ids = Array.from(erasedIdsRef.current);
    if (ids.length > 0) onEraseRef.current(ids);
    erasedIdsRef.current = new Set();
  }, []);

  const cancelErase = useCallback(() => {
    for (const id of erasedIdsRef.current) {
      const el = svgRef.current?.querySelector(
        `[data-stroke-id="${id}"]`,
      ) as SVGElement | null;
      if (el) el.style.opacity = '';
    }
    isErasingRef.current = false;
    activeGestureRef.current = null;
    gesturePointerTypeRef.current = null;
    erasedIdsRef.current = new Set();
  }, []);

  // ── Two-finger pan helper ──

  const getPanCenter = useCallback(() => {
    const pts = Array.from(pointersRef.current.values());
    if (pts.length < 2) return null;
    return {
      cx: (pts[0].x + pts[1].x) / 2,
      cy: (pts[0].y + pts[1].y) / 2,
    };
  }, []);

  // ── Reset gesture state when tool changes ──

  useEffect(() => {
    // Cancel any in-progress gesture so the new tool starts clean.
    cancelDraw();
    cancelErase();
    isPanningRef.current = false;
    lastPanRef.current = null;
    // Release and clear any tracked pointers so no stale entries remain.
    const svg = svgRef.current;
    if (svg) {
      for (const id of pointersRef.current.keys()) {
        try { svg.releasePointerCapture(id); } catch { /* already released */ }
      }
    }
    pointersRef.current.clear();
  }, [tool, cancelDraw, cancelErase]);

  // ── Event listener setup (native events for zero overhead) ──

  useEffect(() => {
    const svg = svgRef.current;
    if (!svg) return;

    const onDown = (e: PointerEvent) => {
      e.preventDefault();

      // ── Pen gesture active: ignore touch pointers entirely ──
      if (
        activeGestureRef.current &&
        gesturePointerTypeRef.current === 'pen' &&
        e.pointerType === 'touch'
      ) {
        return;
      }

      svg.setPointerCapture(e.pointerId);
      pointersRef.current.set(e.pointerId, {
        x: e.clientX,
        y: e.clientY,
        type: e.pointerType,
      });

      // ── Pen pointer: always starts draw/erase immediately ──
      if (e.pointerType === 'pen') {
        // Cancel any ongoing touch-based gesture
        if (isPanningRef.current) {
          isPanningRef.current = false;
          lastPanRef.current = null;
        }
        cancelDraw();
        cancelErase();
        // Remove all touch pointers — pen takes full control
        for (const [id, ptr] of pointersRef.current) {
          if (ptr.type === 'touch') {
            try { svg.releasePointerCapture(id); } catch { /* ok */ }
            pointersRef.current.delete(id);
          }
        }
        if (toolRef.current === 'pen') startDraw(e);
        else startErase(e);
        return;
      }

      // ── Touch / mouse ──
      if (pointersRef.current.size === 1) {
        if (toolRef.current === 'pen') startDraw(e);
        else startErase(e);
      } else {
        // Second+ pointer → switch to pan, cancel any active gesture
        cancelDraw();
        cancelErase();
        isPanningRef.current = true;
        lastPanRef.current = getPanCenter();
      }
    };

    const onMove = (e: PointerEvent) => {
      // Move eraser cursor for any pointer move (including hover)
      if (toolRef.current === 'eraser' && eraserCursorRef.current) {
        eraserCursorRef.current.setAttribute('cx', String(e.clientX));
        eraserCursorRef.current.setAttribute('cy', String(e.clientY));
      }

      // Ignore untracked pointers (e.g. touch during pen gesture)
      if (!pointersRef.current.has(e.pointerId)) return;

      pointersRef.current.set(e.pointerId, {
        x: e.clientX,
        y: e.clientY,
        type: e.pointerType,
      });

      if (isPanningRef.current) {
        const curr = getPanCenter();
        const prev = lastPanRef.current;
        if (curr && prev) {
          const cam = cameraRef.current;
          onCamRef.current({
            x: cam.x + (curr.cx - prev.cx),
            y: cam.y + (curr.cy - prev.cy),
            zoom: cam.zoom,
          });
        }
        lastPanRef.current = curr;
        return;
      }

      // Route draw/erase only to the pointer type that started the gesture.
      // This prevents stray pointers of another type from interfering.
      const gesture = activeGestureRef.current;
      if (gesture && e.pointerType === gesturePointerTypeRef.current) {
        if (gesture === 'draw') moveDraw(e);
        else if (gesture === 'erase') moveErase(e);
      }
    };

    const onUp = (e: PointerEvent) => {
      // Ignore untracked pointers (e.g. touch during pen gesture)
      if (!pointersRef.current.has(e.pointerId)) {
        try { svg.releasePointerCapture(e.pointerId); } catch { /* ok */ }
        return;
      }

      try { svg.releasePointerCapture(e.pointerId); } catch { /* ok */ }

      // End the active gesture if this pointer's type matches and we're
      // not in the middle of a pan.
      if (
        !isPanningRef.current &&
        activeGestureRef.current &&
        e.pointerType === gesturePointerTypeRef.current
      ) {
        const gesture = activeGestureRef.current;
        if (gesture === 'draw') endDraw();
        else if (gesture === 'erase') endErase();
      }

      pointersRef.current.delete(e.pointerId);

      if (pointersRef.current.size < 2) {
        isPanningRef.current = false;
        lastPanRef.current = null;
      }
    };

    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      const cam = cameraRef.current;
      // Wheel / trackpad → pan only (zoom is handled by UI controls)
      onCamRef.current({
        x: cam.x - e.deltaX,
        y: cam.y - e.deltaY,
        zoom: cam.zoom,
      });
    };

    svg.addEventListener('pointerdown', onDown);
    svg.addEventListener('pointermove', onMove);
    svg.addEventListener('pointerup', onUp);
    svg.addEventListener('pointercancel', onUp);
    svg.addEventListener('wheel', onWheel, { passive: false });

    return () => {
      svg.removeEventListener('pointerdown', onDown);
      svg.removeEventListener('pointermove', onMove);
      svg.removeEventListener('pointerup', onUp);
      svg.removeEventListener('pointercancel', onUp);
      svg.removeEventListener('wheel', onWheel);
    };
  }, [
    startDraw,
    moveDraw,
    endDraw,
    cancelDraw,
    startErase,
    moveErase,
    endErase,
    cancelErase,
    getPanCenter,
  ]);

  // ── Render ──

  const transform = `translate(${camera.x},${camera.y}) scale(${camera.zoom})`;

  return (
    <svg
      ref={svgRef}
      className={`canvas-svg${tool === 'eraser' ? ' eraser-mode' : ''}`}
    >
      <g transform={transform}>
        {strokes.map((s) => (
          <StrokePath key={s.id} id={s.id} pathData={s.pathData} />
        ))}
        <path ref={activePathRef} fill="black" />
      </g>
      {tool === 'eraser' && (
        <circle
          ref={eraserCursorRef}
          cx={-100}
          cy={-100}
          r={ERASER_RADIUS}
          fill="none"
          stroke="rgba(0,0,0,0.3)"
          strokeWidth={1.5}
          style={{ pointerEvents: 'none' }}
        />
      )}
    </svg>
  );
}
