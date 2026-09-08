import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app/dependencies.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/doctor/models/template_config.dart';
import '../../domains/patient/models/patient.dart';
import '../../domains/patient/models/patient_info.dart';
import '../../shared/ids/ids.dart';
import '../patient/patient_workspace_screen.dart';
import '../prescription/prescription_workspace_screen.dart';

class MainWorkspaceScreen extends StatefulWidget {
  final LipiDependencies dependencies;
  final DoctorProfile doctorProfile;

  const MainWorkspaceScreen({
    super.key,
    required this.dependencies,
    required this.doctorProfile,
  });

  @override
  State<MainWorkspaceScreen> createState() => _MainWorkspaceScreenState();
}

class _MainWorkspaceScreenState extends State<MainWorkspaceScreen> {
  late DoctorProfile _currentDoctorProfile;
  final _searchController = TextEditingController();
  List<Patient> _patients = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentDoctorProfile = widget.doctorProfile;
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients([String query = '']) async {
    setState(() => _isLoading = true);
    final result = await widget.dependencies.searchPatientsWorkflow.execute(query);
    if (!mounted) return;

    result.fold(
      onSuccess: (list) {
        setState(() {
          _patients = list;
          _isLoading = false;
        });
      },
      onFailure: (err) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading patients: ${err.message}')),
        );
      },
    );
  }

  void _openPatientWorkspace(Patient patient, {bool startPrescriptionImmediately = false}) {
    if (startPrescriptionImmediately) {
      _startPrescriptionForPatient(patient);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientWorkspaceScreen(
          dependencies: widget.dependencies,
          doctorProfile: _currentDoctorProfile,
          patient: patient,
        ),
      ),
    ).then((_) => _loadPatients(_searchController.text.trim()));
  }

  Future<void> _startPrescriptionForPatient(Patient patient) async {
    final consultationId = ConsultationId(const Uuid().v4());
    final startRes = await widget.dependencies.startConsultationWorkflow.execute(
      patientId: patient.id,
      consultationId: consultationId,
    );

    if (!mounted) return;

    startRes.fold(
      onSuccess: (document) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrescriptionWorkspaceScreen(
              dependencies: widget.dependencies,
              doctorProfile: _currentDoctorProfile,
              patient: patient,
              consultationId: consultationId,
              isReopen: false,
              initialDocument: document,
            ),
          ),
        ).then((_) => _loadPatients(_searchController.text.trim()));
      },
      onFailure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start consultation: ${err.message}')),
        );
      },
    );
  }

  void _showNewPatientDialog() {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String gender = 'Male';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Patient Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        nameCtrl.text = 'Ravi Kumar';
                        ageCtrl.text = '42';
                        cityCtrl.text = 'Pune';
                        gender = 'Male';
                      });
                    },
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text('Sample Data', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Patient Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: ageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age *',
                                prefixIcon: Icon(Icons.cake),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => gender = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'City / Location',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A365D),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final nav = Navigator.of(ctx);

                    final patientInfo = PatientInfo(
                      name: nameCtrl.text.trim(),
                      age: int.parse(ageCtrl.text.trim()),
                      gender: gender,
                      city: cityCtrl.text.trim().isEmpty ? 'Unknown' : cityCtrl.text.trim(),
                    );

                    final createRes = await widget.dependencies.createPatientWorkflow.execute(
                      info: patientInfo,
                    );

                    createRes.fold(
                      onSuccess: (newPatient) {
                        nav.pop();
                        _loadPatients(_searchController.text.trim());
                        _openPatientWorkspace(newPatient);
                      },
                      onFailure: (err) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to create patient: ${err.message}')),
                        );
                      },
                    );
                  },
                  child: const Text('Register & Open'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTemplateConfigDialog() {
    final widthCtrl = TextEditingController(text: _currentDoctorProfile.templateWidthMm.toStringAsFixed(0));
    final heightCtrl = TextEditingController(text: _currentDoctorProfile.templateHeightMm.toStringAsFixed(0));
    File? newTemplateFile;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.tune, color: Color(0xFF1A365D)),
                  SizedBox(width: 10),
                  Text('Prescription Pad & Letterhead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dimensions in millimeters (mm):', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: widthCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Width (mm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: heightCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Height (mm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Custom Letterhead Background:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            newTemplateFile != null
                                ? 'New: ${newTemplateFile!.path.split('/').last}'
                                : (_currentDoctorProfile.templatePath != null
                                    ? 'Current: ${_currentDoctorProfile.templatePath!.split('/').last}'
                                    : 'Default Vector Letterhead'),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['png', 'jpg', 'jpeg'],
                            );
                            if (picked.isNotEmpty && picked.first.path != null) {
                              setDialogState(() {
                                newTemplateFile = File(picked.first.path!);
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A365D), foregroundColor: Colors.white),
                  onPressed: () async {
                    final nav = Navigator.of(ctx);
                    final width = double.tryParse(widthCtrl.text) ?? 180.0;
                    final height = double.tryParse(heightCtrl.text) ?? 260.0;

                    final config = TemplateConfig(
                      widthMm: width,
                      heightMm: height,
                      unit: 'mm',
                      customTemplatePath: _currentDoctorProfile.templatePath,
                    );

                    final res = await widget.dependencies.configureTemplateWorkflow.execute(
                      templateConfig: config,
                      customTemplateFile: newTemplateFile,
                    );

                    res.fold(
                      onSuccess: (updatedProfile) {
                        setState(() => _currentDoctorProfile = updatedProfile);
                        nav.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prescription pad configuration updated')),
                        );
                      },
                      onFailure: (err) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating template: ${err.message}')),
                        );
                      },
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeletePatient(Patient patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Patient Deletion'),
        content: Text('Are you sure you want to delete ${patient.name} and all associated prescriptions? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final delRes = await widget.dependencies.deletePatientWorkflow.execute(patient.id);
              nav.pop();

              delRes.fold(
                onSuccess: (_) {
                  _loadPatients(_searchController.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Patient ${patient.name} deleted')),
                  );
                },
                onFailure: (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete patient: ${err.message}')),
                  );
                },
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.local_hospital, color: Colors.blueAccent, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentDoctorProfile.clinicName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _currentDoctorProfile.name,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configure Prescription Pad',
            onPressed: _showTemplateConfigDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search and Action Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _loadPatients(val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search patients by name, city, or ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadPatients();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showNewPatientDialog,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('New Patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A365D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Patients List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No patients registered yet'
                                  : 'No matching patients found',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            if (_searchController.text.isEmpty)
                              ElevatedButton(
                                onPressed: _showNewPatientDialog,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A365D), foregroundColor: Colors.white),
                                child: const Text('Register First Patient'),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _patients.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final patient = _patients[index];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openPatientWorkspace(patient),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFF1A365D).withValues(alpha: 0.1),
                                      child: Text(
                                        patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A365D), fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            patient.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${patient.age} Y • ${patient.gender} • ${patient.city}',
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _openPatientWorkspace(patient, startPrescriptionImmediately: true),
                                      icon: const Icon(Icons.edit_note, size: 18),
                                      label: const Text('New Rx'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF1A365D),
                                        side: const BorderSide(color: Color(0xFF1A365D)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                      tooltip: 'Delete Patient',
                                      onPressed: () => _confirmDeletePatient(patient),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
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
}
