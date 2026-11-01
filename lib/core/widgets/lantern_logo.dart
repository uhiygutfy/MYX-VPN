import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// MYX-VPN wordmark: shield emblem + "MYX" with a red "VPN" tag.
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
    // Cap usable width to avoid tablets blowing up the logo
    final usableWidth = math.min(MediaQuery.sizeOf(context).width, 430.0);
    final width = math.min((widthFraction ?? 0.27) * usableWidth, 140.0);
    final h = height ?? (width / 4.6).clamp(18.0, 30.0);
    final textColor = color ?? context.textPrimary;

    return Semantics(
      label: 'MYX-VPN',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MyxShield(size: h * 1.25),
          SizedBox(width: h * 0.4),
          Text(
            'MYX',
            style: TextStyle(
              fontSize: h * 0.92,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: h * 0.06,
              color: textColor,
            ),
          ),
          SizedBox(width: h * 0.22),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: h * 0.22,
              vertical: h * 0.08,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(h * 0.22),
              gradient: const LinearGradient(
                colors: [AppColors.myxRed, AppColors.myxRedDeep],
              ),
            ),
            child: Text(
              isPro ? 'PRO' : 'VPN',
              style: TextStyle(
                fontSize: h * 0.5,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: h * 0.05,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Square app emblem (used where Lantern showed its rounded logo).
class LanternRoundedLogo extends StatelessWidget {
  final double? height;
  final double? width;
  const LanternRoundedLogo({super.key, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    final s = math.min(height ?? width ?? 64, width ?? height ?? 64);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(s * 0.26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101A3D), AppColors.myxNight],
        ),
        border: Border.all(color: const Color(0x332F6BFF)),
      ),
      alignment: Alignment.center,
      child: MyxShield(size: s * 0.62),
    );
  }
}

/// The MYX shield: blue→red gradient shield with a cut "M" chevron.
class MyxShield extends StatelessWidget {
  final double size;
  const MyxShield({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ShieldPainter()),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shield = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.68, h * 0.09, w * 0.84, h * 0.12, w * 0.96, h * 0.13)
      ..lineTo(w * 0.96, h * 0.48)
      ..cubicTo(w * 0.96, h * 0.74, w * 0.76, h * 0.9, w * 0.5, h)
      ..cubicTo(w * 0.24, h * 0.9, w * 0.04, h * 0.74, w * 0.04, h * 0.48)
      ..lineTo(w * 0.04, h * 0.13)
      ..cubicTo(w * 0.16, h * 0.12, w * 0.32, h * 0.09, w * 0.5, 0)
      ..close();

    final rect = Offset.zero & size;
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.myxBlue, Color(0xFF6A3DFF), AppColors.myxRed],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    // Top sheen
    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.42),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.42)),
    );
    canvas.restore();

    // "M" chevron
    final m = Path()
      ..moveTo(w * 0.27, h * 0.66)
      ..lineTo(w * 0.27, h * 0.33)
      ..lineTo(w * 0.5, h * 0.53)
      ..lineTo(w * 0.73, h * 0.33)
      ..lineTo(w * 0.73, h * 0.66);
    canvas.drawPath(
      m,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
