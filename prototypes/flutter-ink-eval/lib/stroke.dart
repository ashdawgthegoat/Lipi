import 'dart:ui';
import 'package:perfect_freehand/perfect_freehand.dart';

/// A single completed or in-progress stroke on the canvas.
class Stroke {
  Stroke({
    this.color = const Color(0xFFE0E0E0),
    this.size = 3.0,
  });

  final Color color;
  final double size;
  final List<PointVector> points = [];

  /// Stroke options tuned for natural handwriting feel.
  StrokeOptions get options => StrokeOptions(
        size: size,
        thinning: 0.5,
        smoothing: 0.4,
        streamline: 0.4,
        start: StrokeEndOptions.start(
          taperEnabled: true,
          cap: true,
        ),
        end: StrokeEndOptions.end(
          taperEnabled: true,
          cap: true,
        ),
        simulatePressure: !_hasPressure,
      );

  bool _hasPressure = false;

  void addPoint(Offset position, double pressure) {
    if (pressure != 1.0 && pressure != 0.0) {
      _hasPressure = true;
    }
    points.add(PointVector(position.dx, position.dy, pressure));
  }

  /// Returns the outline polygon for this stroke via perfect_freehand.
  List<Offset> get outline {
    return getStroke(points, options: options);
  }

  /// Returns true if this stroke has enough points to render.
  bool get isValid => points.length >= 2;

  /// Axis-aligned bounding box for hit-testing.
  Rect get boundingBox {
    if (points.isEmpty) return Rect.zero;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    final pad = size * 2;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }
}
