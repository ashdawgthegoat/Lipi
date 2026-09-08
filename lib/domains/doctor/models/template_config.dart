import '../../../shared/errors/lipi_error.dart';

/// Configuration for prescription dimensions and custom background letterhead.
///
/// Follows ADR-0005 and ADR-0008 Section 15.
class TemplateConfig {
  final double widthMm;
  final double heightMm;
  final String unit;
  final String? customTemplatePath;

  const TemplateConfig({
    this.widthMm = 180.0,
    this.heightMm = 260.0,
    this.unit = 'mm',
    this.customTemplatePath,
  });

  bool get hasCustomTemplate =>
      customTemplatePath != null && customTemplatePath!.trim().isNotEmpty;

  void validate() {
    if (widthMm <= 0 || widthMm > 1000) {
      throw ValidationError('Invalid template width: $widthMm mm');
    }
    if (heightMm <= 0 || heightMm > 1000) {
      throw ValidationError('Invalid template height: $heightMm mm');
    }
    if (unit.trim().isEmpty) {
      throw const ValidationError('Template unit cannot be empty');
    }
  }

  Map<String, dynamic> toMap() => {
        'width_mm': widthMm,
        'height_mm': heightMm,
        'unit': unit,
        if (customTemplatePath != null)
          'custom_template_path': customTemplatePath,
      };

  factory TemplateConfig.fromMap(Map<String, dynamic> map) => TemplateConfig(
        widthMm: (map['width_mm'] as num?)?.toDouble() ??
            (map['template_width_mm'] as num?)?.toDouble() ??
            180.0,
        heightMm: (map['height_mm'] as num?)?.toDouble() ??
            (map['template_height_mm'] as num?)?.toDouble() ??
            260.0,
        unit: (map['unit'] as String?) ??
            (map['template_unit'] as String?) ??
            'mm',
        customTemplatePath: map['custom_template_path'] as String? ??
            map['template_path'] as String?,
      );

  TemplateConfig copyWith({
    double? widthMm,
    double? heightMm,
    String? unit,
    String? customTemplatePath,
    bool clearCustomTemplate = false,
  }) =>
      TemplateConfig(
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        unit: unit ?? this.unit,
        customTemplatePath: clearCustomTemplate
            ? null
            : (customTemplatePath ?? this.customTemplatePath),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateConfig &&
          other.widthMm == widthMm &&
          other.heightMm == heightMm &&
          other.unit == unit &&
          other.customTemplatePath == customTemplatePath;

  @override
  int get hashCode =>
      Object.hash(widthMm, heightMm, unit, customTemplatePath);

  @override
  String toString() =>
      'TemplateConfig(${widthMm}x$heightMm $unit, custom: $hasCustomTemplate)';
}
