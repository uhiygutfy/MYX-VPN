import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/features/myx/myx_shell.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

/// Home tab: brand header, power button, status, selected server.
class MyxDashboard extends HookConsumerWidget {
  const MyxDashboard({super.key});

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
    final status = ref.watch(vpnProvider);
    final height = MediaQuery.sizeOf(context).height;
    final buttonSize = math.min(220.0, height * 0.3);

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _Header(
                    onMenu: () => ref.read(myxTabProvider.notifier).go(2),
                    onLocations: () => ref.read(myxTabProvider.notifier).go(1),
                  ),
                  SizedBox(height: height * 0.02),
                  const MyxShield(size: 58),
                  const SizedBox(height: 8),
                  const MyxWordmark(fontSize: 26, vpnColor: Colors.white),
                  SizedBox(height: height * 0.05),
                  MyxPowerButton(status: status, size: buttonSize),
                  const SizedBox(height: 18),
                  _StatusText(status: status),
                  SizedBox(height: height * 0.05),
                  const _ServerCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onMenu, required this.onLocations});
  final VoidCallback onMenu;
  final VoidCallback onLocations;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('home.menu_button'),
          tooltip: 'myx_settings'.i18n,
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'myx_locations'.i18n,
          onPressed: onLocations,
          icon: const Icon(Icons.public_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

/// Connected-since timestamp shared across rebuilds/tabs (display only).
DateTime? _connectedAt;

class _StatusText extends HookWidget {
  const _StatusText({required this.status});
  final VPNStatus status;

  @override
  Widget build(BuildContext context) {
    final tick = useState(0);
    final isOn = status == VPNStatus.connected;
    if (isOn) {
      _connectedAt ??= DateTime.now();
    } else {
      _connectedAt = null;
    }
    useEffect(() {
      if (!isOn) return null;
      final sub = Stream.periodic(const Duration(seconds: 1)).listen(
        (_) => tick.value++,
      );
      return sub.cancel;
    }, [isOn]);

    final (title, color) = switch (status) {
      VPNStatus.connected => ('myx_connected'.i18n, AppColors.myxGreen),
      VPNStatus.connecting => ('myx_connecting'.i18n, Colors.white),
      VPNStatus.disconnecting => ('myx_disconnecting'.i18n, Colors.white),
      _ => ('myx_tap_to_connect'.i18n, Colors.white),
    };
    String two(int n) => n.toString().padLeft(2, '0');
    final d = isOn && _connectedAt != null
        ? DateTime.now().difference(_connectedAt!)
        : Duration.zero;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            title,
            key: ValueKey(title),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 22,
          child: isOn
              ? Text(
                  '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// The big round connect button.
class MyxPowerButton extends HookConsumerWidget {
  const MyxPowerButton({super.key, required this.status, required this.size});
  final VPNStatus status;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOn = status == VPNStatus.connected;
    final busy =
        status == VPNStatus.connecting || status == VPNStatus.disconnecting;
    final spin = useAnimationController(duration: const Duration(seconds: 2));
    final glow = useAnimationController(
      duration: const Duration(milliseconds: 2400),
    );
    final morph = useAnimationController(
      duration: const Duration(milliseconds: 500),
      initialValue: isOn ? 1 : 0,
    );
    useEffect(() {
      busy ? spin.repeat() : spin.stop();
      busy || isOn ? glow.repeat(reverse: true) : glow.stop();
      isOn ? morph.forward() : morph.reverse();
      return null;
    }, [status]);
    final pressed = useState(false);

    return Semantics(
      button: true,
      toggled: isOn,
      child: GestureDetector(
        key: const Key('vpn.toggle'),
        onTapDown: (_) => pressed.value = true,
        onTapCancel: () => pressed.value = false,
        onTapUp: (_) => pressed.value = false,
        onTap: busy
            ? null
            : () {
                appLogger.info('myx power button tapped');
                const VPNSwitch().onVPNStateChange(ref, context);
              },
        child: AnimatedScale(
          scale: pressed.value ? 0.95 : 1,
          duration: const Duration(milliseconds: 120),
          child: SizedBox(
            key: Key('vpn.switch.${status.name}'),
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: Listenable.merge([spin, glow, morph]),
              builder: (context, _) => CustomPaint(
                painter: _PowerPainter(
                  on: morph.value,
                  busy: busy,
                  spin: spin.value,
                  glow: glow.value,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: isOn
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('on'),
                            size: size * 0.36,
                            color: AppColors.myxGreen,
                          )
                        : Icon(
                            Icons.power_settings_new_rounded,
                            key: const ValueKey('off'),
                            size: size * 0.3,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerPainter extends CustomPainter {
  _PowerPainter({
    required this.on,
    required this.busy,
    required this.spin,
    required this.glow,
  });

  final double on; // 0 off → 1 connected
  final bool busy;
  final double spin;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ringR = r * 0.80;
    final ringRect = Rect.fromCircle(center: c, radius: ringR);
    final stroke = r * 0.09;

    // Outer glow
    final glowColor = Color.lerp(AppColors.myxBlue, AppColors.myxGreen, on)!;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: 0.32 + 0.12 * glow),
            glowColor.withValues(alpha: 0),
          ],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Ring glow (blurred copy of the ring)
    final ringShader = SweepGradient(
      transform: GradientRotation(busy ? spin * 2 * math.pi : -math.pi / 2),
      colors: on > 0.5
          ? const [AppColors.myxGreen, AppColors.myxTeal, AppColors.myxGreen]
          : const [
              Color(0xFF3B7BFF),
              Color(0xFF7A5CFF),
              Color(0xFFFF2D55),
              Color(0xFF3B7BFF),
            ],
    ).createShader(ringRect);
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.6
        ..shader = ringShader
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );

    // Ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = ringShader;
    if (busy) {
      // Track + spinning arc
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = Colors.white.withValues(alpha: 0.08),
      );
      canvas.drawArc(
        ringRect,
        spin * 2 * math.pi,
        math.pi * 1.3,
        false,
        ring,
      );
    } else {
      canvas.drawCircle(c, ringR, ring);
    }

    // Inner disc
    final discR = ringR - stroke * 0.9;
    final discRect = Rect.fromCircle(center: c, radius: discR);
    canvas.drawCircle(
      c,
      discR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFF1C3172), Color(0xFF0B1840)],
        ).createShader(discRect),
    );
    // Rim highlight
    canvas.drawCircle(
      c,
      discR - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.012)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(discRect),
    );
  }

  @override
  bool shouldRepaint(covariant _PowerPainter old) =>
      old.on != on ||
      old.busy != busy ||
      old.spin != spin ||
      old.glow != glow;
}

/// "Server — Auto Select / Germany" card; opens the Locations tab.
class _ServerCard extends ConsumerWidget {
  const _ServerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(serverLocationProvider);
    final type = loc.serverType.toServerLocationType;
    final isAuto = type == ServerLocationType.auto;
    final auto = loc.autoLocation;

    final String name;
    final String sub;
    final String flag;
    if (isAuto) {
      name = 'myx_auto_select'.i18n;
      sub = auto != null && auto.countryCode.isNotEmpty
          ? auto.displayName
          : 'myx_fastest'.i18n;
      flag = '';
    } else {
      name = loc.displayName;
      sub = loc.protocol;
      flag = loc.countryCode;
    }

    return MyxGlassCard(
      onTap: () => ref.read(myxTabProvider.notifier).go(1),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: flag.isEmpty
                ? const Icon(Icons.language_rounded, color: Colors.white)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Flag(countryCode: flag, size: const Size(28, 20)),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'myx_server'.i18n,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

/// Frosted card used across the myx screens.
class MyxGlassCard extends StatelessWidget {
  const MyxGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.selected = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: selected ? 0.12 : 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? AppColors.myxRed.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.10),
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
