import 'dart:typed_data';
import '../../shared/errors/lipi_error.dart';
import '../../shared/result/result.dart';
import 'vault_crypto.dart';

/// Storage envelope and document package integrity validator.
///
/// Follows ADR-0008 Section 23 (Fail-Closed) & BUILD-PLAN Milestone 9:
/// When data integrity or format cannot be verified, fail closed and
/// do not expose partial or corrupt data.
class IntegrityValidator {
  static const List<int> zipMagic = [0x50, 0x4B, 0x03, 0x04];

  /// Checks whether bytes represent an encrypted envelope or raw ZIP package.
  static Result<StorageEnvelopeType, LipiError> inspectStoragePayload(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const Failure(StorageError('Payload is empty'));
    }

    if (VaultCrypto.isEncryptedEnvelope(bytes)) {
      return const Success(StorageEnvelopeType.encryptedEnvelope);
    }

    if (isZipPackage(bytes)) {
      return const Success(StorageEnvelopeType.canonicalZip);
    }

    return const Failure(DocumentError(
      'Payload does not have valid Lipi storage envelope or ZIP magic bytes',
    ));
  }

  /// Checks if bytes start with ZIP standard magic bytes.
  static bool isZipPackage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == zipMagic[0] &&
        bytes[1] == zipMagic[1] &&
        bytes[2] == zipMagic[2] &&
        bytes[3] == zipMagic[3];
  }
}

enum StorageEnvelopeType {
  encryptedEnvelope,
  canonicalZip,
}
