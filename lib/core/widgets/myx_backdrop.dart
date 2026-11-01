import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';

/// Ambient MYX-VPN background: the theme surface with soft blue (top) and
/// red (bottom) light pools and a faint dot grid.
class MyxBackdrop extends StatelessWidget {
  final Widget child;
  const MyxBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _BackdropPainter(dark: dark),
      child: child,
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final bool dark;
  _BackdropPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final k = dark ? 1.0 : 0.45;

    void pool(Offset center, double radius, Color color, double alpha) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              center.dx / size.width * 2 - 1,
              center.dy / size.height * 2 - 1,
            ),
            radius: radius / size.shortestSide,
            colors: [
              color.withValues(alpha: alpha * k),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    pool(Offset(size.width * 0.15, size.height * 0.08), size.shortestSide * 0.9,
        AppColors.myxBlue, 0.20);
    pool(Offset(size.width * 0.95, size.height * 0.98), size.shortestSide * 0.8,
        AppColors.myxRed, 0.12);

    // Dot grid
    final dot = Paint()
      ..color = (dark ? Colors.white : AppColors.blue10)
          .withValues(alpha: dark ? 0.035 : 0.04);
    const step = 22.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.8, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.dark != dark;
}
