import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domains/consultation/consultation_repository.dart';
import '../domains/doctor/doctor_repository.dart';
import '../domains/patient/patient_repository.dart';
import '../infrastructure/database/sqlite_consultation_repository.dart';
import '../infrastructure/database/sqlite_doctor_repository.dart';
import '../infrastructure/database/sqlite_patient_repository.dart';
import '../infrastructure/database/vault_database.dart';
import '../infrastructure/documents/atomic_document_writer.dart';
import '../infrastructure/documents/document_repository.dart';
import '../infrastructure/documents/document_write_coordinator.dart';
import '../infrastructure/documents/vault_document_repository.dart';
import '../infrastructure/ink/editor_runtime_server.dart';
import '../infrastructure/security/secure_key_store.dart';
import '../infrastructure/security/vault_authentication.dart';
import '../infrastructure/security/vault_crypto.dart';
import '../infrastructure/security/vault_key_store.dart';
import '../infrastructure/themes/theme_service.dart';
import '../infrastructure/vault/vault.dart';
import '../infrastructure/vault/vault_backup_service.dart';
import 'workflows/consultation_workflows.dart';
import 'workflows/doctor_workflows.dart';
import 'workflows/initialize_application_workflow.dart';
import 'workflows/patient_workflows.dart';

/// Central dependency container providing initialized infrastructure, repositories,
/// and application workflows.
class LipiDependencies {
  final LipiVault vault;
  final VaultDatabase database;
  final SecureKeyStore secureStorage;
  final VaultKeyStore keyStore;
  final VaultCrypto crypto;
  final VaultAuthentication auth;

  final DoctorRepository doctorRepository;
  final PatientRepository patientRepository;
  final ConsultationRepository consultationRepository;
  final DocumentRepository documentRepository;
  final AtomicDocumentWriter atomicWriter;
  final DocumentWriteCoordinator writeCoordinator;
  final EditorRuntimeServer editorServer;
  final VaultBackupService vaultBackupService;
  final ThemeService themeService;

  // Workflows
  final InitializeApplicationWorkflow initWorkflow;
  final ConfigureDoctorWorkflow configureDoctorWorkflow;
  final ConfigureTemplateWorkflow configureTemplateWorkflow;
  final CreatePatientWorkflow createPatientWorkflow;
  final SearchPatientsWorkflow searchPatientsWorkflow;
  final OpenPatientWorkflow openPatientWorkflow;
  final DeletePatientWorkflow deletePatientWorkflow;
  final StartConsultationWorkflow startConsultationWorkflow;
  final LoadConsultationWorkflow loadConsultationWorkflow;
  final SaveConsultationWorkflow saveConsultationWorkflow;
  final ListConsultationHistoryWorkflow listConsultationHistoryWorkflow;
  final SearchConsultationsWorkflow searchConsultationsWorkflow;
  final DeleteConsultationWorkflow deleteConsultationWorkflow;

  LipiDependencies._({
    required this.vault,
    required this.database,
    required this.secureStorage,
    required this.keyStore,
    required this.crypto,
    required this.auth,
    required this.doctorRepository,
    required this.patientRepository,
    required this.consultationRepository,
    required this.documentRepository,
    required this.atomicWriter,
    required this.writeCoordinator,
    required this.editorServer,
    required this.vaultBackupService,
    required this.themeService,
    required this.initWorkflow,
    required this.configureDoctorWorkflow,
    required this.configureTemplateWorkflow,
    required this.createPatientWorkflow,
    required this.searchPatientsWorkflow,
    required this.openPatientWorkflow,
    required this.deletePatientWorkflow,
    required this.startConsultationWorkflow,
    required this.loadConsultationWorkflow,
    required this.saveConsultationWorkflow,
    required this.listConsultationHistoryWorkflow,
    required this.searchConsultationsWorkflow,
    required this.deleteConsultationWorkflow,
  });

  /// Factory to initialize all dependencies.
  static Future<LipiDependencies> create({
    Directory? customVaultDir,
    SecureKeyStore? customSecureStorage,
  }) async {
    VaultDatabase.initializeFfiIfRequired();

    final Directory vaultDir;
    final Directory themesDir;
    if (customVaultDir != null) {
      vaultDir = customVaultDir;
      themesDir = Directory(p.join(customVaultDir.path, 'themes'));
    } else {
      final appDocsDir = await getApplicationDocumentsDirectory();
      vaultDir = Directory(p.join(appDocsDir.path, 'lipi_vault'));
      themesDir = Directory(p.join(appDocsDir.path, 'themes'));
    }

    final themeService = await ThemeService.create(storageDirectory: themesDir);

    final vault = LipiVault(vaultDir);
    await vault.initialize();

    final database = VaultDatabase();
    if (!database.isOpen) {
      await database.open(vault.dbFile);
    }

    final secureStorage = customSecureStorage ?? PlatformSecureKeyStore();
    final keyStore = VaultKeyStore(secureStorage);
    final crypto = VaultCrypto();
    final auth = VaultAuthentication(keyStore);

    // Auto-unlock vault if key exists
    try {
      await auth.unlock();
    } catch (_) {}

    final doctorRepo = SqliteDoctorRepository(database);
    final patientRepo = SqlitePatientRepository(database);
    final consultationRepo = SqliteConsultationRepository(database);

    final atomicWriter = DefaultAtomicDocumentWriter(
      vault,
      crypto: crypto,
      auth: auth,
    );

    final docRepo = VaultDocumentRepository(
      vault,
      crypto: crypto,
      auth: auth,
      atomicWriter: atomicWriter,
    );

    final writeCoordinator = DocumentWriteCoordinator(
      writer: atomicWriter,
      consultationRepository: consultationRepo,
    );

    final editorServer = EditorRuntimeServer.instance;

    final vaultBackupService = VaultBackupService(
      vault: vault,
      database: database,
    );

    final initWorkflow = InitializeApplicationWorkflow(
      vault: vault,
      database: database,
      doctorRepository: doctorRepo,
    );

    final configureDoctorWorkflow = ConfigureDoctorWorkflow(
      doctorRepository: doctorRepo,
      vault: vault,
    );

    final configureTemplateWorkflow = ConfigureTemplateWorkflow(
      configureDoctorWorkflow: configureDoctorWorkflow,
      doctorRepository: doctorRepo,
    );

    final createPatientWorkflow = CreatePatientWorkflow(
      vault: vault,
      patientRepository: patientRepo,
    );

    final searchPatientsWorkflow = SearchPatientsWorkflow(patientRepo);

    final openPatientWorkflow = OpenPatientWorkflow(
      patientRepository: patientRepo,
      consultationRepository: consultationRepo,
    );

    final deletePatientWorkflow = DeletePatientWorkflow(
      vault: vault,
      patientRepository: patientRepo,
      consultationRepository: consultationRepo,
    );

    final startConsultationWorkflow = StartConsultationWorkflow(
      doctorRepository: doctorRepo,
      patientRepository: patientRepo,
      consultationRepository: consultationRepo,
      documentRepository: docRepo,
      vault: vault,
    );

    final loadConsultationWorkflow = LoadConsultationWorkflow(docRepo);

    final saveConsultationWorkflow = SaveConsultationWorkflow(
      documentRepository: docRepo,
      consultationRepository: consultationRepo,
    );

    final listConsultationHistoryWorkflow = ListConsultationHistoryWorkflow(
      consultationRepository: consultationRepo,
    );

    final deleteConsultationWorkflow = DeleteConsultationWorkflow(
      vault: vault,
      consultationRepository: consultationRepo,
      documentRepository: docRepo,
    );

    final searchConsultationsWorkflow = SearchConsultationsWorkflow(
      consultationRepository: consultationRepo,
    );

    return LipiDependencies._(
      vault: vault,
      database: database,
      secureStorage: secureStorage,
      keyStore: keyStore,
      crypto: crypto,
      auth: auth,
      doctorRepository: doctorRepo,
      patientRepository: patientRepo,
      consultationRepository: consultationRepo,
      documentRepository: docRepo,
      atomicWriter: atomicWriter,
      writeCoordinator: writeCoordinator,
      editorServer: editorServer,
      vaultBackupService: vaultBackupService,
      themeService: themeService,
      initWorkflow: initWorkflow,
      configureDoctorWorkflow: configureDoctorWorkflow,
      configureTemplateWorkflow: configureTemplateWorkflow,
      createPatientWorkflow: createPatientWorkflow,
      searchPatientsWorkflow: searchPatientsWorkflow,
      openPatientWorkflow: openPatientWorkflow,
      deletePatientWorkflow: deletePatientWorkflow,
      startConsultationWorkflow: startConsultationWorkflow,
      loadConsultationWorkflow: loadConsultationWorkflow,
      saveConsultationWorkflow: saveConsultationWorkflow,
      listConsultationHistoryWorkflow: listConsultationHistoryWorkflow,
      searchConsultationsWorkflow: searchConsultationsWorkflow,
      deleteConsultationWorkflow: deleteConsultationWorkflow,
    );
  }

  Future<void> dispose() async {
    await editorServer.stop();
    await database.close();
    vault.close();
  }
}
