import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/infrastructure/themes/built_in_themes.dart';
import 'package:lipi/infrastructure/themes/theme_service.dart';
import 'package:lipi/presentation/settings/theme_settings_dialog.dart';

void main() {
  group('Theme UI & Selector Tests', () {
    late Directory tempDir;
    late ThemeService themeService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('theme_ui_test_');
      themeService = await ThemeService.create(storageDirectory: tempDir);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    testWidgets('ThemeSettingsDialog renders themes and switches active selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ThemeSettingsDialog.show(context, themeService),
                child: const Text('Open Themes'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Themes'));
      await tester.pumpAndSettle();

      // Verify dialog header and themes rendered
      expect(find.text('Theme & Presentation Settings'), findsOneWidget);
      expect(find.text('Vista Light'), findsOneWidget);
      expect(find.text('16-Bit Light'), findsOneWidget);
      expect(find.text('Import Theme (.json)'), findsOneWidget);

      // Initially Vista Light is active
      expect(themeService.activeTheme.id, equals(BuiltInThemes.defaultTheme.id));

      // Tap 16-Bit Light theme tile
      await tester.tap(find.text('16-Bit Light'));
      await tester.pumpAndSettle();

      // Verify active theme immediately updated
      expect(themeService.activeTheme.id, equals('sixteen-bit-light'));

      // Close dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Theme & Presentation Settings'), findsNothing);
    });
  });
}
