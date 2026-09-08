import 'dart:typed_data';
import '../../../shared/errors/lipi_error.dart';
import '../../../shared/ids/ids.dart';
import 'doctor_snapshot.dart';
import 'ink_document.dart';
import 'page_dimensions.dart';
import 'patient_snapshot.dart';

/// The authoritative in-memory canonical clinical document model for Lipi.
///
/// Follows ADR-0005 and ADR-0008 Section 6:
/// - It is NOT an Excalidraw scene.
/// - It is NOT a SQLite row.
/// - It is NOT a Flutter widget tree.
/// - It is NOT a screenshot.
/// - It is NOT a PDF.
///
/// This canonical model is the single source of truth from which .lipi packages
/// and PDF documents are generated.
class ClinicalDocument {
  static const String currentFormat = 'lipi';
  static const int currentVersion = 1;

  final String format;
  final int version;
  final ConsultationId consultationId;
  final PageDimensions page;
  final PatientSnapshot patientSnapshot;
  final DoctorSnapshot? doctorSnapshot;
  final InkDocument ink;
  final Uint8List? templateBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClinicalDocument({
    this.format = currentFormat,
    this.version = currentVersion,
    required this.consultationId,
    this.page = const PageDimensions(),
    required this.patientSnapshot,
    this.doctorSnapshot,
    this.ink = const InkDocument(),
    this.templateBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    validate();
  }

  bool get hasCustomTemplate =>
      templateBytes != null &&
      doctorSnapshot?.templateImageFile != null &&
      doctorSnapshot!.templateImageFile!.isNotEmpty;

  /// Validates all structural and clinical invariants.
  void validate() {
    if (format != currentFormat) {
      throw ValidationError('Unsupported document format: $format');
    }
    if (version != currentVersion) {
      throw ValidationError('Unsupported document version: $version');
    }
    if (!consultationId.isValid) {
      throw const ValidationError('Invalid consultation identifier');
    }
    if (patientSnapshot.name.trim().isEmpty) {
      throw const ValidationError('Patient snapshot name cannot be empty');
    }
    page.validate();
    ink.validate();
  }

  ClinicalDocument copyWith({
    PageDimensions? page,
    PatientSnapshot? patientSnapshot,
    DoctorSnapshot? doctorSnapshot,
    InkDocument? ink,
    Uint8List? templateBytes,
    DateTime? updatedAt,
  }) =>
      ClinicalDocument(
        format: format,
        version: version,
        consultationId: consultationId,
        page: page ?? this.page,
        patientSnapshot: patientSnapshot ?? this.patientSnapshot,
        doctorSnapshot: doctorSnapshot ?? this.doctorSnapshot,
        ink: ink ?? this.ink,
        templateBytes: templateBytes ?? this.templateBytes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  String toString() =>
      'ClinicalDocument(id: ${consultationId.value}, patient: ${patientSnapshot.name}, strokes: ${ink.strokeCount})';
}
