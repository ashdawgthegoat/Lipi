import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domains/consultation/models/consultation.dart';
import '../../../infrastructure/themes/theme_model.dart';
import '../../widgets/file_manager/lipi_file_manager_icons.dart';

/// Theme-aware presentation of a consultation as an authentic literal File Manager Document.
///
/// Implements the mental model: "The doctor is looking at clinical document sheets in a folder."
/// - The file itself is the primary interactive UI element (no enclosing card/panel).
/// - Vista Light: Purpose-built Aero clinical document sheet with dog-ear corner,
///   paper-binding accent strip, faint rules, and soft ambient drop shadow.
/// - 16-Bit Light: Purpose-built retro 16-bit pixel art document with dog-ear fold,
///   1px black borders, and integer pixel scale (`FilterQuality.none`).
class PrescriptionFileItem extends StatefulWidget {
  final Consultation consultation;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const PrescriptionFileItem({
    super.key,
    required this.consultation,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<PrescriptionFileItem> createState() => _PrescriptionFileItemState();
}

class _PrescriptionFileItemState extends State<PrescriptionFileItem> {
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

    final con = widget.consultation;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedDate = dateFormat.format(con.createdAt);
    final shortId = con.id.value.length > 8
        ? con.id.value.substring(0, 8).toUpperCase()
        : con.id.value.toUpperCase();

    final isRetro = ext.isRetro;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onOpen();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: isRetro
              ? _buildRetro16BitFile(context, cs, ext, con, formattedDate, shortId)
              : _buildVistaAeroFile(context, cs, ext, con, formattedDate, shortId),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISTA / AERO FILE MANAGER DOCUMENT
  // ---------------------------------------------------------------------------
  Widget _buildVistaAeroFile(
    BuildContext context,
    ColorScheme cs,
    LipiExtendedColors ext,
    Consultation con,
    String formattedDate,
    String shortId,
  ) {
    final isSaved = con.status.name == 'saved';
    final statusColor = isSaved ? ext.success : cs.secondary;

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
          // 1. Prominent Purpose-Built Vista File Document Graphic
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              LipiFileIcon(
                type: LipiIconType.file,
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
                    key: Key('delete_prescription_${con.id.value}'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    icon: Icon(
                      Icons.delete_outline,
                      color: cs.error,
                      size: 18,
                    ),
                    tooltip: 'Delete Prescription',
                    onPressed: widget.onDelete,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Prescription Tag Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Prescription',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 3. Primary Label: Clinical Date
          Text(
            formattedDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),

          // 4. Secondary Label: Status & Doc ID
          Text(
            'Status: ${con.status.name.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Doc #$shortId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),

          // 5. Bottom Action: "Open" Pill & Fallback Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: widget.onOpen,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 10,
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
  // 16-BIT RETRO FILE MANAGER DOCUMENT
  // ---------------------------------------------------------------------------
  Widget _buildRetro16BitFile(
    BuildContext context,
    ColorScheme cs,
    LipiExtendedColors ext,
    Consultation con,
    String formattedDate,
    String shortId,
  ) {
    const darkShadow = Color(0xFF000000);
    const shadowGray = Color(0xFF808080);
    const whiteHighlight = Color(0xFFFFFFFF);
    final isSaved = con.status.name == 'saved';

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
          // 1. Prominent Purpose-Built 16-Bit Pixel Art File Graphic
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              LipiFileIcon(
                type: LipiIconType.file,
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
                    key: Key('delete_prescription_${con.id.value}'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFF800000),
                      size: 18,
                    ),
                    tooltip: 'Delete Prescription',
                    onPressed: widget.onDelete,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Retro Tag Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFD4D0C8),
              border: Border.all(color: shadowGray, width: 1.0),
            ),
            child: const Text(
              'FILE: RX',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: darkShadow,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // 3. Primary Label: Clinical Date
          Text(
            formattedDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: darkShadow,
            ),
          ),
          const SizedBox(height: 2),

          // 4. Secondary Label: Status & Doc ID
          Text(
            'Status: ${con.status.name.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isSaved ? const Color(0xFF008000) : const Color(0xFF000080),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '#$shortId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF505050),
            ),
          ),
          const SizedBox(height: 5),

          // 5. Bottom Action: Retro Beveled "Open" Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: widget.onOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
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
                      Icon(Icons.open_in_new, size: 11, color: darkShadow),
                      SizedBox(width: 3),
                      Text(
                        'Open',
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
