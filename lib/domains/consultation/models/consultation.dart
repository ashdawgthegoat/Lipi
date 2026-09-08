import '../../../shared/ids/ids.dart';
import 'consultation_status.dart';
import 'doctor_snapshot.dart';
import 'page_dimensions.dart';
import 'patient_snapshot.dart';

/// Clinical consultation metadata record.
///
/// Follows ADR-0008 Section 4.3:
/// Represents consultation identity, patient association, doctor snapshot,
/// patient snapshot, document reference, and lifecycle state.
class Consultation {
  final ConsultationId id;
  final PatientId patientId;
  final PatientSnapshot patientSnapshot;
  final DoctorSnapshot doctorSnapshot;
  final PageDimensions pageDimensions;
  final ConsultationStatus status;
  final String lipiRelativePath;
  final String? pdfRelativePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Consultation({
    required this.id,
    required this.patientId,
    required this.patientSnapshot,
    required this.doctorSnapshot,
    this.pageDimensions = const PageDimensions(),
    this.status = ConsultationStatus.draft,
    required this.lipiRelativePath,
    this.pdfRelativePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasPdf =>
      pdfRelativePath != null && pdfRelativePath!.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id.value,
        'patient_id': patientId.value,
        'patient_snapshot': patientSnapshot.toJson(),
        'doctor_snapshot': doctorSnapshot.toJson(),
        'page_dimensions': pageDimensions.toJson(),
        'status': status.name,
        'lipi_relative_path': lipiRelativePath,
        if (pdfRelativePath != null) 'pdf_relative_path': pdfRelativePath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Consultation.fromMap(Map<String, dynamic> map) => Consultation(
        id: ConsultationId(map['id'] as String? ??
            map['consultation_id'] as String? ??
            generateId()),
        patientId: PatientId(map['patient_id'] as String? ?? ''),
        patientSnapshot: PatientSnapshot.fromJson(
            (map['patient_snapshot'] as Map<String, dynamic>?) ?? {}),
        doctorSnapshot: DoctorSnapshot.fromJson(
            (map['doctor_snapshot'] as Map<String, dynamic>?) ?? {}),
        pageDimensions: PageDimensions.fromJson(
            (map['page_dimensions'] as Map<String, dynamic>?) ?? {}),
        status: ConsultationStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => ConsultationStatus.active,
        ),
        lipiRelativePath: (map['lipi_relative_path'] as String?) ??
            (map['file_path'] as String?) ??
            '',
        pdfRelativePath: map['pdf_relative_path'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.now(),
      );

  Consultation copyWith({
    ConsultationId? id,
    PatientId? patientId,
    PatientSnapshot? patientSnapshot,
    DoctorSnapshot? doctorSnapshot,
    PageDimensions? pageDimensions,
    ConsultationStatus? status,
    String? lipiRelativePath,
    String? pdfRelativePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Consultation(
        id: id ?? this.id,
        patientId: patientId ?? this.patientId,
        patientSnapshot: patientSnapshot ?? this.patientSnapshot,
        doctorSnapshot: doctorSnapshot ?? this.doctorSnapshot,
        pageDimensions: pageDimensions ?? this.pageDimensions,
        status: status ?? this.status,
        lipiRelativePath: lipiRelativePath ?? this.lipiRelativePath,
        pdfRelativePath: pdfRelativePath ?? this.pdfRelativePath,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Consultation &&
          other.id.value == id.value &&
          other.patientId.value == patientId.value &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id.value, patientId.value, createdAt);

  @override
  String toString() =>
      'Consultation(id: ${id.value}, patient: ${patientSnapshot.name}, status: ${status.name})';
}
