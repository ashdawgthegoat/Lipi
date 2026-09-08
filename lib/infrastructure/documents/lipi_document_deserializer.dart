import 'dart:typed_data';
import '../../domains/consultation/models/clinical_document.dart';
import '../../shared/ids/ids.dart';
import '../ink/inkml_converter.dart';
import 'lipi_package_validator.dart';

/// Deserializes a .lipi package into a canonical [ClinicalDocument].
///
/// Follows ADR-0005 and ADR-0008 Section 7.
class LipiDocumentDeserializer {
  /// Unpacks, validates, and reconstructs a [ClinicalDocument] from .lipi ZIP bytes.
  static ClinicalDocument deserialize(Uint8List zipBytes) {
    // 1. Strict package validation
    final validated = LipiPackageValidator.validate(zipBytes);
    final manifest = validated.manifest;

    // 2. Parse canonical InkML
    final inkDoc = InkMLConverter.inkMLToInkDocument(validated.inkmlContent);

    // 3. Reconstruct ClinicalDocument
    return ClinicalDocument(
      format: manifest.format,
      version: manifest.version,
      consultationId: ConsultationId(manifest.consultationId),
      page: manifest.page,
      patientSnapshot: manifest.patientSnapshot,
      doctorSnapshot: manifest.doctorSnapshot,
      ink: inkDoc,
      templateBytes: validated.templateBytes,
      createdAt: DateTime.parse(manifest.createdAt),
      updatedAt: DateTime.parse(manifest.createdAt),
    );
  }
}
