import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'resumable_download.dart';

/// Downloads and installs a Jellyamp APK update in-app.
class UpdateInstaller {
  UpdateInstaller._();

  static const MethodChannel _channel = MethodChannel('com.unicornsonlsd.finamp/update_installer');

  // Borrowed names, kept so callers/tests keep compiling.
  static const Duration defaultStallTimeout = ResumableDownload.defaultStallTimeout;
  static const int defaultMaxAttempts = ResumableDownload.defaultMaxAttempts;

  static Future<File> _targetFile() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/jellyamp-update.apk');
  }

  /// Downloads the APK at [url] to app-private cache, reporting [onProgress]
  /// as a fraction in [0, 1].
  ///
  /// Resumable and stall-tolerant (see [ResumableDownload]): a stall aborts the
  /// transfer after [stallTimeout] with no bytes instead of hanging on
  /// "Downloading… 43 %" forever, and a retry — in this call or a later tap —
  /// continues from the bytes already on disk instead of restarting the APK.
  static Future<File> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
    Duration stallTimeout = defaultStallTimeout,
    int maxAttempts = defaultMaxAttempts,
    bool resume = true,
  }) async {
    final file = await _targetFile();
    return ResumableDownload.toFile(
      Uri.parse(url),
      destination: file,
      onProgress: onProgress,
      stallTimeout: stallTimeout,
      maxAttempts: maxAttempts,
      resume: resume,
    );
  }

  /// Removes any half-downloaded update (used when a checksum fails, so the
  /// next attempt cannot resume from bytes known to be wrong).
  static Future<void> discardPartialDownload() async {
    final file = await _targetFile();
    await ResumableDownload.discardPartial(file);
    if (await file.exists()) await file.delete();
  }

  /// Computes the SHA-256 hex digest of [file].
  static Future<String> sha256Of(File file) async {
    // Streamed, not readAsBytes: the APK is ~40–110 MB and reading it whole
    // doubles peak memory on a phone that is installing an update.
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Returns true when [file]'s SHA-256 matches [expectedHex] (case-insensitive).
  static Future<bool> verifySha256(File file, String expectedHex) async {
    final actual = await sha256Of(file);
    return actual.toLowerCase() == expectedHex.toLowerCase();
  }

  /// Fires the Android install intent for [path].
  static Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', {'path': path});
  }

  /// Whether the OS allows this app to install packages (Android 8+ gate).
  static Future<bool> canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  /// Opens the "Install unknown apps" settings for this app.
  static Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  /// Posts a system notification that an update is available.
  static Future<void> showUpdateNotification(String version, String? note, String? url) async {
    await _channel.invokeMethod<void>('showUpdateNotification', {'version': version, 'note': note, 'url': url});
  }
}
