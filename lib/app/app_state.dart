import 'package:flutter/foundation.dart';

enum VaultStatus {
  uninitialized,
  initializing,
  locked,
  unlocked,
  active,
  error,
}

/// Coordinates high-level application state for Lipi.
class AppState extends ChangeNotifier {
  VaultStatus _vaultStatus = VaultStatus.uninitialized;
  String? _vaultErrorMessage;
  bool _isDoctorConfigured = false;

  VaultStatus get vaultStatus => _vaultStatus;
  String? get vaultErrorMessage => _vaultErrorMessage;
  bool get isDoctorConfigured => _isDoctorConfigured;

  void setVaultStatus(VaultStatus status, {String? errorMessage}) {
    _vaultStatus = status;
    _vaultErrorMessage = errorMessage;
    notifyListeners();
  }

  void setDoctorConfigured(bool configured) {
    _isDoctorConfigured = configured;
    notifyListeners();
  }
}
