import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../ink/inkml_converter.dart';
import 'lipi_manifest.dart';

/// Serializes a canonical [ClinicalDocument] into a durable .lipi ZIP package.
///
/// Follows ADR-0005 and ADR-0008 Section 7:
/// consultation_`<uuid>`.lipi
/// ├── manifest.json
/// ├── ink/
/// │   └── page-001.inkml
/// └── templates/
///     └── custom_template.png
class LipiDocumentSerializer {
  /// Serializes a [ClinicalDocument] into complete .lipi ZIP package bytes.
  static Uint8List serialize(ClinicalDocument document) {
    document.validate();

    final archive = Archive();

    // 1. Prepare InkML
    final inkmlXml = InkMLConverter.inkDocumentToInkML(document.ink);
    const inkPath = 'ink/page-001.inkml';

    // 2. Prepare Template image if present
    String? templateFilePath;
    if (document.templateBytes != null && document.templateBytes!.isNotEmpty) {
      templateFilePath = document.doctorSnapshot?.templateImageFile ?? 'templates/custom_template.png';
      archive.addFile(ArchiveFile(
        templateFilePath,
        document.templateBytes!.length,
        document.templateBytes!,
      ));
    }

    // 3. Prepare Manifest
    final manifest = LipiManifest(
      format: document.format,
      version: document.version,
      consultationId: document.consultationId.value,
      createdAt: document.createdAt.toIso8601String(),
      page: document.page,
      patientSnapshot: document.patientSnapshot,
      doctorSnapshot: document.doctorSnapshot,
      ink: inkPath,
    );

    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    archive.addFile(ArchiveFile(
      'manifest.json',
      manifestBytes.length,
      manifestBytes,
    ));

    // 4. Add InkML file
    final inkBytes = utf8.encode(inkmlXml);
    archive.addFile(ArchiveFile(
      inkPath,
      inkBytes.length,
      inkBytes,
    ));

    // 5. Encode archive to ZIP
    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }
}
