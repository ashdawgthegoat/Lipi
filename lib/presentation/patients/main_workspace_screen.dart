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
import '../settings/theme_settings_dialog.dart';
import '../widgets/file_manager/lipi_file_manager_icons.dart';
import '../widgets/lipi_logo.dart';
import 'widgets/patient_folder_item.dart';

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
  Map<String, int> _patientVisitCounts = {};
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

    await result.fold(
      onSuccess: (list) async {
        final counts = <String, int>{};
        for (final p in list) {
          final cRes = await widget.dependencies.consultationRepository.getConsultationsForPatient(p.id);
          counts[p.id.value] = cRes.valueOrNull?.length ?? 0;
        }
        if (!mounted) return;
        setState(() {
          _patients = list;
          _patientVisitCounts = counts;
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
        final cs = Theme.of(ctx).colorScheme;
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
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
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
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.tune, color: cs.primary),
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
                    Text('Dimensions in millimeters (mm):', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
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

                    // Recommendation Banner
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.primaryContainer),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, color: cs.primary, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'For best results, use the original PDF prescription template when available.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: cs.primary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'You can also upload an image of the template (.png, .jpg).',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Text('Custom Letterhead Background (PDF or Image):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          (newTemplateFile?.path.toLowerCase().endsWith('.pdf') ??
                                  _currentDoctorProfile.templatePath?.toLowerCase().endsWith('.pdf') ??
                                  false)
                              ? const LipiFileIcon(type: LipiIconType.filePdf, size: 28)
                              : const LipiFileIcon(type: LipiIconType.fileImage, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  newTemplateFile != null
                                      ? 'New: ${newTemplateFile!.path.split('/').last}'
                                      : (_currentDoctorProfile.templatePath != null
                                          ? 'Current: ${_currentDoctorProfile.templatePath!.split('/').last}'
                                          : 'Default Vector Letterhead'),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
                                ),
                                if (newTemplateFile?.path.toLowerCase().endsWith('.pdf') == true ||
                                    (_currentDoctorProfile.templatePath?.toLowerCase().endsWith('.pdf') == true && newTemplateFile == null))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'PDF Template (Page 1 imported)',
                                      style: TextStyle(fontSize: 11, color: cs.error, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
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
                          if (newTemplateFile != null)
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: cs.error),
                              onPressed: () => setDialogState(() => newTemplateFile = null),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
        title: const Text('Confirm Patient Deletion'),
        content: Text('Are you sure you want to delete ${patient.name} and all associated prescriptions? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
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
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const LipiLogo(size: 24, borderRadius: 6),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).appBarTheme.foregroundColor?.withValues(alpha: 0.8) ?? cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Theme & Presentation',
            onPressed: () => ThemeSettingsDialog.show(context, widget.dependencies.themeService),
          ),
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
            color: cs.surface,
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
                      fillColor: cs.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cs.outlineVariant),
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
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _searchController.text.isEmpty
                                ? const LipiFolderIcon(isOpen: true, size: 80)
                                : Icon(Icons.search_off, size: 64, color: cs.outline),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No patients registered yet'
                                  : 'No matching patients found',
                              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            if (_searchController.text.isEmpty)
                              ElevatedButton(
                                onPressed: _showNewPatientDialog,
                                style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                                child: const Text('Register First Patient'),
                              ),
                          ],
                        ),
                      )
                      : GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 24,
                            childAspectRatio: 0.94,
                          ),
                          itemCount: _patients.length,
                          itemBuilder: (context, index) {
                            final patient = _patients[index];
                            final visitCount = _patientVisitCounts[patient.id.value] ?? 0;
                            return PatientFolderItem(
                              key: Key('patient_folder_${patient.id.value}'),
                              patient: patient,
                              visitCount: visitCount,
                              onTap: () => _openPatientWorkspace(patient),
                              onNewRx: () => _openPatientWorkspace(patient, startPrescriptionImmediately: true),
                              onDelete: () => _confirmDeletePatient(patient),
                            );
                          },
                        ),
          ),
        ],
      ),
    );
  }
}
