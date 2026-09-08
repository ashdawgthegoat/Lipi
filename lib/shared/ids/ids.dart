import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a cryptographically secure / RFC4122 v4 UUID string.
String generateId() => _uuid.v4();

/// Type-safe value wrapper for an internal patient identifier.
extension type const PatientId(String value) {
  factory PatientId.generate() => PatientId(_uuid.v4());
  bool get isValid => value.trim().isNotEmpty;
}

/// Type-safe value wrapper for a consultation/prescription identifier.
extension type const ConsultationId(String value) {
  factory ConsultationId.generate() => ConsultationId(_uuid.v4());
  bool get isValid => value.trim().isNotEmpty;
}

/// Type-safe value wrapper for a doctor identifier.
extension type const DoctorId(String value) {
  factory DoctorId.generate() => DoctorId(_uuid.v4());
  bool get isValid => value.trim().isNotEmpty;
}
