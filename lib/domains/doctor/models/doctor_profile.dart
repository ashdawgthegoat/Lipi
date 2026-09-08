import '../../../shared/errors/lipi_error.dart';
import '../../../shared/ids/ids.dart';
import 'doctor_preferences.dart';
import 'template_config.dart';

/// Doctor identity, clinical qualifications, and active template configuration.
///
/// Follows ADR-0008 Section 4.2:
/// Owns doctor identity, profile, and active template configuration.
/// Historical snapshot configuration is captured separately at consultation time.
class DoctorProfile {
  final DoctorId id;
  final String name;
  final String clinicName;
  final String qualifications;
  final String regNumber;
  final TemplateConfig templateConfig;
  final DoctorPreferences preferences;

  DoctorProfile({
    required this.id,
    required this.name,
    required this.clinicName,
    this.qualifications = '',
    this.regNumber = '',
    this.templateConfig = const TemplateConfig(),
    this.preferences = const DoctorPreferences(),
  }) {
    validate();
  }

  // Convenience getters for backward compatibility with prototype and UI
  String? get templatePath => templateConfig.customTemplatePath;
  double get templateWidthMm => templateConfig.widthMm;
  double get templateHeightMm => templateConfig.heightMm;
  String get templateUnit => templateConfig.unit;

  void validate() {
    if (name.trim().isEmpty) {
      throw const ValidationError('Doctor name cannot be empty');
    }
    if (clinicName.trim().isEmpty) {
      throw const ValidationError('Clinic name cannot be empty');
    }
    templateConfig.validate();
  }

  Map<String, dynamic> toMap() => {
        'id': id.value,
        'name': name.trim(),
        'clinic_name': clinicName.trim(),
        'qualifications': qualifications.trim(),
        'reg_number': regNumber.trim(),
        'template_path': templateConfig.customTemplatePath,
        'template_width_mm': templateConfig.widthMm,
        'template_height_mm': templateConfig.heightMm,
        'template_unit': templateConfig.unit,
        'preferences': preferences.toMap(),
      };

  factory DoctorProfile.fromMap(Map<String, dynamic> map) => DoctorProfile(
        id: DoctorId(map['id'] as String? ?? generateId()),
        name: (map['name'] as String?)?.trim() ?? '',
        clinicName: (map['clinic_name'] as String?)?.trim() ?? '',
        qualifications: (map['qualifications'] as String?)?.trim() ?? '',
        regNumber: (map['reg_number'] as String?)?.trim() ?? '',
        templateConfig: TemplateConfig.fromMap(map),
        preferences: map['preferences'] is Map<String, dynamic>
            ? DoctorPreferences.fromMap(
                map['preferences'] as Map<String, dynamic>)
            : const DoctorPreferences(),
      );

  DoctorProfile copyWith({
    DoctorId? id,
    String? name,
    String? clinicName,
    String? qualifications,
    String? regNumber,
    TemplateConfig? templateConfig,
    DoctorPreferences? preferences,
  }) =>
      DoctorProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        clinicName: clinicName ?? this.clinicName,
        qualifications: qualifications ?? this.qualifications,
        regNumber: regNumber ?? this.regNumber,
        templateConfig: templateConfig ?? this.templateConfig,
        preferences: preferences ?? this.preferences,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorProfile &&
          other.id.value == id.value &&
          other.name == name &&
          other.clinicName == clinicName &&
          other.qualifications == qualifications &&
          other.regNumber == regNumber &&
          other.templateConfig == templateConfig;

  @override
  int get hashCode => Object.hash(
        id.value,
        name,
        clinicName,
        qualifications,
        regNumber,
        templateConfig,
      );

  @override
  String toString() => 'DoctorProfile(name: $name, clinic: $clinicName)';
}
