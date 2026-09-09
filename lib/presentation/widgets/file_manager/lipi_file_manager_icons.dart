import 'package:flutter/material.dart';
import '../../../infrastructure/themes/theme_model.dart';

/// Semantic types of file manager icons supported in Lipi.
enum LipiIconType {
  /// Closed patient folder
  folder,

  /// Open patient folder (used in headers, dossier, and empty states)
  folderOpen,

  /// Clinical prescription file document
  file,

  /// PDF report or prescription template document
  filePdf,

  /// Image template document
  fileImage,
}

/// Visual interaction states for file manager icons.
enum LipiIconState {
  normal,
  hovered,
  pressed,
  selected,
  disabled,
}

/// Purpose-built file manager icon component for Lipi.
///
/// Automatically adapts between:
/// - **Vista Light**: Windows Vista Aero-style luminous gradients, soft 3D volume,
///   gentle highlights, and ambient drop shadows.
/// - **16-Bit Light**: Windows 95 / classic retro pixel-art with hard 1px black borders
///   and integer pixel integrity (`FilterQuality.none`).
///
/// Centralizes all file and folder iconography so individual screens do not need
/// theme switching or one-off icon logic.
class LipiFileManagerIcon extends StatelessWidget {
  final LipiIconType type;
  final LipiIconState state;
  final double size;

  const LipiFileManagerIcon({
    super.key,
    required this.type,
    this.state = LipiIconState.normal,
    this.size = 72.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<LipiExtendedColors>();
    final isRetro = ext?.isRetro ?? false;

    // Resolve theme-specific asset path
    final themeFolder = isRetro ? 'sixteen_bit' : 'vista';
    final assetFileName = switch (type) {
      LipiIconType.folder => 'folder.png',
      LipiIconType.folderOpen => 'folder_open.png',
      LipiIconType.file => 'file.png',
      LipiIconType.filePdf => 'file_pdf.png',
      LipiIconType.fileImage => 'file_image.png',
    };

    final assetPath = 'assets/icons/$themeFolder/$assetFileName';

    // State transforms
    final isHovered = state == LipiIconState.hovered;
    final isPressed = state == LipiIconState.pressed;
    final isSelected = state == LipiIconState.selected;
    final isDisabled = state == LipiIconState.disabled;

    Widget iconWidget = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // CRITICAL: FilterQuality.none guarantees sharp, pixel-perfect 16-bit rendering without blur
      filterQuality: isRetro ? FilterQuality.none : FilterQuality.medium,
    );

    if (isDisabled) {
      iconWidget = Opacity(opacity: 0.45, child: iconWidget);
    }

    if (isSelected) {
      if (isRetro) {
        // Retro selection: dotted/sunken focus frame
        iconWidget = Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF000080).withValues(alpha: 0.15),
            border: Border.all(
              color: const Color(0xFF000080),
              width: 1.5,
            ),
          ),
          child: iconWidget,
        );
      } else {
        // Vista Aero selection: luminous glow aura
        iconWidget = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.40),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.20),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: iconWidget,
        );
      }
    }

    // Smooth press and hover scaling
    final scale = isPressed
        ? 0.94
        : isHovered
            ? 1.05
            : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: iconWidget,
    );
  }
}

/// Convenience widget for patient folder icons (closed or open).
class LipiFolderIcon extends StatelessWidget {
  final bool isOpen;
  final LipiIconState state;
  final double size;

  const LipiFolderIcon({
    super.key,
    this.isOpen = false,
    this.state = LipiIconState.normal,
    this.size = 72.0,
  });

  @override
  Widget build(BuildContext context) {
    return LipiFileManagerIcon(
      type: isOpen ? LipiIconType.folderOpen : LipiIconType.folder,
      state: state,
      size: size,
    );
  }
}

/// Convenience widget for prescription and document file icons.
class LipiFileIcon extends StatelessWidget {
  final LipiIconType type;
  final LipiIconState state;
  final double size;

  const LipiFileIcon({
    super.key,
    this.type = LipiIconType.file,
    this.state = LipiIconState.normal,
    this.size = 72.0,
  });

  @override
  Widget build(BuildContext context) {
    return LipiFileManagerIcon(
      type: type,
      state: state,
      size: size,
    );
  }
}
