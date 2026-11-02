import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/myx/myx_dashboard.dart';
import 'package:lantern/features/myx/myx_shell.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

/// Locations tab: Auto Select + every real server location, grouped by
/// country, with flags, latency and search.
class MyxLocations extends HookConsumerWidget {
  const MyxLocations({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(availableServersProvider);
    final selected = ref.watch(serverLocationProvider);
    final canSelect = ref.watch(canSelectServerProvider);
    final query = useState('');
    final busy = useState(false);
    final expanded = useState<String?>(null);

    final isAuto =
        selected.serverType.toServerLocationType == ServerLocationType.auto;

    Future<void> run(
      Future<Either<Failure, String>> Function(bool skipConflictCheck) attempt,
      FutureOr<void> Function() save, {
      bool skipConflictCheck = false,
    }) async {
      if (PlatformUtils.isMacOS && !ref.read(macosExtensionProvider).isReady) {
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
      busy.value = true;
      final Either<Failure, String> result;
      try {
        result = await attempt(skipConflictCheck);
      } finally {
        if (context.mounted) busy.value = false;
      }
      if (!context.mounted) return;
      result.fold(
        (failure) {
          if (failure is VpnConflictFailure && !skipConflictCheck) {
            AppDialog.vpnConflictDialog(
              context: context,
              onConnectAnyway: () {
                appRouter.maybePop();
                unawaited(run(attempt, save, skipConflictCheck: true));
              },
            );
            return;
          }
          context.showSnackBar(failure.localizedErrorMessage);
        },
        (_) {
          // Back to Home to watch it connect; the choice is saved on connect.
          ref.read(myxTabProvider.notifier).go(0);
          unawaited(
            ref.read(serverLocationProvider.notifier).saveOnceConnected(save),
          );
        },
      );
    }

    void chooseAuto() {
      if (isAuto) {
        ref.read(myxTabProvider.notifier).go(0);
        return;
      }
      unawaited(
        run(
          (skip) => ref
              .read(vpnProvider.notifier)
              .startVPN(force: true, skipConflictCheck: skip),
          ref.read(serverLocationProvider.notifier).switchToAuto,
        ),
      );
    }

    void chooseServer(Server server) {
      if (!canSelect) {
        context.showSnackBar('myx_locations_locked'.i18n);
        return;
      }
      unawaited(
        run(
          (skip) => ref
              .read(vpnProvider.notifier)
              .connectToServer(
                ServerLocationType.lanternLocation,
                server.tag,
                skipConflictCheck: skip,
              ),
          () => ref
              .read(serverLocationProvider.notifier)
              .updateServerLocation(ServerLocation.fromServer(server: server)),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'myx_locations'.i18n,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (busy.value)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.myxRed,
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'myx_refresh'.i18n,
                    onPressed: () => ref
                        .read(availableServersProvider.notifier)
                        .forceFetchAvailableServers(),
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => query.value = v.trim().toLowerCase(),
              style: const TextStyle(color: Colors.white),
              cursorColor: AppColors.myxRed,
              decoration: InputDecoration(
                hintText: 'myx_search_locations'.i18n,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.myxRed),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: serversAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.myxRed),
              ),
              error: (e, _) => _Message(
                icon: Icons.cloud_off_rounded,
                text: 'myx_no_locations'.i18n,
                onRetry: () => ref
                    .read(availableServersProvider.notifier)
                    .forceFetchAvailableServers(),
              ),
              data: (servers) {
                final byCountry = <String, List<Server>>{};
                for (final s in servers.lanternServerLocations) {
                  final l = s.location;
                  final q = query.value;
                  if (q.isNotEmpty &&
                      !l.country.toLowerCase().contains(q) &&
                      !l.city.toLowerCase().contains(q) &&
                      l.countryCode.toLowerCase() != q) {
                    continue;
                  }
                  byCountry.putIfAbsent(l.country, () => []).add(s);
                }
                final countries = byCountry.entries.toList();
                return RefreshIndicator(
                  color: AppColors.myxRed,
                  onRefresh: () => ref
                      .read(availableServersProvider.notifier)
                      .forceFetchAvailableServers(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      MyxGlassCard(
                        selected: isAuto,
                        onTap: busy.value ? null : chooseAuto,
                        child: _Row(
                          leading: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                          ),
                          leadingBg: AppColors.myxRed,
                          title: 'myx_auto_select'.i18n,
                          subtitle: 'myx_fastest'.i18n,
                          selected: isAuto,
                        ),
                      ),
                      if (!canSelect) ...[
                        const SizedBox(height: 12),
                        _Notice(text: 'myx_locations_locked'.i18n),
                      ],
                      const SizedBox(height: 18),
                      if (countries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: _Message(
                            icon: Icons.travel_explore_rounded,
                            text: query.value.isEmpty
                                ? 'myx_no_locations'.i18n
                                : 'myx_no_results'.i18n,
                          ),
                        ),
                      for (final entry in countries) ...[
                        _CountryTile(
                          country: entry.key,
                          servers: entry.value,
                          selectedTag: isAuto ? '' : selected.serverName,
                          enabled: canSelect && !busy.value,
                          expanded:
                              expanded.value == entry.key ||
                              query.value.isNotEmpty,
                          onToggle: () => expanded.value =
                              expanded.value == entry.key ? null : entry.key,
                          onSelect: chooseServer,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.servers,
    required this.selectedTag,
    required this.enabled,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final String country;
  final List<Server> servers;
  final String selectedTag;
  final bool enabled;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Server> onSelect;

  @override
  Widget build(BuildContext context) {
    final code = servers.first.location.countryCode;
    final single = servers.length == 1;
    final anySelected = servers.any((s) => s.tag == selectedTag);
    final best = _bestPing(servers);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: MyxGlassCard(
        selected: anySelected,
        padding: EdgeInsets.zero,
        onTap: single ? () => onSelect(servers.first) : onToggle,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: _Row(
                leading: _FlagBadge(code: code),
                title: country,
                subtitle: single
                    ? servers.first.location.city
                    : '${servers.length} ${'myx_cities'.i18n}',
                ping: best,
                selected: anySelected && single,
                trailing: single
                    ? null
                    : AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
              ),
            ),
            if (!single && expanded)
              for (final s in servers)
                InkWell(
                  onTap: () => onSelect(s),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      70,
                      12,
                      14,
                      12,
                    ),
                    child: _Row(
                      title: s.location.city.isEmpty
                          ? country
                          : s.location.city,
                      ping: _ping(s),
                      selected: s.tag == selectedTag,
                      dense: true,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static int? _ping(Server s) => s.hasSuccessfulProbe && !s.isProbedUnreachable
      ? s.selectionHistory?.lastSuccessDelayMs
      : null;

  static int? _bestPing(List<Server> list) {
    int? best;
    for (final s in list) {
      final p = _ping(s);
      if (p != null && (best == null || p < best)) best = p;
    }
    return best;
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.leading,
    this.leadingBg,
    this.subtitle,
    this.ping,
    this.selected = false,
    this.trailing,
    this.dense = false,
  });

  final Widget? leading;
  final Color? leadingBg;
  final String title;
  final String? subtitle;
  final int? ping;
  final bool selected;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: leadingBg ?? Colors.white.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: leading,
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: dense ? 14.5 : 16,
                  fontWeight: dense ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ),
        if (ping != null) _PingChip(ms: ping!),
        if (selected) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.myxGreen,
            size: 22,
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
    );
  }
}

class _PingChip extends StatelessWidget {
  const _PingChip({required this.ms});
  final int ms;

  @override
  Widget build(BuildContext context) {
    final color = ms < 400
        ? AppColors.myxGreen
        : ms < 1000
        ? const Color(0xFFFFC14D)
        : AppColors.myxRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_cellular_alt_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$ms ms',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) {
      return const Icon(Icons.flag_rounded, color: Colors.white);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Flag(countryCode: code, size: const Size(28, 20)),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFC14D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55FFC14D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFFC14D)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'myx_refresh'.i18n,
                style: const TextStyle(color: AppColors.myxRed),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
