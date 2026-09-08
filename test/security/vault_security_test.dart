import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/clinical_document.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/ink_document.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/consultation/models/stroke.dart';
import 'package:lipi/domains/consultation/models/stroke_point.dart';
import 'package:lipi/infrastructure/documents/atomic_document_writer.dart';
import 'package:lipi/infrastructure/documents/vault_document_repository.dart';
import 'package:lipi/infrastructure/security/integrity_validator.dart';
import 'package:lipi/infrastructure/security/secure_key_store.dart';
import 'package:lipi/infrastructure/security/vault_authentication.dart';
import 'package:lipi/infrastructure/security/vault_crypto.dart';
import 'package:lipi/infrastructure/security/vault_key_store.dart';
import 'package:lipi/infrastructure/vault/vault.dart';
import 'package:lipi/shared/errors/lipi_error.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LipiVault vault;
  late SecureKeyStore secureStorage;
  late VaultKeyStore keyStore;
  late VaultCrypto crypto;
  late VaultAuthentication auth;
  late DefaultAtomicDocumentWriter writer;
  late VaultDocumentRepository repository;

  final patientId = PatientId('pat-sec-1');
  final consultationId = ConsultationId('con-sec-1');

  final patientSnapshot = const PatientSnapshot(
    name: 'Alice Smith',
    age: 34,
    gender: 'Female',
    city: 'Bengaluru',
  );

  final doctorSnapshot = const DoctorSnapshot(
    name: 'Dr. John',
    clinic: 'Care Hospital',
    qualifications: 'MBBS',
    regNumber: 'REG-999',
  );

  const page = PageDimensions(width: 210, height: 297, unit: 'mm');

  final testDocument = ClinicalDocument(
    consultationId: consultationId,
    page: page,
    patientSnapshot: patientSnapshot,
    doctorSnapshot: doctorSnapshot,
    ink: const InkDocument(strokes: [
      Stroke(
        points: [
          StrokePoint(x: 10, y: 15, pressure: 0.5),
          StrokePoint(x: 20, y: 25, pressure: 0.8),
        ],
        color: '#FF0000',
        strokeWidth: 3.0,
      )
    ]),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_sec_test_');
    vault = LipiVault(tempDir);
    await vault.initialize();

    secureStorage = InMemorySecureKeyStore();
    keyStore = VaultKeyStore(secureStorage);
    crypto = VaultCrypto();
    auth = VaultAuthentication(keyStore);

    writer = DefaultAtomicDocumentWriter(
      vault,
      crypto: crypto,
      auth: auth,
    );

    repository = VaultDocumentRepository(
      vault,
      crypto: crypto,
      auth: auth,
      atomicWriter: writer,
    );
  });

  tearDown(() async {
    vault.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone 9 — Security Implementation', () {
    test('KeyStore generates random 256-bit Master Key and separates subkeys via HKDF', () async {
      expect(await keyStore.hasMasterKey(), isFalse);

      final masterKey = await keyStore.getOrCreateMasterKey();
      expect(await keyStore.hasMasterKey(), isTrue);

      final masterBytes = await masterKey.extractBytes();
      expect(masterBytes.length, equals(32)); // 256 bits

      // Subkeys derived via HKDF
      final docKey = await keyStore.deriveDocumentKey(masterKey);
      final dbKey = await keyStore.deriveDatabaseKey(masterKey);

      final docBytes = await docKey.extractBytes();
      final dbBytes = await dbKey.extractBytes();

      expect(docBytes.length, equals(32));
      expect(dbBytes.length, equals(32));

      // Purpose separation invariant
      expect(docBytes, isNot(equals(masterBytes)));
      expect(dbBytes, isNot(equals(masterBytes)));
      expect(docBytes, isNot(equals(dbBytes)));
    });

    test('Locked Vault rejects write and read operations (Fail-Closed)', () async {
      expect(auth.isUnlocked, isFalse);

      // Attempt write while locked
      final writeRes = await repository.saveDocument(patientId, testDocument);
      expect(writeRes.isFailure, isTrue);
      expect(writeRes.errorOrNull, isA<SecurityError>());
      expect(writeRes.errorOrNull!.message, contains('Vault is locked'));

      // File should not exist
      final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
      expect(await vault.fs.exists(relPath), isFalse);
    });

    test('Unlocked Vault encrypts document at rest with authenticated storage envelope', () async {
      // 1. Unlock Vault
      await auth.unlock();
      expect(auth.isUnlocked, isTrue);

      // 2. Save document
      final saveRes = await repository.saveDocument(patientId, testDocument);
      expect(saveRes.isSuccess, isTrue);

      // 3. Verify on-disk representation is ENCRYPTED, NOT PLAINTEXT ZIP
      final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
      final onDiskBytes = await vault.fs.readBytes(relPath);

      // Check magic header
      expect(VaultCrypto.isEncryptedEnvelope(onDiskBytes), isTrue);
      expect(IntegrityValidator.isZipPackage(onDiskBytes), isFalse);

      final inspection = IntegrityValidator.inspectStoragePayload(onDiskBytes);
      expect(inspection.valueOrNull, equals(StorageEnvelopeType.encryptedEnvelope));

      // 4. Read back while unlocked
      final readRes = await repository.readDocument(patientId, consultationId);
      expect(readRes.isSuccess, isTrue);
      final readDoc = readRes.valueOrNull!;
      expect(readDoc.consultationId.value, equals(consultationId.value));
      expect(readDoc.patientSnapshot.name, equals('Alice Smith'));
      expect(readDoc.ink.strokeCount, equals(1));
    });

    test('Locked Vault fails closed when attempting to read encrypted document', () async {
      // 1. Save while unlocked
      await auth.unlock();
      final saveRes = await repository.saveDocument(patientId, testDocument);
      expect(saveRes.isSuccess, isTrue);

      // 2. Lock Vault
      auth.lock();
      expect(auth.isUnlocked, isFalse);

      // 3. Read attempt while locked must fail closed
      final readRes = await repository.readDocument(patientId, consultationId);
      expect(readRes.isFailure, isTrue);
      expect(readRes.errorOrNull, isA<SecurityError>());
      expect(readRes.errorOrNull!.message, contains('Vault is locked'));
    });

    test('Corrupted or tampered ciphertext triggers authentication error and fails closed', () async {
      await auth.unlock();
      await repository.saveDocument(patientId, testDocument);

      final relPath = vault.getPrescriptionRelativePath(patientId, consultationId);
      final originalBytes = await vault.fs.readBytes(relPath);

      // Tamper with a single byte in ciphertext
      final tamperedBytes = Uint8List.fromList(originalBytes);
      tamperedBytes[tamperedBytes.length - 5] ^= 0x5A;

      await vault.fs.writeBytes(relPath, tamperedBytes);

      // Reading tampered document must fail closed
      final readRes = await repository.readDocument(patientId, consultationId);
      expect(readRes.isFailure, isTrue);
      expect(readRes.errorOrNull, isA<SecurityError>());
      expect(readRes.errorOrNull!.message, contains('corrupted or tampered with'));
    });

    test('Wrong key fails authentication and preserves document integrity', () async {
      await auth.unlock();
      await repository.saveDocument(patientId, testDocument);

      // Setup a second independent auth with completely different keys
      final secondStorage = InMemorySecureKeyStore();
      final secondKeyStore = VaultKeyStore(secondStorage);
      final secondAuth = VaultAuthentication(secondKeyStore);
      await secondAuth.unlock();

      final repoWithWrongKey = VaultDocumentRepository(
        vault,
        crypto: crypto,
        auth: secondAuth,
      );

      final readRes = await repoWithWrongKey.readDocument(patientId, consultationId);
      expect(readRes.isFailure, isTrue);
      expect(readRes.errorOrNull, isA<SecurityError>());
    });
  });
}
