import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads and installs a Jellyamp APK update in-app.
class UpdateInstaller {
  UpdateInstaller._();

  static const MethodChannel _channel = MethodChannel('com.unicornsonlsd.finamp/update_installer');

  /// Downloads the APK at [url] to app-private cache, reporting [onProgress]
  /// as a fraction in [0, 1].
  static Future<File> downloadApk(String url, {void Function(double progress)? onProgress}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/jellyamp-update.apk');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();

      return file;
    } finally {
      client.close();
    }
  }

  /// Computes the SHA-256 hex digest of [file].
  static Future<String> sha256Of(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
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
