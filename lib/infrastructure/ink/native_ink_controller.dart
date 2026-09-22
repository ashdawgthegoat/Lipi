import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/ink_document.dart';
import '../../domains/consultation/models/stroke.dart';
import '../../domains/consultation/models/stroke_point.dart';
import 'ink_action.dart';
import 'stroke_model_ext.dart';

/// Active tool mode for the native ink engine.
enum InkToolMode { pen, eraser }

/// Controller managing in-memory canonical stroke state, active pointer drawing,
/// eraser hit-testing, and native stroke-level undo/redo history.
class NativeInkController extends ChangeNotifier {
  final List<Stroke> _strokes = [];
  final List<InkAction> _undoStack = [];
  final List<InkAction> _redoStack = [];

  // Stroke path cache to avoid recomputing outlines during repaints
  final Map<Stroke, Path> _pathCache = {};

  // Tool state
  InkToolMode _toolMode = InkToolMode.pen;
  double _strokeWidth = 2.0;
  String _strokeColor = '#1A365D';
  double _eraserRadius = 20.0;

  // Active stroke in progress
  final List<StrokePoint> _activePoints = [];
  bool _isDrawingStroke = false;

  // Active erase transaction snapshot
  List<Stroke> _preEraseStrokes = [];
  bool _isErasing = false;

  // Palm rejection tracking: true when a physical stylus is in contact with screen
  bool _isStylusActive = false;

  // Dedicated notifiers for lightweight high-frequency repaints (90 Hz)
  // without triggering rebuilds of the surrounding UI
  final ValueNotifier<int> activeStrokeRepaintNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Offset?> eraserCursorNotifier = ValueNotifier<Offset?>(null);

  /// Callback fired whenever a stroke, erase, undo, redo, or clear mutates canonical ink.
  void Function(InkDocument)? onDocumentChanged;

  NativeInkController({
    double initialStrokeWidth = 2.0,
    String initialStrokeColor = '#1A365D',
    double initialEraserRadius = 20.0,
  })  : _strokeWidth = initialStrokeWidth,
        _strokeColor = initialStrokeColor,
        _eraserRadius = initialEraserRadius;

  // --- Getters ---

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  InkToolMode get toolMode => _toolMode;
  double get strokeWidth => _strokeWidth;
  String get strokeColor => _strokeColor;
  double get eraserRadius => _eraserRadius;

  bool get isStylusActive => _isStylusActive;
  bool get isDrawingStroke => _isDrawingStroke;
  bool get isErasing => _isErasing;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Read-only view of points for the stroke currently being drawn.
  List<StrokePoint> get activePoints => List.unmodifiable(_activePoints);

  /// Retrieves or computes the cached [Path] for a completed stroke.
  Path getPathForStroke(Stroke stroke) {
    var path = _pathCache[stroke];
    if (path == null) {
      path = NativeStrokeRenderer.getStrokePath(stroke);
      _pathCache[stroke] = path;
    }
    return path;
  }

  // --- Tool & Property Setters ---

  void setToolMode(InkToolMode mode) {
    if (_toolMode == mode) return;
    _toolMode = mode;
    if (_toolMode != InkToolMode.eraser) {
      eraserCursorNotifier.value = null;
    }
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    if (_strokeWidth == width) return;
    _strokeWidth = width.clamp(0.5, 20.0);
    notifyListeners();
  }

  void setStrokeColor(String colorHex) {
    if (_strokeColor == colorHex) return;
    _strokeColor = colorHex;
    notifyListeners();
  }

  void setEraserRadius(double radius) {
    if (_eraserRadius == radius) return;
    _eraserRadius = radius.clamp(4.0, 100.0);
    notifyListeners();
  }

  void setStylusActive(bool active) {
    _isStylusActive = active;
  }

  // --- Document Loading & Export ---

  /// Initializes the canvas with strokes from [document].
  void loadDocument(ClinicalDocument document) {
    _strokes.clear();
    _pathCache.clear();
    _undoStack.clear();
    _redoStack.clear();
    _activePoints.clear();
    _preEraseStrokes.clear();
    _isDrawingStroke = false;
    _isErasing = false;

    _strokes.addAll(document.ink.strokes);
    for (final s in _strokes) {
      _pathCache[s] = NativeStrokeRenderer.getStrokePath(s);
    }
    notifyListeners();
  }

  /// Exports current canonical strokes as an [InkDocument].
  InkDocument exportCurrentInk() {
    return InkDocument(strokes: List.unmodifiable(_strokes));
  }

  // --- Pen Drawing Actions ---

  /// Starts a new ink stroke at document position [docPos] with [pressure].
  void startStroke(Offset docPos, double pressure) {
    if (_toolMode != InkToolMode.pen) return;
    _isDrawingStroke = true;
    _activePoints.clear();

    final normalizedPressure = (pressure <= 0.0 || pressure > 1.0) ? 0.5 : pressure;
    _activePoints.add(StrokePoint(
      x: docPos.dx,
      y: docPos.dy,
      pressure: normalizedPressure,
    ));

    activeStrokeRepaintNotifier.value++;
  }

  /// Adds a new point to the active stroke.
  void updateStroke(Offset docPos, double pressure) {
    if (!_isDrawingStroke || _toolMode != InkToolMode.pen) return;

    final normalizedPressure = (pressure <= 0.0 || pressure > 1.0) ? 0.5 : pressure;
    _activePoints.add(StrokePoint(
      x: docPos.dx,
      y: docPos.dy,
      pressure: normalizedPressure,
    ));

    activeStrokeRepaintNotifier.value++;
  }

  /// Finalizes the active stroke, commits it to canonical history, and notifies listeners.
  void endStroke() {
    if (!_isDrawingStroke || _activePoints.isEmpty) {
      _isDrawingStroke = false;
      _activePoints.clear();
      activeStrokeRepaintNotifier.value++;
      return;
    }

    final stroke = Stroke(
      points: List<StrokePoint>.from(_activePoints),
      color: _strokeColor,
      strokeWidth: _strokeWidth,
    );

    _strokes.add(stroke);
    _pathCache[stroke] = NativeStrokeRenderer.getStrokePath(stroke);

    // Commit to undo history
    _undoStack.add(AddStrokeAction(stroke));
    _redoStack.clear();

    _isDrawingStroke = false;
    _activePoints.clear();

    activeStrokeRepaintNotifier.value++;
    _notifyDocumentChanged();
    notifyListeners();
  }

  // --- Eraser Actions ---

  /// Starts a continuous eraser stroke at [docPos].
  void startErasing(Offset docPos) {
    if (_toolMode != InkToolMode.eraser) return;
    _isErasing = true;
    _preEraseStrokes = List<Stroke>.from(_strokes);
    eraserCursorNotifier.value = docPos;
    _eraseAt(docPos);
  }

  /// Continues an eraser stroke at [docPos].
  void updateErasing(Offset docPos) {
    if (!_isErasing || _toolMode != InkToolMode.eraser) return;
    eraserCursorNotifier.value = docPos;
    _eraseAt(docPos);
  }

  /// Concludes the eraser stroke and commits all erased strokes into one undo unit.
  void endErasing() {
    eraserCursorNotifier.value = null;
    if (!_isErasing) return;
    _isErasing = false;

    if (_strokes.length != _preEraseStrokes.length) {
      _undoStack.add(EraseStrokesAction(
        preEraseStrokes: List<Stroke>.from(_preEraseStrokes),
        postEraseStrokes: List<Stroke>.from(_strokes),
      ));
      _redoStack.clear();
      _preEraseStrokes = [];

      _notifyDocumentChanged();
      notifyListeners();
    } else {
      _preEraseStrokes = [];
    }
  }

  /// Updates the hover/preview position of the circular eraser cursor.
  void updateEraserCursor(Offset? docPos) {
    eraserCursorNotifier.value = docPos;
  }

  void _eraseAt(Offset docPos) {
    bool strokeErased = false;
    for (int i = _strokes.length - 1; i >= 0; i--) {
      final stroke = _strokes[i];
      if (NativeStrokeRenderer.strokeIntersectsCircle(stroke, docPos, _eraserRadius)) {
        _strokes.removeAt(i);
        _pathCache.remove(stroke);
        strokeErased = true;
      }
    }

    if (strokeErased) {
      activeStrokeRepaintNotifier.value++;
    }
  }

  // --- Undo / Redo / Clear ---

  /// Reverses the most recent stroke or erase action.
  void undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    action.undo(_strokes);
    _redoStack.add(action);

    // Refresh path cache for any restored strokes
    for (final s in _strokes) {
      _pathCache.putIfAbsent(s, () => NativeStrokeRenderer.getStrokePath(s));
    }

    activeStrokeRepaintNotifier.value++;
    _notifyDocumentChanged();
    notifyListeners();
  }

  /// Re-applies the most recently undone action.
  void redo() {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();
    action.redo(_strokes);
    _undoStack.add(action);

    // Refresh path cache for restored strokes
    for (final s in _strokes) {
      _pathCache.putIfAbsent(s, () => NativeStrokeRenderer.getStrokePath(s));
    }

    activeStrokeRepaintNotifier.value++;
    _notifyDocumentChanged();
    notifyListeners();
  }

  /// Clears all strokes from the canvas with a reversible undo action.
  void clear() {
    if (_strokes.isEmpty) return;
    final previous = List<Stroke>.from(_strokes);
    _strokes.clear();
    _pathCache.clear();

    _undoStack.add(ClearAllAction(previous));
    _redoStack.clear();

    activeStrokeRepaintNotifier.value++;
    _notifyDocumentChanged();
    notifyListeners();
  }

  void _notifyDocumentChanged() {
    onDocumentChanged?.call(exportCurrentInk());
  }

  @override
  void dispose() {
    activeStrokeRepaintNotifier.dispose();
    eraserCursorNotifier.dispose();
    super.dispose();
  }
}
