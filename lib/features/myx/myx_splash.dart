import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/common.dart';

/// Cold-start splash: white page, shield + wordmark + tagline, red/blue wave.
/// Fades itself out after a short moment and calls [onDone].
class MyxSplash extends HookWidget {
  const MyxSplash({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final intro = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );
    final fade = useAnimationController(
      duration: const Duration(milliseconds: 380),
    );
    useEffect(() {
      intro.forward();
      Future.delayed(const Duration(milliseconds: 1700), () async {
        if (!context.mounted || fade.isAnimating || fade.isCompleted) return;
        await fade.forward();
        if (context.mounted) onDone();
      });
      return null;
    }, const []);

    return AnimatedBuilder(
      animation: Listenable.merge([intro, fade]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(intro.value);
        return IgnorePointer(
          ignoring: fade.value > 0.5,
          child: Opacity(
            opacity: 1 - fade.value,
            child: Material(
              color: Colors.white,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _SplashBackdrop()),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - t)),
                      child: Opacity(
                        opacity: t,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MyxShield(size: 96 + 8 * t),
                            const SizedBox(height: 14),
                            const MyxWordmark(
                              fontSize: 38,
                              vpnColor: AppColors.myxNavy,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'myx_tagline'.i18n,
                              style: const TextStyle(
                                color: AppColors.myxNavy,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment(0, 0.62),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: AppColors.myxRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SplashBackdrop extends CustomPainter {
  const _SplashBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Faint dotted "world" band behind the logo.
    final dot = Paint()..color = const Color(0xFF13286B).withValues(alpha: 0.06);
    final rnd = math.Random(7);
    for (var i = 0; i < 420; i++) {
      final x = rnd.nextDouble() * w;
      final y = h * 0.55 + (rnd.nextDouble() - 0.5) * h * 0.22;
      canvas.drawCircle(Offset(x, y), 1.4, dot);
    }

    // Bottom waves: red then blue.
    Path wave(double top, double amp) => Path()
      ..moveTo(0, h * top)
      ..cubicTo(w * 0.3, h * (top - amp), w * 0.6, h * (top + amp), w, h * (top - amp * 0.4))
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      wave(0.84, 0.05),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF4B5C), Color(0xFFC3123A)],
        ).createShader(Rect.fromLTWH(0, h * 0.75, w, h * 0.25)),
    );
    canvas.drawPath(
      wave(0.9, 0.04),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1336A8), Color(0xFF3B7BFF)],
        ).createShader(Rect.fromLTWH(0, h * 0.8, w, h * 0.2)),
    );
    canvas.drawPath(
      wave(0.95, 0.025),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
