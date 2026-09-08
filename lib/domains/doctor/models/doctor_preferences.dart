/// Doctor workspace preferences (pen width, default ink color, auto-export, etc.).
///
/// Follows ADR-0008 Section 4.2.
class DoctorPreferences {
  final double defaultPenWidth;
  final String defaultPenColor;
  final bool autoExportPdf;

  const DoctorPreferences({
    this.defaultPenWidth = 1.5,
    this.defaultPenColor = '#000000',
    this.autoExportPdf = false,
  });

  Map<String, dynamic> toMap() => {
        'default_pen_width': defaultPenWidth,
        'default_pen_color': defaultPenColor,
        'auto_export_pdf': autoExportPdf,
      };

  factory DoctorPreferences.fromMap(Map<String, dynamic> map) =>
      DoctorPreferences(
        defaultPenWidth:
            (map['default_pen_width'] as num?)?.toDouble() ?? 1.5,
        defaultPenColor:
            (map['default_pen_color'] as String?) ?? '#000000',
        autoExportPdf: (map['auto_export_pdf'] as bool?) ?? false,
      );

  DoctorPreferences copyWith({
    double? defaultPenWidth,
    String? defaultPenColor,
    bool? autoExportPdf,
  }) =>
      DoctorPreferences(
        defaultPenWidth: defaultPenWidth ?? this.defaultPenWidth,
        defaultPenColor: defaultPenColor ?? this.defaultPenColor,
        autoExportPdf: autoExportPdf ?? this.autoExportPdf,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorPreferences &&
          other.defaultPenWidth == defaultPenWidth &&
          other.defaultPenColor == defaultPenColor &&
          other.autoExportPdf == autoExportPdf;

  @override
  int get hashCode =>
      Object.hash(defaultPenWidth, defaultPenColor, autoExportPdf);
}
