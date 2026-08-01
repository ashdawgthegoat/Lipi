import { useCallback } from 'react';
import type { Camera } from '../types';

interface ZoomControlProps {
  camera: Camera;
  onCameraChange: (camera: Camera) => void;
}

const MIN_ZOOM = 0.1;
const MAX_ZOOM = 10;
const ZOOM_STEP = 0.25;

function clampZoom(z: number): number {
  return Math.min(Math.max(z, MIN_ZOOM), MAX_ZOOM);
}

/**
 * Simple zoom control: [-] percentage [+]
 *
 * Zooms toward the viewport center so the user's content stays
 * visually anchored.
 */
export function ZoomControl({ camera, onCameraChange }: ZoomControlProps) {
  const applyZoom = useCallback(
    (newZoom: number) => {
      const clamped = clampZoom(newZoom);
      if (clamped === camera.zoom) return;
      // Zoom toward viewport center
      const cx = window.innerWidth / 2;
      const cy = window.innerHeight / 2;
      const r = clamped / camera.zoom;
      onCameraChange({
        x: cx - (cx - camera.x) * r,
        y: cy - (cy - camera.y) * r,
        zoom: clamped,
      });
    },
    [camera, onCameraChange],
  );

  const zoomIn = useCallback(
    () => applyZoom(camera.zoom + ZOOM_STEP),
    [camera.zoom, applyZoom],
  );

  const zoomOut = useCallback(
    () => applyZoom(camera.zoom - ZOOM_STEP),
    [camera.zoom, applyZoom],
  );

  const pct = Math.round(camera.zoom * 100);

  return (
    <div className="zoom-control" role="group" aria-label="Zoom controls">
      <button
        onClick={zoomOut}
        disabled={camera.zoom <= MIN_ZOOM}
        title="Zoom out"
        aria-label="Zoom out"
      >
        −
      </button>
      <span className="zoom-level">{pct}%</span>
      <button
        onClick={zoomIn}
        disabled={camera.zoom >= MAX_ZOOM}
        title="Zoom in"
        aria-label="Zoom in"
      >
        +
      </button>
    </div>
  );
}
