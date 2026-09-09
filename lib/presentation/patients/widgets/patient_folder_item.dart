import 'package:flutter/material.dart';
import '../../../domains/patient/models/patient.dart';
import '../../../infrastructure/themes/theme_model.dart';
import '../../widgets/file_manager/lipi_file_manager_icons.dart';

/// Theme-aware presentation of a patient record as an authentic, literal File Manager Folder.
///
/// Implements the mental model: "The doctor is looking at patient folders on a filing desk."
/// - The folder itself is the primary interactive UI element (no enclosing card/panel).
/// - Vista Light: Purpose-built Aero luminous 3D folder with peeking paper, soft glow,
///   and clean file-manager typography.
/// - 16-Bit Light: Purpose-built retro 16-bit pixel art folder with crisp black borders,
///   integer pixel scale (`FilterQuality.none`), and beveled controls.
class PatientFolderItem extends StatefulWidget {
  final Patient patient;
  final int visitCount;
  final VoidCallback onTap;
  final VoidCallback onNewRx;
  final VoidCallback onDelete;

  const PatientFolderItem({
    super.key,
    required this.patient,
    required this.visitCount,
    required this.onTap,
    required this.onNewRx,
    required this.onDelete,
  });

  @override
  State<PatientFolderItem> createState() => _PatientFolderItemState();
}

class _PatientFolderItemState extends State<PatientFolderItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<LipiExtendedColors>() ??
        const LipiExtendedColors(
          success: Color(0xFF107C10),
          warning: Color(0xFFD48800),
          paperBg: Color(0xFFFFFFFF),
          selectedBg: Color(0xFFD6E8F7),
        );

    final isRetro = ext.isRetro;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: isRetro
              ? _buildRetro16BitFolder(context, cs, ext)
              : _buildVistaAeroFolder(context, cs, ext),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISTA / AERO FILE MANAGER FOLDER
  // ---------------------------------------------------------------------------
  Widget _buildVistaAeroFolder(
    BuildContext context,
    ColorScheme cs,
    LipiExtendedColors ext,
  ) {
    final patient = widget.patient;
    final shortId = patient.id.value.length > 8
        ? patient.id.value.substring(0, 8).toUpperCase()
        : patient.id.value.toUpperCase();

    final iconState = _isPressed
        ? LipiIconState.pressed
        : _isHovered
            ? LipiIconState.hovered
            : LipiIconState.normal;

    return Container(
      decoration: BoxDecoration(
        color: _isHovered ? cs.primary.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isHovered ? cs.primary.withValues(alpha: 0.25) : Colors.transparent,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Prominent Purpose-Built Vista Folder Graphic
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              LipiFolderIcon(
                isOpen: false,
                state: iconState,
                size: 78,
              ),
              // Discreet Top Action (Delete Icon)
              Positioned(
                top: -4,
                right: -8,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    icon: Icon(
                      Icons.delete_outline,
                      color: cs.error,
                      size: 18,
                    ),
                    tooltip: 'Delete Patient',
                    onPressed: widget.onDelete,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Tab Identifier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: ext.folderTabBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ext.folderBorder, width: 0.8),
            ),
            child: Text(
              'RECORD #$shortId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 3. Primary Label: Patient Name
          Text(
            patient.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 2),

          // 4. Secondary Label: Demographics
          Text(
            '${patient.age} Y • ${patient.gender} • ${patient.city}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),

          // 5. Bottom Metadata Row: Visit Count & "New Rx" Action
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.visitCount == 0
                        ? '0 Visits'
                        : widget.visitCount == 1
                            ? '1 Prescription'
                            : '${widget.visitCount} Prescriptions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: widget.onNewRx,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, size: 12, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'New Rx',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 16-BIT RETRO FILE MANAGER FOLDER
  // ---------------------------------------------------------------------------
  Widget _buildRetro16BitFolder(
    BuildContext context,
    ColorScheme cs,
    LipiExtendedColors ext,
  ) {
    final patient = widget.patient;
    final shortId = patient.id.value.length > 8
        ? patient.id.value.substring(0, 8).toUpperCase()
        : patient.id.value.toUpperCase();

    const whiteHighlight = Color(0xFFFFFFFF);
    const shadowGray = Color(0xFF808080);
    const darkShadow = Color(0xFF000000);

    final iconState = _isPressed
        ? LipiIconState.pressed
        : _isHovered
            ? LipiIconState.hovered
            : LipiIconState.normal;

    return Container(
      decoration: BoxDecoration(
        color: _isHovered ? const Color(0xFF000080).withValues(alpha: 0.06) : Colors.transparent,
        border: _isHovered
            ? Border.all(color: shadowGray, width: 1.0)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Prominent Purpose-Built 16-Bit Pixel Art Folder Graphic
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              LipiFolderIcon(
                isOpen: false,
                state: iconState,
                size: 76,
              ),
              // Discreet Top Action (Retro Delete Button)
              Positioned(
                top: -4,
                right: -8,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFF800000),
                      size: 18,
                    ),
                    tooltip: 'Delete Patient',
                    onPressed: widget.onDelete,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Retro Tab Identifier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: const BoxDecoration(
              color: Color(0xFFDDD7C8),
              border: Border(
                top: BorderSide(color: whiteHighlight, width: 1.0),
                left: BorderSide(color: whiteHighlight, width: 1.0),
                right: BorderSide(color: shadowGray, width: 1.0),
                bottom: BorderSide(color: shadowGray, width: 1.0),
              ),
            ),
            child: Text(
              'FILE: $shortId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: darkShadow,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 3. Primary Label: Patient Name
          Text(
            patient.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: darkShadow,
            ),
          ),
          const SizedBox(height: 2),

          // 4. Secondary Label: Demographics
          Text(
            '${patient.age} Y • ${patient.gender} • ${patient.city}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF404040),
            ),
          ),
          const SizedBox(height: 5),

          // 5. Bottom Metadata Row: Visit Count & Retro "New Rx" Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    border: Border.all(color: shadowGray, width: 1.0),
                  ),
                  child: Text(
                    widget.visitCount == 0
                        ? '0 Visits'
                        : widget.visitCount == 1
                            ? '1 Prescription'
                            : '${widget.visitCount} Prescriptions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000080),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onNewRx,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4D0C8),
                    border: Border(
                      top: BorderSide(color: whiteHighlight, width: 1.5),
                      left: BorderSide(color: whiteHighlight, width: 1.5),
                      right: BorderSide(color: darkShadow, width: 1.5),
                      bottom: BorderSide(color: darkShadow, width: 1.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, size: 12, color: darkShadow),
                      SizedBox(width: 2),
                      Text(
                        'New Rx',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: darkShadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
