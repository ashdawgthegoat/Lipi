/// Base error hierarchy for Lipi application.
///
/// Follows ADR-0008 Section 22 and IMPLEMENTATION-CONTRACT Section 28.
/// Infrastructure failures are translated into explicit LipiError instances,
/// maintaining fail-closed semantics without leaking clinical data to logs.
abstract class LipiError implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const LipiError(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Errors relating to Vault lifecycle, locking, and structure.
class VaultError extends LipiError {
  const VaultError(super.message, [super.cause, super.stackTrace]);
}

/// Errors relating to underlying filesystem storage or I/O.
class StorageError extends LipiError {
  const StorageError(super.message, [super.cause, super.stackTrace]);
}

/// Errors relating to .lipi package reading, manifest format, or missing parts.
class DocumentError extends LipiError {
  const DocumentError(super.message, [super.cause, super.stackTrace]);
}

/// Errors when integrity verification (checksum, signature, HMAC) fails.
class IntegrityError extends LipiError {
  const IntegrityError(super.message, [super.cause, super.stackTrace]);
}

/// Errors relating to encryption, decryption, key derivation, or keystore access.
class SecurityError extends LipiError {
  const SecurityError(super.message, [super.cause, super.stackTrace]);
}

/// Errors during document or asset import.
class ImportError extends LipiError {
  const ImportError(super.message, [super.cause, super.stackTrace]);
}

/// Errors during PDF or data export.
class ExportError extends LipiError {
  const ExportError(super.message, [super.cause, super.stackTrace]);
}

/// Errors during validation of domain models or input formats.
class ValidationError extends LipiError {
  const ValidationError(super.message, [super.cause, super.stackTrace]);
}

/// Errors when recovering a damaged Vault or document.
class RecoveryError extends LipiError {
  const RecoveryError(super.message, [super.cause, super.stackTrace]);
}

/// Errors from the handwriting editor or WebView bridge.
class EditorError extends LipiError {
  const EditorError(super.message, [super.cause, super.stackTrace]);
}
