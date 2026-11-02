import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';

/// MYX-VPN power button: an orbit ring + glowing core that reflects the VPN
/// status (red = unprotected, spinning blue/red = working, blue = protected).
class VPNSwitch extends HookConsumerWidget {
  const VPNSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<LanternStatus>>(vPNStatusProvider, (previous, next) {
      if (next is AsyncData<LanternStatus> &&
          next.value.status == VPNStatus.error) {
        context.showSnackBar(
          next.value.error ?? 'error_while_vpn_connection'.i18n,
        );
      }
    });
    final vpnStatus = ref.watch(vpnProvider);
    final isOn = vpnStatus == VPNStatus.connected;
    final busy = vpnStatus == VPNStatus.connecting ||
        vpnStatus == VPNStatus.disconnecting;

    final spin = useAnimationController(duration: const Duration(seconds: 2));
    final breathe = useAnimationController(
      duration: const Duration(milliseconds: 2600),
    );
    final morph = useAnimationController(
      duration: const Duration(milliseconds: 650),
      initialValue: isOn ? 1 : 0,
    );
    useEffect(() {
      busy ? spin.repeat() : spin.stop();
      // Only animate the glow while protected, to keep idle CPU/battery at zero.
      isOn ? breathe.repeat(reverse: true) : breathe.stop();
      isOn ? morph.forward() : morph.reverse();
      return null;
    }, [vpnStatus]);

    // Session timer (display only; status itself comes from the stream).
    final connectedAt = useState<DateTime?>(null);
    final tick = useState(0);
    useEffect(() {
      if (isOn) {
        connectedAt.value ??= DateTime.now();
      } else {
        connectedAt.value = null;
      }
      return null;
    }, [isOn]);
    useEffect(() {
      if (!isOn) return null;
      final s = Stream.periodic(const Duration(seconds: 1)).listen(
        (_) => tick.value++,
      );
      return s.cancel;
    }, [isOn]);

    final showFocus = useState(false);
    final pressed = useState(false);
    final focusNode = useFocusNode(debugLabel: 'VPNSwitch');
    // On TV the switch claims focus itself, and Home pushes routes (e.g.
    // onboarding) over it; while covered it must not hold focus, or the remote
    // would toggle it unseen.
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    useEffect(() {
      if (PlatformUtils.isTv && isCurrent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNode.context != null) focusNode.requestFocus();
        });
      }
      return null;
    }, [isCurrent]);

    final size = math.min(
      PlatformUtils.isDesktop ? 230.0 : 250.r,
      MediaQuery.sizeOf(context).height * 0.34,
    );
    final textTheme = Theme.of(context).textTheme;

    final String title;
    final String subtitle;
    switch (vpnStatus) {
      case VPNStatus.connected:
        title = 'myx_protected'.i18n;
        final since = connectedAt.value;
        subtitle = since == null
            ? ''
            : '${'myx_session'.i18n}  ${_fmt(DateTime.now().difference(since))}';
      case VPNStatus.connecting:
        title = 'myx_connecting'.i18n;
        subtitle = '';
      case VPNStatus.disconnecting:
        title = 'myx_disconnecting'.i18n;
        subtitle = '';
      default:
        title = 'myx_not_protected'.i18n;
        subtitle = 'myx_tap_to_connect'.i18n;
    }

    return FocusableActionDetector(
      focusNode: focusNode,
      enabled: !PlatformUtils.isTv || isCurrent,
      onShowFocusHighlight: (value) => showFocus.value = value,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            appLogger.info('VPN Switch activated');
            onVPNStateChange(ref, context);
            return null;
          },
        ),
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            toggled: isOn,
            label: title,
            child: GestureDetector(
              key: const Key('vpn.toggle'),
              onTapDown: (_) => pressed.value = true,
              onTapCancel: () => pressed.value = false,
              onTapUp: (_) => pressed.value = false,
              onTap: busy
                  ? null
                  : () {
                      appLogger.info('VPN Switch tapped');
                      onVPNStateChange(ref, context);
                    },
              child: AnimatedScale(
                scale: pressed.value ? 0.96 : 1,
                duration: const Duration(milliseconds: 120),
                child: SizedBox(
                  key: Key('vpn.switch.${vpnStatus.name}'),
                  width: size,
                  height: size,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([spin, breathe, morph]),
                    builder: (context, _) => CustomPaint(
                      painter: _PowerPainter(
                        on: morph.value,
                        busy: busy,
                        spin: spin.value,
                        breathe: breathe.value,
                        focused: showFocus.value,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          size: size * 0.2,
                          color: Color.lerp(
                            AppColors.myxRed,
                            Colors.white,
                            morph.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              title,
              key: ValueKey(title),
              style: textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: isOn ? AppColors.myxBlue : context.textPrimary,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          SizedBox(
            height: 20,
            child: Text(
              subtitle,
              style: textTheme.bodyMedium!.copyWith(
                color: context.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  Future<void> onVPNStateChange(WidgetRef ref, BuildContext context) async {
    if (PlatformUtils.isMacOS) {
      final systemExtensionStatus = ref.read(macosExtensionProvider);
      if (!systemExtensionStatus.isReady) {
        final value = await appRouter.push(const MacOSExtensionDialog());
        if (!context.mounted) return;
        appLogger.info(
          'Returned from MacOS Extension Dialog with value: $value',
        );
        if (value is bool && value) {
          appLogger.info(
            'Retrying VPN state change after MacOS Extension setup',
          );
          return onVPNStateChange(ref, context);
        }
        return;
      }
    }

    final result = await ref.read(vpnProvider.notifier).onVPNStateChange();

    if (!context.mounted) return;
    result.fold((failure) {
      if (failure is VpnConflictFailure) {
        AppDialog.vpnConflictDialog(
          context: context,
          onConnectAnyway: () async {
            appRouter.maybePop();
            final retryResult = await ref
                .read(vpnProvider.notifier)
                .startVPN(skipConflictCheck: true);
            if (!context.mounted) return;
            retryResult.fold((failure) {
              context.showSnackBar(failure.localizedErrorMessage);
              appLogger.error("Error changing VPN state: ${failure.error}");
            }, (_) => null);
          },
        );
      } else {
        context.showSnackBar(failure.localizedErrorMessage);
        appLogger.error("Error changing VPN state: ${failure.error}");
      }
    }, (_) => null);
  }
}

class _PowerPainter extends CustomPainter {
  /// 0 = off (red), 1 = on (blue); animated in between.
  final double on;
  final bool busy;
  final double spin;
  final double breathe;
  final bool focused;

  _PowerPainter({
    required this.on,
    required this.busy,
    required this.spin,
    required this.breathe,
    required this.focused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final accent = Color.lerp(AppColors.myxRed, AppColors.myxBlue, on)!;

    // 1. Halo glow (breathes).
    final haloR = r * (0.92 + 0.06 * breathe);
    canvas.drawCircle(
      c,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.10 + 0.22 * on + 0.06 * breathe),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: haloR)),
    );

    // 2. Track ring.
    final ringR = r * 0.80;
    final ringRect = Rect.fromCircle(center: c, radius: ringR);
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..color = const Color(0xFF1B2440),
    );

    // 3. Tick marks around the ring (instrument-like detail).
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1, r * 0.012);
    const ticks = 60;
    for (var i = 0; i < ticks; i++) {
      final a = (i / ticks) * 2 * math.pi - math.pi / 2;
      final major = i % 5 == 0;
      final inner = ringR + r * (major ? 0.07 : 0.085);
      final outer = ringR + r * 0.11;
      final lit = on > 0.5 || (busy && ((i / ticks + spin) % 1) < 0.25);
      tickPaint.color = lit
          ? accent.withValues(alpha: major ? 0.9 : 0.55)
          : const Color(0xFF2A3354).withValues(alpha: major ? 0.9 : 0.6);
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * inner,
        c + Offset(math.cos(a), math.sin(a)) * outer,
        tickPaint,
      );
    }

    // 4. Progress arc: spinning comet while busy, full gradient ring when on.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.045;
    if (busy) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(spin * 2 * math.pi);
      canvas.translate(-c.dx, -c.dy);
      arcPaint.shader = SweepGradient(
        colors: const [
          Color(0x002F6BFF),
          AppColors.myxBlue,
          AppColors.myxRed,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(ringRect);
      canvas.drawArc(ringRect, 0, math.pi * 1.4, false, arcPaint);
      canvas.restore();
    } else if (on > 0) {
      arcPaint.shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
        colors: const [
          AppColors.myxBlue,
          AppColors.myxCyan,
          AppColors.myxBlue,
        ],
      ).createShader(ringRect);
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        2 * math.pi * on,
        false,
        arcPaint,
      );
    } else {
      // Off: a short red marker at 12 o'clock.
      arcPaint.color = AppColors.myxRed.withValues(alpha: 0.85);
      canvas.drawArc(ringRect, -math.pi / 2 - 0.18, 0.36, false, arcPaint);
    }

    // 5. Core button.
    final coreR = r * 0.62;
    final coreRect = Rect.fromCircle(center: c, radius: coreR);
    // Drop shadow
    canvas.drawCircle(
      c + Offset(0, r * 0.04),
      coreR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
    final offColors = [const Color(0xFF1A2240), const Color(0xFF0B1022)];
    final onColors = [const Color(0xFF3D7BFF), AppColors.myxBlueDeep];
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(offColors[0], onColors[0], on)!,
            Color.lerp(offColors[1], onColors[1], on)!,
          ],
        ).createShader(coreRect),
    );
    // Rim highlight
    canvas.drawCircle(
      c,
      coreR - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.012)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(coreRect),
    );
    // Inner accent ring
    canvas.drawCircle(
      c,
      coreR * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.008)
        ..color = accent.withValues(alpha: 0.18 + 0.12 * breathe),
    );

    if (focused) {
      canvas.drawCircle(
        c,
        r * 0.97,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white70,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PowerPainter old) =>
      old.on != on ||
      old.busy != busy ||
      old.spin != spin ||
      old.breathe != breathe ||
      old.focused != focused;
}
