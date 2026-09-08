import '../../shared/errors/lipi_error.dart';

/// Status of clinical document persistence.
enum SaveStatus {
  idle,
  dirty,
  saving,
  saved,
  error,
}

/// Immutable state representing autosave and persistence progress.
///
/// Follows ADR-0008 Section 18 & BUILD-PLAN Milestone 8.
class SaveState {
  final SaveStatus status;
  final DateTime? lastSavedAt;
  final LipiError? error;

  const SaveState({
    required this.status,
    this.lastSavedAt,
    this.error,
  });

  factory SaveState.idle() => const SaveState(status: SaveStatus.idle);

  SaveState toDirty() => SaveState(
        status: SaveStatus.dirty,
        lastSavedAt: lastSavedAt,
      );

  SaveState toSaving() => SaveState(
        status: SaveStatus.saving,
        lastSavedAt: lastSavedAt,
      );

  SaveState toSaved(DateTime savedAt) => SaveState(
        status: SaveStatus.saved,
        lastSavedAt: savedAt,
      );

  SaveState toError(LipiError err) => SaveState(
        status: SaveStatus.error,
        lastSavedAt: lastSavedAt,
        error: err,
      );

  bool get isIdle => status == SaveStatus.idle;
  bool get isDirty => status == SaveStatus.dirty;
  bool get isSaving => status == SaveStatus.saving;
  bool get isSaved => status == SaveStatus.saved;
  bool get hasError => status == SaveStatus.error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lastSavedAt == other.lastSavedAt &&
          error == other.error;

  @override
  int get hashCode => Object.hash(status, lastSavedAt, error);

  @override
  String toString() => 'SaveState(status: $status, lastSavedAt: $lastSavedAt, error: $error)';
}
