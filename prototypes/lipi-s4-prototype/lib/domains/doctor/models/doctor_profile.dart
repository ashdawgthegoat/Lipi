class DoctorProfile {
  final String id;
  final String name;
  final String clinicName;
  final String qualifications;
  final String regNumber;
  final String? templatePath;
  final double templateWidthMm;
  final double templateHeightMm;
  final String templateUnit;

  DoctorProfile({
    required this.id,
    required this.name,
    required this.clinicName,
    required this.qualifications,
    required this.regNumber,
    this.templatePath,
    this.templateWidthMm = 180.0,
    this.templateHeightMm = 260.0,
    this.templateUnit = 'mm',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'clinic_name': clinicName,
      'qualifications': qualifications,
      'reg_number': regNumber,
      'template_path': templatePath,
      'template_width_mm': templateWidthMm,
      'template_height_mm': templateHeightMm,
      'template_unit': templateUnit,
    };
  }

  factory DoctorProfile.fromMap(Map<String, dynamic> map) {
    return DoctorProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      clinicName: map['clinic_name'] as String,
      qualifications: (map['qualifications'] as String?) ?? '',
      regNumber: (map['reg_number'] as String?) ?? '',
      templatePath: map['template_path'] as String?,
      templateWidthMm: (map['template_width_mm'] as num?)?.toDouble() ?? 180.0,
      templateHeightMm: (map['template_height_mm'] as num?)?.toDouble() ?? 260.0,
      templateUnit: (map['template_unit'] as String?) ?? 'mm',
    );
  }
}
