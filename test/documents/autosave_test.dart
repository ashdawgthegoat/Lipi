import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/consultation_repository.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/consultation/models/consultation.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/infrastructure/database/sqlite_consultation_repository.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/documents/atomic_document_writer.dart';
import 'package:lipi/infrastructure/documents/autosave_controller.dart';
import 'package:lipi/infrastructure/documents/document_write_coordinator.dart';
import 'package:lipi/infrastructure/documents/lipi_document_deserializer.dart';
import 'package:lipi/infrastructure/vault/vault.dart';
import 'package:lipi/shared/errors/lipi_error.dart';
import 'package:lipi/shared/ids/ids.dart';
import 'package:lipi/shared/result/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  late Directory tempDir;
  late LipiVault vault;
  late VaultDatabase db;
  late ConsultationRepository consultationRepo;
  late AtomicDocumentWriter writer;
  late DocumentWriteCoordinator writeCoordinator;

  final patientId = PatientId('patient-auto-1');
  final consultationId = ConsultationId('consultation-auto-1');

  final patientSnapshot = const PatientSnapshot(
    name: 'Jane Doe',
    age: 28,
    gender: 'Female',
    city: 'Mumbai',
  );

  final doctorSnapshot = const DoctorSnapshot(
    name: 'Dr. Watson',
    clinic: 'Watson Care',
    qualifications: 'MBBS, MD',
    regNumber: 'REG-12345',
  );

  const page = PageDimensions(width: 210, height: 297, unit: 'mm');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_autosave_test_');
    vault = LipiVault(tempDir);
    await vault.initialize();

    db = VaultDatabase();
    await db.open(vault.dbFile);
    consultationRepo = SqliteConsultationRepository(db);

    writer = DefaultAtomicDocumentWriter(vault);
    writeCoordinator = DocumentWriteCoordinator(
      writer: writer,
      consultationRepository: consultationRepo,
    );

    // Seed SQLite consultation
    final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
    await consultationRepo.upsertConsultation(Consultation(
      id: consultationId,
      patientId: patientId,
      patientSnapshot: patientSnapshot,
      doctorSnapshot: doctorSnapshot,
      pageDimensions: page,
      status: ConsultationStatus.active,
      lipiRelativePath: relPath,
    ));
  });

  tearDown(() async {
    await db.close();
    vault.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ClinicalDocument createDocWithStrokes(int count) {
    final strokes = List.generate(
      count,
      (i) => Stroke(
        points: [
          StrokePoint(x: 10.0 * i, y: 20.0 * i, pressure: 0.5),
          StrokePoint(x: 15.0 * i, y: 25.0 * i, pressure: 0.8),
        ],
        color: '#000000',
        strokeWidth: 2.0,
      ),
    );

    return ClinicalDocument(
      consultationId: consultationId,
      page: page,
      patientSnapshot: patientSnapshot,
      doctorSnapshot: doctorSnapshot,
      ink: InkDocument(strokes: strokes),
    );
  }

  group('Milestone 8 — Autosave and Crash Safety', () {
    test('Debounced autosave triggers write and transitions SaveState to saved', () async {
      final controller = AutosaveController(
        patientId: patientId,
        consultationId: consultationId,
        writeCoordinator: writeCoordinator,
        debounceDuration: const Duration(milliseconds: 100),
      );

      expect(controller.state.isIdle, isTrue);

      // Edit 1
      final doc1 = createDocWithStrokes(1);
      controller.notifyDocumentChanged(doc1);

      expect(controller.state.isDirty, isTrue);

      // Wait for debounce timer (100ms) + write execution
      await Future.delayed(const Duration(milliseconds: 250));

      expect(controller.state.isSaved, isTrue);
      expect(controller.state.lastSavedAt, isNotNull);

      // Verify file on disk
      final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
      final bytes = await vault.fs.readBytes(relPath);
      final readDoc = LipiDocumentDeserializer.deserialize(bytes);
      expect(readDoc.ink.strokeCount, equals(1));

      controller.dispose();
    });

    test('Rapid consecutive edits are coalesced by debounce interval', () async {
      final controller = AutosaveController(
        patientId: patientId,
        consultationId: consultationId,
        writeCoordinator: writeCoordinator,
        debounceDuration: const Duration(milliseconds: 150),
      );

      // 5 rapid edits spaced by 30ms (total 120ms < 150ms debounce)
      for (int i = 1; i <= 5; i++) {
        controller.notifyDocumentChanged(createDocWithStrokes(i));
        await Future.delayed(const Duration(milliseconds: 30));
      }

      expect(controller.state.isDirty, isTrue);

      // Wait for debounce to fire
      await Future.delayed(const Duration(milliseconds: 250));

      expect(controller.state.isSaved, isTrue);

      // Verify file contains the latest (5th) edit
      final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
      final bytes = await vault.fs.readBytes(relPath);
      final readDoc = LipiDocumentDeserializer.deserialize(bytes);
      expect(readDoc.ink.strokeCount, equals(5));

      controller.dispose();
    });

    test('saveNow immediately flushes pending changes without waiting for debounce', () async {
      final controller = AutosaveController(
        patientId: patientId,
        consultationId: consultationId,
        writeCoordinator: writeCoordinator,
        debounceDuration: const Duration(seconds: 10), // Long debounce
      );

      final doc = createDocWithStrokes(3);
      controller.notifyDocumentChanged(doc);
      expect(controller.state.isDirty, isTrue);

      // Flush immediately
      final res = await controller.saveNow();
      expect(res.isSuccess, isTrue);
      expect(controller.state.isSaved, isTrue);

      // Verify disk
      final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
      final bytes = await vault.fs.readBytes(relPath);
      final readDoc = LipiDocumentDeserializer.deserialize(bytes);
      expect(readDoc.ink.strokeCount, equals(3));

      controller.dispose();
    });

    test('Pre-commit failure preserves previous valid document intact', () async {
      // 1. Save valid initial document with 2 strokes
      final validDoc = createDocWithStrokes(2);
      final initialRes = await writeCoordinator.requestWrite(
        patientId: patientId,
        document: validDoc,
      );
      expect(initialRes.isSuccess, isTrue);

      final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
      final initialBytes = await vault.fs.readBytes(relPath);
      final initialRead = LipiDocumentDeserializer.deserialize(initialBytes);
      expect(initialRead.ink.strokeCount, equals(2));

      // 2. Simulate writer failure via broken writer that aborts during write
      final failingWriter = _FailingAtomicDocumentWriter();
      final failingCoordinator = DocumentWriteCoordinator(
        writer: failingWriter,
        consultationRepository: consultationRepo,
      );

      final failingController = AutosaveController(
        patientId: patientId,
        consultationId: consultationId,
        writeCoordinator: failingCoordinator,
        debounceDuration: const Duration(milliseconds: 50),
      );

      // Notify new edit (4 strokes)
      failingController.notifyDocumentChanged(createDocWithStrokes(4));

      // Wait for debounce and failed write
      await Future.delayed(const Duration(milliseconds: 150));

      expect(failingController.state.hasError, isTrue);
      expect(failingController.state.error, isA<DocumentError>());

      // 3. Verify previous valid file on disk is COMPLETELY INTACT
      final afterFailureBytes = await vault.fs.readBytes(relPath);
      final afterFailureDoc = LipiDocumentDeserializer.deserialize(afterFailureBytes);
      expect(afterFailureDoc.ink.strokeCount, equals(2));

      failingController.dispose();
    });
  });
}

class _FailingAtomicDocumentWriter implements AtomicDocumentWriter {
  @override
  Future<Result<void, LipiError>> writeDocument({
    required PatientId patientId,
    required ClinicalDocument document,
  }) async {
    return Failure(DocumentError('Simulated pre-commit validation failure'));
  }
}
