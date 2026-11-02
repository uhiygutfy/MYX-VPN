import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// myx-VPN wordmark: shield emblem + "myx" (red) "-VPN" (navy / white).
/// (Class name kept so existing call sites don't change.)
class LanternLogo extends StatelessWidget {
  final bool isPro;
  final Color? color;
  final double? height;
  final double? widthFraction;

  const LanternLogo({
    super.key,
    this.isPro = false,
    this.color,
    this.height,
    this.widthFraction = 0.27,
  });

  @override
  Widget build(BuildContext context) {
    final usableWidth = math.min(MediaQuery.sizeOf(context).width, 430.0);
    final width = math.min((widthFraction ?? 0.27) * usableWidth, 140.0);
    final h = height ?? (width / 4.2).clamp(18.0, 30.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MyxShield(size: h * 1.3),
        SizedBox(width: h * 0.35),
        MyxWordmark(fontSize: h, vpnColor: color),
      ],
    );
  }
}

/// "myx-VPN" in the brand colours. [vpnColor] defaults to navy on light
/// backgrounds and white on dark ones.
class MyxWordmark extends StatelessWidget {
  const MyxWordmark({super.key, required this.fontSize, this.vpnColor});
  final double fontSize;
  final Color? vpnColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = TextStyle(
      fontSize: fontSize,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'myx',
            style: base.copyWith(color: AppColors.myxRed),
          ),
          TextSpan(
            text: '-VPN',
            style: base.copyWith(
              color: vpnColor ?? (dark ? Colors.white : AppColors.myxNavy),
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      semanticsLabel: 'myx-VPN',
    );
  }
}

/// Square app emblem.
class LanternRoundedLogo extends StatelessWidget {
  final double? height;
  final double? width;
  const LanternRoundedLogo({super.key, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    final s = math.min(height ?? width ?? 64, width ?? height ?? 64);
    return SizedBox(
      width: s,
      height: s,
      child: Center(child: MyxShield(size: s * 0.92)),
    );
  }
}

/// The myx shield: left half blue, right half red, white padlock.
class MyxShield extends StatelessWidget {
  final double size;
  const MyxShield({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: MyxShieldPainter()),
    );
  }
}

class MyxShieldPainter extends CustomPainter {
  static Path shieldPath(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.66, h * 0.08, w * 0.82, h * 0.11, w * 0.95, h * 0.12)
      ..lineTo(w * 0.95, h * 0.47)
      ..cubicTo(w * 0.95, h * 0.73, w * 0.76, h * 0.9, w * 0.5, h)
      ..cubicTo(w * 0.24, h * 0.9, w * 0.05, h * 0.73, w * 0.05, h * 0.47)
      ..lineTo(w * 0.05, h * 0.12)
      ..cubicTo(w * 0.18, h * 0.11, w * 0.34, h * 0.08, w * 0.5, 0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shield = shieldPath(size);

    // Soft drop shadow
    canvas.drawPath(
      shield.shift(Offset(0, h * 0.03)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );

    canvas.save();
    canvas.clipPath(shield);
    // Left: blue
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w * 0.5, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B7BFF), Color(0xFF1336A8)],
        ).createShader(Rect.fromLTWH(0, 0, w * 0.5, h)),
    );
    // Right: red
    canvas.drawRect(
      Rect.fromLTWH(w * 0.5, 0, w * 0.5, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF4B5C), Color(0xFFB80F2E)],
        ).createShader(Rect.fromLTWH(w * 0.5, 0, w * 0.5, h)),
    );
    // Top sheen
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.30), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45)),
    );
    canvas.restore();

    // Inner white rim
    final inner = shieldPath(Size(w * 0.84, h * 0.84)).shift(
      Offset(w * 0.08, h * 0.075),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.035)
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    // Padlock
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.33, h * 0.43, w * 0.34, h * 0.27),
      Radius.circular(w * 0.05),
    );
    final shackle = Path()
      ..moveTo(w * 0.39, h * 0.44)
      ..lineTo(w * 0.39, h * 0.37)
      ..arcToPoint(
        Offset(w * 0.61, h * 0.37),
        radius: Radius.circular(w * 0.11),
      )
      ..lineTo(w * 0.61, h * 0.44);
    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    canvas.drawRRect(bodyRect, Paint()..color = Colors.white);
    // Keyhole
    final kc = Offset(w * 0.5, h * 0.54);
    final keyPaint = Paint()..color = AppColors.myxNavy;
    canvas.drawCircle(kc, w * 0.035, keyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: kc + Offset(0, h * 0.045),
          width: w * 0.03,
          height: h * 0.07,
        ),
        Radius.circular(w * 0.015),
      ),
      keyPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
