import '../../../shared/errors/lipi_error.dart';

/// Single point along a digital ink stroke in canonical document space.
///
/// Follows ADR-0005 and ADR-0008 Section 14:
/// Coordinates represent finite document space (editor px at 96 DPI: 1mm = 3.78 px),
/// completely invariant to viewport camera zoom/pan.
class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
  });

  void validate() {
    if (!x.isFinite || !y.isFinite || !pressure.isFinite) {
      throw ValidationError('Stroke point coordinates must be finite numbers: ($x, $y, p=$pressure)');
    }
    if (pressure < 0.0 || pressure > 1.0) {
      throw ValidationError('Stroke point pressure must be between 0.0 and 1.0: $pressure');
    }
  }

  Map<String, dynamic> toMap() => {
        'x': x,
        'y': y,
        'pressure': pressure,
      };

  factory StrokePoint.fromMap(Map<String, dynamic> map) => StrokePoint(
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        pressure: (map['pressure'] as num?)?.toDouble() ?? 0.5,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrokePoint &&
          other.x == x &&
          other.y == y &&
          other.pressure == pressure;

  @override
  int get hashCode => Object.hash(x, y, pressure);

  @override
  String toString() => 'StrokePoint($x, $y, p=$pressure)';
}
