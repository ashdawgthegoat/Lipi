import 'package:flutter/material.dart';

/// Renders the signature Lipi soft clean fountain pen logo on a pure white background.
///
/// Communicates writing, handwriting, professionalism, simplicity, and refinement.
/// Independent of the selected theme (white background intentional).
class LipiLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showBackground;

  const LipiLogo({
    super.key,
    this.size = 24.0,
    this.borderRadius = 6.0,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/branding/lipi_fountain_pen.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.edit_outlined,
          size: size,
          color: const Color(0xFF1E293B),
        );
      },
    );

    if (!showBackground) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: image,
    );
  }
}
