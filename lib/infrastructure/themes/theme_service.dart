import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'built_in_themes.dart';
import 'theme_model.dart';
import 'theme_validator.dart';

/// Exception thrown when a theme package fails validation.
class ThemeException implements Exception {
  final String message;
  final List<String> details;

  ThemeException(this.message, [this.details = const []]);

  @override
  String toString() => details.isEmpty
      ? 'ThemeException: $message'
      : 'ThemeException: $message (${details.join(', ')})';
}

/// Service managing available presentation themes, active selection,
/// custom theme imports, and sandboxed theme storage.
class ThemeService {
  final Directory storageDirectory;
  final ValueNotifier<LipiTheme> activeThemeNotifier;
  final Map<String, LipiTheme> _themes = {};

  ThemeService._({
    required this.storageDirectory,
    required LipiTheme initialTheme,
  }) : activeThemeNotifier = ValueNotifier<LipiTheme>(initialTheme);

  /// Factory to initialize theme service and load custom themes.
  static Future<ThemeService> create({required Directory storageDirectory}) async {
    final customThemesDir = Directory(p.join(storageDirectory.path, 'custom'));
    if (!await customThemesDir.exists()) {
      await customThemesDir.create(recursive: true);
    }

    final service = ThemeService._(
      storageDirectory: storageDirectory,
      initialTheme: BuiltInThemes.defaultTheme,
    );

    await service._loadAllThemes();
    return service;
  }

  /// All available themes (built-in and custom).
  List<LipiTheme> get availableThemes => _themes.values.toList();

  /// Current active theme.
  LipiTheme get activeTheme => activeThemeNotifier.value;

  File get _prefFile => File(p.join(storageDirectory.path, 'active_theme.json'));
  Directory get _customDir => Directory(p.join(storageDirectory.path, 'custom'));

  /// Loads all themes from built-ins and custom storage.
  Future<void> _loadAllThemes() async {
    _themes.clear();

    // 1. Add all built-ins
    for (final theme in BuiltInThemes.all.values) {
      _themes[theme.id] = theme;
    }

    // 2. Discover custom themes in sandbox
    if (await _customDir.exists()) {
      await for (final entity in _customDir.list()) {
        if (entity is Directory) {
          final themeJson = File(p.join(entity.path, 'theme.json'));
          if (await themeJson.exists()) {
            try {
              final content = await themeJson.readAsString();
              final map = jsonDecode(content) as Map<String, dynamic>;
              final val = ThemeValidator.validateThemeJson(map);
              if (val.isValid) {
                final customTheme = LipiTheme.fromJson(map, isBuiltIn: false);
                _themes[customTheme.id] = customTheme;
              } else {
                debugPrint('[Lipi][Theme] Skipping invalid custom theme in ${entity.path}: ${val.errors}');
              }
            } catch (e) {
              debugPrint('[Lipi][Theme] Error loading custom theme from ${entity.path}: $e');
            }
          }
        }
      }
    }

    // 3. Restore persisted active theme ID
    String targetThemeId = BuiltInThemes.defaultTheme.id;
    if (await _prefFile.exists()) {
      try {
        final prefContent = await _prefFile.readAsString();
        final prefMap = jsonDecode(prefContent) as Map<String, dynamic>;
        final storedId = prefMap['activeThemeId'] as String?;
        if (storedId != null && _themes.containsKey(storedId)) {
          targetThemeId = storedId;
        }
      } catch (e) {
        debugPrint('[Lipi][Theme] Error reading theme preferences: $e');
      }
    }

    activeThemeNotifier.value = _themes[targetThemeId] ?? BuiltInThemes.defaultTheme;
  }

  /// Switches active theme immediately and persists preference.
  Future<void> switchTheme(String themeId) async {
    final target = _themes[themeId] ?? BuiltInThemes.defaultTheme;
    activeThemeNotifier.value = target;

    try {
      if (!await storageDirectory.exists()) {
        await storageDirectory.create(recursive: true);
      }
      await _prefFile.writeAsString(jsonEncode({'activeThemeId': target.id}));
    } catch (e) {
      debugPrint('[Lipi][Theme] Failed to persist active theme: $e');
    }
  }

  /// Imports a theme from a JSON descriptor string.
  Future<LipiTheme> importThemeFromJson(String jsonContent) async {
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (e) {
      throw ThemeException("Malformed JSON: $e");
    }

    final valResult = ThemeValidator.validateThemeJson(parsed);
    if (!valResult.isValid) {
      throw ThemeException("Theme validation failed", valResult.errors);
    }

    final theme = LipiTheme.fromJson(parsed, isBuiltIn: false);
    final targetDir = Directory(p.join(_customDir.path, theme.id));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = File(p.join(targetDir.path, 'theme.json'));
    await targetFile.writeAsString(jsonEncode(theme.toJson()));

    _themes[theme.id] = theme;
    await switchTheme(theme.id);
    return theme;
  }

  /// Imports a custom theme from a directory package.
  Future<LipiTheme> importThemeFromDirectory(Directory sourceDir) async {
    final valResult = await ThemeValidator.validateThemeDirectory(sourceDir);
    if (!valResult.isValid) {
      throw ThemeException("Theme package validation failed", valResult.errors);
    }

    final themeJsonFile = File(p.join(sourceDir.path, 'theme.json'));
    final content = await themeJsonFile.readAsString();
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final theme = LipiTheme.fromJson(parsed, isBuiltIn: false);

    final targetDir = Directory(p.join(_customDir.path, theme.id));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Copy all safe files from source directory into sandbox
    await for (final entity in sourceDir.list(recursive: true)) {
      final relative = p.relative(entity.path, from: sourceDir.path);
      final destPath = p.join(targetDir.path, relative);
      if (entity is Directory) {
        await Directory(destPath).create(recursive: true);
      } else if (entity is File) {
        await File(destPath).parent.create(recursive: true);
        await entity.copy(destPath);
      }
    }

    _themes[theme.id] = theme;
    await switchTheme(theme.id);
    return theme;
  }

  /// Deletes a custom theme package.
  /// Throws if attempting to delete built-in themes.
  Future<void> deleteCustomTheme(String themeId) async {
    final theme = _themes[themeId];
    if (theme == null) return;

    if (theme.isBuiltIn || BuiltInThemes.all.containsKey(themeId)) {
      throw ThemeException("Protected built-in theme '$themeId' cannot be deleted.");
    }

    final targetDir = Directory(p.join(_customDir.path, themeId));
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }

    _themes.remove(themeId);

    // If active theme was deleted, fall back to default built-in
    if (activeTheme.id == themeId) {
      await switchTheme(BuiltInThemes.defaultTheme.id);
    }
  }
}
