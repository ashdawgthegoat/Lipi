import '../../../shared/errors/lipi_error.dart';
import 'stroke_point.dart';

/// Single continuous digital ink stroke in canonical document space.
///
/// Follows ADR-0005: Lipi digital ink maintains vector points,
/// pressure dynamics, stroke width, and color.
class Stroke {
  final List<StrokePoint> points;
  final String color;
  final double strokeWidth;

  const Stroke({
    required this.points,
    this.color = '#000000',
    this.strokeWidth = 1.0,
  });

  void validate() {
    if (points.isEmpty) {
      throw const ValidationError('Stroke must contain at least one point');
    }
    if (strokeWidth <= 0 || !strokeWidth.isFinite) {
      throw ValidationError('Invalid stroke width: $strokeWidth');
    }
    for (final pt in points) {
      pt.validate();
    }
  }

  Map<String, dynamic> toMap() => {
        'points': points.map((p) => p.toMap()).toList(),
        'color': color,
        'stroke_width': strokeWidth,
      };

  factory Stroke.fromMap(Map<String, dynamic> map) => Stroke(
        points: (map['points'] as List<dynamic>?)
                ?.map((p) => StrokePoint.fromMap(p as Map<String, dynamic>))
                .toList() ??
            const [],
        color: (map['color'] as String?) ?? '#000000',
        strokeWidth: (map['stroke_width'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stroke &&
          other.color == color &&
          other.strokeWidth == strokeWidth &&
          _listEquals(other.points, points);

  static bool _listEquals(List<StrokePoint> a, List<StrokePoint> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(points.length, color, strokeWidth);

  @override
  String toString() => 'Stroke(${points.length} pts, width: $strokeWidth, color: $color)';
}
