/** A single completed stroke with pre-computed SVG path data. */
export interface Stroke {
  id: string;
  /** Raw input points as [x, y, pressure] tuples in canvas coordinates. */
  points: number[][];
  /** Pre-computed SVG path string for rendering. */
  pathData: string;
  /** Whether pressure was simulated (mouse) or real (stylus). */
  simulatePressure: boolean;
}

export type Tool = 'pen' | 'eraser';

export interface Camera {
  x: number;
  y: number;
  zoom: number;
}
