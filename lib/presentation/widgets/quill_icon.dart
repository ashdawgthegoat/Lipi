import 'package:flutter/material.dart';
import 'lipi_logo.dart';

/// Legacy alias for [LipiLogo]. Renders the signature Lipi fountain pen logo.
class QuillIcon extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showBackground;

  const QuillIcon({
    super.key,
    this.size = 24.0,
    this.borderRadius = 6.0,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return LipiLogo(
      size: size,
      borderRadius: borderRadius,
      showBackground: showBackground,
    );
  }
}
