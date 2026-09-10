import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/dependencies.dart';
import '../../domains/consultation/models/consultation.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient.dart';
import '../../infrastructure/themes/theme_model.dart';
import '../../shared/ids/ids.dart';
import '../prescription/prescription_workspace_screen.dart';
import '../widgets/file_manager/lipi_file_manager_icons.dart';
import 'widgets/prescription_file_item.dart';

class PatientWorkspaceScreen extends StatefulWidget {
  final LipiDependencies dependencies;
  final DoctorProfile doctorProfile;
  final Patient patient;

  const PatientWorkspaceScreen({
    super.key,
    required this.dependencies,
    required this.doctorProfile,
    required this.patient,
  });

  @override
  State<PatientWorkspaceScreen> createState() => _PatientWorkspaceScreenState();
}

class _PatientWorkspaceScreenState extends State<PatientWorkspaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Consultation> _consultations = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConsultations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConsultations({String? query}) async {
    setState(() => _isLoading = true);
    final effectiveQuery = query ?? _searchController.text.trim();
    _searchQuery = effectiveQuery;

    final result = effectiveQuery.isEmpty
        ? await widget.dependencies.listConsultationHistoryWorkflow
            .execute(widget.patient.id)
        : await widget.dependencies.searchConsultationsWorkflow.execute(
            patientId: widget.patient.id,
            query: effectiveQuery,
          );

    if (!mounted) return;

    result.fold(
      onSuccess: (list) {
        setState(() {
          _consultations = list;
          _isLoading = false;
        });
      },
      onFailure: (err) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading consultations: ${err.message}')),
        );
      },
    );
  }

  Future<void> _startNewPrescription() async {
    final consultationId = ConsultationId(const Uuid().v4());
    final startRes = await widget.dependencies.startConsultationWorkflow.execute(
      patientId: widget.patient.id,
      consultationId: consultationId,
    );

    if (!mounted) return;

    startRes.fold(
      onSuccess: (document) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrescriptionWorkspaceScreen(
              dependencies: widget.dependencies,
              doctorProfile: widget.doctorProfile,
              patient: widget.patient,
              consultationId: consultationId,
              isReopen: false,
              initialDocument: document,
            ),
          ),
        ).then((_) => _loadConsultations());
      },
      onFailure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start consultation: ${err.message}')),
        );
      },
    );
  }

  Future<void> _reopenPrescription(Consultation consultation) async {
    final loadRes = await widget.dependencies.loadConsultationWorkflow.execute(
      patientId: widget.patient.id,
      consultationId: consultation.id,
    );

    if (!mounted) return;

    loadRes.fold(
      onSuccess: (document) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrescriptionWorkspaceScreen(
              dependencies: widget.dependencies,
              doctorProfile: widget.doctorProfile,
              patient: widget.patient,
              consultationId: consultation.id,
              isReopen: true,
              initialDocument: document,
            ),
          ),
        ).then((_) => _loadConsultations());
      },
      onFailure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open prescription: ${err.message}')),
        );
      },
    );
  }

  void _showPrescriptionContextualDialog(Consultation consultation) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final ext = theme.extension<LipiExtendedColors>();
        final isRetro = ext?.isRetro ?? false;

        return AlertDialog(
          shape: isRetro
              ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const LipiFileIcon(type: LipiIconType.file, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateFormat.format(consultation.createdAt),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Status: ${consultation.status.name.toUpperCase()}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.open_in_new, color: cs.primary),
                title: const Text('Open Prescription'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _reopenPrescription(consultation);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: isRetro ? const Color(0xFF800000) : cs.error,
                ),
                title: Text(
                  'Delete Prescription',
                  style: TextStyle(
                    color: isRetro ? const Color(0xFF800000) : cs.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('Permanently remove this prescription sheet'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeletePrescription(consultation);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeletePrescription(Consultation consultation) async {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final ext = theme.extension<LipiExtendedColors>();
        final isRetro = ext?.isRetro ?? false;
        
        return AlertDialog(
          shape: isRetro
              ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: isRetro ? const Color(0xFF800000) : cs.error, size: 28),
              const SizedBox(width: 10),
              const Text('Delete Prescription?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete this prescription document and its digital ink.\n\nOther prescriptions and patient records will remain unaffected.',
                style: TextStyle(fontSize: 14, height: 1.4, color: cs.onSurface),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRetro ? const Color(0xFFE4E0D8) : cs.surfaceContainerLowest,
                  borderRadius: isRetro ? null : BorderRadius.circular(8),
                  border: Border.all(color: isRetro ? const Color(0xFF808080) : cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient: ${widget.patient.name}',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text('Date: ${dateFormat.format(consultation.createdAt)}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('Status: ${consultation.status.name.toUpperCase()}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRetro ? const Color(0xFF800000) : cs.error,
                foregroundColor: isRetro ? Colors.white : cs.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final res = await widget.dependencies.deleteConsultationWorkflow.execute(
        patientId: widget.patient.id,
        consultationId: consultation.id,
      );

      if (!mounted) return;

      if (res.isSuccess) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Prescription deleted successfully.'),
            backgroundColor: cs.onSurface,
          ),
        );
        _loadConsultations();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete prescription: ${res.errorOrNull?.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<LipiExtendedColors>() ??
        const LipiExtendedColors(
          success: Color(0xFF107C10),
          warning: Color(0xFFD48800),
          paperBg: Color(0xFFFFFFFF),
          selectedBg: Color(0xFFD6E8F7),
        );
    
    final patient = widget.patient;
    final isRetro = ext.isRetro;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 1,
      ),
      body: Column(
        children: [
          // Opened Patient Folder / Dossier Top Section
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Folder Tab Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: isRetro
                          ? const BoxDecoration(
                              color: Color(0xFFDDD7C8),
                              border: Border(
                                top: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                                left: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                                right: BorderSide(color: Color(0xFF000000), width: 2.0),
                              ),
                            )
                          : BoxDecoration(
                              color: ext.folderTabBg,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                              border: Border.all(
                                color: ext.folderBorder,
                                width: 1.0,
                              ),
                            ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LipiFolderIcon(
                            isOpen: true,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isRetro ? 'FILE DOSSIER' : 'PATIENT DOSSIER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isRetro ? const Color(0xFF000000) : cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Dossier Body
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: isRetro
                      ? const BoxDecoration(
                          color: Color(0xFFD4D0C8),
                          border: Border(
                            top: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                            left: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                            right: BorderSide(color: Color(0xFF000000), width: 2.0),
                            bottom: BorderSide(color: Color(0xFF000000), width: 2.0),
                          ),
                        )
                      : BoxDecoration(
                          color: ext.folderBg,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          border: Border.all(
                            color: ext.folderBorder,
                            width: 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A002040),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _badge(
                                  '${patient.age} Years',
                                  isRetro ? const Color(0xFFE4E0D8) : cs.primaryContainer,
                                  isRetro ? const Color(0xFF000080) : cs.primary,
                                  isRetro,
                                ),
                                _badge(
                                  patient.gender,
                                  isRetro ? const Color(0xFFE4E0D8) : cs.tertiaryContainer,
                                  isRetro ? const Color(0xFF008080) : cs.tertiary,
                                  isRetro,
                                ),
                                _badge(
                                  patient.city,
                                  isRetro ? const Color(0xFFE4E0D8) : cs.surfaceContainerHighest,
                                  isRetro ? const Color(0xFF000000) : cs.onSurface,
                                  isRetro,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (isRetro)
                        GestureDetector(
                          onTap: _startNewPrescription,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD4D0C8),
                              border: Border(
                                top: BorderSide(color: Color(0xFFFFFFFF), width: 2.5),
                                left: BorderSide(color: Color(0xFFFFFFFF), width: 2.5),
                                right: BorderSide(color: Color(0xFF000000), width: 2.5),
                                bottom: BorderSide(color: Color(0xFF000000), width: 2.5),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.note_add, size: 18, color: Color(0xFF000080)),
                                SizedBox(width: 8),
                                Text(
                                  'New Prescription',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _startNewPrescription,
                          icon: const Icon(Icons.note_add, size: 20),
                          label: const Text('New Prescription'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isRetro ? const Color(0xFF808080) : cs.outlineVariant),

          // Patient-Scoped Prescription Search Field
          Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: TextField(
              key: const Key('patient_prescription_search_field'),
              controller: _searchController,
              onChanged: (val) => _loadConsultations(query: val.trim()),
              decoration: InputDecoration(
                hintText: 'Search prescriptions by date (e.g. 2026-09-08, Sep)...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isRetro ? const Color(0xFF808080) : cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: isRetro ? const Color(0xFF000080) : cs.primary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadConsultations(query: '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isRetro ? const Color(0xFFFFFFFF) : cs.surfaceContainerLowest,
                isDense: true,
                border: isRetro
                    ? const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: Color(0xFF808080), width: 1.5),
                      )
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                enabledBorder: isRetro
                    ? const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: Color(0xFF808080), width: 1.5),
                      )
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          Divider(height: 1, color: isRetro ? const Color(0xFF808080) : cs.outlineVariant),

          // Consultation History Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
            child: Row(
              children: [
                const LipiFileIcon(
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Prescription & Consultation History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_consultations.length} ${_searchQuery.isNotEmpty ? "Found" : "Prescriptions"}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // History List or Search Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _consultations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _searchQuery.isNotEmpty
                                ? Icon(Icons.search_off, size: 56, color: cs.outline)
                                : const LipiFolderIcon(isOpen: true, size: 80),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No prescriptions found matching "$_searchQuery"'
                                  : 'No prescriptions recorded yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isRetro ? const Color(0xFF000000) : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try searching with another date format'
                                  : 'This patient folder is empty. Create the first clinical prescription.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isRetro ? const Color(0xFF505050) : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_searchQuery.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadConsultations(query: '');
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('Clear search filter'),
                              )
                            else if (isRetro)
                              GestureDetector(
                                onTap: _startNewPrescription,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4D0C8),
                                    border: Border(
                                      top: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                                      left: BorderSide(color: Color(0xFFFFFFFF), width: 2.0),
                                      right: BorderSide(color: Color(0xFF000000), width: 2.0),
                                      bottom: BorderSide(color: Color(0xFF000000), width: 2.0),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.create, size: 16, color: Color(0xFF000080)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Create First Prescription',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF000000),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: _startNewPrescription,
                                icon: const Icon(Icons.create, size: 18),
                                label: const Text('Create First Prescription'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                ),
                              ),
                          ],
                        ),
                      )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 24,
                            childAspectRatio: 0.88,
                          ),
                          itemCount: _consultations.length,
                          itemBuilder: (context, index) {
                            final con = _consultations[index];
                            return PrescriptionFileItem(
                              consultation: con,
                              onOpen: () => _reopenPrescription(con),
                              onDelete: () => _confirmDeletePrescription(con),
                              onLongPress: () => _showPrescriptionContextualDialog(con),
                            );
                          },
                        ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textCol, [bool isRetro = false]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: isRetro ? null : BorderRadius.circular(6),
        border: isRetro
            ? const Border(
                top: BorderSide(color: Color(0xFF808080), width: 1.0),
                left: BorderSide(color: Color(0xFF808080), width: 1.0),
                right: BorderSide(color: Color(0xFFFFFFFF), width: 1.0),
                bottom: BorderSide(color: Color(0xFFFFFFFF), width: 1.0),
              )
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textCol,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
