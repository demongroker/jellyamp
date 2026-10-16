import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:clipboard/clipboard.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final _log = Logger("AppShareHelper");

/// Manages a temporary local HTTP server that serves the Jellyamp APK.
class _ApkServer {
  static const int _autoStopMinutes = 15;

  HttpServer? _server;
  String? _servingPath;
  int? _servingPort;
  String? _currentToken;
  Timer? _autoStopTimer;

  bool get isRunning => _server != null;
  int? get port => _servingPort;
  String? get token => _currentToken;

  Future<String?> start({required File apkFile, int port = 8765}) async {
    await stop();

    _currentToken = _generateToken();
    _servingPath = apkFile.path;
    _servingPort = port;

    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = server;

      _startAutoStopTimer();

      unawaited(
        server.forEach((request) async {
          try {
            if (request.method != 'GET') {
              request.response.statusCode = HttpStatus.methodNotAllowed;
              await request.response.close();
              return;
            }

            final token = request.uri.queryParameters['token'];
            if (token != _currentToken) {
              request.response.statusCode = HttpStatus.forbidden;
              await request.response.close();
              return;
            }

            if (request.uri.path.endsWith('.apk') || request.uri.path == '/') {
              final length = await apkFile.length();
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType('application', 'vnd.android.package-archive');
              request.response.headers.set('Content-Length', length);
              request.response.headers.set('Content-Disposition', 'attachment; filename="Jellyamp.apk"');
              await request.response.addStream(apkFile.openRead());
            } else {
              request.response.statusCode = HttpStatus.ok;
              request.response.headers.contentType = ContentType.html;
              request.response.write(
                '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width">'
                '<title>Jellyamp</title></head><body style="font-family:sans-serif;padding:2rem">'
                '<h1>Jellyamp</h1>'
                '<p><a href="/Jellyamp.apk?token=$_currentToken">Download Jellyamp.apk</a></p>'
                '</body></html>',
              );
            }
          } catch (e, st) {
            _log.warning("APK server request error", e, st);
          } finally {
            try {
              await request.response.close();
            } catch (_) {}
          }
        }),
      );

      return _currentToken;
    } catch (e, st) {
      _log.severe("Failed to start APK server", e, st);
      await stop();
      return null;
    }
  }

  Future<void> stop() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    final s = _server;
    _server = null;
    _servingPath = null;
    _servingPort = null;
    _currentToken = null;

    if (s != null) {
      await s.close(force: true);
    }
  }

  void _startAutoStopTimer() {
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(Duration(minutes: _autoStopMinutes), () {
      if (isRunning) {
        _log.info('Auto-stopping APK server after $_autoStopMinutes minutes');
        stop();
      }
    });
  }

  String _generateToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

/// Share the Jellyamp APK via the system share sheet, or serve it on the LAN.
class AppShareHelper {
  AppShareHelper._();

  static const _channel = MethodChannel('com.unicornsonlsd.finamp/app_share');
  static const defaultPort = 8765;

  static final _ApkServer _apkServer = _ApkServer();

  static bool get isServerRunning => _apkServer.isRunning;
  static int? get serverPort => _apkServer.port;

  /// Absolute path to the installed APK on Android.
  static Future<String?> getInstalledApkPath() async {
    if (!Platform.isAndroid) return null;
    try {
      final path = await _channel.invokeMethod<String>('getInstalledApkPath');
      if (path != null && path.isNotEmpty && await File(path).exists()) {
        return path;
      }
    } catch (e, st) {
      _log.warning("getInstalledApkPath failed", e, st);
    }
    return null;
  }

  static Future<File?> prepareShareableApkFile() async {
    final sourcePath = await getInstalledApkPath();
    if (sourcePath == null) return null;

    final cache = await getTemporaryDirectory();
    final out = File(path_helper.join(cache.path, 'jellyamp_share', 'Jellyamp.apk'));
    await out.parent.create(recursive: true);

    await File(sourcePath).copy(out.path);
    return out;
  }

  static Future<void> shareApkFile() async {
    try {
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkPreparing);
      final file = await prepareShareableApkFile();
      if (file == null) {
        GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkUnavailable);
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/vnd.android.package-archive', name: 'Jellyamp.apk')],
          text: 'Jellyamp — Jellyfin music player',
          subject: 'Jellyamp.apk',
        ),
      );
    } catch (e, st) {
      _log.severe("shareApkFile failed", e, st);
      GlobalSnackbar.error(e);
    }
  }

  static Future<String?> startLocalApkServer({int port = defaultPort}) async {
    final file = await prepareShareableApkFile();
    if (file == null) {
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkUnavailable);
      return null;
    }

    final token = await _apkServer.start(apkFile: file, port: port);
    if (token != null) {
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkServerStarted(port.toString()));
    }
    return token;
  }

  static Future<void> stopLocalApkServer() async {
    await _apkServer.stop();
    GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkServerStopped);
  }

  static Future<void> copyLocalApkUrls({int port = defaultPort}) async {
    if (!isServerRunning) {
      await startLocalApkServer(port: port);
    }

    final urls = await _localHttpUrls(_apkServer.port ?? port);
    await FlutterClipboard.copy(urls.join('\n'));
    GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareApkUrlsCopied);
  }

  static Future<List<String>> _localHttpUrls(int port) async {
    final ips = <String>[];
    try {
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false)) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) ips.add(addr.address);
        }
      }
    } catch (e) {
      _log.warning("list interfaces failed", e);
    }
    if (ips.isEmpty) ips.add('127.0.0.1');

    final token = _apkServer.token;
    return ips.map((ip) => 'http://$ip:$port/Jellyamp.apk?token=$token').toList();
  }
}
