import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/updater/updater.dart';

enum UpdateChoice { install, later }

/// MYX-VPN update prompts. All entry points are no-ops when there's no
/// navigator yet (e.g. the check finished before the first frame).
class UpdateDialog {
  static BuildContext? get _context {
    final c = appRouter.navigatorKey.currentContext;
    return (c != null && c.mounted) ? c : null;
  }

  static Future<UpdateChoice?> showAvailable({
    required String current,
    required AppRelease release,
    required Future<InstallResult> Function(void Function(double?)) onInstall,
  }) async {
    final context = _context;
    if (context == null) return null;
    return showDialog<UpdateChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateAvailableDialog(
        current: current,
        release: release,
        onInstall: onInstall,
      ),
    );
  }

  static Future<void> showUpToDate(String version) async {
    final context = _context;
    if (context == null) return;
    context.showSnackBar('${'app_name'.i18n} $version ✓');
  }

  static Future<void> showCheckFailed() async {
    final context = _context;
    if (context == null) return;
    context.showSnackBar('error'.i18n);
  }
}

class _UpdateAvailableDialog extends StatefulWidget {
  const _UpdateAvailableDialog({
    required this.current,
    required this.release,
    required this.onInstall,
  });

  final String current;
  final AppRelease release;
  final Future<InstallResult> Function(void Function(double?)) onInstall;

  @override
  State<_UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<_UpdateAvailableDialog> {
  bool _working = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _working = true;
      _error = null;
      _progress = null;
    });
    try {
      final result = await widget.onInstall((p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      switch (result) {
        case InstallResult.needsPermission:
          // Android opened "Install unknown apps"; let the user retry.
          setState(() => _working = false);
        case InstallResult.started:
        case InstallResult.openedPage:
          Navigator.of(context).pop(UpdateChoice.install);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final notes = widget.release.notes;
    final newVersion = widget.release.version.toString();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: context.bgElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderDefault),
            boxShadow: const [
              BoxShadow(
                color: Color(0x662F6BFF),
                blurRadius: 40,
                spreadRadius: -12,
                offset: Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header band
              Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF13245E), Color(0xFF0B1022)],
                  ),
                ),
                child: Column(
                  children: [
                    const LanternRoundedLogo(height: 64, width: 64),
                    const SizedBox(height: 16),
                    Text(
                      'myx_update_title'.i18n,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _VersionChip(label: widget.current, muted: true),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white54,
                          ),
                        ),
                        _VersionChip(label: newVersion),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                child: Text(
                  'myx_update_body'.i18n.fill([newVersion, widget.current]),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(color: context.textSecondary),
                ),
              ),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'myx_whats_new'.i18n,
                        style: text.titleSmall!.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.borderDefault),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            notes,
                            style: text.bodySmall!.copyWith(
                              color: context.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_working)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      color: AppColors.myxBlue,
                      backgroundColor: context.borderDefault,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: text.bodySmall!.copyWith(color: context.borderError),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _working
                            ? null
                            : () => Navigator.of(context).pop(UpdateChoice.later),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: context.textTertiary,
                        ),
                        child: Text('myx_update_later'.i18n),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _GradientButton(
                        label: 'myx_update_now'.i18n,
                        onPressed: _working ? null : () => unawaited(_install()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.label, this.muted = false});
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: muted ? Colors.white10 : AppColors.myxRed,
      ),
      child: Text(
        'v$label',
        style: TextStyle(
          color: muted ? Colors.white70 : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.myxBlue, Color(0xFF6A3DFF), AppColors.myxRed],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              height: 50,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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
