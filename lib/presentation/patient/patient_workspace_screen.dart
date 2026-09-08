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
  List<Consultation> _consultations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsultations();
  }

  Future<void> _loadConsultations() async {
    setState(() => _isLoading = true);
    final result = await widget.dependencies.listConsultationHistoryWorkflow.execute(widget.patient.id);
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

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
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

          // Consultation History Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
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
                  '${_consultations.length} Prescriptions',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _consultations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: 56, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No prescriptions recorded yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
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
