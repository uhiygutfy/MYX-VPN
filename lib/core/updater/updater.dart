import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/updater/update_config.dart';
import 'package:lantern/core/updater/update_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// A downloadable file for one platform in a release.
class UpdateAsset {
  const UpdateAsset({required this.url, this.sha256 = ''});
  final String url;
  final String sha256;

  static UpdateAsset? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = json['url'];
    if (url is! String || !url.startsWith('https://')) return null;
    final sum = json['sha256'];
    return UpdateAsset(url: url, sha256: sum is String ? sum.trim() : '');
  }
}

/// A published MYX-VPN release.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.notes,
    required this.page,
    required this.assets,
  });

  final Version version;
  final String notes;
  final String page;

  /// Keys: android-arm64, android-armv7, windows-x64, macos, ios, linux-x64.
  final Map<String, UpdateAsset> assets;

  /// Parses the `latest.json` manifest written by the release workflow.
  static AppRelease? fromManifest(Map<String, dynamic> json) {
    final version = _parseVersion(json['version']);
    if (version == null) return null;
    final assets = <String, UpdateAsset>{};
    final raw = json['assets'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final a = UpdateAsset.fromJson(value);
        if (a != null) assets[key.toString()] = a;
      });
    }
    return AppRelease(
      version: version,
      notes: (json['notes'] ?? '').toString().trim(),
      page: (json['page'] ?? UpdateConfig.releasesPage).toString(),
      assets: assets,
    );
  }

  /// Fallback: builds a release from the GitHub REST API response. Asset
  /// checksums aren't available there, so downloads fall back to the page.
  static AppRelease? fromGitHubApi(Map<String, dynamic> json) {
    final version = _parseVersion(json['tag_name']);
    if (version == null) return null;
    return AppRelease(
      version: version,
      notes: (json['body'] ?? '').toString().trim(),
      page: (json['html_url'] ?? UpdateConfig.releasesPage).toString(),
      assets: const {},
    );
  }

  static Version? _parseVersion(Object? raw) {
    if (raw is! String) return null;
    var v = raw.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    try {
      return Version.parse(v);
    } catch (_) {
      return null;
    }
  }
}

/// Checks GitHub Releases for a newer MYX-VPN and offers to install it.
///
/// Android: the APK is downloaded and verified (SHA-256, package name,
/// versionCode, signing certificate) by the native installer, then handed to
/// the system package installer. Windows: the installer is downloaded,
/// verified and launched. Other platforms open the release page.
class Updater {
  Updater({http.Client? client}) : _client = client ?? http.Client();

  static const _startupDelay = Duration(seconds: 8);
  static const _requestTimeout = Duration(seconds: 15);
  static const _snoozeVersionKey = 'myx.update.snoozedVersion';
  static const _snoozeUntilKey = 'myx.update.snoozedUntil';
  static const _methodChannel = MethodChannel('org.getlantern.lantern/method');

  final http.Client _client;
  Timer? _timer;
  bool _started = false;
  bool _checking = false;
  bool _promptOpen = false;
  bool _disposed = false;
  DateTime? _lastCheck;

  bool get _supported => !kIsWeb && !kDebugMode;

  Future<void> init() async {
    if (_started || _disposed || !_supported) return;
    _started = true;
    _timer = Timer(_startupDelay, () => _check(userInitiated: false));
  }

  Future<bool> canCheckForUpdates() async => !kIsWeb && !_disposed;

  /// Manual "Check for updates" from Settings.
  Future<void> checkNow() => _check(userInitiated: true);

  /// Called when the app returns to the foreground.
  void retryPendingCheck() {
    if (!_started || _disposed) return;
    final last = _lastCheck;
    if (last == null ||
        DateTime.now().difference(last) >= UpdateConfig.checkInterval) {
      unawaited(_check(userInitiated: false));
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _client.close();
  }

  Future<void> _check({required bool userInitiated}) async {
    if (_checking || _disposed) return;
    _checking = true;
    _timer?.cancel();
    try {
      final current = Version.parse(
        (await PackageInfo.fromPlatform()).version,
      );
      final release = await fetchLatest();
      _lastCheck = DateTime.now();
      if (release == null) {
        if (userInitiated) await UpdateDialog.showCheckFailed();
        return;
      }
      if (release.version <= current) {
        appLogger.info('MYX update: up to date ($current)');
        if (userInitiated) await UpdateDialog.showUpToDate(current.toString());
        return;
      }
      if (!userInitiated && await _isSnoozed(release.version)) return;
      if (_promptOpen) return;
      _promptOpen = true;
      try {
        final choice = await UpdateDialog.showAvailable(
          current: current.toString(),
          release: release,
          onInstall: (progress) => install(release, progress),
        );
        if (choice == UpdateChoice.later) await _snooze(release.version);
      } finally {
        _promptOpen = false;
      }
    } catch (e, st) {
      appLogger.error('MYX update check failed', e, st);
      if (userInitiated) await UpdateDialog.showCheckFailed();
    } finally {
      _checking = false;
      if (!_disposed && _started) {
        _timer = Timer(
          UpdateConfig.checkInterval,
          () => _check(userInitiated: false),
        );
      }
    }
  }

  /// Reads the latest release: manifest first, REST API as fallback.
  Future<AppRelease?> fetchLatest() async {
    try {
      final res = await _client
          .get(Uri.parse(UpdateConfig.manifestUrl))
          .timeout(_requestTimeout);
      if (res.statusCode == 200) {
        final release = AppRelease.fromManifest(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
        );
        if (release != null) return release;
      }
      appLogger.warning('MYX update manifest: HTTP ${res.statusCode}');
    } catch (e) {
      appLogger.warning('MYX update manifest unavailable: $e');
    }
    try {
      final res = await _client
          .get(
            Uri.parse(UpdateConfig.apiLatestUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'MYX-VPN',
            },
          )
          .timeout(_requestTimeout);
      if (res.statusCode == 200) {
        return AppRelease.fromGitHubApi(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
        );
      }
      appLogger.warning('MYX update API: HTTP ${res.statusCode}');
    } catch (e) {
      appLogger.warning('MYX update API unavailable: $e');
    }
    return null;
  }

  /// Installs [release] for the current platform. [progress] receives 0..1
  /// while downloading (null = indeterminate).
  Future<InstallResult> install(
    AppRelease release,
    void Function(double? progress) progress,
  ) async {
    final asset = await _assetForThisDevice(release);
    if (asset == null || asset.sha256.isEmpty) {
      await _openPage(release.page);
      return InstallResult.openedPage;
    }
    if (Platform.isAndroid) return _installAndroid(release, asset, progress);
    if (Platform.isWindows) return _installWindows(asset, progress);
    await _openPage(release.page);
    return InstallResult.openedPage;
  }

  Future<UpdateAsset?> _assetForThisDevice(AppRelease release) async {
    if (Platform.isAndroid) {
      final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
      final key = abis.contains('arm64-v8a') ? 'android-arm64' : 'android-armv7';
      return release.assets[key];
    }
    if (Platform.isWindows) return release.assets['windows-x64'];
    if (Platform.isMacOS) return release.assets['macos'];
    if (Platform.isIOS) return release.assets['ios'];
    if (Platform.isLinux) return release.assets['linux-x64'];
    return null;
  }

  Future<InstallResult> _installAndroid(
    AppRelease release,
    UpdateAsset asset,
    void Function(double?) progress,
  ) async {
    progress(null);
    // Native side downloads + verifies checksum, package, versionCode and
    // signing certificate before launching the system installer.
    final status = await _methodChannel.invokeMethod<String>(
      'installSideloadUpdate',
      {
        'url': asset.url,
        'checksum': asset.sha256,
        'version': release.version.toString(),
      },
    );
    if (status == 'permission_required') return InstallResult.needsPermission;
    return InstallResult.started;
  }

  Future<InstallResult> _installWindows(
    UpdateAsset asset,
    void Function(double?) progress,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}MYX-VPN-setup.exe');
    final req = http.Request('GET', Uri.parse(asset.url));
    final res = await _client.send(req);
    if (res.statusCode != 200) {
      throw HttpException('Download failed: HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    final hashOut = _DigestSink();
    final hasher = sha256.startChunkedConversion(hashOut);
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        progress(total > 0 ? received / total : null);
      }
    } finally {
      await sink.close();
      hasher.close();
    }
    if (hashOut.value.toString() != asset.sha256.toLowerCase()) {
      await file.delete().catchError((_) => file);
      throw const FormatException('Installer checksum mismatch');
    }
    await Process.start(file.path, const [], mode: ProcessStartMode.detached);
    // Give the installer a moment, then quit so files can be replaced.
    Timer(const Duration(seconds: 2), () => exit(0));
    return InstallResult.started;
  }

  Future<void> _openPage(String url) async {
    final uri = Uri.tryParse(url) ?? Uri.parse(UpdateConfig.releasesPage);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _isSnoozed(Version v) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_snoozeVersionKey) != v.toString()) return false;
    final until = DateTime.tryParse(prefs.getString(_snoozeUntilKey) ?? '');
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> _snooze(Version v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snoozeVersionKey, v.toString());
    await prefs.setString(
      _snoozeUntilKey,
      DateTime.now().add(UpdateConfig.snoozeFor).toIso8601String(),
    );
  }
}

enum InstallResult { started, needsPermission, openedPage }

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
