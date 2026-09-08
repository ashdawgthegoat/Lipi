import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/dependencies.dart';
import '../../domains/consultation/models/consultation.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient.dart';
import '../../shared/ids/ids.dart';
import '../prescription/prescription_workspace_screen.dart';

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

  Future<void> _confirmDeletePrescription(Consultation consultation) async {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 10),
            Text('Delete Prescription?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete this prescription document and its digital ink.\n\nOther prescriptions and patient records will remain unaffected.',
              style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${dateFormat.format(consultation.createdAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text('Status: ${consultation.status.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('ID: ${consultation.id.value}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final res = await widget.dependencies.deleteConsultationWorkflow.execute(
        patientId: widget.patient.id,
        consultationId: consultation.id,
      );

      if (!mounted) return;

      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription deleted successfully.'),
            backgroundColor: Color(0xFF1E293B),
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
    final patient = widget.patient;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 1,
      ),
      body: Column(
        children: [
          // Patient Demographic Summary Card
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _badge('${patient.age} Years', Colors.blue[50]!, Colors.blue[900]!),
                            const SizedBox(width: 8),
                            _badge(patient.gender, Colors.purple[50]!, Colors.purple[900]!),
                            const SizedBox(width: 8),
                            _badge(patient.city, Colors.grey[100]!, Colors.grey[800]!),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _startNewPrescription,
                      icon: const Icon(Icons.note_add, size: 20),
                      label: const Text('New Prescription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A365D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Patient ID: ${patient.id.value}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Patient-Scoped Prescription Search Field
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: TextField(
              key: const Key('patient_prescription_search_field'),
              controller: _searchController,
              onChanged: (val) => _loadConsultations(query: val.trim()),
              decoration: InputDecoration(
                hintText: 'Search prescriptions by date (e.g. 2026-09-08, Sep) or ID...',
                prefixIcon: const Icon(Icons.search, size: 20),
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
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Consultation History Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
            child: Row(
              children: [
                const Icon(Icons.history, size: 20, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                const Text(
                  'Prescription & Consultation History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Text(
                  '${_consultations.length} ${_searchQuery.isNotEmpty ? "Found" : "Prescriptions"}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.description_outlined,
                              size: 56,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No prescriptions found matching "$_searchQuery"'
                                  : 'No prescriptions recorded yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            if (_searchQuery.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadConsultations(query: '');
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('Clear search filter'),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: _startNewPrescription,
                                icon: const Icon(Icons.create, size: 18),
                                label: const Text('Create First Prescription'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A365D),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _consultations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final con = _consultations[index];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _reopenPrescription(con),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A365D).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.edit_document, color: Color(0xFF1A365D), size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateFormat.format(con.createdAt),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Status: ${con.status.name.toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: con.status.name == 'saved' ? Colors.green[700] : Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _reopenPrescription(con),
                                      icon: const Icon(Icons.open_in_new, size: 16),
                                      label: const Text('Open'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF1A365D),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      key: Key('delete_prescription_${con.id.value}'),
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
                                      tooltip: 'Delete Prescription',
                                      onPressed: () => _confirmDeletePrescription(con),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: textCol, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
