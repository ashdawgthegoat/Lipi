import 'dart:async';
import '../../domains/consultation/consultation_repository.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/consultation_status.dart';
import '../../shared/errors/lipi_error.dart';
import '../../shared/ids/ids.dart';
import '../../shared/result/result.dart';
import 'atomic_document_writer.dart';

class _PendingWrite {
  final PatientId patientId;
  final ClinicalDocument document;
  final ConsultationStatus status;
  final List<Completer<Result<void, LipiError>>> completers;

  _PendingWrite({
    required this.patientId,
    required this.document,
    required this.status,
    required this.completers,
  });
}

/// Serializes and coalesces concurrent write operations for clinical documents.
///
/// Follows ADR-0008 Section 18 & 22:
/// - Guarantees non-concurrent sequential execution.
/// - Coalesces rapid intermediate edits so only the latest valid state is written.
/// - Synchronizes database metadata with document state.
class DocumentWriteCoordinator {
  final AtomicDocumentWriter writer;
  final ConsultationRepository consultationRepository;

  bool _isWriting = false;
  _PendingWrite? _pending;

  DocumentWriteCoordinator({
    required this.writer,
    required this.consultationRepository,
  });

  /// Requests a safe document write.
  ///
  /// If a write is currently executing, this request will be coalesced and
  /// resolved when the pending batch finishes writing.
  Future<Result<void, LipiError>> requestWrite({
    required PatientId patientId,
    required ClinicalDocument document,
    ConsultationStatus status = ConsultationStatus.saved,
  }) async {
    if (_isWriting) {
      final completer = Completer<Result<void, LipiError>>();
      final existingCompleters = _pending?.completers ?? <Completer<Result<void, LipiError>>>[];
      _pending = _PendingWrite(
        patientId: patientId,
        document: document,
        status: status,
        completers: [...existingCompleters, completer],
      );
      return completer.future;
    }

    _isWriting = true;
    try {
      final result = await _executeWrite(patientId, document, status);
      return result;
    } finally {
      _isWriting = false;
      _drainPending();
    }
  }

  Future<Result<void, LipiError>> _executeWrite(
    PatientId patientId,
    ClinicalDocument document,
    ConsultationStatus status,
  ) async {
    // 1. Safe atomic replacement of .lipi package
    final writeRes = await writer.writeDocument(
      patientId: patientId,
      document: document,
    );
    if (writeRes.isFailure) return writeRes;

    // 2. Synchronize metadata in SQLite
    final metaRes = await consultationRepository.getConsultationById(document.consultationId);
    if (metaRes.isSuccess && metaRes.valueOrNull != null) {
      final existing = metaRes.valueOrNull!;
      final updated = existing.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      final updateRes = await consultationRepository.upsertConsultation(updated);
      if (updateRes.isFailure) return Failure(updateRes.errorOrNull!);
    }

    return const Success(null);
  }

  void _drainPending() {
    if (_pending == null) return;
    final next = _pending!;
    _pending = null;

    _isWriting = true;
    _executeWrite(next.patientId, next.document, next.status).then((result) {
      for (final c in next.completers) {
        if (!c.isCompleted) c.complete(result);
      }
    }).whenComplete(() {
      _isWriting = false;
      _drainPending();
    });
  }
}
