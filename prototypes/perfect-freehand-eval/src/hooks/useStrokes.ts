import { useState, useCallback, useRef } from 'react';
import type { Stroke } from '../types';

type Action =
  | { type: 'draw'; stroke: Stroke }
  | { type: 'erase'; strokes: Stroke[] };

/**
 * Manages stroke state with action-based undo/redo.
 * Each draw or erase gesture becomes a single undoable action.
 */
export function useStrokes() {
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const strokesRef = useRef<Stroke[]>([]);
  const pastRef = useRef<Action[]>([]);
  const futureRef = useRef<Action[]>([]);
  // Revision counter forces re-render so canUndo/canRedo are recalculated
  const [, setRevision] = useState(0);
  const bump = useCallback(() => setRevision((v) => v + 1), []);

  const commit = useCallback(
    (next: Stroke[]) => {
      strokesRef.current = next;
      setStrokes(next);
      bump();
    },
    [bump],
  );

  const addStroke = useCallback(
    (stroke: Stroke) => {
      pastRef.current.push({ type: 'draw', stroke });
      futureRef.current = [];
      commit([...strokesRef.current, stroke]);
    },
    [commit],
  );

  const eraseStrokes = useCallback(
    (ids: string[]) => {
      if (ids.length === 0) return;
      const idSet = new Set(ids);
      const erased = strokesRef.current.filter((s) => idSet.has(s.id));
      if (erased.length === 0) return;
      pastRef.current.push({ type: 'erase', strokes: erased });
      futureRef.current = [];
      commit(strokesRef.current.filter((s) => !idSet.has(s.id)));
    },
    [commit],
  );

  const undo = useCallback(() => {
    const action = pastRef.current.pop();
    if (!action) return;
    futureRef.current.push(action);
    if (action.type === 'draw') {
      commit(strokesRef.current.filter((s) => s.id !== action.stroke.id));
    } else {
      commit([...strokesRef.current, ...action.strokes]);
    }
  }, [commit]);

  const redo = useCallback(() => {
    const action = futureRef.current.pop();
    if (!action) return;
    pastRef.current.push(action);
    if (action.type === 'draw') {
      commit([...strokesRef.current, action.stroke]);
    } else {
      const idSet = new Set(action.strokes.map((s) => s.id));
      commit(strokesRef.current.filter((s) => !idSet.has(s.id)));
    }
  }, [commit]);

  const clear = useCallback(() => {
    if (strokesRef.current.length === 0) return;
    pastRef.current.push({ type: 'erase', strokes: [...strokesRef.current] });
    futureRef.current = [];
    commit([]);
  }, [commit]);

  return {
    strokes,
    addStroke,
    eraseStrokes,
    undo,
    redo,
    clear,
    canUndo: pastRef.current.length > 0,
    canRedo: futureRef.current.length > 0,
  };
}
