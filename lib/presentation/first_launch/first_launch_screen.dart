import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../app/dependencies.dart';
import '../../domains/doctor/models/doctor_preferences.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/doctor/models/template_config.dart';
import '../../shared/ids/ids.dart';
import '../patients/main_workspace_screen.dart';

class FirstLaunchScreen extends StatefulWidget {
  final LipiDependencies dependencies;

  const FirstLaunchScreen({
    super.key,
    required this.dependencies,
  });

  @override
  State<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

class _FirstLaunchScreenState extends State<FirstLaunchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Dr. Aarti Sharma');
  final _clinicController = TextEditingController(text: 'City Health Clinic');
  final _qualificationsController = TextEditingController(text: 'MBBS, MD (General Medicine)');
  final _regNumberController = TextEditingController(text: 'MCI-45892');
  final _widthController = TextEditingController(text: '180');
  final _heightController = TextEditingController(text: '260');

  File? _customTemplateFile;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _clinicController.dispose();
    _qualificationsController.dispose();
    _regNumberController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pickTemplateFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        setState(() {
          _customTemplateFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final width = double.tryParse(_widthController.text.trim()) ?? 180.0;
      final height = double.tryParse(_heightController.text.trim()) ?? 260.0;

      final profile = DoctorProfile(
        id: DoctorId('doc-1'),
        name: _nameController.text.trim(),
        clinicName: _clinicController.text.trim(),
        qualifications: _qualificationsController.text.trim(),
        regNumber: _regNumberController.text.trim(),
        templateConfig: TemplateConfig(
          widthMm: width,
          heightMm: height,
          unit: 'mm',
        ),
        preferences: const DoctorPreferences(),
      );

      final result = await widget.dependencies.configureDoctorWorkflow.execute(
        profile: profile,
        customTemplateFile: _customTemplateFile,
      );

      if (!mounted) return;

      result.fold(
        onSuccess: (savedProfile) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainWorkspaceScreen(
                dependencies: widget.dependencies,
                doctorProfile: savedProfile,
              ),
            ),
          );
        },
        onFailure: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving doctor profile: ${err.message}')),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Lipi — Clinical Setup', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A365D).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_hospital, color: Color(0xFF1A365D), size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Doctor & Clinic Profile',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Configure your identity and prescription pad dimensions.',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 36),

                      // Doctor Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Doctor Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Clinic Name
                      TextFormField(
                        controller: _clinicController,
                        decoration: const InputDecoration(
                          labelText: 'Clinic / Hospital Name *',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Qualifications & Reg No
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _qualificationsController,
                              decoration: const InputDecoration(
                                labelText: 'Qualifications',
                                prefixIcon: Icon(Icons.school),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _regNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Registration No.',
                                prefixIcon: Icon(Icons.badge),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 36),

                      // Prescription Pad Geometry
                      const Text(
                        'Prescription Pad Dimensions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Default printable canvas area in millimeters (mm).',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _widthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Width (mm)',
                                suffixText: 'mm',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => double.tryParse(v ?? '') == null ? 'Enter number' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Height (mm)',
                                suffixText: 'mm',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => double.tryParse(v ?? '') == null ? 'Enter number' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Custom Template Letterhead Image Picker
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image, color: Color(0xFF3B82F6), size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Custom Letterhead Image (Optional)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    _customTemplateFile != null
                                        ? 'Selected: ${_customTemplateFile!.path.split('/').last}'
                                        : 'Using default vector clinic letterhead',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _customTemplateFile != null ? Colors.green[700] : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickTemplateFile,
                              icon: const Icon(Icons.folder_open, size: 18),
                              label: Text(_customTemplateFile != null ? 'Change' : 'Upload'),
                            ),
                            if (_customTemplateFile != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                onPressed: () => setState(() => _customTemplateFile = null),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action buttons
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A365D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Save & Enter Workspace',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
