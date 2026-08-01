import type { Stroke } from '../types';

/**
 * Find the ID of a stroke whose raw input points are within `threshold`
 * pixels of the given canvas-space point. Checks strokes in reverse
 * order so topmost strokes are found first.
 */
export function findStrokeAtPoint(
  strokes: Stroke[],
  x: number,
  y: number,
  threshold: number,
): string | null {
  const t2 = threshold * threshold;

  for (let i = strokes.length - 1; i >= 0; i--) {
    const stroke = strokes[i];
    for (const pt of stroke.points) {
      const dx = pt[0] - x;
      const dy = pt[1] - y;
      if (dx * dx + dy * dy < t2) {
        return stroke.id;
      }
    }
  }

  return null;
}
