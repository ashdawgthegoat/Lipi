import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../shared/errors/lipi_error.dart';

/// Cryptographic operations for the Lipi Vault storage envelope.
///
/// Follows ADR-0008 Section 19 & IMPLEMENTATION-CONTRACT Section 24 & 26:
/// - Authenticated encryption using AES-256-GCM.
/// - Authenticated envelope around canonical .lipi package bytes at rest.
/// - Fail-closed: corrupted, tampered, or mismatched ciphertexts are rejected.
class VaultCrypto {
  /// 8-byte magic identifier for encrypted Lipi envelopes: 'LIPIENC1'
  static const List<int> magicBytes = [0x4C, 0x49, 0x50, 0x49, 0x45, 0x4E, 0x43, 0x31];

  final AesGcm _aes = AesGcm.with256bits();

  /// Checks if byte payload begins with the Lipi authenticated encryption magic header.
  static bool isEncryptedEnvelope(Uint8List bytes) {
    if (bytes.length < magicBytes.length + 28) return false;
    for (int i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  /// Encrypts plaintext bytes into an authenticated Lipi storage envelope.
  Future<Uint8List> encryptEnvelope({
    required Uint8List plaintext,
    required SecretKey key,
    List<int>? aad,
  }) async {
    try {
      final secretBox = await _aes.encrypt(
        plaintext,
        secretKey: key,
        aad: aad ?? const [],
      );

      final concatenatedBox = secretBox.concatenation();
      final envelope = Uint8List(magicBytes.length + concatenatedBox.length);

      envelope.setRange(0, magicBytes.length, magicBytes);
      envelope.setRange(magicBytes.length, envelope.length, concatenatedBox);

      return envelope;
    } catch (e, st) {
      if (e is LipiError) rethrow;
      throw SecurityError('Failed to encrypt document envelope', e, st);
    }
  }

  /// Decrypts an authenticated Lipi storage envelope.
  ///
  /// Throws [SecurityError] if:
  /// - Envelope format or magic bytes are invalid.
  /// - Envelope has been tampered with or corrupted.
  /// - Decryption key does not match.
  Future<Uint8List> decryptEnvelope({
    required Uint8List envelopeBytes,
    required SecretKey key,
    List<int>? aad,
  }) async {
    try {
      if (!isEncryptedEnvelope(envelopeBytes)) {
        throw const SecurityError('Payload is not a valid Lipi encrypted envelope');
      }

      final boxBytes = envelopeBytes.sublist(magicBytes.length);
      final secretBox = SecretBox.fromConcatenation(
        boxBytes,
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );

      final decrypted = await _aes.decrypt(
        secretBox,
        secretKey: key,
        aad: aad ?? const [],
      );

      return Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError catch (e, st) {
      throw SecurityError('Decryption authentication failed: envelope corrupted or tampered with', e, st);
    } catch (e, st) {
      if (e is LipiError) rethrow;
      throw SecurityError('Failed to decrypt document envelope', e, st);
    }
  }
}
