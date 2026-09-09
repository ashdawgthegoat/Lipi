import 'package:flutter/material.dart';
import 'theme_model.dart';

/// Built-in pre-packaged themes for Lipi.
class BuiltInThemes {
  BuiltInThemes._();

  /// Vista/Aero-inspired presentation:
  /// Soft slate-cyan blues, gentle layered depth, polished rounded controls,
  /// subtle shadows, luminous hover states, paper-like prescription surface.
  /// Inspired by the visual language of Windows Vista Aero (2006–2009).
  static const LipiTheme vistaLight = LipiTheme(
    id: 'vista-light',
    name: 'Vista Light',
    version: '1.0',
    author: 'Lipi Team',
    description: 'Aero-inspired clinical workspace with soft blues, layered depth, and polished rounded controls.',
    styleType: 'vista',
    isBuiltIn: true,
    colors: ThemeColors(
      primary: Color(0xFF3672A4),          // Soft Aero blue — luminous, not harsh
      primaryContainer: Color(0xFFE3EEF8), // Light blue wash for badges/containers
      surface: Color(0xFFFFFFFF),          // Clean white for cards/dialogs
      surfaceVariant: Color(0xFFF0F4F9),   // Cool off-white for elevated sections
      background: Color(0xFFE8EDF4),       // Soft slate desktop background
      onPrimary: Color(0xFFFFFFFF),        // White text on blue
      onSurface: Color(0xFF1A2332),        // Deep slate text — high readability
      border: Color(0xFFC4CFDC),           // Soft blue-gray border
      appBarBg: Color(0xFF2D5F8A),         // Aero glass-inspired blue header
      appBarFg: Color(0xFFFFFFFF),         // White header text
      accent: Color(0xFF0078D4),           // Sky blue accent (confirmation/links)
      canvasBg: Color(0xFFDEE5EE),         // Soft desk surface around paper
      paperBg: Color(0xFFFFFFFF),          // Pure white prescription paper
      sliderBg: Color(0xFFE0E8F0),         // Harmonized slider track
      error: Color(0xFFC42B1C),            // Vista crimson — clear clinical error
      success: Color(0xFF107C10),          // Vista emerald — successful actions
      warning: Color(0xFFD48800),          // Warm amber — caution/attention
      mutedText: Color(0xFF6B7D94),        // Muted blue-gray for secondary text
      inputBg: Color(0xFFF7F9FC),          // Very light blue-white input fields
      selectedBg: Color(0xFFD6E8F7),       // Soft blue selection highlight
      folderBg: Color(0xFFFFFFFF),         // Clean white folder sheet
      folderTabBg: Color(0xFFE2EDF8),      // Soft Aero tab tone
      folderBorder: Color(0xFFBACADB),     // Crisp Aero folder outline
    ),
    shapes: ThemeShapes(
      borderRadius: 6.0,                  // Inputs and dialogs
      cardBorderRadius: 8.0,              // Cards: soft rounded
      buttonBorderRadius: 4.0,            // Buttons: subtle rounding
      borderWidth: 1.0,                   // Refined 1px borders
    ),
  );

  /// Retro 16-bit OS presentation:
  /// Warm putty-gray surfaces, crisp square corners, 2px bevel-style borders,
  /// classic navy titlebar, teal accents, compact utilitarian controls.
  /// Inspired by Windows 95/98 and classic 16-bit desktop environments.
  static const LipiTheme sixteenBitLight = LipiTheme(
    id: 'sixteen-bit-light',
    name: '16-Bit Light',
    version: '1.0',
    author: 'Lipi Team',
    description: 'Classic 16-bit workstation theme with warm gray surfaces, crisp beveled borders, and retro desktop accents.',
    styleType: 'retro16bit',
    isBuiltIn: true,
    colors: ThemeColors(
      primary: Color(0xFF000080),          // Classic Win95 navy blue
      primaryContainer: Color(0xFFD4D0C8), // Warm chassis gray container
      surface: Color(0xFFD4D0C8),          // Classic warm button-face gray
      surfaceVariant: Color(0xFFE4E0D8),   // Elevated warm panel
      background: Color(0xFFC0BDB6),       // Desktop warm gray
      onPrimary: Color(0xFFFFFFFF),        // High-contrast title text
      onSurface: Color(0xFF000000),        // Pure black body text — max legibility
      border: Color(0xFF808080),           // Classic shadow gray border
      appBarBg: Color(0xFF000080),         // Classic navy titlebar
      appBarFg: Color(0xFFFFFFFF),         // White titlebar text
      accent: Color(0xFF008080),           // Classic teal accent
      canvasBg: Color(0xFFA8A5A0),         // Warm desk gray behind prescription
      paperBg: Color(0xFFFFFFFF),          // Pure white clinical paper
      sliderBg: Color(0xFFC0C0C0),         // Classic silver scrollbar track
      error: Color(0xFFC00000),            // Clear clinical red
      success: Color(0xFF008000),          // Classic green
      warning: Color(0xFF808000),          // Classic olive warning
      mutedText: Color(0xFF808080),        // Classic disabled/muted text
      inputBg: Color(0xFFFFFFFF),          // White input wells (sunken)
      selectedBg: Color(0xFF000080),       // Classic navy selection
      folderBg: Color(0xFFD4D0C8),         // Classic warm button-face chassis
      folderTabBg: Color(0xFFDDD7C8),      // Warm manila tab tone
      folderBorder: Color(0xFF808080),     // Classic 3D shadow gray border
    ),
    shapes: ThemeShapes(
      borderRadius: 0.0,                  // Strict square corners
      cardBorderRadius: 0.0,              // No rounding
      buttonBorderRadius: 0.0,            // Sharp buttons
      borderWidth: 2.0,                   // Classic 2px bevel-depth borders
    ),
  );

  /// All built-in themes mapped by ID.
  static final Map<String, LipiTheme> all = {
    vistaLight.id: vistaLight,
    sixteenBitLight.id: sixteenBitLight,
  };

  /// The default built-in theme.
  static const LipiTheme defaultTheme = vistaLight;
}
