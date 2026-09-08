import 'package:cryptography/cryptography.dart';
import '../../shared/errors/lipi_error.dart';
import 'vault_key_store.dart';

/// Manages the Vault lock/unlock lifecycle and in-memory key availability.
///
/// Follows ADR-0008 Section 21 & BUILD-PLAN Milestone 9:
/// - Vault keys exist in active memory only while unlocked.
/// - Locking the Vault clears references to sensitive keys.
/// - Unlocked state is required for reading/writing protected documents.
class VaultAuthentication {
  final VaultKeyStore keyStore;

  SecretKey? _activeMasterKey;
  SecretKey? _activeDocumentKey;
  SecretKey? _activeDatabaseKey;
  bool _isUnlocked = false;

  VaultAuthentication(this.keyStore);

  bool get isUnlocked => _isUnlocked;

  /// Unlocks the Vault by loading or generating the master key and deriving subkeys.
  Future<void> unlock() async {
    try {
      final masterKey = await keyStore.getOrCreateMasterKey();
      final docKey = await keyStore.deriveDocumentKey(masterKey);
      final dbKey = await keyStore.deriveDatabaseKey(masterKey);

      _activeMasterKey = masterKey;
      _activeDocumentKey = docKey;
      _activeDatabaseKey = dbKey;
      _isUnlocked = true;
    } catch (e, st) {
      lock();
      if (e is LipiError) rethrow;
      throw SecurityError('Failed to unlock Vault', e, st);
    }
  }

  /// Locks the Vault, revoking access to cryptographic keys and clearing them from memory.
  void lock() {
    _activeMasterKey = null;
    _activeDocumentKey = null;
    _activeDatabaseKey = null;
    _isUnlocked = false;
  }

  /// Active Master Key.
  ///
  /// Throws [SecurityError] if the Vault is locked.
  SecretKey get masterKey {
    if (!_isUnlocked || _activeMasterKey == null) {
      throw const SecurityError('Cannot access master key: Vault is locked');
    }
    return _activeMasterKey!;
  }

  /// Active Document Encryption Key.
  ///
  /// Throws [SecurityError] if the Vault is locked.
  SecretKey get documentKey {
    if (!_isUnlocked || _activeDocumentKey == null) {
      throw const SecurityError('Cannot access document key: Vault is locked');
    }
    return _activeDocumentKey!;
  }

  /// Active Database Key.
  ///
  /// Throws [SecurityError] if the Vault is locked.
  SecretKey get databaseKey {
    if (!_isUnlocked || _activeDatabaseKey == null) {
      throw const SecurityError('Cannot access database key: Vault is locked');
    }
    return _activeDatabaseKey!;
  }
}
