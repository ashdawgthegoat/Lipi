import 'package:flutter/material.dart';

/// Presentation-only color palette for Lipi.
class ThemeColors {
  final Color primary;
  final Color primaryContainer;
  final Color surface;
  final Color surfaceVariant;
  final Color background;
  final Color onPrimary;
  final Color onSurface;
  final Color border;
  final Color appBarBg;
  final Color appBarFg;
  final Color accent;
  final Color canvasBg;
  final Color paperBg;
  final Color sliderBg;

  const ThemeColors({
    required this.primary,
    required this.primaryContainer,
    required this.surface,
    required this.surfaceVariant,
    required this.background,
    required this.onPrimary,
    required this.onSurface,
    required this.border,
    required this.appBarBg,
    required this.appBarFg,
    required this.accent,
    required this.canvasBg,
    required this.paperBg,
    required this.sliderBg,
  });

  static Color _parseHex(dynamic hex, Color fallback) {
    if (hex is! String) return fallback;
    var clean = hex.trim().replaceFirst('#', '');
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  static String _toHex(Color color) {
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  factory ThemeColors.fromJson(Map<String, dynamic> json) {
    return ThemeColors(
      primary: _parseHex(json['primary'], const Color(0xFF1E5A8A)),
      primaryContainer: _parseHex(json['primaryContainer'], const Color(0xFFDCE8F5)),
      surface: _parseHex(json['surface'], const Color(0xFFFFFFFF)),
      surfaceVariant: _parseHex(json['surfaceVariant'], const Color(0xFFF0F4F8)),
      background: _parseHex(json['background'], const Color(0xFFE8EEF5)),
      onPrimary: _parseHex(json['onPrimary'], const Color(0xFFFFFFFF)),
      onSurface: _parseHex(json['onSurface'], const Color(0xFF1E293B)),
      border: _parseHex(json['border'], const Color(0xFFB8C8D9)),
      appBarBg: _parseHex(json['appBarBg'], const Color(0xFF1E3A5F)),
      appBarFg: _parseHex(json['appBarFg'], const Color(0xFFFFFFFF)),
      accent: _parseHex(json['accent'], const Color(0xFF0284C7)),
      canvasBg: _parseHex(json['canvasBg'], const Color(0xFFD6E2EE)),
      paperBg: _parseHex(json['paperBg'], const Color(0xFFFFFFFF)),
      sliderBg: _parseHex(json['sliderBg'], const Color(0xFFE2EBF4)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary': _toHex(primary),
      'primaryContainer': _toHex(primaryContainer),
      'surface': _toHex(surface),
      'surfaceVariant': _toHex(surfaceVariant),
      'background': _toHex(background),
      'onPrimary': _toHex(onPrimary),
      'onSurface': _toHex(onSurface),
      'border': _toHex(border),
      'appBarBg': _toHex(appBarBg),
      'appBarFg': _toHex(appBarFg),
      'accent': _toHex(accent),
      'canvasBg': _toHex(canvasBg),
      'paperBg': _toHex(paperBg),
      'sliderBg': _toHex(sliderBg),
    };
  }
}

/// Structural styling rules (radii, border widths).
class ThemeShapes {
  final double borderRadius;
  final double cardBorderRadius;
  final double buttonBorderRadius;
  final double borderWidth;

  const ThemeShapes({
    required this.borderRadius,
    required this.cardBorderRadius,
    required this.buttonBorderRadius,
    required this.borderWidth,
  });

  factory ThemeShapes.fromJson(Map<String, dynamic> json) {
    return ThemeShapes(
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 8.0,
      cardBorderRadius: (json['cardBorderRadius'] as num?)?.toDouble() ?? 8.0,
      buttonBorderRadius: (json['buttonBorderRadius'] as num?)?.toDouble() ?? 6.0,
      borderWidth: (json['borderWidth'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'borderRadius': borderRadius,
      'cardBorderRadius': cardBorderRadius,
      'buttonBorderRadius': buttonBorderRadius,
      'borderWidth': borderWidth,
    };
  }
}

/// Declarative Presentation Theme for Lipi.
/// strictly isolated to styling (colors, borders, fonts).
/// Never touches clinical models, encryption, vault, or .lipi serialization.
class LipiTheme {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String styleType; // 'vista' | 'retro16bit' | 'modern'
  final bool isBuiltIn;
  final ThemeColors colors;
  final ThemeShapes shapes;

  const LipiTheme({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.styleType,
    this.isBuiltIn = false,
    required this.colors,
    required this.shapes,
  });

  factory LipiTheme.fromJson(Map<String, dynamic> json, {bool isBuiltIn = false}) {
    return LipiTheme(
      id: json['id'] as String? ?? 'custom-theme',
      name: json['name'] as String? ?? 'Custom Theme',
      version: json['version'] as String? ?? '1.0',
      author: json['author'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      styleType: json['styleType'] as String? ?? 'modern',
      isBuiltIn: isBuiltIn || (json['isBuiltIn'] as bool? ?? false),
      colors: ThemeColors.fromJson((json['colors'] as Map<String, dynamic>?) ?? {}),
      shapes: ThemeShapes.fromJson((json['shapes'] as Map<String, dynamic>?) ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'author': author,
      'description': description,
      'styleType': styleType,
      'isBuiltIn': isBuiltIn,
      'colors': colors.toJson(),
      'shapes': shapes.toJson(),
    };
  }

  /// Converts theme to web-compatible dictionary for sending to web editor.
  Map<String, dynamic> toWebThemeJson() {
    return {
      'toolbarBg': ThemeColors._toHex(colors.surface),
      'canvasBg': ThemeColors._toHex(colors.canvasBg),
      'paperBg': ThemeColors._toHex(colors.paperBg),
      'primary': ThemeColors._toHex(colors.primary),
      'border': ThemeColors._toHex(colors.border),
      'textColor': ThemeColors._toHex(colors.onSurface),
      'sliderBg': ThemeColors._toHex(colors.sliderBg),
      'borderRadius': shapes.borderRadius,
      'buttonBorderRadius': shapes.buttonBorderRadius,
      'borderWidth': shapes.borderWidth,
    };
  }

  /// Generates Flutter ThemeData.
  ThemeData toThemeData() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onSurface,
      secondary: colors.accent,
      onSecondary: Colors.white,
      surface: colors.surface,
      onSurface: colors.onSurface,
      surfaceContainerHighest: colors.surfaceVariant,
      outline: colors.border,
      error: Colors.redAccent,
      onError: Colors.white,
    );

    final borderSide = BorderSide(
      color: colors.border,
      width: shapes.borderWidth,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.canvasBg,
      cardColor: colors.surface,
      dividerColor: colors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.appBarBg,
        foregroundColor: colors.appBarFg,
        elevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.appBarFg,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: colors.appBarFg),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: styleType == 'retro16bit' ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.cardBorderRadius),
          side: borderSide,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: styleType == 'retro16bit' ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.buttonBorderRadius),
            side: styleType == 'retro16bit'
                ? BorderSide(color: colors.border, width: shapes.borderWidth)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.buttonBorderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.borderRadius),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.borderRadius),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.borderRadius),
          borderSide: BorderSide(color: colors.primary, width: shapes.borderWidth + 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.borderRadius),
          side: borderSide,
        ),
      ),
    );
  }
}
