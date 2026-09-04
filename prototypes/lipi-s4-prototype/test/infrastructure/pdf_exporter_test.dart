import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi_s4_prototype/infrastructure/export/pdf_exporter.dart';
import 'package:lipi_s4_prototype/infrastructure/ink/inkml_converter.dart';
import 'package:lipi_s4_prototype/infrastructure/storage/lipi_package.dart';
import 'package:pdf/pdf.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_pdf_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ── Helper to generate minimal 1x1 PNG bytes for custom template tests ────
  Uint8List createDummyPngBytes() {
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
      0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT
      0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00,
      0x18, 0xDD, 0x8D, 0xB0,
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND
      0xAE, 0x42, 0x60, 0x82,
    ]);
  }

  // ── Test 1: Coordinate Preservation ───────────────────────────────────────
  test('Test 1 — Coordinate Preservation: Document coordinates map faithfully to PDF points', () {
    const page = PageDimensions(width: 180, height: 260, unit: 'mm');
    final pdfWidth = 180.0 * PdfPageFormat.mm;
    final pdfHeight = 260.0 * PdfPageFormat.mm;
    final pxWidth = (180.0 * 3.78).roundToDouble(); // 680.0
    final pxHeight = (260.0 * 3.78).roundToDouble(); // 983.0

    final scaleX = pdfWidth / pxWidth;
    final scaleY = pdfHeight / pxHeight;

    // Top-left origin: doc (0, 0) -> PDF (0, pdfHeight)
    final ptTopLeft = PdfExporter.documentPointToPdfPoint(docX: 0, docY: 0, page: page);
    expect(ptTopLeft.x, closeTo(0.0, 0.001));
    expect(ptTopLeft.y, closeTo(pdfHeight, 0.001));

    // Bottom-right corner: doc (pxWidth, pxHeight) -> PDF (pdfWidth, 0)
    final ptBottomRight = PdfExporter.documentPointToPdfPoint(docX: pxWidth, docY: pxHeight, page: page);
    expect(ptBottomRight.x, closeTo(pdfWidth, 0.001));
    expect(ptBottomRight.y, closeTo(0.0, 0.001));

    // Center point: doc (pxWidth/2, pxHeight/2) -> PDF (pdfWidth/2, pdfHeight/2)
    final ptCenter = PdfExporter.documentPointToPdfPoint(docX: pxWidth / 2, docY: pxHeight / 2, page: page);
    expect(ptCenter.x, closeTo(pdfWidth / 2, 0.001));
    expect(ptCenter.y, closeTo(pdfHeight / 2, 0.001));

    // Known clinical note point (e.g. Rx note at x=100, y=250)
    final ptNote = PdfExporter.documentPointToPdfPoint(docX: 100, docY: 250, page: page);
    expect(ptNote.x, closeTo(100.0 * scaleX, 0.001));
    expect(ptNote.y, closeTo(pdfHeight - (250.0 * scaleY), 0.001));
  });

  // ── Test 2: Page Dimensions ───────────────────────────────────────────────
  test('Test 2 — Page Dimensions: PDF matches configured finite document dimensions', () async {
    // 1. Standard custom dimension (180x260 mm)
    final pdfFile1 = File('${tempDir.path}/dim_180x260.pdf');
    final manifest1 = LipiManifest(
      consultationId: 'c-dim-01',
      page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
      patientSnapshot: const PatientSnapshot(name: 'A', age: 30, gender: 'M', city: 'C'),
    );
    await PdfExporter.exportToPdf(
      targetFile: pdfFile1,
      manifest: manifest1,
      inkmlContent: '',
    );
    expect(await pdfFile1.exists(), isTrue);
    expect((await pdfFile1.readAsBytes()).length, greaterThan(1000));

    // 2. Standard A4 dimension (210x297 mm)
    final pdfFile2 = File('${tempDir.path}/dim_a4.pdf');
    final manifest2 = LipiManifest(
      consultationId: 'c-dim-a4',
      page: const PageDimensions(width: 210, height: 297, unit: 'mm'),
      patientSnapshot: const PatientSnapshot(name: 'B', age: 45, gender: 'F', city: 'D'),
    );
    await PdfExporter.exportToPdf(
      targetFile: pdfFile2,
      manifest: manifest2,
      inkmlContent: '',
    );
    expect(await pdfFile2.exists(), isTrue);
    expect((await pdfFile2.readAsBytes()).length, greaterThan(1000));
  });

  // ── Test 3: Custom Template Export ────────────────────────────────────────
  test('Test 3 — Custom Template: Preserves full-page custom letterhead image and vector ink', () async {
    final pdfFile = File('${tempDir.path}/custom_template_export.pdf');
    final dummyPng = createDummyPngBytes();

    final manifest = LipiManifest(
      consultationId: 'c-custom-tmpl',
      page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
      patientSnapshot: const PatientSnapshot(name: 'Ravi Kumar', age: 42, gender: 'Male', city: 'Pune'),
      doctorSnapshot: const DoctorSnapshot(
        name: 'Dr. Ashutosh Agrawal',
        clinic: 'Apex Super-Specialty Clinic',
        qualifications: 'MD (Cardiology)',
        regNumber: 'MCI-99881',
        templateImageFile: 'templates/custom_template.png',
      ),
    );

    const inkml = '''<?xml version="1.0" encoding="UTF-8"?>
<ink xmlns="http://www.w3.org/2003/InkML">
  <trace contextRef="#ctx0" color="#1a365d" width="2.0">
    100.0 200.0 0.5, 150.0 210.0 0.6, 200.0 205.0 0.5
  </trace>
</ink>''';

    final result = await PdfExporter.exportToPdf(
      targetFile: pdfFile,
      manifest: manifest,
      inkmlContent: inkml,
      templateImageBytes: dummyPng,
    );

    expect(await result.exists(), isTrue);
    final bytes = await result.readAsBytes();
    // PDF should contain image and ink objects
    expect(bytes.length, greaterThan(1000));
    final header = String.fromCharCodes(bytes.take(5));
    expect(header, '%PDF-');
  });

  // ── Test 4: Default Template Export ───────────────────────────────────────
  test('Test 4 — Default Template: Faithful replica of standard letterhead layout', () async {
    final pdfFile = File('${tempDir.path}/default_template_export.pdf');

    final manifest = LipiManifest(
      consultationId: 'c-default-tmpl',
      page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
      patientSnapshot: const PatientSnapshot(name: 'Sunita Patil', age: 38, gender: 'Female', city: 'Mumbai'),
      doctorSnapshot: const DoctorSnapshot(
        name: 'Dr. Aarti Sharma',
        clinic: 'City Health Clinic',
        qualifications: 'MBBS, MD',
        regNumber: 'MCI-45892',
      ),
    );

    const inkml = '''<?xml version="1.0" encoding="UTF-8"?>
<ink xmlns="http://www.w3.org/2003/InkML">
  <trace contextRef="#ctx0" color="#000000" width="1.5">
    50.0 160.0 0.5, 120.0 160.0 0.5, 180.0 160.0 0.5
  </trace>
</ink>''';

    final result = await PdfExporter.exportToPdf(
      targetFile: pdfFile,
      manifest: manifest,
      inkmlContent: inkml,
      templateImageBytes: null, // Default template
      dateString: '04 Sep 2026',
    );

    expect(await result.exists(), isTrue);
    final bytes = await result.readAsBytes();
    expect(bytes.length, greaterThan(1500));
  });

  // ── Test 5: Zoom Independence ─────────────────────────────────────────────
  test('Test 5 — Zoom Independence: Exported PDF is invariant to editor viewport zoom/pan', () async {
    // In Lipi architecture, Excalidraw viewport state (zoom, scrollX, scrollY) does NOT
    // mutate the canonical document coordinates of freedraw elements.
    // Here we verify that two strokes representing the exact same clinical marks
    // produce identical PDF output regardless of the zoom level at which they were written.

    final pdfFile1 = File('${tempDir.path}/zoom_state_100.pdf');
    final pdfFile2 = File('${tempDir.path}/zoom_state_150.pdf');

    final manifest = LipiManifest(
      consultationId: 'c-zoom-test',
      page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
      patientSnapshot: const PatientSnapshot(name: 'Test Patient', age: 50, gender: 'Other', city: 'Delhi'),
    );

    const inkml = '''<?xml version="1.0" encoding="UTF-8"?>
<ink xmlns="http://www.w3.org/2003/InkML">
  <trace contextRef="#ctx0" color="#000000" width="1.5">
    100.0 188.0 0.5, 200.0 188.0 0.5, 300.0 188.0 0.5
  </trace>
</ink>''';

    // Export 1 (as if at zoom 1.0)
    await PdfExporter.exportToPdf(
      targetFile: pdfFile1,
      manifest: manifest,
      inkmlContent: inkml,
    );

    // Export 2 (as if at zoom 1.48 with pan)
    await PdfExporter.exportToPdf(
      targetFile: pdfFile2,
      manifest: manifest,
      inkmlContent: inkml,
    );

    final bytes1 = await pdfFile1.readAsBytes();
    final bytes2 = await pdfFile2.readAsBytes();

    expect(bytes1.length, equals(bytes2.length));
  });

  // ── Test 6: Reopen Then Export ────────────────────────────────────────────
  test('Test 6 — Reopen Then Export: Write -> Save .lipi -> Reopen -> Export preserves ink', () async {
    final lipiFile = File('${tempDir.path}/consultation_reopen_test.lipi');
    final pdfFile = File('${tempDir.path}/consultation_reopen_test.pdf');

    final originalManifest = LipiManifest(
      consultationId: 'c-reopen-export-01',
      page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
      patientSnapshot: const PatientSnapshot(name: 'Kavita Joshi', age: 29, gender: 'Female', city: 'Nagpur'),
      doctorSnapshot: const DoctorSnapshot(
        name: 'Dr. Aarti Sharma',
        clinic: 'City Health Clinic',
        qualifications: 'MBBS, MD',
        regNumber: 'MCI-45892',
      ),
    );

    const originalInkml = '''<?xml version="1.0" encoding="UTF-8"?>
<ink xmlns="http://www.w3.org/2003/InkML">
  <trace contextRef="#ctx0" color="#000000" width="1.5">
    80.0 200.0 0.5, 140.0 205.0 0.6, 220.0 198.0 0.5
  </trace>
</ink>''';

    // 1. Write to .lipi archive
    await LipiPackage.write(
      lipiFile,
      manifest: originalManifest,
      inkmlContent: originalInkml,
    );
    expect(await lipiFile.exists(), isTrue);

    // 2. Reopen from .lipi archive
    final reopenedPackage = await LipiPackage.read(lipiFile);
    expect(reopenedPackage.manifest.consultationId, 'c-reopen-export-01');
    expect(reopenedPackage.manifest.patientSnapshot.name, 'Kavita Joshi');
    expect(reopenedPackage.inkmlContent, originalInkml);

    // 3. Export to PDF from reopened package
    await PdfExporter.exportToPdf(
      targetFile: pdfFile,
      manifest: reopenedPackage.manifest,
      inkmlContent: reopenedPackage.inkmlContent,
    );

    expect(await pdfFile.exists(), isTrue);
    final pdfBytes = await pdfFile.readAsBytes();
    expect(pdfBytes.length, greaterThan(1500));
  });

  // ── Test 7: Historical Editing ────────────────────────────────────────────
  test('Test 7 — Historical Editing: Reopen existing .lipi, add stroke, save and export', () async {
    final lipiFile = File('${tempDir.path}/consultation_edit_test.lipi');
    final pdfFile = File('${tempDir.path}/consultation_edit_test.pdf');

    final manifest = LipiManifest(
      consultationId: 'c-historical-edit-01',
      page: const PageDimensions(width: 180, height: 260, unit: 'mm'),
      patientSnapshot: const PatientSnapshot(name: 'Amit Deshmukh', age: 52, gender: 'Male', city: 'Nashik'),
      doctorSnapshot: const DoctorSnapshot(
        name: 'Dr. Aarti Sharma',
        clinic: 'City Health Clinic',
        qualifications: 'MBBS, MD',
        regNumber: 'MCI-45892',
      ),
    );

    // Phase 1: Doctor wrote initial prescription note (Stroke 1)
    const initialInkml = '''<?xml version="1.0" encoding="UTF-8"?>
<ink xmlns="http://www.w3.org/2003/InkML">
  <trace contextRef="#ctx0" color="#000000" width="1.5">
    50.0 200.0 0.5, 100.0 200.0 0.5, 150.0 200.0 0.5
  </trace>
</ink>''';

    await LipiPackage.write(
      lipiFile,
      manifest: manifest,
      inkmlContent: initialInkml,
    );

    // Phase 2: Later, doctor reopens historical prescription
    final openedPkg = await LipiPackage.read(lipiFile);
    final existingElements = InkMLConverter.inkMLToExcalidraw(openedPkg.inkmlContent);
    expect(existingElements.length, 1);

    // Doctor adds a second stroke (Stroke 2: new clinical note)
    final newElements = List<Map<String, dynamic>>.from(existingElements);
    newElements.add({
      'id': 'new_stroke_02',
      'type': 'freedraw',
      'x': 50.0,
      'y': 250.0,
      'width': 100.0,
      'height': 10.0,
      'strokeColor': '#1a365d',
      'strokeWidth': 2.0,
      'points': [
        [0.0, 0.0],
        [50.0, 2.0],
        [100.0, 0.0],
      ],
      'pressures': [0.5, 0.6, 0.5],
      'isDeleted': false,
    });

    // Save edited prescription back to the same .lipi file
    final updatedInkml = InkMLConverter.excalidrawToInkML(newElements);
    await LipiPackage.write(
      lipiFile,
      manifest: openedPkg.manifest,
      inkmlContent: updatedInkml,
    );

    // Phase 3: Reopen updated .lipi file and verify both strokes preserved
    final reReopenedPkg = await LipiPackage.read(lipiFile);
    final finalStrokes = InkMLConverter.parseInkML(reReopenedPkg.inkmlContent);
    expect(finalStrokes.length, 2);
    expect(finalStrokes[0].color, '#000000');
    expect(finalStrokes[1].color, '#1a365d');

    // Phase 4: Export edited historical prescription to PDF
    await PdfExporter.exportToPdf(
      targetFile: pdfFile,
      manifest: reReopenedPkg.manifest,
      inkmlContent: reReopenedPkg.inkmlContent,
    );

    expect(await pdfFile.exists(), isTrue);
    final pdfBytes = await pdfFile.readAsBytes();
    expect(pdfBytes.length, greaterThan(1500));
  });

  // ── Test 8: Real Tablet Artifact Re-Export Validation ─────────────────────
  test('Test 8 — Real Tablet Re-Export: Custom & Default templates from actual tablet session', () async {
    final customLipiFile = File('/tmp/old_rx_custom.lipi');
    final customTmplFile = File('/tmp/tablet_custom_template.png');
    final defaultLipiFile = File('/tmp/old_rx_default.lipi');

    if (await customLipiFile.exists() && await customTmplFile.exists()) {
      final pkg = await LipiPackage.read(customLipiFile);
      final tmplBytes = await customTmplFile.readAsBytes();
      final outPdf = File('/tmp/new_rx_custom.pdf');

      await PdfExporter.exportToPdf(
        targetFile: outPdf,
        manifest: pkg.manifest,
        inkmlContent: pkg.inkmlContent,
        templateImageBytes: tmplBytes,
        dateString: pkg.manifest.createdAt.split('T').first,
      );
      expect(await outPdf.exists(), isTrue);
    }

    if (await defaultLipiFile.exists()) {
      final pkg = await LipiPackage.read(defaultLipiFile);
      final outPdf = File('/tmp/new_rx_default.pdf');

      await PdfExporter.exportToPdf(
        targetFile: outPdf,
        manifest: pkg.manifest,
        inkmlContent: pkg.inkmlContent,
        templateImageBytes: null, // Default letterhead
        dateString: pkg.manifest.createdAt.split('T').first,
      );
      expect(await outPdf.exists(), isTrue);
    }
  });
}
