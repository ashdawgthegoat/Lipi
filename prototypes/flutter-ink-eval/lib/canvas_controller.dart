import 'package:flutter/material.dart';
import 'package:flutter_ink_eval/stroke.dart';

/// Active tool mode.
enum ToolMode { pen, eraser }

/// Manages canvas state: strokes, undo/redo history, active tool.
class CanvasController extends ChangeNotifier {
  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  Stroke? _activeStroke;

  ToolMode _toolMode = ToolMode.pen;

  // -- Public API --

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get activeStroke => _activeStroke;
  ToolMode get toolMode => _toolMode;

  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  double strokeSize = 3.0;
  Color strokeColor = const Color(0xFFE0E0E0);

  void setToolMode(ToolMode mode) {
    _toolMode = mode;
    notifyListeners();
  }

  // -- Pen input --

  void startStroke(Offset position, double pressure) {
    if (_toolMode == ToolMode.eraser) return;
    _activeStroke = Stroke(color: strokeColor, size: strokeSize);
    _activeStroke!.addPoint(position, pressure);
    notifyListeners();
  }

  void updateStroke(Offset position, double pressure) {
    if (_toolMode == ToolMode.eraser) {
      _eraseAt(position);
      return;
    }
    _activeStroke?.addPoint(position, pressure);
    notifyListeners();
  }

  void endStroke() {
    if (_activeStroke != null && _activeStroke!.isValid) {
      _strokes.add(_activeStroke!);
      _redoStack.clear();
    }
    _activeStroke = null;
    notifyListeners();
  }

  // -- Eraser --

  void _eraseAt(Offset position) {
    final eraseRadius = 20.0;
    final eraseRect = Rect.fromCenter(
      center: position,
      width: eraseRadius * 2,
      height: eraseRadius * 2,
    );

    final toRemove = <Stroke>[];
    for (final stroke in _strokes) {
      if (stroke.boundingBox.overlaps(eraseRect)) {
        // Fine-grained check: any point within radius?
        for (final p in stroke.points) {
          final dx = p.x - position.dx;
          final dy = p.y - position.dy;
          if (dx * dx + dy * dy < eraseRadius * eraseRadius) {
            toRemove.add(stroke);
            break;
          }
        }
      }
    }

    if (toRemove.isNotEmpty) {
      for (final s in toRemove) {
        _strokes.remove(s);
      }
      _redoStack.clear();
      notifyListeners();
    }
  }

  // -- Undo / Redo --

  void undo() {
    if (_strokes.isEmpty) return;
    _redoStack.add(_strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _strokes.add(_redoStack.removeLast());
    notifyListeners();
  }

  // -- Clear --

  void clear() {
    _strokes.clear();
    _redoStack.clear();
    _activeStroke = null;
    notifyListeners();
  }
}
