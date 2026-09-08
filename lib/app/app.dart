import 'package:flutter/material.dart';
import '../domains/doctor/models/doctor_profile.dart';
import '../infrastructure/themes/built_in_themes.dart';
import '../infrastructure/themes/theme_model.dart';
import '../presentation/first_launch/first_launch_screen.dart';
import '../presentation/patients/main_workspace_screen.dart';
import '../presentation/widgets/lipi_logo.dart';
import 'dependencies.dart';
import 'workflows/initialize_application_workflow.dart';

/// Root application widget for Lipi.
class LipiApp extends StatefulWidget {
  final LipiDependencies? dependencies;
  final AppInitResult? initialInitResult;

  const LipiApp({
    super.key,
    this.dependencies,
    this.initialInitResult,
  });

  @override
  State<LipiApp> createState() => _LipiAppState();
}

class _LipiAppState extends State<LipiApp> {
  LipiDependencies? _dependencies;
  bool _isLoading = true;
  String? _errorMessage;
  AppLaunchDestination? _destination;
  DoctorProfile? _doctorProfile;

  @override
  void initState() {
    super.initState();
    if (widget.initialInitResult != null && widget.dependencies != null) {
      _dependencies = widget.dependencies;
      _destination = widget.initialInitResult!.destination;
      _doctorProfile = widget.initialInitResult!.doctorProfile;
      _isLoading = false;
    } else {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deps = widget.dependencies ?? await LipiDependencies.create();
      _dependencies = deps;

      final initResult = await deps.initWorkflow.execute();
      if (!mounted) return;

      initResult.fold(
        onSuccess: (res) {
          setState(() {
            _destination = res.destination;
            _doctorProfile = res.doctorProfile;
            _isLoading = false;
          });
        },
        onFailure: (err) {
          setState(() {
            _errorMessage = err.message;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = _dependencies?.themeService.activeThemeNotifier;
    if (themeNotifier != null) {
      return ValueListenableBuilder<LipiTheme>(
        valueListenable: themeNotifier,
        builder: (context, activeTheme, _) {
          return MaterialApp(
            title: 'Lipi',
            debugShowCheckedModeBanner: false,
            theme: activeTheme.toThemeData(),
            home: _buildHome(),
          );
        },
      );
    }

    return MaterialApp(
      title: 'Lipi',
      debugShowCheckedModeBanner: false,
      theme: BuiltInThemes.defaultTheme.toThemeData(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LipiLogo(size: 64, borderRadius: 12),
              SizedBox(height: 16),
              Text(
                'Lipi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
              ),
              SizedBox(height: 8),
              Text(
                'Clinical Digital Ink Workspace',
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2.5),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text('Application Initialization Failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _bootstrap,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final deps = _dependencies!;
    if (_destination == AppLaunchDestination.mainWorkspace && _doctorProfile != null) {
      return MainWorkspaceScreen(
        dependencies: deps,
        doctorProfile: _doctorProfile!,
      );
    }

    return FirstLaunchScreen(dependencies: deps);
  }
}
