import 'dart:typed_data';
import '../../domains/consultation/models/clinical_document.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import '../security/vault_authentication.dart';
import '../security/vault_crypto.dart';
import '../vault/vault.dart';
import 'lipi_document_serializer.dart';
import 'lipi_package_validator.dart';

/// Contract for safe, atomic document persistence.
///
/// Follows ADR-0008 Section 18 & 22:
/// Before commit: previous valid document remains intact.
/// After commit: new valid document exists and is valid.
abstract class AtomicDocumentWriter {
  Future<Result<void, LipiError>> writeDocument({
    required PatientId patientId,
    required ClinicalDocument document,
  });
}

/// Default implementation enforcing pre-commit validation, encryption envelope (if configured),
/// and atomic replacement.
class DefaultAtomicDocumentWriter implements AtomicDocumentWriter {
  final LipiVault vault;
  final VaultCrypto? crypto;
  final VaultAuthentication? auth;

  DefaultAtomicDocumentWriter(
    this.vault, {
    this.crypto,
    this.auth,
  });

  @override
  Future<Result<void, LipiError>> writeDocument({
    required PatientId patientId,
    required ClinicalDocument document,
  }) async {
    try {
      // 1. Pre-commit serialization to in-memory bytes
      final Uint8List zipBytes;
      try {
        zipBytes = LipiDocumentSerializer.serialize(document);
      } catch (e, st) {
        return Failure(DocumentError('Document serialization failed prior to write', e, st));
      }

      // 2. Pre-commit validation of candidate archive
      try {
        LipiPackageValidator.validate(zipBytes);
      } catch (e, st) {
        if (e is LipiError) return Failure(e);
        return Failure(DocumentError('Pre-commit validation rejected invalid package', e, st));
      }

      // 3. Encrypt into authenticated storage envelope if configured and unlocked
      final Uint8List payload;
      if (crypto != null && auth != null) {
        if (!auth!.isUnlocked) {
          return const Failure(SecurityError('Cannot write document: Vault is locked'));
        }
        payload = await crypto!.encryptEnvelope(
          plaintext: zipBytes,
          key: auth!.documentKey,
        );
      } else {
        payload = zipBytes;
      }

      // 4. Resolve destination path in patient folder
      final relPath = vault.getPrescriptionRelativePath(
        patientId,
        document.consultationId,
      );

      // 5. Safe atomic replacement via temp file flush + rename
      await vault.fs.atomicReplace(relPath, payload);

      return const Success(null);
    } catch (e, st) {
      if (e is LipiError) return Failure(e);
      return Failure(StorageError('Atomic write failed for patient ${patientId.value}', e, st));
    }
  }
}
