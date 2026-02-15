import 'dart:math';
import 'package:flutter/material.dart';

/// Matte texture & grain overlay — gives that analog film look
class GrainOverlay extends StatelessWidget {
  final Widget child;
  final double opacity;

  const GrainOverlay({super.key, required this.child, this.opacity = 0.04});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _GrainPainter(opacity: opacity)),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  final double opacity;
  final Random _random = Random(42); // Fixed seed for consistent grain

  _GrainPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Paint scattered dots for film grain effect
    for (int i = 0; i < (size.width * size.height * 0.006).toInt(); i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final brightness = _random.nextDouble();
      paint.color = (brightness > 0.5 ? Colors.white : Colors.black).withAlpha(
        (opacity * 255 * _random.nextDouble()).toInt(),
      );
      canvas.drawCircle(Offset(x, y), _random.nextDouble() * 0.8 + 0.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Centralized matte color palette
class MatteColors {
  // Backgrounds — true matte blacks
  static const bg = Color(0xFF111111);
  static const bgCard = Color(0xFF1A1A1A);
  static const bgElevated = Color(0xFF222222);
  static const bgHover = Color(0xFF2A2A2A);

  // Borders
  static const border = Color(0xFF2E2E2E);
  static const borderSubtle = Color(0xFF252525);

  // Text — matte whites (not pure white)
  static const textPrimary = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFFA0A0A0);
  static const textTertiary = Color(0xFF6A6A6A);
  static const textMuted = Color(0xFF4A4A4A);

  // Accents — warm, muted tones
  static const accent = Color(0xFFB8C4D0); // Matte steel blue
  static const accentWarm = Color(0xFFD4A574); // Warm amber
  static const success = Color(0xFF7FB069); // Matte green
  static const error = Color(0xFFCF6679); // Matte rose

  // Interactive
  static const activeHighlight = Color(0xFF2A3040);
}
