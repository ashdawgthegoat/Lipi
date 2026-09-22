import '../../domains/consultation/models/stroke.dart';

/// Base class representing a reversible user action on the digital ink canvas.
abstract class InkAction {
  const InkAction();

  /// Reverses this action on the target [strokes] list.
  void undo(List<Stroke> strokes);

  /// Re-applies this action on the target [strokes] list.
  void redo(List<Stroke> strokes);
}

/// Action representing adding a single drawn stroke.
class AddStrokeAction extends InkAction {
  final Stroke stroke;

  const AddStrokeAction(this.stroke);

  @override
  void undo(List<Stroke> strokes) {
    strokes.remove(stroke);
  }

  @override
  void redo(List<Stroke> strokes) {
    strokes.add(stroke);
  }
}

/// Action representing erasing one or more strokes during a continuous erase gesture.
///
/// Preserves exact pre-erase and post-erase stroke sequences to maintain
/// strict stroke ordering.
class EraseStrokesAction extends InkAction {
  final List<Stroke> preEraseStrokes;
  final List<Stroke> postEraseStrokes;

  const EraseStrokesAction({
    required this.preEraseStrokes,
    required this.postEraseStrokes,
  });

  @override
  void undo(List<Stroke> strokes) {
    strokes.clear();
    strokes.addAll(preEraseStrokes);
  }

  @override
  void redo(List<Stroke> strokes) {
    strokes.clear();
    strokes.addAll(postEraseStrokes);
  }
}

/// Action representing clearing all strokes from the canvas.
class ClearAllAction extends InkAction {
  final List<Stroke> previousStrokes;

  const ClearAllAction(this.previousStrokes);

  @override
  void undo(List<Stroke> strokes) {
    strokes.clear();
    strokes.addAll(previousStrokes);
  }

  @override
  void redo(List<Stroke> strokes) {
    strokes.clear();
  }
}
