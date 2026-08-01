import { useState, useCallback, useMemo } from 'react';
import { Excalidraw } from '@excalidraw/excalidraw';
import '@excalidraw/excalidraw/index.css';

import type { ExcalidrawImperativeAPI } from '@excalidraw/excalidraw/types';
import { ExportButton } from './components/ExportButton';

/**
 * Excalidraw handwriting evaluation prototype.
 *
 * Starts in freedraw mode with shape tools hidden via CSS.
 * Only exposes: freehand drawing, eraser, undo/redo, pan, zoom, SVG export.
 */
export function App() {
  const [api, setApi] = useState<ExcalidrawImperativeAPI | null>(null);

  const handleApi = useCallback(
    (excalidrawApi: ExcalidrawImperativeAPI) => {
      setApi(excalidrawApi);
    },
    [],
  );

  // Start in freedraw mode with a white background
  const initialData = useMemo(
    () => ({
      appState: {
        activeTool: { type: 'freedraw' as const, customType: null, lastActiveTool: null, locked: false },
        currentItemStrokeColor: '#000000',
        currentItemStrokeWidth: 1,
        viewBackgroundColor: '#ffffff',
      },
    }),
    [],
  );

  // Hide non-handwriting canvas actions
  const uiOptions = useMemo(
    () => ({
      canvasActions: {
        changeViewBackgroundColor: false,
        clearCanvas: true,
        loadScene: false,
        saveToActiveFile: false,
        toggleTheme: false,
        saveAsImage: false,
        export: false as const,
      },
      welcomeScreen: false,
    }),
    [],
  );

  const renderTopRightUI = useCallback(
    () => <ExportButton api={api} />,
    [api],
  );

  return (
    <div className="excalidraw-wrapper">
      <Excalidraw
        excalidrawAPI={handleApi}
        initialData={initialData}
        UIOptions={uiOptions}
        renderTopRightUI={renderTopRightUI}
      />
    </div>
  );
}
