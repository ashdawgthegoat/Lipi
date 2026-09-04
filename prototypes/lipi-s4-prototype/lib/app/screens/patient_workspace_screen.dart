import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domains/doctor/doctor_service.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient_record.dart';
import '../../domains/patient/patient_service.dart';
import 'prescription_workspace_screen.dart';

class PatientWorkspaceScreen extends StatefulWidget {
  final DoctorService doctorService;
  final PatientService patientService;
  final DoctorProfile doctorProfile;
  final PatientRecord patient;
  final bool startPrescriptionImmediately;

  const PatientWorkspaceScreen({
    super.key,
    required this.doctorService,
    required this.patientService,
    required this.doctorProfile,
    required this.patient,
    this.startPrescriptionImmediately = false,
  });

  @override
  State<PatientWorkspaceScreen> createState() => _PatientWorkspaceScreenState();
}

class _PatientWorkspaceScreenState extends State<PatientWorkspaceScreen> {
  List<PrescriptionSummary> _prescriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();

    if (widget.startPrescriptionImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startNewPrescription();
      });
    }
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.patientService.getPatientPrescriptions(widget.patient.id);
      if (mounted) {
        setState(() {
          _prescriptions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clinical history: $e')),
        );
      }
    }
  }

  void _startNewPrescription() {
    final consultationId = const Uuid().v4();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrescriptionWorkspaceScreen(
          doctorService: widget.doctorService,
          patientService: widget.patientService,
          doctorProfile: widget.doctorProfile,
          patient: widget.patient,
          consultationId: consultationId,
          isReopen: false,
        ),
      ),
    ).then((_) => _loadPrescriptions());
  }

  void _reopenPrescription(PrescriptionSummary summary) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrescriptionWorkspaceScreen(
          doctorService: widget.doctorService,
          patientService: widget.patientService,
          doctorProfile: widget.doctorProfile,
          patient: widget.patient,
          consultationId: summary.consultationId,
          isReopen: true,
        ),
      ),
    ).then((_) => _loadPrescriptions());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          p.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Patient Demographic Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Age: ${p.age} Y • Gender: ${p.gender} • City: ${p.city}',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Patient ID: ${p.id.substring(0, 8)}... • Registered: ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _startNewPrescription,
                      icon: const Icon(Icons.edit_note, size: 20),
                      label: const Text('New Prescription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Prescription History Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFFF1F5F9),
            child: const Text(
              'Clinical History — Prescriptions (.lipi documents)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _prescriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.history_edu_outlined, size: 56, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            const Text(
                              'No historical prescriptions written for this patient yet.',
                              style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _startNewPrescription,
                              icon: const Icon(Icons.draw),
                              label: const Text('Write First Prescription'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A73E8),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _prescriptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _prescriptions[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.assignment, color: Color(0xFF1A73E8), size: 36),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Consultation: ${item.consultationId}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Date: ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} ${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '.lipi package',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            if (item.hasPdf) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'PDF Exported',
                                                  style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _reopenPrescription(item),
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('Reopen'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1A73E8),
                                    ),
                                  ),
                                ],
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
}
