import '../../../shared/errors/lipi_error.dart';

/// Finite prescription page dimensions.
///
/// Follows ADR-0005: Lipi prescriptions have finite dimensions
/// and a stable canonical document coordinate system.
class PageDimensions {
  final double width;
  final double height;
  final String unit;

  const PageDimensions({
    this.width = 180.0,
    this.height = 260.0,
    this.unit = 'mm',
  });

  void validate() {
    if (width <= 0 || width > 1000) {
      throw ValidationError('Invalid page width: $width');
    }
    if (height <= 0 || height > 1000) {
      throw ValidationError('Invalid page height: $height');
    }
  }

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'unit': unit,
      };

  factory PageDimensions.fromJson(Map<String, dynamic> json) => PageDimensions(
        width: (json['width'] as num?)?.toDouble() ?? 180.0,
        height: (json['height'] as num?)?.toDouble() ?? 260.0,
        unit: (json['unit'] as String?) ?? 'mm',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageDimensions &&
          other.width == width &&
          other.height == height &&
          other.unit == unit;

  @override
  int get hashCode => Object.hash(width, height, unit);

  @override
  String toString() => 'PageDimensions(${width}x$height $unit)';
}
