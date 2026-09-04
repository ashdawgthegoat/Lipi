import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class PageDimensions {
  final double width;
  final double height;
  final String unit;

  const PageDimensions({
    this.width = 180.0,
    this.height = 260.0,
    this.unit = 'mm',
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'unit': unit,
      };

  factory PageDimensions.fromJson(Map<String, dynamic> json) => PageDimensions(
        width: (json['width'] as num?)?.toDouble() ?? 180.0,
        height: (json['height'] as num?)?.toDouble() ?? 260.0,
        unit: (json['unit'] as String?) ?? 'mm',
      );
}

class PatientSnapshot {
  final String name;
  final int age;
  final String gender;
  final String city;

  const PatientSnapshot({
    required this.name,
    required this.age,
    required this.gender,
    required this.city,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'gender': gender,
        'city': city,
      };

  factory PatientSnapshot.fromJson(Map<String, dynamic> json) => PatientSnapshot(
        name: (json['name'] as String?) ?? '',
        age: (json['age'] as num?)?.toInt() ?? 0,
        gender: (json['gender'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
      );
}

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
        'name': name,
        'clinic': clinic,
        'qualifications': qualifications,
        'reg_number': regNumber,
        if (templateImageFile != null) 'template_image_file': templateImageFile,
      };

  factory DoctorSnapshot.fromJson(Map<String, dynamic> json) => DoctorSnapshot(
        name: (json['name'] as String?) ?? '',
        clinic: (json['clinic'] as String?) ?? '',
        qualifications: (json['qualifications'] as String?) ?? '',
        regNumber: (json['reg_number'] as String?) ?? '',
        templateImageFile: json['template_image_file'] as String?,
      );
}

class LipiManifest {
  final String format;
  final int version;
  final String consultationId;
  final PageDimensions page;
  final PatientSnapshot patientSnapshot;
  final DoctorSnapshot? doctorSnapshot;
  final String ink;
  final String createdAt;

  LipiManifest({
    this.format = 'lipi',
    this.version = 1,
    required this.consultationId,
    required this.page,
    required this.patientSnapshot,
    this.doctorSnapshot,
    this.ink = 'ink/page-001.inkml',
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'consultation_id': consultationId,
        'created_at': createdAt,
        'page': page.toJson(),
        'patient_snapshot': patientSnapshot.toJson(),
        if (doctorSnapshot != null) 'doctor_snapshot': doctorSnapshot!.toJson(),
        'ink': ink,
      };

  factory LipiManifest.fromJson(Map<String, dynamic> json) => LipiManifest(
        format: (json['format'] as String?) ?? 'lipi',
        version: (json['version'] as num?)?.toInt() ?? 1,
        consultationId: (json['consultation_id'] as String?) ?? '',
        createdAt: json['created_at'] as String?,
        page: PageDimensions.fromJson(
            (json['page'] as Map<String, dynamic>?) ?? {}),
        patientSnapshot: PatientSnapshot.fromJson(
            (json['patient_snapshot'] as Map<String, dynamic>?) ?? {}),
        doctorSnapshot: json['doctor_snapshot'] != null
            ? DoctorSnapshot.fromJson(
                json['doctor_snapshot'] as Map<String, dynamic>)
            : null,
        ink: (json['ink'] as String?) ?? 'ink/page-001.inkml',
      );
}

/// Represents a loaded .lipi package
class LipiPackage {
  final LipiManifest manifest;
  final String inkmlContent;
  final Uint8List? templateImageBytes;

  LipiPackage({
    required this.manifest,
    required this.inkmlContent,
    this.templateImageBytes,
  });

  /// Writes a .lipi ZIP archive to the target file.
  static Future<void> write(
    File targetFile, {
    required LipiManifest manifest,
    required String inkmlContent,
    Uint8List? templateImageBytes,
  }) async {
    final archive = Archive();

    // 1. manifest.json
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    archive.addFile(ArchiveFile(
      'manifest.json',
      manifestBytes.length,
      manifestBytes,
    ));

    // 2. ink/page-001.inkml
    final inkBytes = utf8.encode(inkmlContent);
    archive.addFile(ArchiveFile(
      manifest.ink,
      inkBytes.length,
      inkBytes,
    ));

    // 3. Optional template image
    if (templateImageBytes != null &&
        manifest.doctorSnapshot?.templateImageFile != null) {
      archive.addFile(ArchiveFile(
        manifest.doctorSnapshot!.templateImageFile!,
        templateImageBytes.length,
        templateImageBytes,
      ));
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw StateError('Failed to encode ZIP archive for .lipi document');
    }

    // Ensure parent directory exists
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    await targetFile.writeAsBytes(zipData, flush: true);
  }

  /// Reads and unpacks a .lipi file.
  static Future<LipiPackage> read(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Lipi file does not exist', file.path);
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Locate manifest.json
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw FormatException('Invalid .lipi archive: manifest.json missing');
    }

    final manifestJson = json.decode(
      utf8.decode(manifestFile.content as List<int>),
    ) as Map<String, dynamic>;
    final manifest = LipiManifest.fromJson(manifestJson);

    // 2. Locate ink file
    final inkFile = archive.findFile(manifest.ink);
    final inkmlContent = inkFile != null
        ? utf8.decode(inkFile.content as List<int>)
        : '';

    // 3. Locate template image if specified
    Uint8List? templateImageBytes;
    if (manifest.doctorSnapshot?.templateImageFile != null) {
      final imgFile = archive.findFile(manifest.doctorSnapshot!.templateImageFile!);
      if (imgFile != null) {
        templateImageBytes = Uint8List.fromList(imgFile.content as List<int>);
      }
    }

    return LipiPackage(
      manifest: manifest,
      inkmlContent: inkmlContent,
      templateImageBytes: templateImageBytes,
    );
  }
}
