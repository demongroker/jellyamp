import 'dart:async';
import 'dart:convert';

import 'package:finamp/services/update_installer.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _log = Logger('UpdateChecker');

/// Simple update information returned by the checker.
class UpdateInfo {
  final String latestVersion;
  final String htmlUrl;
  final String? body;

  /// Direct download URL for the APK asset, when the release exposes one.
  /// Used for in-app update; null means "open the release page instead".
  final String? downloadUrl;

  /// Expected SHA-256 hex of the APK, published in the release body as
  /// `SHA-256: <hex>`. When present, the installer verifies before installing.
  final String? sha256;

  const UpdateInfo({required this.latestVersion, required this.htmlUrl, this.body, this.downloadUrl, this.sha256});

  /// Short one-line release note derived from the GitHub release body
  /// (first meaningful markdown line, headers/bullets/backticks stripped).
  String? get note {
    final b = body;
    if (b == null || b.isEmpty) return null;

    final lines =
        b
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .map((l) => l.replaceFirst(RegExp(r'^#{1,6}\s*'), '').replaceFirst(RegExp(r'^\s*[-*]\s*'), '').trim())
            .where((l) => l.isNotEmpty)
            .toList();

    if (lines.isEmpty) return null;

    final note = lines.first.replaceAll(RegExp(r'[`*_#]'), '').trim();
    if (note.isEmpty) return null;

    return note.length > 80 ? '${note.substring(0, 77)}…' : note;
  }
}

/// Checks for newer Jellyamp releases on GitHub.
class UpdateChecker {
  UpdateChecker._();

  static const String _repo = 'demongroker/jellyamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  static DateTime? _lastCheck;
  static UpdateInfo? _cachedResult;

  /// Returns update info if a newer version is available, otherwise null.
  static Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!force &&
        _cachedResult != null &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _cacheDuration) {
      return _cachedResult;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse('https://api.github.com/repos/$_repo/releases/latest');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _log.warning('GitHub API returned ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Tag is "v0.9.29" or "0.9.29" — strip a leading "v" only (not all "v"s),
      // and ignore any "+build" suffix that may appear.
      final rawTag = (data['tag_name'] as String?) ?? '';
      final latestTag = rawTag.replaceFirst(RegExp(r'^v'), '').split('+').first;
      final htmlUrl = data['html_url'] as String? ?? 'https://github.com/$_repo/releases';

      // Select the APK by an exact release contract (jellyamp-<version>.apk),
      // never "the first *.apk". Fall back only to a single jellyamp-*.apk asset.
      final assets = (data['assets'] as List?) ?? const [];
      final exactName = 'jellyamp-$latestTag.apk';
      String? downloadUrl;
      for (final asset in assets) {
        if (asset is Map && asset['name'] == exactName) {
          downloadUrl = asset['browser_download_url'] as String?;
          if (downloadUrl != null) break;
        }
      }
      if (downloadUrl == null) {
        final apks =
            assets
                .whereType<Map<String, dynamic>>()
                .where((a) => ((a['name'] as String?) ?? '').toLowerCase().endsWith('.apk'))
                .toList();
        if (apks.length == 1 && (((apks.first['name'] as String?) ?? '').toLowerCase().startsWith('jellyamp-'))) {
          downloadUrl = apks.first['browser_download_url'] as String?;
        }
      }

      // Expected SHA-256, published in the release body as "SHA-256: <hex>".
      final body = data['body'] as String?;
      String? sha256;
      if (body != null) {
        final match = RegExp(r'SHA-256:\s+([0-9a-fA-F]{64})').firstMatch(body);
        if (match != null) sha256 = match.group(1)!.toLowerCase();
      }

      if (latestTag.isEmpty) return null;

      if (_isNewerVersion(latestTag, currentVersion)) {
        final info = UpdateInfo(
          latestVersion: latestTag,
          htmlUrl: htmlUrl,
          body: body,
          downloadUrl: downloadUrl,
          sha256: sha256,
        );

        _cachedResult = info;
        _lastCheck = DateTime.now();
        unawaited(_maybeNotify(info));
        return info;
      }

      _lastCheck = DateTime.now();
      return null;
    } catch (e, st) {
      _log.warning('Update check failed', e, st);
      return null;
    }
  }

  /// Posts a one-time system notification for a newly detected update,
  /// de-duplicated so it only fires once per version.
  static Future<void> _maybeNotify(UpdateInfo info) async {
    try {
      final box = Hive.box<String>('UpdateState');
      final lastNotified = box.get('lastNotifiedVersion');
      if (lastNotified == info.latestVersion) return;

      await UpdateInstaller.showUpdateNotification(info.latestVersion, info.note, info.htmlUrl);
      await box.put('lastNotifiedVersion', info.latestVersion);
    } catch (e, st) {
      _log.warning('Update notification failed', e, st);
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    // Normalise: strip leading "v", drop any "+build" suffix, and keep only
    // numeric dotted components so "0.9.29" vs "0.9.28+129" compares correctly.
    String clean(String s) => s.replaceFirst(RegExp(r'^v'), '').split('+').first;
    try {
      final latestParts = clean(latest).split('.').map(int.parse).toList();
      final currentParts = clean(current).split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return clean(latest).compareTo(clean(current)) > 0;
    }
  }
}
