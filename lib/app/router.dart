import 'package:flutter/material.dart';

class AppRoutes {
  static const String root = '/';
  static const String firstLaunch = '/first-launch';
  static const String doctorSetup = '/doctor-setup';
  static const String patients = '/patients';
  static const String patient = '/patient';
  static const String prescription = '/prescription';
  static const String settings = '/settings';
}

/// Simple, robust navigation helper adhering to MVP guidelines.
class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
      case AppRoutes.firstLaunch:
      case AppRoutes.patients:
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('Lipi Clinical Workspace'),
            ),
          ),
        );
    }
  }
}
