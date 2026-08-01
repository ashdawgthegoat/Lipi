import getStroke from 'perfect-freehand';

/**
 * Perfect Freehand options tuned for natural handwriting feel.
 * Adjust these to experiment with stroke quality.
 */
export const PEN_OPTIONS = {
  size: 6,
  thinning: 0.5,
  smoothing: 0.5,
  streamline: 0.5,
  easing: (t: number) => t,
  start: { cap: true, taper: 0 },
  end: { cap: true, taper: 0 },
};

/**
 * Convert the outline points returned by getStroke into an SVG path string.
 * Uses quadratic bézier curves through the midpoints for smooth rendering.
 *
 * Optimised for hot-path performance: builds the path string via direct
 * concatenation rather than array reduce + join.
 */
export function getSvgPathFromStroke(points: number[][]): string {
  if (!points.length) return '';

  const max = points.length - 1;

  let d = `M ${points[0][0]} ${points[0][1]} Q`;

  for (let i = 0; i < max; i++) {
    const pt = points[i];
    const nx = points[i + 1];
    d += ` ${pt[0]} ${pt[1]} ${(pt[0] + nx[0]) / 2} ${(pt[1] + nx[1]) / 2}`;
  }

  d += ' Z';
  return d;
}

/** Generate a complete SVG path data string from raw input points. */
export function computePathData(
  points: number[][],
  simulatePressure: boolean,
  last: boolean = false,
): string {
  const outlinePoints = getStroke(points, {
    ...PEN_OPTIONS,
    simulatePressure,
    last,
  });
  return getSvgPathFromStroke(outlinePoints);
}

let nextId = 0;

/** Generate a unique stroke ID. */
export function generateStrokeId(): string {
  return `s${Date.now()}-${nextId++}`;
}
