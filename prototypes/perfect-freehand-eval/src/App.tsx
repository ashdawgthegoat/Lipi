import { useState, useEffect, useCallback } from 'react';
import { Canvas } from './components/Canvas';
import { Toolbar } from './components/Toolbar';
import { ZoomControl } from './components/ZoomControl';
import { useStrokes } from './hooks/useStrokes';
import { useCamera } from './hooks/useCamera';
import { exportToSvg } from './utils/svg-export';
import type { Tool } from './types';

export function App() {
  const { strokes, addStroke, eraseStrokes, undo, redo, clear, canUndo, canRedo } =
    useStrokes();
  const { camera, setCamera } = useCamera();
  const [tool, setTool] = useState<Tool>('pen');

  const handleExport = useCallback(() => {
    exportToSvg(strokes);
  }, [strokes]);

  // Keyboard shortcuts
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const mod = e.ctrlKey || e.metaKey;

      // Undo: Ctrl+Z
      if (mod && e.key === 'z' && !e.shiftKey) {
        e.preventDefault();
        undo();
        return;
      }
      // Redo: Ctrl+Shift+Z or Ctrl+Y
      if (mod && ((e.key === 'z' && e.shiftKey) || e.key === 'y')) {
        e.preventDefault();
        redo();
        return;
      }
      // Tool shortcuts
      if (e.key === 'p' || e.key === 'P') setTool('pen');
      if (e.key === 'e' || e.key === 'E') setTool('eraser');
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [undo, redo]);

  return (
    <>
      <Canvas
        strokes={strokes}
        tool={tool}
        camera={camera}
        onAddStroke={addStroke}
        onEraseStrokes={eraseStrokes}
        onCameraChange={setCamera}
      />
      <Toolbar
        tool={tool}
        onToolChange={setTool}
        onUndo={undo}
        onRedo={redo}
        onClear={clear}
        onExport={handleExport}
        canUndo={canUndo}
        canRedo={canRedo}
      />
      <ZoomControl camera={camera} onCameraChange={setCamera} />
    </>
  );
}
