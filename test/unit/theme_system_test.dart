import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi/infrastructure/themes/built_in_themes.dart';
import 'package:lipi/infrastructure/themes/theme_model.dart';
import 'package:lipi/infrastructure/themes/theme_service.dart';
import 'package:lipi/infrastructure/themes/theme_validator.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Theme Architecture & Model Tests', () {
    test('Built-in themes are registered and have correct style types', () {
      expect(BuiltInThemes.all.containsKey('vista-light'), isTrue);
      expect(BuiltInThemes.all.containsKey('sixteen-bit-light'), isTrue);

      final vista = BuiltInThemes.vistaLight;
      expect(vista.id, equals('vista-light'));
      expect(vista.styleType, equals('vista'));
      expect(vista.isBuiltIn, isTrue);
      expect(vista.colors.paperBg, equals(const Color(0xFFFFFFFF)));
      expect(vista.colors.folderBg, equals(const Color(0xFFFFFFFF)));
      expect(vista.colors.folderTabBg, equals(const Color(0xFFE2EDF8)));

      final retro = BuiltInThemes.sixteenBitLight;
      expect(retro.id, equals('sixteen-bit-light'));
      expect(retro.styleType, equals('retro16bit'));
      expect(retro.isBuiltIn, isTrue);
      expect(retro.shapes.borderWidth, equals(2.0));
      expect(retro.colors.paperBg, equals(const Color(0xFFFFFFFF)));
      expect(retro.colors.folderBg, equals(const Color(0xFFD4D0C8)));
    });

    test('LipiTheme toThemeData generates valid ThemeData and LipiExtendedColors', () {
      final vistaThemeData = BuiltInThemes.vistaLight.toThemeData();
      expect(vistaThemeData.brightness, equals(Brightness.light));
      expect(vistaThemeData.colorScheme.primary, equals(BuiltInThemes.vistaLight.colors.primary));
      final vistaExt = vistaThemeData.extension<LipiExtendedColors>();
      expect(vistaExt, isNotNull);
      expect(vistaExt!.isVista, isTrue);
      expect(vistaExt.isRetro, isFalse);

      final retroThemeData = BuiltInThemes.sixteenBitLight.toThemeData();
      expect(retroThemeData.brightness, equals(Brightness.light));
      expect(retroThemeData.colorScheme.primary, equals(BuiltInThemes.sixteenBitLight.colors.primary));
      final retroExt = retroThemeData.extension<LipiExtendedColors>();
      expect(retroExt, isNotNull);
      expect(retroExt!.isRetro, isTrue);
      expect(retroExt.isVista, isFalse);
    });

    test('LipiTheme serialization roundtrip preserves colors, folder tokens, and shapes', () {
      final original = BuiltInThemes.vistaLight;
      final json = original.toJson();
      final restored = LipiTheme.fromJson(json, isBuiltIn: true);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.version, equals('1.0'));
      expect(restored.colors.primary, equals(original.colors.primary));
      expect(restored.colors.canvasBg, equals(original.colors.canvasBg));
      expect(restored.colors.folderBg, equals(original.colors.folderBg));
      expect(restored.colors.folderTabBg, equals(original.colors.folderTabBg));
      expect(restored.shapes.borderRadius, equals(original.shapes.borderRadius));
    });

    test('ThemeColors handles missing optional folder tokens with backward compatibility', () {
      final minimalJson = {
        'primary': '#1A365D',
        'surface': '#FFFFFF',
        'background': '#F8FAFC',
        'onPrimary': '#FFFFFF',
        'onSurface': '#0F172A',
        'border': '#E2E8F0',
        'appBarBg': '#1A365D',
      };
      final colors = ThemeColors.fromJson(minimalJson);
      expect(colors.folderBg, equals(const Color(0xFFFFFFFF)));
      expect(colors.folderTabBg, isNotNull);
      expect(colors.folderBorder, isNotNull);
    });

    test('toWebThemeJson produces correct web css variables', () {
      final webMap = BuiltInThemes.vistaLight.toWebThemeJson();
      expect(webMap.containsKey('toolbarBg'), isTrue);
      expect(webMap.containsKey('canvasBg'), isTrue);
      expect(webMap.containsKey('paperBg'), isTrue);
      expect(webMap.containsKey('primary'), isTrue);
      expect(webMap.containsKey('borderRadius'), isTrue);
    });
  });

  group('ThemeValidator Security & Schema Tests', () {
    test('Valid theme manifest passes validation', () {
      final validJson = {
        'id': 'mint-fresh',
        'name': 'Mint Fresh',
        'version': '1.0',
        'author': 'Dr. Test',
        'description': 'A soothing mint green theme',
        'styleType': 'modern',
        'colors': {
          'primary': '#0D9488',
          'surface': '#FFFFFF',
          'background': '#F0FDF4',
          'onPrimary': '#FFFFFF',
          'onSurface': '#134E4A',
          'border': '#CBD5E1',
          'appBarBg': '#115E59',
        },
        'shapes': {
          'borderRadius': 8.0,
          'borderWidth': 1.0,
        },
      };

      final result = ThemeValidator.validateThemeJson(validJson);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('Rejects invalid version (fails closed on non-1.0)', () {
      final badVersionJson = {
        'id': 'bad-version',
        'name': 'Bad Version',
        'version': '2.0',
        'colors': {
          'primary': '#0D9488',
          'surface': '#FFFFFF',
          'background': '#F0FDF4',
          'onPrimary': '#FFFFFF',
          'onSurface': '#134E4A',
          'border': '#CBD5E1',
          'appBarBg': '#115E59',
        },
      };

      final result = ThemeValidator.validateThemeJson(badVersionJson);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains("Unsupported theme version")), isTrue);
    });

    test('Rejects conflict with protected built-in theme ID', () {
      final conflictJson = {
        'id': 'vista-light',
        'name': 'Hacked Vista',
        'version': '1.0',
        'colors': {
          'primary': '#000000',
          'surface': '#FFFFFF',
          'background': '#F0FDF4',
          'onPrimary': '#FFFFFF',
          'onSurface': '#134E4A',
          'border': '#CBD5E1',
          'appBarBg': '#115E59',
        },
      };

      final result = ThemeValidator.validateThemeJson(conflictJson, allowBuiltInIds: false);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('conflicts with protected built-in')), isTrue);
    });

    test('Rejects invalid hex colors', () {
      final badColorJson = {
        'id': 'bad-color',
        'name': 'Bad Color',
        'version': '1.0',
        'colors': {
          'primary': 'blue', // invalid hex
          'surface': '#FFFFFF',
          'background': '#F0FDF4',
          'onPrimary': '#FFFFFF',
          'onSurface': '#134E4A',
          'border': '#CBD5E1',
          'appBarBg': '#115E59',
        },
      };

      final result = ThemeValidator.validateThemeJson(badColorJson);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('valid hex string')), isTrue);
    });

    test('Rejects theme directory containing executable or script files', () async {
      final tempDir = await Directory.systemTemp.createTemp('lipi_theme_test_');
      try {
        final themeJson = File(p.join(tempDir.path, 'theme.json'));
        await themeJson.writeAsString('''{
          "id": "exploit-theme",
          "name": "Exploit",
          "version": "1.0",
          "colors": {
            "primary": "#0D9488",
            "surface": "#FFFFFF",
            "background": "#F0FDF4",
            "onPrimary": "#FFFFFF",
            "onSurface": "#134E4A",
            "border": "#CBD5E1",
            "appBarBg": "#115E59"
          }
        }''');

        // Add malicious script file
        final scriptFile = File(p.join(tempDir.path, 'payload.sh'));
        await scriptFile.writeAsString('#!/bin/sh\necho exploit\n');

        final result = await ThemeValidator.validateThemeDirectory(tempDir);
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('prohibited executable or script')), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('ThemeService Lifecycle & Sandbox Tests', () {
    test('ThemeService initializes with built-in themes and persists active theme', () async {
      final tempDir = await Directory.systemTemp.createTemp('lipi_theme_service_test_');
      try {
        final service = await ThemeService.create(storageDirectory: tempDir);
        expect(service.availableThemes.length, greaterThanOrEqualTo(2));
        expect(service.activeTheme.id, equals(BuiltInThemes.defaultTheme.id));

        // Switch to 16-bit
        await service.switchTheme('sixteen-bit-light');
        expect(service.activeTheme.id, equals('sixteen-bit-light'));

        // Re-create service from same directory: should restore active theme
        final restoredService = await ThemeService.create(storageDirectory: tempDir);
        expect(restoredService.activeTheme.id, equals('sixteen-bit-light'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Custom theme import and deletion works in sandbox', () async {
      final tempDir = await Directory.systemTemp.createTemp('lipi_theme_import_test_');
      try {
        final service = await ThemeService.create(storageDirectory: tempDir);

        const customJson = '''{
          "id": "nordic-slate",
          "name": "Nordic Slate",
          "version": "1.0",
          "author": "Dr. North",
          "description": "Clean cool arctic tones",
          "colors": {
            "primary": "#4C566A",
            "surface": "#ECEFF4",
            "background": "#D8DEE9",
            "onPrimary": "#FFFFFF",
            "onSurface": "#2E3440",
            "border": "#BAC3D2",
            "appBarBg": "#3B4252"
          }
        }''';

        final imported = await service.importThemeFromJson(customJson);
        expect(imported.id, equals('nordic-slate'));
        expect(service.activeTheme.id, equals('nordic-slate'));
        expect(service.availableThemes.any((t) => t.id == 'nordic-slate'), isTrue);

        // Delete custom theme
        await service.deleteCustomTheme('nordic-slate');
        expect(service.availableThemes.any((t) => t.id == 'nordic-slate'), isFalse);
        // Falls back to default built-in
        expect(service.activeTheme.id, equals(BuiltInThemes.defaultTheme.id));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('Cannot delete protected built-in theme', () async {
      final tempDir = await Directory.systemTemp.createTemp('lipi_theme_protect_test_');
      try {
        final service = await ThemeService.create(storageDirectory: tempDir);
        expect(
          () => service.deleteCustomTheme('vista-light'),
          throwsA(isA<ThemeException>()),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
