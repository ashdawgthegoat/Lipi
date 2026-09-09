import 'package:flutter/material.dart';

/// Flutter ThemeExtension carrying Lipi-specific color tokens that have
/// no direct Material ColorScheme equivalent.
class LipiExtendedColors extends ThemeExtension<LipiExtendedColors> {
  final Color success;
  final Color warning;
  final Color paperBg;
  final Color selectedBg;
  final String styleType;
  final Color folderBg;
  final Color folderTabBg;
  final Color folderBorder;
  final Color bevelLight;
  final Color bevelDark;

  const LipiExtendedColors({
    required this.success,
    required this.warning,
    required this.paperBg,
    required this.selectedBg,
    this.styleType = 'vista',
    this.folderBg = Colors.white,
    this.folderTabBg = const Color(0xFFE3EEF8),
    this.folderBorder = const Color(0xFFC4CFDC),
    this.bevelLight = Colors.white,
    this.bevelDark = const Color(0xFF808080),
  });

  bool get isRetro => styleType == 'retro16bit';
  bool get isVista => styleType == 'vista';

  @override
  LipiExtendedColors copyWith({
    Color? success,
    Color? warning,
    Color? paperBg,
    Color? selectedBg,
    String? styleType,
    Color? folderBg,
    Color? folderTabBg,
    Color? folderBorder,
    Color? bevelLight,
    Color? bevelDark,
  }) {
    return LipiExtendedColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      paperBg: paperBg ?? this.paperBg,
      selectedBg: selectedBg ?? this.selectedBg,
      styleType: styleType ?? this.styleType,
      folderBg: folderBg ?? this.folderBg,
      folderTabBg: folderTabBg ?? this.folderTabBg,
      folderBorder: folderBorder ?? this.folderBorder,
      bevelLight: bevelLight ?? this.bevelLight,
      bevelDark: bevelDark ?? this.bevelDark,
    );
  }

  @override
  LipiExtendedColors lerp(LipiExtendedColors? other, double t) {
    if (other is! LipiExtendedColors) return this;
    return LipiExtendedColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      paperBg: Color.lerp(paperBg, other.paperBg, t)!,
      selectedBg: Color.lerp(selectedBg, other.selectedBg, t)!,
      styleType: t < 0.5 ? styleType : other.styleType,
      folderBg: Color.lerp(folderBg, other.folderBg, t)!,
      folderTabBg: Color.lerp(folderTabBg, other.folderTabBg, t)!,
      folderBorder: Color.lerp(folderBorder, other.folderBorder, t)!,
      bevelLight: Color.lerp(bevelLight, other.bevelLight, t)!,
      bevelDark: Color.lerp(bevelDark, other.bevelDark, t)!,
    );
  }
}

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

  // Extended tokens (v1.1/v1.2 — backward-compatible, optional in JSON)
  final Color error;
  final Color success;
  final Color warning;
  final Color mutedText;
  final Color inputBg;
  final Color selectedBg;
  final Color folderBg;
  final Color folderTabBg;
  final Color folderBorder;

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
    this.error = const Color(0xFFD93025),
    this.success = const Color(0xFF107C10),
    this.warning = const Color(0xFFD48800),
    this.mutedText = const Color(0xFF6B7D94),
    this.inputBg = const Color(0xFFF7F9FC),
    this.selectedBg = const Color(0xFFD6E8F7),
    this.folderBg = const Color(0xFFFFFFFF),
    this.folderTabBg = const Color(0xFFE3EEF8),
    this.folderBorder = const Color(0xFFC4CFDC),
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
      primary: _parseHex(json['primary'], const Color(0xFF3672A4)),
      primaryContainer: _parseHex(json['primaryContainer'], const Color(0xFFE3EEF8)),
      surface: _parseHex(json['surface'], const Color(0xFFFFFFFF)),
      surfaceVariant: _parseHex(json['surfaceVariant'], const Color(0xFFF0F4F9)),
      background: _parseHex(json['background'], const Color(0xFFE8EDF4)),
      onPrimary: _parseHex(json['onPrimary'], const Color(0xFFFFFFFF)),
      onSurface: _parseHex(json['onSurface'], const Color(0xFF1A2332)),
      border: _parseHex(json['border'], const Color(0xFFC4CFDC)),
      appBarBg: _parseHex(json['appBarBg'], const Color(0xFF2D5F8A)),
      appBarFg: _parseHex(json['appBarFg'], const Color(0xFFFFFFFF)),
      accent: _parseHex(json['accent'], const Color(0xFF0078D4)),
      canvasBg: _parseHex(json['canvasBg'], const Color(0xFFDEE5EE)),
      paperBg: _parseHex(json['paperBg'], const Color(0xFFFFFFFF)),
      sliderBg: _parseHex(json['sliderBg'], const Color(0xFFE0E8F0)),
      error: _parseHex(json['error'], const Color(0xFFD93025)),
      success: _parseHex(json['success'], const Color(0xFF107C10)),
      warning: _parseHex(json['warning'], const Color(0xFFD48800)),
      mutedText: _parseHex(json['mutedText'], const Color(0xFF6B7D94)),
      inputBg: _parseHex(json['inputBg'], const Color(0xFFF7F9FC)),
      selectedBg: _parseHex(json['selectedBg'], const Color(0xFFD6E8F7)),
      folderBg: _parseHex(json['folderBg'], _parseHex(json['surface'], const Color(0xFFFFFFFF))),
      folderTabBg: _parseHex(json['folderTabBg'], _parseHex(json['primaryContainer'], const Color(0xFFE3EEF8))),
      folderBorder: _parseHex(json['folderBorder'], _parseHex(json['border'], const Color(0xFFC4CFDC))),
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
      'error': _toHex(error),
      'success': _toHex(success),
      'warning': _toHex(warning),
      'mutedText': _toHex(mutedText),
      'inputBg': _toHex(inputBg),
      'selectedBg': _toHex(selectedBg),
      'folderBg': _toHex(folderBg),
      'folderTabBg': _toHex(folderTabBg),
      'folderBorder': _toHex(folderBorder),
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

  /// Generates Flutter ThemeData with comprehensive, styleType-aware theming.
  ThemeData toThemeData() {
    final isRetro = styleType == 'retro16bit';

    // --- ColorScheme: fully populated ---
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onSurface,
      secondary: colors.accent,
      onSecondary: Colors.white,
      secondaryContainer: colors.primaryContainer,
      onSecondaryContainer: colors.onSurface,
      tertiary: colors.success,
      onTertiary: Colors.white,
      tertiaryContainer: colors.success.withValues(alpha: 0.12),
      onTertiaryContainer: colors.success,
      surface: colors.surface,
      onSurface: colors.onSurface,
      onSurfaceVariant: colors.mutedText,
      surfaceContainerHighest: colors.surfaceVariant,
      surfaceContainerHigh: colors.surfaceVariant,
      surfaceContainer: colors.surfaceVariant,
      surfaceContainerLow: colors.inputBg,
      surfaceContainerLowest: colors.inputBg,
      outline: colors.border,
      outlineVariant: colors.border.withValues(alpha: 0.5),
      error: colors.error,
      onError: Colors.white,
      errorContainer: colors.error.withValues(alpha: 0.1),
      onErrorContainer: colors.error,
      shadow: isRetro ? Colors.transparent : Colors.black.withValues(alpha: 0.12),
      inverseSurface: colors.appBarBg,
      onInverseSurface: colors.appBarFg,
      inversePrimary: colors.primaryContainer,
    );

    final borderSide = BorderSide(
      color: colors.border,
      width: shapes.borderWidth,
    );

    // --- styleType-driven elevation and shadows ---
    final cardElevation = isRetro ? 0.0 : 1.5;
    final buttonElevation = isRetro ? 0.0 : 1.0;
    final dialogElevation = isRetro ? 0.0 : 6.0;

    // --- TextTheme ---
    final baseTextColor = colors.onSurface;
    final mutedColor = colors.mutedText;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.canvasBg,
      cardColor: colors.surface,
      dividerColor: colors.border,
      shadowColor: isRetro ? Colors.transparent : Colors.black26,

      // --- Extensions: Lipi-specific tokens ---
      extensions: [
        LipiExtendedColors(
          success: colors.success,
          warning: colors.warning,
          paperBg: colors.paperBg,
          selectedBg: colors.selectedBg,
          styleType: styleType,
          folderBg: colors.folderBg,
          folderTabBg: colors.folderTabBg,
          folderBorder: colors.folderBorder,
          bevelLight: isRetro ? const Color(0xFFFFFFFF) : const Color(0x80FFFFFF),
          bevelDark: isRetro ? const Color(0xFF808080) : const Color(0x182B6CA3),
        ),
      ],

      // --- AppBar ---
      appBarTheme: AppBarTheme(
        backgroundColor: colors.appBarBg,
        foregroundColor: colors.appBarFg,
        elevation: isRetro ? 0 : 1,
        shadowColor: isRetro ? Colors.transparent : colors.appBarBg.withValues(alpha: 0.3),
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.appBarFg,
          fontSize: isRetro ? 14 : 17,
          fontWeight: FontWeight.bold,
          letterSpacing: isRetro ? 0.0 : 0.3,
        ),
        iconTheme: IconThemeData(color: colors.appBarFg, size: isRetro ? 20 : 22),
      ),

      // --- Cards ---
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: cardElevation,
        shadowColor: isRetro ? Colors.transparent : colors.primary.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.cardBorderRadius),
          side: borderSide,
        ),
      ),

      // --- Elevated Buttons ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: buttonElevation,
          shadowColor: isRetro ? Colors.transparent : colors.primary.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.buttonBorderRadius),
            side: isRetro
                ? BorderSide(color: colors.border, width: shapes.borderWidth)
                : BorderSide.none,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isRetro ? 14 : 18,
            vertical: isRetro ? 10 : 12,
          ),
          textStyle: TextStyle(
            fontSize: isRetro ? 13 : 14,
            fontWeight: FontWeight.bold,
            letterSpacing: isRetro ? 0.0 : 0.2,
          ),
        ),
      ),

      // --- Outlined Buttons ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.buttonBorderRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isRetro ? 14 : 18,
            vertical: isRetro ? 10 : 12,
          ),
          textStyle: TextStyle(
            fontSize: isRetro ? 13 : 14,
            fontWeight: isRetro ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),

      // --- Text Buttons ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.buttonBorderRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isRetro ? 10 : 14,
            vertical: isRetro ? 8 : 10,
          ),
          textStyle: TextStyle(
            fontSize: isRetro ? 13 : 14,
            fontWeight: isRetro ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),

      // --- Icon Buttons ---
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.buttonBorderRadius),
          ),
        ),
      ),

      // --- Input Fields ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputBg,
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
          borderSide: BorderSide(
            color: colors.primary,
            width: isRetro ? shapes.borderWidth : shapes.borderWidth + 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.borderRadius),
          borderSide: BorderSide(color: colors.error, width: shapes.borderWidth),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.borderRadius),
          borderSide: BorderSide(color: colors.error, width: shapes.borderWidth + 1),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isRetro ? 10 : 14,
          vertical: isRetro ? 10 : 12,
        ),
        hintStyle: TextStyle(color: mutedColor, fontSize: isRetro ? 13 : 14),
        labelStyle: TextStyle(color: mutedColor, fontSize: isRetro ? 13 : 14),
      ),

      // --- Dialogs ---
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: dialogElevation,
        shadowColor: isRetro ? Colors.transparent : Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isRetro ? 0 : shapes.borderRadius + 4),
          side: borderSide,
        ),
        titleTextStyle: TextStyle(
          color: baseTextColor,
          fontSize: isRetro ? 15 : 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: mutedColor,
          fontSize: isRetro ? 13 : 14,
        ),
      ),

      // --- Dividers ---
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: isRetro ? 2.0 : 1.0,
        space: isRetro ? 2.0 : 1.0,
      ),

      // --- SnackBars ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.appBarBg,
        contentTextStyle: TextStyle(color: colors.appBarFg, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isRetro ? 0 : 8),
        ),
        behavior: isRetro ? SnackBarBehavior.fixed : SnackBarBehavior.floating,
      ),

      // --- PopupMenu ---
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        elevation: isRetro ? 0 : 4,
        shadowColor: isRetro ? Colors.transparent : Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isRetro ? 0 : shapes.borderRadius),
          side: borderSide,
        ),
        textStyle: TextStyle(color: baseTextColor, fontSize: isRetro ? 13 : 14),
      ),

      // --- Tooltips ---
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isRetro ? const Color(0xFFFFFFE1) : colors.appBarBg,
          borderRadius: BorderRadius.circular(isRetro ? 0 : 4),
          border: isRetro ? Border.all(color: colors.border) : null,
        ),
        textStyle: TextStyle(
          color: isRetro ? colors.onSurface : colors.appBarFg,
          fontSize: 12,
        ),
      ),

      // --- Floating Action Button ---
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: isRetro ? 0 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isRetro ? 0 : 16),
          side: isRetro ? borderSide : BorderSide.none,
        ),
      ),

      // --- Dropdown Menu ---
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(shapes.borderRadius),
            borderSide: borderSide,
          ),
        ),
      ),

      // --- ListTile ---
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.cardBorderRadius),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isRetro ? 10 : 16,
          vertical: isRetro ? 4 : 6,
        ),
        titleTextStyle: TextStyle(
          color: baseTextColor,
          fontSize: isRetro ? 14 : 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: mutedColor,
          fontSize: isRetro ? 12 : 13,
        ),
      ),

      // --- Icon Theme ---
      iconTheme: IconThemeData(
        color: colors.onSurface,
        size: isRetro ? 20 : 22,
      ),

      // --- Progress Indicator ---
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.primaryContainer,
      ),
    );
  }
}
