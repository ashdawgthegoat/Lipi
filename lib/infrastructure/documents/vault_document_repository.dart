import 'dart:typed_data';
import '../../domains/consultation/models/clinical_document.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import '../security/vault_authentication.dart';
import '../security/vault_crypto.dart';
import '../vault/vault.dart';
import 'atomic_document_writer.dart';
import 'document_repository.dart';
import 'lipi_document_deserializer.dart';
import 'lipi_document_serializer.dart';

/// Filesystem-backed Vault implementation of [DocumentRepository].
///
/// Follows ADR-0008 Section 7, 8, 17, 18, 22, 26:
/// - Persists canonical .lipi packages inside patient folders.
/// - Enforces atomic document replacement via [VaultFilesystem.atomicReplace].
/// - Transparently supports encrypted Vault storage envelopes at rest.
/// - Fail-closed: invalid, corrupt, or locked documents produce an error rather than
///   silent fabrication.
class VaultDocumentRepository implements DocumentRepository {
  final LipiVault vault;
  final VaultCrypto? crypto;
  final VaultAuthentication? auth;
  final AtomicDocumentWriter? atomicWriter;

  VaultDocumentRepository(
    this.vault, {
    this.crypto,
    this.auth,
    this.atomicWriter,
  });

  @override
  Future<Result<void, LipiError>> saveDocument(
    PatientId patientId,
    ClinicalDocument document,
  ) async {
    try {
      if (atomicWriter != null) {
        return await atomicWriter!.writeDocument(
          patientId: patientId,
          document: document,
        );
      }

      // 1. Serialize canonical document to .lipi ZIP bytes
      final zipBytes = LipiDocumentSerializer.serialize(document);

      // 2. Encrypt if envelope security is configured and unlocked
      final Uint8List payload;
      if (crypto != null && auth != null) {
        if (!auth!.isUnlocked) {
          return const Failure(SecurityError('Cannot save document: Vault is locked'));
        }
        payload = await crypto!.encryptEnvelope(
          plaintext: zipBytes,
          key: auth!.documentKey,
        );
      } else {
        payload = zipBytes;
      }

      // 3. Resolve relative path inside Vault
      final relPath = vault.getPrescriptionRelativePath(
        patientId,
        document.consultationId,
      );

      // 4. Atomically replace document
      await vault.fs.atomicReplace(relPath, payload);
      return const Success(null);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Failed to save document for ${patientId.value}', e, st));
    }
  }

  @override
  Future<Result<ClinicalDocument, LipiError>> readDocument(
    PatientId patientId,
    ConsultationId consultationId,
  ) async {
    try {
      final relPath = vault.getPrescriptionRelativePath(
        patientId,
        consultationId,
      );

      if (!await vault.fs.exists(relPath)) {
        return Failure(DocumentError('Prescription file not found at $relPath'));
      }

      final Uint8List rawBytes = await vault.fs.readBytes(relPath);
      final Uint8List zipBytes;

      // Handle encrypted envelope vs plaintext canonical ZIP
      if (VaultCrypto.isEncryptedEnvelope(rawBytes)) {
        if (crypto == null || auth == null || !auth!.isUnlocked) {
          return const Failure(SecurityError('Vault is locked: cannot decrypt prescription document'));
        }
        try {
          zipBytes = await crypto!.decryptEnvelope(
            envelopeBytes: rawBytes,
            key: auth!.documentKey,
          );
        } catch (e, st) {
          if (e is LipiError) return Failure(e);
          return Failure(SecurityError('Prescription envelope decryption failed', e, st));
        }
      } else {
        zipBytes = rawBytes;
      }

      final document = LipiDocumentDeserializer.deserialize(zipBytes);
      return Success(document);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(DocumentError('Failed to read prescription document', e, st));
    }
  }

  @override
  Future<Result<bool, LipiError>> documentExists(
    PatientId patientId,
    ConsultationId consultationId,
  ) async {
    try {
      final relPath = vault.getPrescriptionRelativePath(
        patientId,
        consultationId,
      );
      final exists = await vault.fs.exists(relPath);
      return Success(exists);
    } catch (e, st) {
      return Failure(StorageError('Failed to check document existence', e, st));
    }
  }

  @override
  Future<Result<void, LipiError>> deleteDocument(
    PatientId patientId,
    ConsultationId consultationId,
  ) async {
    try {
      final relPath = vault.getPrescriptionRelativePath(
        patientId,
        consultationId,
      );
      await vault.fs.delete(relPath);

      // Also clean up derived PDF if it exists
      final pdfPath = vault.getPrescriptionPdfRelativePath(
        patientId,
        consultationId,
      );
      if (await vault.fs.exists(pdfPath)) {
        await vault.fs.delete(pdfPath);
      }

      return const Success(null);
    } catch (e, st) {
      return Failure(StorageError('Failed to delete document', e, st));
    }
  }
}
