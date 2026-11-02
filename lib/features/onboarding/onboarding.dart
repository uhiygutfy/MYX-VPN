import 'dart:math' as math;

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

import '../home/provider/app_setting_notifier.dart';
import '../home/provider/radiance_settings_providers.dart';

/// myx-VPN first-run walkthrough. No account or sign-in step.
@RoutePage(name: 'Onboarding')
class Onboarding extends StatefulHookConsumerWidget {
  const Onboarding({super.key});

  @override
  ConsumerState<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<Onboarding> {
  @override
  Widget build(BuildContext context) {
    final controller = usePageController();
    final page = useState(0);
    final appSetting = ref.read(appSettingProvider);

    final pages = [
      (_Art.shield, 'myx_onb1_title'.i18n, 'myx_onb1_body'.i18n),
      (_Art.globe, 'myx_onb2_title'.i18n, 'myx_onb2_body'.i18n),
      (_Art.bolt, 'myx_onb3_title'.i18n, 'myx_onb3_body'.i18n),
    ];
    final last = page.value == pages.length - 1;

    Future<void> finish() async {
      await ref
          .read(radianceSettingsProvider.notifier)
          .setRoutingMode(RoutingMode.smart);
      ref.read(appSettingProvider.notifier).setOnboardingCompleted(true);
      final showExtensionDialog =
          appSetting.showSplashScreen && PlatformUtils.isMacOS;
      appRouter.pop();
      if (showExtensionDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.push(const MacOSExtensionDialog());
        });
        ref.read(appSettingProvider.notifier).setSplashScreen(false);
      }
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const Key('onboarding.screen'),
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _SoftBackdrop())),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MyxShield(size: 34),
                      SizedBox(width: 8),
                      MyxWordmark(fontSize: 22, vpnColor: AppColors.myxNavy),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: controller,
                      itemCount: pages.length,
                      onPageChanged: (i) => page.value = i,
                      itemBuilder: (context, i) => _Page(
                        art: pages[i].$1,
                        title: pages[i].$2,
                        body: pages[i].$3,
                      ),
                    ),
                  ),
                  _Dots(count: pages.length, index: page.value),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        key: const Key('onboarding.primary'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.myxRed,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: AppColors.myxRed.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          if (last) {
                            finish();
                          } else {
                            controller.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        child: Text(
                          last ? 'myx_get_started'.i18n : 'myx_next'.i18n,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 44,
                    child: last
                        ? null
                        : TextButton(
                            key: const Key('onboarding.skip'),
                            onPressed: finish,
                            child: Text(
                              'myx_skip'.i18n,
                              style: const TextStyle(
                                color: AppColors.myxRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Art { shield, globe, bolt }

class _Page extends StatelessWidget {
  const _Page({required this.art, required this.title, required this.body});
  final _Art art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final size = math.min(MediaQuery.sizeOf(context).width * 0.62, 260.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _ArtPainter(art)),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0B1638),
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5A6380),
              fontSize: 15.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: i == index ? AppColors.myxRed : const Color(0xFFC9D3EE),
            ),
          ),
      ],
    );
  }
}

/// Illustrations: a big soft disc with a glyph built from simple shapes.
class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art);
  final _Art art;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Halo + disc
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x332F6BFF), Color(0x002F6BFF)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF0FF), Color(0xFFFFE8EC)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.72)),
    );
    // Orbit ring with two satellites
    final orbit = Rect.fromCircle(center: c, radius: r * 0.88);
    canvas.drawOval(
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x552F6BFF),
    );
    canvas.drawCircle(
      c + Offset(math.cos(-0.9), math.sin(-0.9)) * r * 0.88,
      r * 0.05,
      Paint()..color = AppColors.myxRed,
    );
    canvas.drawCircle(
      c + Offset(math.cos(2.3), math.sin(2.3)) * r * 0.88,
      r * 0.04,
      Paint()..color = AppColors.myxBlue,
    );

    switch (art) {
      case _Art.shield:
        final s = r * 0.95;
        canvas.save();
        canvas.translate(c.dx - s / 2, c.dy - s / 2);
        MyxShieldPainter().paint(canvas, Size(s, s));
        canvas.restore();
      case _Art.globe:
        final g = r * 0.48;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..color = AppColors.myxBlue;
        canvas.drawCircle(c, g, p);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: g * 1.0, height: g * 2),
          p,
        );
        canvas.drawLine(c - Offset(g, 0), c + Offset(g, 0), p);
        canvas.drawLine(
          c - Offset(g * 0.87, g * 0.5),
          c + Offset(g * 0.87, -g * 0.5),
          p,
        );
        canvas.drawLine(
          c - Offset(g * 0.87, -g * 0.5),
          c + Offset(g * 0.87, g * 0.5),
          p,
        );
        // Location pin
        final pin = c + Offset(g * 0.55, -g * 0.55);
        canvas.drawCircle(pin, r * 0.13, Paint()..color = AppColors.myxRed);
        canvas.drawCircle(pin, r * 0.05, Paint()..color = Colors.white);
      case _Art.bolt:
        final ring = Rect.fromCircle(center: c, radius: r * 0.45);
        canvas.drawArc(
          ring,
          -math.pi / 2 + 0.5,
          2 * math.pi - 1.0,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07
            ..strokeCap = StrokeCap.round
            ..shader = const SweepGradient(
              colors: [AppColors.myxBlue, Color(0xFF7A5CFF), AppColors.myxRed],
            ).createShader(ring),
        );
        canvas.drawLine(
          c - Offset(0, r * 0.52),
          c - Offset(0, r * 0.18),
          Paint()
            ..strokeWidth = r * 0.07
            ..strokeCap = StrokeCap.round
            ..color = AppColors.myxNavy,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.art != art;
}

class _SoftBackdrop extends CustomPainter {
  const _SoftBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-1.1, -1.0),
          radius: 1.0,
          colors: [Color(0x22FF2D55), Color(0x00FF2D55)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(1.1, 1.0),
          radius: 1.0,
          colors: [Color(0x222F6BFF), Color(0x002F6BFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
