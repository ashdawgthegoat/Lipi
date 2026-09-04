import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domains/doctor/doctor_service.dart';
import '../../domains/doctor/models/doctor_profile.dart';
import '../../domains/patient/patient_service.dart';
import 'main_workspace_screen.dart';

class FirstRunScreen extends StatefulWidget {
  final DoctorService doctorService;
  final PatientService patientService;

  const FirstRunScreen({
    super.key,
    required this.doctorService,
    required this.patientService,
  });

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Dr. Aarti Sharma');
  final _clinicController = TextEditingController(text: 'City Health Clinic');
  final _qualificationsController = TextEditingController(text: 'MBBS, MD (General Medicine)');
  final _regNumberController = TextEditingController(text: 'MCI-45892');
  final _widthController = TextEditingController(text: '180');
  final _heightController = TextEditingController(text: '260');

  File? _customTemplateFile;
  bool _isSaving = false;

  Future<void> _pickTemplateFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        final path = files.first.path!;
        final file = File(path);
        final size = await file.length();
        debugPrint('[Lipi][Template] Step 1: Doctor selected template file: path=$path, size=$size bytes');
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
      final profile = DoctorProfile(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        clinicName: _clinicController.text.trim(),
        qualifications: _qualificationsController.text.trim(),
        regNumber: _regNumberController.text.trim(),
        templateWidthMm: double.tryParse(_widthController.text) ?? 180.0,
        templateHeightMm: double.tryParse(_heightController.text) ?? 260.0,
        templateUnit: 'mm',
        // templatePath intentionally absent here — saveProfile resolves and returns it
      );

      debugPrint('[Lipi][Template] Initializing workspace with doctor "${profile.name}", clinic "${profile.clinicName}". Custom template: ${_customTemplateFile?.path ?? "NONE (Default Letterhead)"}');

      final savedProfile = await widget.doctorService.saveProfile(
        profile,
        customTemplateFile: _customTemplateFile,
      );

      debugPrint('[Lipi][Template] Profile saved successfully: id=${savedProfile.id}, templatePath=${savedProfile.templatePath}');

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainWorkspaceScreen(
            doctorService: widget.doctorService,
            patientService: widget.patientService,
            doctorProfile: savedProfile, // ← use the profile with templatePath set
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving doctor profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Project Lipi — Doctor Setup',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Welcome to Lipi',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please provide minimal doctor details to initialize your local Vault and prescription template.',
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                      const Divider(height: 32),

                      // Doctor Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Doctor Full Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Clinic Name
                      TextFormField(
                        controller: _clinicController,
                        decoration: const InputDecoration(
                          labelText: 'Clinic / Hospital Name *',
                          prefixIcon: Icon(Icons.local_hospital),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Qualifications & Reg
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _qualificationsController,
                              decoration: const InputDecoration(
                                labelText: 'Qualifications',
                                hintText: 'e.g. MBBS, MD',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _regNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Registration No.',
                                hintText: 'e.g. MCI-12345',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Prescription Template section
                      const Text(
                        'Prescription Template (Doctor Domain)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose between default professional letterhead or import your custom image/PDF.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _customTemplateFile != null ? Icons.image : Icons.description_outlined,
                              color: const Color(0xFF0F172A),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _customTemplateFile != null
                                        ? 'Custom template: ${_customTemplateFile!.path.split('/').last}'
                                        : 'Standard Clinic Letterhead (Default)',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    _customTemplateFile != null
                                        ? 'Stored under Doctor Domain in Vault'
                                        : 'Automatically uses clinic and doctor information',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickTemplateFile,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: Text(_customTemplateFile == null ? 'Import' : 'Change'),
                            ),
                            if (_customTemplateFile != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _customTemplateFile = null;
                                  });
                                  debugPrint('[Lipi][Template] Custom template cleared — using default template');
                                },
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                tooltip: 'Reset to Default Template',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Page Dimensions
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _widthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Page Width (mm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Page Height (mm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Initialize Lipi Workspace',
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
