/// Immutable snapshot of doctor information and template binding captured into a consultation.
///
/// Follows ADR-0005 and ADR-0008 Section 16:
/// Stored doctor snapshot ensures reopening an older prescription displays
/// the exact clinic, qualifications, and letterhead valid at consultation time.
class DoctorSnapshot {
  final String name;
  final String clinic;
  final String qualifications;
  final String regNumber;
  final String? templateImageFile;

  const DoctorSnapshot({
    required this.name,
    required this.clinic,
    required this.qualifications,
    required this.regNumber,
    this.templateImageFile,
  });

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'clinic': clinic.trim(),
        'qualifications': qualifications.trim(),
        'reg_number': regNumber.trim(),
        if (templateImageFile != null)
          'template_image_file': templateImageFile,
      };

  factory DoctorSnapshot.fromJson(Map<String, dynamic> json) => DoctorSnapshot(
        name: (json['name'] as String?)?.trim() ?? '',
        clinic: (json['clinic'] as String?)?.trim() ?? '',
        qualifications: (json['qualifications'] as String?)?.trim() ?? '',
        regNumber: (json['reg_number'] as String?)?.trim() ?? '',
        templateImageFile: json['template_image_file'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorSnapshot &&
          other.name == name &&
          other.clinic == clinic &&
          other.qualifications == qualifications &&
          other.regNumber == regNumber &&
          other.templateImageFile == templateImageFile;

  @override
  int get hashCode => Object.hash(
        name,
        clinic,
        qualifications,
        regNumber,
        templateImageFile,
      );

  @override
  String toString() => 'DoctorSnapshot($name, $clinic, reg: $regNumber)';
}
