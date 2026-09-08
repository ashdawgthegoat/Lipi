import '../../domains/consultation/models/doctor_snapshot.dart';
import '../../domains/consultation/models/page_dimensions.dart';
import '../../domains/consultation/models/patient_snapshot.dart';
import '../../shared/errors/lipi_error.dart';

/// Manifest metadata for a version-1 .lipi package.
///
/// Follows ADR-0005: Exactly one manifest.json per .lipi package.
class LipiManifest {
  final String format;
  final int version;
  final String consultationId;
  final String createdAt;
  final PageDimensions page;
  final PatientSnapshot patientSnapshot;
  final DoctorSnapshot? doctorSnapshot;
  final String ink;

  const LipiManifest({
    this.format = 'lipi',
    this.version = 1,
    required this.consultationId,
    required this.createdAt,
    required this.page,
    required this.patientSnapshot,
    this.doctorSnapshot,
    this.ink = 'ink/page-001.inkml',
  });

  void validate() {
    if (format != 'lipi') {
      throw ValidationError('Invalid .lipi manifest format: $format');
    }
    if (version != 1) {
      throw ValidationError('Unsupported .lipi manifest version: $version');
    }
    if (consultationId.trim().isEmpty) {
      throw const ValidationError('Manifest consultation_id cannot be empty');
    }
    if (ink.trim().isEmpty) {
      throw const ValidationError('Manifest ink reference cannot be empty');
    }
    page.validate();
    if (patientSnapshot.name.trim().isEmpty) {
      throw const ValidationError('Patient snapshot name cannot be empty');
    }
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'consultation_id': consultationId,
        'created_at': createdAt,
        'page': page.toJson(),
        'patient_snapshot': patientSnapshot.toJson(),
        if (doctorSnapshot != null)
          'doctor_snapshot': doctorSnapshot!.toJson(),
        'ink': ink,
      };

  factory LipiManifest.fromJson(Map<String, dynamic> json) {
    return LipiManifest(
      format: (json['format'] as String?) ?? '',
      version: (json['version'] as num?)?.toInt() ?? 0,
      consultationId: (json['consultation_id'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
      page: PageDimensions.fromJson(
          (json['page'] as Map<String, dynamic>?) ?? {}),
      patientSnapshot: PatientSnapshot.fromJson(
          (json['patient_snapshot'] as Map<String, dynamic>?) ?? {}),
      doctorSnapshot: json['doctor_snapshot'] != null
          ? DoctorSnapshot.fromJson(
              json['doctor_snapshot'] as Map<String, dynamic>)
          : null,
      ink: (json['ink'] as String?) ?? '',
    );
  }
}
