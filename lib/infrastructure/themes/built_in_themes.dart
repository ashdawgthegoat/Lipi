import 'package:flutter/material.dart';
import 'theme_model.dart';

/// Built-in pre-packaged themes for Lipi.
class BuiltInThemes {
  BuiltInThemes._();

  /// Vista/Aero-inspired presentation:
  /// Soft blues/slate, gently rounded controls, clean typography, paper-like prescription surface.
  static const LipiTheme vistaLight = LipiTheme(
    id: 'vista-light',
    name: 'Vista Light',
    version: '1.0',
    author: 'Lipi Team',
    description: 'Vista/Aero-inspired presentation with soft blues, slate surfaces, and gently rounded controls.',
    styleType: 'vista',
    isBuiltIn: true,
    colors: ThemeColors(
      primary: Color(0xFF1E5A8A),        // Aero blue
      primaryContainer: Color(0xFFDCE8F5),
      surface: Color(0xFFFFFFFF),
      surfaceVariant: Color(0xFFF1F5F9),
      background: Color(0xFFE2E8F0),     // Soft slate background
      onPrimary: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1E293B),
      border: Color(0xFFCBD5E1),
      appBarBg: Color(0xFF1E3A5F),       // Deep aero blue app bar
      appBarFg: Color(0xFFFFFFFF),
      accent: Color(0xFF0284C7),         // Vibrant sky blue
      canvasBg: Color(0xFFD6E2EE),       // Paper viewport cool grey
      paperBg: Color(0xFFFFFFFF),        // Paper stays pure white
      sliderBg: Color(0xFFE2EBF4),
    ),
    shapes: ThemeShapes(
      borderRadius: 8.0,
      cardBorderRadius: 8.0,
      buttonBorderRadius: 6.0,
      borderWidth: 1.0,
    ),
  );

  /// Retro 16-bit OS presentation:
  /// Warm light grey, chunky pixel/beveled borders, retro UI accents, readable typography, paper remains clean.
  static const LipiTheme sixteenBitLight = LipiTheme(
    id: 'sixteen-bit-light',
    name: '16-Bit Light',
    version: '1.0',
    author: 'Lipi Team',
    description: 'Retro 16-bit OS styling with warm light grey surfaces, chunky pixel borders, and classic window accents.',
    styleType: 'retro16bit',
    isBuiltIn: true,
    colors: ThemeColors(
      primary: Color(0xFF2B3A67),        // Retro indigo/navy
      primaryContainer: Color(0xFFCCD1DC),
      surface: Color(0xFFECECEC),        // Classic 90s OS grey
      surfaceVariant: Color(0xFFDFE1E5),
      background: Color(0xFFD4D6D8),     // Warm light grey background
      onPrimary: Color(0xFFFFFFFF),
      onSurface: Color(0xFF111111),
      border: Color(0xFF262626),         // Dark chunky pixel border
      appBarBg: Color(0xFF354674),       // Classic window titlebar
      appBarFg: Color(0xFFFFFFFF),
      accent: Color(0xFFD9531E),         // Retro 16-bit pixel orange
      canvasBg: Color(0xFFB8BCC0),       // Classic desk grey
      paperBg: Color(0xFFFFFFFF),        // Prescription paper stays crisp white
      sliderBg: Color(0xFFD8D8D8),
    ),
    shapes: ThemeShapes(
      borderRadius: 2.0,
      cardBorderRadius: 2.0,
      buttonBorderRadius: 2.0,
      borderWidth: 2.0,
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
