import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/app/app.dart';
import 'package:lipi/app/dependencies.dart';
import 'package:lipi/app/workflows/initialize_application_workflow.dart';
import 'package:lipi/infrastructure/database/vault_database.dart';
import 'package:lipi/infrastructure/security/secure_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VaultDatabase.initializeFfiIfRequired();

  late Directory tempDir;
  late LipiDependencies deps;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lipi_widget_test_');
    deps = await LipiDependencies.create(
      customVaultDir: tempDir,
      customSecureStorage: InMemorySecureKeyStore(),
    );
  });

  tearDown(() async {
    await deps.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('LipiApp renders FirstLaunchScreen when doctor is unconfigured', (WidgetTester tester) async {
    await tester.pumpWidget(LipiApp(
      dependencies: deps,
      initialInitResult: const AppInitResult(destination: AppLaunchDestination.doctorSetup),
    ));

    expect(find.text('Lipi — Clinical Setup'), findsOneWidget);
    expect(find.text('Doctor & Clinic Profile'), findsOneWidget);
    expect(find.text('Save & Enter Workspace'), findsOneWidget);
  });
}
