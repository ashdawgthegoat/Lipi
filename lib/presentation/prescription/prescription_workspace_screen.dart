import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../app/dependencies.dart';
import '../../domains/consultation/models/clinical_document.dart';
import '../../domains/consultation/models/ink_document.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient.dart';
import '../../infrastructure/documents/autosave_controller.dart';
import '../../infrastructure/documents/save_state.dart';
import '../../infrastructure/export/pdf_exporter.dart';
import '../../infrastructure/ink/native_ink_canvas.dart';
import '../../infrastructure/ink/native_ink_controller.dart';
import '../../infrastructure/themes/theme_model.dart';
import '../../shared/ids/ids.dart';

class PrescriptionWorkspaceScreen extends StatefulWidget {
  final LipiDependencies dependencies;
  final DoctorProfile doctorProfile;
  final Patient patient;
  final ConsultationId consultationId;
  final bool isReopen;
  final ClinicalDocument initialDocument;

  const PrescriptionWorkspaceScreen({
    super.key,
    required this.dependencies,
    required this.doctorProfile,
    required this.patient,
    required this.consultationId,
    required this.isReopen,
    required this.initialDocument,
  });

  @override
  State<PrescriptionWorkspaceScreen> createState() => _PrescriptionWorkspaceScreenState();
}

class _PrescriptionWorkspaceScreenState extends State<PrescriptionWorkspaceScreen> {
  late ClinicalDocument _currentDocument;
  late final AutosaveController _autosaveController;
  late final NativeInkController _inkController;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _currentDocument = widget.initialDocument;

    _autosaveController = AutosaveController(
      patientId: widget.patient.id,
      consultationId: widget.consultationId,
      writeCoordinator: widget.dependencies.writeCoordinator,
      debounceDuration: const Duration(milliseconds: 800),
    );

    _inkController = NativeInkController(
      initialStrokeWidth: widget.doctorProfile.preferences.defaultPenWidth,
      initialStrokeColor: widget.doctorProfile.preferences.defaultPenColor,
    );
    _inkController.loadDocument(_currentDocument);
    _inkController.onDocumentChanged = _onInkChanged;
  }

  @override
  void dispose() {
    _inkController.dispose();
    _autosaveController.dispose();
    super.dispose();
  }

  void _onInkChanged(InkDocument inkDoc) {
    _currentDocument = _currentDocument.copyWith(ink: inkDoc);
    _autosaveController.notifyDocumentChanged(_currentDocument);
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      // 1. Flush any pending ink sync and autosave
      _currentDocument = _currentDocument.copyWith(ink: _inkController.exportCurrentInk());
      await _autosaveController.saveNow();

      // 2. Generate PDF bytes from canonical clinical document
      final pdfBytes = await PdfExporter.generatePdfBytes(
        document: _currentDocument,
      );

      if (!mounted) return;

      // 3. Open system print / share / preview sheet
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: 'Prescription_${widget.patient.name}_${widget.consultationId.value.substring(0, 8)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleClose() async {
    _currentDocument = _currentDocument.copyWith(ink: _inkController.exportCurrentInk());
    await _autosaveController.saveNow();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _currentDocument = _currentDocument.copyWith(ink: _inkController.exportCurrentInk());
          _autosaveController.saveNow();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Prescription — ${widget.patient.name} (${widget.patient.age} Y)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Reactive Autosave Status Pill
            ValueListenableBuilder<SaveState>(
              valueListenable: _autosaveController.stateNotifier,
              builder: (context, state, _) {
                return _buildSaveStatusPill(state);
              },
            ),
            const SizedBox(width: 8),

            // Deliberate PDF Export
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _isExporting ? null : _exportPdf,
            ),

            // Done / Save & Exit Action
            TextButton.icon(
              onPressed: _handleClose,
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
              label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: NativeInkCanvas(
          controller: _inkController,
          document: _currentDocument,
          dateString: _currentDocument.createdAt.toIso8601String().split('T').first,
          isDesktopMode: !Platform.isAndroid,
        ),
      ),
    );
  }

  Widget _buildSaveStatusPill(SaveState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<LipiExtendedColors>()!;

    String label = 'Saved';
    Color color = ext.success;
    IconData icon = Icons.check;

    if (state.isSaving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    } else if (state.isDirty) {
      label = 'Unsaved changes';
      color = ext.warning;
      icon = Icons.edit;
    } else if (state.hasError) {
      label = 'Save error';
      color = cs.error;
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
