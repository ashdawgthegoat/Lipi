import '../../../shared/ids/ids.dart';
import 'clinical_history.dart';
import 'patient_info.dart';

/// Primary root entity for a patient in the Lipi domain.
///
/// Follows ADR-0003 and ADR-0008:
/// Pure Dart model, free of Flutter, SQLite, or network dependencies.
class Patient {
  final PatientId id;
  final PatientInfo info;
  final ClinicalHistory history;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    required this.id,
    required this.info,
    this.history = const ClinicalHistory(),
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    info.validate();
  }

  // Convenience getters mapping directly to commonly used fields
  String get name => info.name;
  int get age => info.age;
  String get gender => info.gender;
  String get city => info.city;

  Map<String, dynamic> toMap() => {
        'id': id.value,
        'info': info.toMap(),
        'history': history.toMap(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Patient.fromMap(Map<String, dynamic> map) {
    // Supports both nested info/history format and flattened SQLite row format
    final infoMap = map['info'] is Map<String, dynamic>
        ? map['info'] as Map<String, dynamic>
        : map;
    final historyMap = map['history'] is Map<String, dynamic>
        ? map['history'] as Map<String, dynamic>
        : <String, dynamic>{};

    return Patient(
      id: PatientId(map['id'] as String? ?? generateId()),
      info: PatientInfo.fromMap(infoMap),
      history: ClinicalHistory.fromMap(historyMap),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Patient copyWith({
    PatientId? id,
    PatientInfo? info,
    ClinicalHistory? history,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Patient(
        id: id ?? this.id,
        info: info ?? this.info,
        history: history ?? this.history,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Patient &&
          other.id.value == id.value &&
          other.info == info &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id.value, info, createdAt);

  @override
  String toString() => 'Patient(id: ${id.value}, name: $name, age: $age)';
}
