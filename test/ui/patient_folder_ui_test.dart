import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/domains/consultation/models/consultation.dart';
import 'package:lipi/domains/consultation/models/consultation_status.dart';
import 'package:lipi/domains/consultation/models/doctor_snapshot.dart';
import 'package:lipi/domains/consultation/models/page_dimensions.dart';
import 'package:lipi/domains/consultation/models/patient_snapshot.dart';
import 'package:lipi/domains/patient/models/patient.dart';
import 'package:lipi/domains/patient/models/patient_info.dart';
import 'package:lipi/infrastructure/themes/built_in_themes.dart';
import 'package:lipi/presentation/patient/widgets/prescription_file_item.dart';
import 'package:lipi/presentation/patients/widgets/patient_folder_item.dart';
import 'package:lipi/presentation/widgets/file_manager/lipi_file_manager_icons.dart';
import 'package:lipi/shared/ids/ids.dart';

void main() {
  group('PatientFolderItem Literal Folder UI & Theme Adaptation Tests', () {
    late Patient patient;

    setUp(() {
      patient = Patient(
        id: PatientId('pat-test-12345'),
        info: const PatientInfo(
          name: 'Arun Gupta',
          age: 48,
          gender: 'Male',
          city: 'Mumbai',
        ),
      );
    });

    testWidgets('Renders Vista Light folder presentation with LipiFolderIcon and NO surrounding Card', (tester) async {
      bool tapped = false;
      bool newRxTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.vistaLight.toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 240,
              child: PatientFolderItem(
                patient: patient,
                visitCount: 5,
                onTap: () => tapped = true,
                onNewRx: () => newRxTapped = true,
                onDelete: () => deleteTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Explicitly assert that NO Material Card is used
      expect(find.byType(Card), findsNothing);

      // Check purpose-built folder icon
      expect(find.byType(LipiFolderIcon), findsOneWidget);

      // Check Aero folder tab and labels
      expect(find.text('PATIENT RECORD'), findsOneWidget);
      expect(find.textContaining('PAT-TEST'), findsNothing);
      expect(find.text('Arun Gupta'), findsOneWidget);
      expect(find.text('48 Y • Male • Mumbai'), findsOneWidget);
      expect(find.text('5 Prescriptions'), findsOneWidget);
      expect(find.text('New Rx'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Verify direct tap on folder item
      await tester.tap(find.text('Arun Gupta'));
      expect(tapped, isTrue);

      await tester.tap(find.text('New Rx'));
      expect(newRxTapped, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleteTapped, isTrue);
    });

    testWidgets('Renders 16-Bit Light folder presentation with retro pixel-art LipiFolderIcon and NO surrounding Card', (tester) async {
      bool tapped = false;
      bool newRxTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.sixteenBitLight.toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 240,
              child: PatientFolderItem(
                patient: patient,
                visitCount: 0,
                onTap: () => tapped = true,
                onNewRx: () => newRxTapped = true,
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Explicitly assert that NO Material Card is used
      expect(find.byType(Card), findsNothing);

      // Check purpose-built retro folder icon
      expect(find.byType(LipiFolderIcon), findsOneWidget);

      // Check 16-bit retro folder tab and labels
      expect(find.text('PATIENT FILE'), findsOneWidget);
      expect(find.textContaining('PAT-TEST'), findsNothing);
      expect(find.text('Arun Gupta'), findsOneWidget);
      expect(find.text('48 Y • Male • Mumbai'), findsOneWidget);
      expect(find.text('0 Visits'), findsOneWidget);
      expect(find.text('New Rx'), findsOneWidget);

      // Verify interactions
      await tester.tap(find.text('Arun Gupta'));
      expect(tapped, isTrue);

      await tester.tap(find.text('New Rx'));
      expect(newRxTapped, isTrue);
    });

    testWidgets('PatientFolderItem triggers onLongPress without firing onTap', (tester) async {
      bool tapped = false;
      bool longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.vistaLight.toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 240,
              child: PatientFolderItem(
                patient: patient,
                visitCount: 2,
                onTap: () => tapped = true,
                onNewRx: () {},
                onDelete: () {},
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(PatientFolderItem));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
      expect(tapped, isFalse);
    });
  });

  group('PrescriptionFileItem Literal Document File UI & Theme Adaptation Tests', () {
    late Consultation consultation;

    setUp(() {
      consultation = Consultation(
        id: ConsultationId('rx-test-9988'),
        patientId: PatientId('pat-test-12345'),
        patientSnapshot: const PatientSnapshot(
          name: 'Arun Gupta',
          age: 48,
          gender: 'Male',
          city: 'Mumbai',
        ),
        doctorSnapshot: const DoctorSnapshot(
          name: 'Dr. Rao',
          clinic: 'Clinic',
          qualifications: 'MBBS',
          regNumber: '123',
        ),
        pageDimensions: const PageDimensions(width: 180, height: 260, unit: 'mm'),
        status: ConsultationStatus.saved,
        lipiRelativePath: 'patient/pat-test-12345/prescriptions/rx-test-9988.lipi',
        createdAt: DateTime(2026, 9, 8, 11, 15),
        updatedAt: DateTime(2026, 9, 8, 11, 15),
      );
    });

    testWidgets('Renders Vista Light clinical document sheet with LipiFileIcon and NO Card', (tester) async {
      bool opened = false;
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.vistaLight.toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: PrescriptionFileItem(
                consultation: consultation,
                onOpen: () => opened = true,
                onDelete: () => deleted = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Explicitly assert that NO Material Card is used
      expect(find.byType(Card), findsNothing);

      // Check purpose-built file icon
      expect(find.byType(LipiFileIcon), findsOneWidget);

      expect(find.text('08 Sep 2026, 11:15 AM'), findsOneWidget);
      expect(find.text('Prescription'), findsOneWidget);
      expect(find.text('Status: SAVED'), findsOneWidget);
      expect(find.textContaining('Doc #'), findsNothing);
      expect(find.textContaining('RX-TEST'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(find.byKey(const Key('delete_prescription_rx-test-9988')), findsOneWidget);

      await tester.tap(find.text('Open'));
      expect(opened, isTrue);

      await tester.tap(find.byKey(const Key('delete_prescription_rx-test-9988')));
      expect(deleted, isTrue);
    });

    testWidgets('Renders 16-Bit Light retro document sheet with LipiFileIcon and NO Card', (tester) async {
      bool opened = false;
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.sixteenBitLight.toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: PrescriptionFileItem(
                consultation: consultation,
                onOpen: () => opened = true,
                onDelete: () => deleted = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Explicitly assert that NO Material Card is used
      expect(find.byType(Card), findsNothing);

      // Check purpose-built retro file icon
      expect(find.byType(LipiFileIcon), findsOneWidget);

      expect(find.text('08 Sep 2026, 11:15 AM'), findsOneWidget);
      expect(find.text('FILE: RX'), findsOneWidget);
      expect(find.text('Status: SAVED'), findsOneWidget);
      expect(find.textContaining('#RX-TEST'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(find.byKey(const Key('delete_prescription_rx-test-9988')), findsOneWidget);

      await tester.tap(find.text('Open'));
      expect(opened, isTrue);

      await tester.tap(find.byKey(const Key('delete_prescription_rx-test-9988')));
      expect(deleted, isTrue);
    });

    testWidgets('PrescriptionFileItem triggers onLongPress without firing onOpen', (tester) async {
      bool opened = false;
      bool longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.vistaLight.toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: PrescriptionFileItem(
                consultation: consultation,
                onOpen: () => opened = true,
                onDelete: () {},
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(PrescriptionFileItem));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
      expect(opened, isFalse);
    });
  });

  group('LipiFileManagerIcon Component & Asset Resolution Tests', () {
    testWidgets('Resolves Vista Light assets correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.vistaLight.toThemeData(),
          home: const Scaffold(
            body: Column(
              children: [
                LipiFolderIcon(isOpen: false),
                LipiFolderIcon(isOpen: true),
                LipiFileIcon(type: LipiIconType.file),
                LipiFileIcon(type: LipiIconType.filePdf),
                LipiFileIcon(type: LipiIconType.fileImage),
              ],
            ),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(5));

      final assetNames = images.map((img) => (img.image as AssetImage).assetName).toList();
      expect(assetNames[0], equals('assets/icons/vista/folder.png'));
      expect(assetNames[1], equals('assets/icons/vista/folder_open.png'));
      expect(assetNames[2], equals('assets/icons/vista/file.png'));
      expect(assetNames[3], equals('assets/icons/vista/file_pdf.png'));
      expect(assetNames[4], equals('assets/icons/vista/file_image.png'));
    });

    testWidgets('Resolves 16-Bit Light assets with FilterQuality.none for crisp pixel art', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.sixteenBitLight.toThemeData(),
          home: const Scaffold(
            body: Column(
              children: [
                LipiFolderIcon(isOpen: false),
                LipiFolderIcon(isOpen: true),
                LipiFileIcon(type: LipiIconType.file),
              ],
            ),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(3));

      for (final img in images) {
        expect(img.filterQuality, equals(FilterQuality.none));
      }

      final assetNames = images.map((img) => (img.image as AssetImage).assetName).toList();
      expect(assetNames[0], equals('assets/icons/sixteen_bit/folder.png'));
      expect(assetNames[1], equals('assets/icons/sixteen_bit/folder_open.png'));
      expect(assetNames[2], equals('assets/icons/sixteen_bit/file.png'));
    });

    testWidgets('Applies state transforms for selected, hovered, and pressed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BuiltInThemes.vistaLight.toThemeData(),
          home: const Scaffold(
            body: Column(
              children: [
                LipiFolderIcon(state: LipiIconState.selected),
                LipiFileIcon(state: LipiIconState.disabled),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Opacity), findsOneWidget);
      expect(find.byType(LipiFileManagerIcon), findsNWidgets(2));
    });
  });
}
