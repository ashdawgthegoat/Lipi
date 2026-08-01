import { useState, useCallback } from 'react';
import type { Camera } from '../types';

/** Simple camera state for pan and zoom. */
export function useCamera() {
  const [camera, setCamera] = useState<Camera>({ x: 0, y: 0, zoom: 1 });

  const resetCamera = useCallback(() => {
    setCamera({ x: 0, y: 0, zoom: 1 });
  }, []);

  return { camera, setCamera, resetCamera };
}
