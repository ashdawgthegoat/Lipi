import { useCallback } from 'react';
import type { ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types';
import { exportSceneToSvg } from '../utils/export';

interface ExportButtonProps {
  api: ExcalidrawImperativeAPI | null;
}

/**
 * SVG export button rendered in Excalidraw's top-right UI slot.
 */
export function ExportButton({ api }: ExportButtonProps) {
  const handleExport = useCallback(() => {
    if (api) exportSceneToSvg(api);
  }, [api]);

  return (
    <button
      className="export-btn"
      onClick={handleExport}
      title="Export SVG"
      aria-label="Export SVG"
    >
      <svg
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
        <polyline points="7 10 12 15 17 10" />
        <line x1="12" y1="15" x2="12" y2="3" />
      </svg>
    </button>
  );
}
