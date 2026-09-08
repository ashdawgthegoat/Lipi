import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/consultation_status.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import 'document_write_coordinator.dart';
import 'save_state.dart';

/// Coordinates debounced autosaving for active clinical consultation documents.
///
/// Follows ADR-0008 Section 18 & BUILD-PLAN Milestone 8:
/// - Coalesces frequent editor handwriting changes.
/// - Triggers background writes via [DocumentWriteCoordinator].
/// - Provides reactive [stateNotifier] for UI save status badges.
/// - Supports immediate explicit flush via [saveNow].
class AutosaveController {
  final PatientId patientId;
  final ConsultationId consultationId;
  final DocumentWriteCoordinator writeCoordinator;
  final Duration debounceDuration;

  late final ValueNotifier<SaveState> stateNotifier;

  Timer? _debounceTimer;
  ClinicalDocument? _latestDocument;
  bool _disposed = false;

  AutosaveController({
    required this.patientId,
    required this.consultationId,
    required this.writeCoordinator,
    this.debounceDuration = const Duration(milliseconds: 800),
  }) {
    stateNotifier = ValueNotifier<SaveState>(SaveState.idle());
  }

  SaveState get state => stateNotifier.value;

  /// Notifies the controller that the document was modified by handwriting/drawing.
  void notifyDocumentChanged(ClinicalDocument document) {
    if (_disposed) return;
    _latestDocument = document;

    // Transition to dirty state
    stateNotifier.value = stateNotifier.value.toDirty();

    // Restart debounce window
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      _performAutosave();
    });
  }

  Future<Result<void, LipiError>> _performAutosave() async {
    if (_disposed || _latestDocument == null) {
      return const Success(null);
    }

    final docToSave = _latestDocument!;
    stateNotifier.value = stateNotifier.value.toSaving();

    final result = await writeCoordinator.requestWrite(
      patientId: patientId,
      document: docToSave,
      status: ConsultationStatus.saved,
    );

    if (_disposed) return result;

    result.fold(
      onSuccess: (_) {
        // Only mark saved if no newer edits occurred while writing
        if (_latestDocument == docToSave) {
          stateNotifier.value = stateNotifier.value.toSaved(DateTime.now());
        }
      },
      onFailure: (err) {
        stateNotifier.value = stateNotifier.value.toError(err);
      },
    );

    return result;
  }

  /// Immediately flushes any pending edits to disk without waiting for the debounce timer.
  Future<Result<void, LipiError>> saveNow() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_latestDocument != null) {
      return await _performAutosave();
    }
    return const Success(null);
  }

  /// Cancels any scheduled debounce timer without saving.
  void cancel() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Disposes resources and cancels pending timers.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    stateNotifier.dispose();
  }
}
