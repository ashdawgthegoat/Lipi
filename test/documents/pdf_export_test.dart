import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/infrastructure/export/pdf_exporter.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  group('Milestone 11 — PDF Exporter Tests', () {
    final patientSnapshot = const PatientSnapshot(
      name: 'John Doe',
      age: 45,
      gender: 'Male',
      city: 'Delhi',
    );

    final doctorSnapshot = const DoctorSnapshot(
      name: 'Dr. Strange',
      clinic: 'Sanctum Medical',
      qualifications: 'MD, PhD',
      regNumber: 'REG-777',
    );

    const page = PageDimensions(width: 210, height: 297, unit: 'mm');

    test('generatePdfBytes produces valid PDF byte buffer with header and strokes', () async {
      final document = ClinicalDocument(
        consultationId: ConsultationId('con-pdf-1'),
        page: page,
        patientSnapshot: patientSnapshot,
        doctorSnapshot: doctorSnapshot,
        ink: const InkDocument(strokes: [
          Stroke(
            points: [
              StrokePoint(x: 50.0, y: 100.0, pressure: 0.5),
              StrokePoint(x: 120.0, y: 150.0, pressure: 0.8),
            ],
            color: '#1A365D',
            strokeWidth: 2.0,
          ),
          Stroke(
            points: [
              StrokePoint(x: 200.0, y: 300.0, pressure: 0.6),
            ],
            color: '#E53E3E',
            strokeWidth: 4.0,
          ),
        ]),
      );

      final pdfBytes = await PdfExporter.generatePdfBytes(document: document);
      expect(pdfBytes.isNotEmpty, isTrue);

      // Verify PDF header '%PDF-'
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('exportToPdf writes valid PDF file to destination', () async {
      final tempDir = await Directory.systemTemp.createTemp('lipi_pdf_test_');
      final targetFile = File('${tempDir.path}/test_prescription.pdf');

      final document = ClinicalDocument(
        consultationId: ConsultationId('con-pdf-2'),
        page: page,
        patientSnapshot: patientSnapshot,
        doctorSnapshot: doctorSnapshot,
        ink: const InkDocument(),
      );

      final exported = await PdfExporter.exportToPdf(
        targetFile: targetFile,
        document: document,
      );

      expect(await exported.exists(), isTrue);
      expect(await exported.length(), greaterThan(100));

      await tempDir.delete(recursive: true);
    });
  });
}
