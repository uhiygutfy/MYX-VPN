import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/update_config.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings tab. Links into the existing detail screens; no account items.
class MyxSettings extends HookConsumerWidget {
  const MyxSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = useFuture(useMemoized(PackageInfo.fromPlatform));
    final showRouting = !PlatformUtils.isIOS;
    final showSplit =
        PlatformUtils.isAndroid ||
        PlatformUtils.isMacOS ||
        PlatformUtils.isWindows;

    Future<void> checkUpdates() async {
      try {
        await sl<Updater>().checkNow();
      } catch (e) {
        if (context.mounted) context.showSnackBar(e.toString());
      }
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'myx_settings'.i18n,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'myx_section_connection'.i18n,
            items: [
              if (showRouting)
                _Item(
                  icon: Icons.alt_route_rounded,
                  label: 'myx_routing'.i18n,
                  onTap: () => appRouter.push(const SmartRouting()),
                ),
              if (showSplit)
                _Item(
                  icon: Icons.call_split_rounded,
                  label: 'myx_split'.i18n,
                  onTap: () => appRouter.push(const SplitTunneling()),
                ),
              _Item(
                icon: Icons.tune_rounded,
                label: 'myx_vpn_settings'.i18n,
                onTap: () => appRouter.push(const VPNSetting()),
              ),
            ],
          ),
          _Section(
            title: 'myx_section_app'.i18n,
            items: [
              _Item(
                icon: Icons.translate_rounded,
                label: 'myx_language'.i18n,
                onTap: () => appRouter.push(const Language()),
              ),
              _Item(
                icon: Icons.system_update_rounded,
                label: 'myx_check_updates'.i18n,
                onTap: checkUpdates,
              ),
              _Item(
                icon: Icons.receipt_long_rounded,
                label: 'myx_logs'.i18n,
                onTap: () => appRouter.push(const Logs()),
              ),
            ],
          ),
          _Section(
            title: 'myx_section_about'.i18n,
            items: [
              _Item(
                icon: Icons.info_outline_rounded,
                label: 'myx_version'.i18n,
                value: version.data?.version ?? '',
              ),
              _Item(
                icon: Icons.code_rounded,
                label: 'myx_source'.i18n,
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/${UpdateConfig.githubRepo}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _Item(
                icon: Icons.gavel_rounded,
                label: 'myx_licenses'.i18n,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'myx-VPN',
                  applicationVersion: version.data?.version,
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: MyxShield(size: 56),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                const MyxShield(size: 36),
                const SizedBox(height: 6),
                const MyxWordmark(fontSize: 16, vpnColor: Colors.white),
                const SizedBox(height: 4),
                Text(
                  'myx_tagline'.i18n,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 58,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F6BFF), Color(0xFF1336A8)],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                  ),
                ),
              if (onTap != null)
                Icon(
                  rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
