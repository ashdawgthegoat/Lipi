import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../domains/doctor/doctor_service.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/models/patient_record.dart';
import '../../domains/patient/patient_service.dart';
import 'patient_workspace_screen.dart';

class MainWorkspaceScreen extends StatefulWidget {
  final DoctorService doctorService;
  final PatientService patientService;
  final DoctorProfile doctorProfile;

  const MainWorkspaceScreen({
    super.key,
    required this.doctorService,
    required this.patientService,
    required this.doctorProfile,
  });

  @override
  State<MainWorkspaceScreen> createState() => _MainWorkspaceScreenState();
}

class _MainWorkspaceScreenState extends State<MainWorkspaceScreen> {
  late DoctorProfile _currentDoctorProfile;
  final _searchController = TextEditingController();
  List<PatientRecord> _patients = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentDoctorProfile = widget.doctorProfile;
    _loadPatients();
  }

  Future<void> _loadPatients([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.patientService.searchPatients(query);
      if (mounted) {
        setState(() {
          _patients = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading patients: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _loadPatients(query);
  }

  void _openPatientWorkspace(PatientRecord patient, {bool startPrescriptionImmediately = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientWorkspaceScreen(
          doctorService: widget.doctorService,
          patientService: widget.patientService,
          doctorProfile: _currentDoctorProfile,
          patient: patient,
          startPrescriptionImmediately: startPrescriptionImmediately,
        ),
      ),
    ).then((_) => _loadPatients(_searchController.text));
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age (Years) *',
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                final parsed = int.tryParse(v);
                                if (parsed == null || parsed <= 0) return 'Invalid age';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => gender = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(ctx).pop();

                    final patient = await widget.patientService.createPatient(
                      name: nameCtrl.text.trim(),
                      age: int.parse(ageCtrl.text.trim()),
                      gender: gender,
                      city: cityCtrl.text.trim(),
                    );

                    _openPatientWorkspace(patient, startPrescriptionImmediately: true);
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Create & Prescribe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showTemplateSettingsDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasCustom = _currentDoctorProfile.templatePath != null;
          return AlertDialog(
            title: const Text('Prescription Template Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Template: ${hasCustom ? "Custom Letterhead" : "Default Letterhead"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (hasCustom)
                  Text(
                    'Path: ${_currentDoctorProfile.templatePath}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  )
                else
                  const Text(
                    'Using standard Lipi generic clinic prescription letterhead layout.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      File? templateFile;
                      // 1. Check if tablet test template exists
                      final sampleFile = File('/data/user/0/com.lipi.lipi_s4_prototype/app_flutter/LipiVault/doctor/templates/custom_template.png');
                      final sdcardSample = File('/sdcard/Download/sample_custom_template.png');
                      if (await sampleFile.exists()) {
                        templateFile = sampleFile;
                      } else if (await sdcardSample.exists()) {
                        templateFile = sdcardSample;
                      } else {
                        try {
                          final files = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['png', 'jpg', 'jpeg'],
                          );
                          if (files.isNotEmpty && files.first.path != null) {
                            templateFile = File(files.first.path!);
                          }
                        } catch (e) {
                          debugPrint('File picker error: $e');
                        }
                      }

                      if (templateFile != null && await templateFile.exists()) {
                        final updated = await widget.doctorService.saveProfile(
                          _currentDoctorProfile,
                          customTemplateFile: templateFile,
                        );
                        if (mounted) {
                          setState(() {
                            _currentDoctorProfile = updated;
                          });
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Custom prescription template activated!')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Use Custom Template Letterhead'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updated = await widget.doctorService.saveProfile(
                        _currentDoctorProfile,
                        customTemplateFile: null,
                      );
                      if (mounted) {
                        setState(() {
                          _currentDoctorProfile = updated;
                        });
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Switched to Generic / Default template')),
                        );
                      }
                    },
                    icon: const Icon(Icons.format_paint),
                    label: const Text('Use Default Generic Letterhead'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentDoctorProfile.clinicName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_currentDoctorProfile.name} • ${_currentDoctorProfile.qualifications}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Template Settings',
            onPressed: _showTemplateSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Top Action Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                // Patient Search Bar
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search returning patient by name or city...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _loadPatients();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // New Patient Action
                ElevatedButton.icon(
                  onPressed: _showNewPatientDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('New Patient'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Patients List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _patients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_shared_outlined, size: 64, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No patients registered in this Vault yet.'
                                  : 'No matching patients found for "${_searchController.text}".',
                              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showNewPatientDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Register New Patient'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _patients.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = _patients[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE2E8F0),
                                foregroundColor: const Color(0xFF1E293B),
                                child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P'),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2F6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${p.age} Y • ${p.gender}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('City: ${p.city} • Registered: ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}'),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                              onTap: () => _openPatientWorkspace(p),
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
