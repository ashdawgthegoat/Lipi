import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'built_in_themes.dart';

/// Validation result for theme packages and manifests.
class ThemeValidationResult {
  final bool isValid;
  final List<String> errors;

  const ThemeValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  factory ThemeValidationResult.valid() => const ThemeValidationResult(isValid: true);
  factory ThemeValidationResult.invalid(List<String> errors) =>
      ThemeValidationResult(isValid: false, errors: errors);
}

/// Strict security and schema validator for Lipi theme packages.
/// Fails closed on any structural error, disallowed file, or path traversal attempt.
class ThemeValidator {
  static final RegExp _idRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
  static final RegExp _hexColorRegex = RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  static const Set<String> _disallowedExtensions = {
    '.exe', '.sh', '.bat', '.cmd', '.js', '.mjs', '.cjs', '.dart',
    '.so', '.dll', '.dylib', '.bin', '.apk', '.jar', '.py', '.vbs',
    '.ps1', '.html', '.htm', '.php', '.class'
  };

  /// Validates a raw `theme.json` map against the Lipi Theme Specification 1.0.
  static ThemeValidationResult validateThemeJson(
    Map<String, dynamic> json, {
    bool allowBuiltInIds = false,
  }) {
    final errors = <String>[];

    // 1. Version Check
    final version = json['version'];
    if (version != '1.0') {
      errors.add("Unsupported theme version: '$version'. Lipi requires version '1.0'.");
    }

    // 2. ID Validation
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      errors.add('Theme ID must be a non-empty string.');
    } else {
      if (!_idRegex.hasMatch(id)) {
        errors.add("Invalid theme ID '$id'. ID may only contain alphanumeric characters, underscores, and hyphens.");
      }
      if (!allowBuiltInIds && BuiltInThemes.all.containsKey(id)) {
        errors.add("Theme ID '$id' conflicts with protected built-in theme.");
      }
    }

    // 3. Name Validation
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      errors.add('Theme name must be a non-empty string.');
    }

    // 4. Color Palette Validation
    final colors = json['colors'];
    if (colors is! Map<String, dynamic>) {
      errors.add('Theme colors must be a key-value object.');
    } else {
      const requiredColorKeys = [
        'primary',
        'surface',
        'background',
        'onPrimary',
        'onSurface',
        'border',
        'appBarBg',
      ];
      for (final key in requiredColorKeys) {
        final val = colors[key];
        if (val is! String || !_hexColorRegex.hasMatch(val.trim())) {
          errors.add("Color '$key' must be a valid hex string (#RRGGBB or #AARRGGBB). Found: '$val'.");
        }
      }
      // Validate any optional color keys present
      for (final entry in colors.entries) {
        final val = entry.value;
        if (val is! String || !_hexColorRegex.hasMatch(val.trim())) {
          errors.add("Color '${entry.key}' must be a valid hex string. Found: '$val'.");
        }
      }
    }

    // 5. Shapes Validation
    if (json.containsKey('shapes')) {
      final shapes = json['shapes'];
      if (shapes is! Map<String, dynamic>) {
        errors.add('Theme shapes must be an object.');
      } else {
        for (final entry in shapes.entries) {
          if (entry.value is! num) {
            errors.add("Shape property '${entry.key}' must be a number.");
          }
        }
      }
    }

    return errors.isEmpty
        ? ThemeValidationResult.valid()
        : ThemeValidationResult.invalid(errors);
  }

  /// Validates a directory containing a custom theme package.
  /// Enforces sandboxing, absence of scripts/binaries, and path safety.
  static Future<ThemeValidationResult> validateThemeDirectory(Directory dir) async {
    final errors = <String>[];

    if (!await dir.exists()) {
      return ThemeValidationResult.invalid(['Theme directory does not exist: ${dir.path}']);
    }

    final themeJsonFile = File(p.join(dir.path, 'theme.json'));
    if (!await themeJsonFile.exists()) {
      return ThemeValidationResult.invalid(["Theme package missing required 'theme.json' root descriptor."]);
    }

    // Check all files in directory recursively
    await for (final entity in dir.list(recursive: true)) {
      final relative = p.relative(entity.path, from: dir.path);

      // Path traversal check
      if (relative.contains('..') || p.isAbsolute(relative)) {
        errors.add("Path traversal attempt detected in theme package: '$relative'.");
      }

      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_disallowedExtensions.contains(ext)) {
          errors.add("Theme package contains prohibited executable or script file: '$relative'.");
        }
      }
    }

    // Validate theme.json content
    try {
      final content = await themeJsonFile.readAsString();
      final parsed = jsonDecode(content);
      if (parsed is! Map<String, dynamic>) {
        errors.add("'theme.json' must be a JSON object.");
      } else {
        final jsonResult = validateThemeJson(parsed);
        if (!jsonResult.isValid) {
          errors.addAll(jsonResult.errors);
        }
      }
    } catch (e) {
      errors.add("Failed to parse 'theme.json': $e");
    }

    return errors.isEmpty
        ? ThemeValidationResult.valid()
        : ThemeValidationResult.invalid(errors);
  }
}
