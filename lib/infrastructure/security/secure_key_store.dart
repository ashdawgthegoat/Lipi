import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../shared/errors/lipi_error.dart';

/// Platform-agnostic contract for secure hardware-backed key storage.
///
/// Follows ADR-0008 Section 20 and IMPLEMENTATION-CONTRACT Section 25:
/// Application code must not directly depend on Android Keystore or iOS Keychain APIs.
abstract class SecureKeyStore {
  Future<void> storeKey(String keyAlias, Uint8List keyBytes);
  Future<Uint8List?> retrieveKey(String keyAlias);
  Future<void> deleteKey(String keyAlias);
  Future<bool> keyExists(String keyAlias);
}

/// Production implementation backed by FlutterSecureStorage (Android Keystore / iOS Keychain).
class PlatformSecureKeyStore implements SecureKeyStore {
  final FlutterSecureStorage _storage;

  PlatformSecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<void> storeKey(String keyAlias, Uint8List keyBytes) async {
    try {
      final base64Key = base64Encode(keyBytes);
      await _storage.write(key: keyAlias, value: base64Key);
    } catch (e, st) {
      throw SecurityError('Failed to store key in secure storage for $keyAlias', e, st);
    }
  }

  @override
  Future<Uint8List?> retrieveKey(String keyAlias) async {
    try {
      final value = await _storage.read(key: keyAlias);
      if (value == null || value.isEmpty) return null;
      return base64Decode(value);
    } catch (e, st) {
      throw SecurityError('Failed to read key from secure storage for $keyAlias', e, st);
    }
  }

  @override
  Future<void> deleteKey(String keyAlias) async {
    try {
      await _storage.delete(key: keyAlias);
    } catch (e, st) {
      throw SecurityError('Failed to delete key from secure storage for $keyAlias', e, st);
    }
  }

  @override
  Future<bool> keyExists(String keyAlias) async {
    try {
      return await _storage.containsKey(key: keyAlias);
    } catch (e, st) {
      throw SecurityError('Failed to check key existence in secure storage for $keyAlias', e, st);
    }
  }
}

/// In-memory implementation for unit testing and headless environments.
class InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, Uint8List> _store = {};

  @override
  Future<void> storeKey(String keyAlias, Uint8List keyBytes) async {
    _store[keyAlias] = Uint8List.fromList(keyBytes);
  }

  @override
  Future<Uint8List?> retrieveKey(String keyAlias) async {
    final val = _store[keyAlias];
    if (val == null) return null;
    return Uint8List.fromList(val);
  }

  @override
  Future<void> deleteKey(String keyAlias) async {
    _store.remove(keyAlias);
  }

  @override
  Future<bool> keyExists(String keyAlias) async {
    return _store.containsKey(keyAlias);
  }

  void clear() {
    _store.clear();
  }
}
