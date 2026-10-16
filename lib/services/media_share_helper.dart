import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final _shareLog = Logger("MediaShareHelper");

/// Maximum age (in hours) for temporary share files before cleanup.
const int _shareTempMaxAgeHours = 48;

/// Deletes old temporary share files from previous sessions.
Future<void> cleanupOldShareFiles() async {
  try {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory(path_helper.join(tempDir.path, 'jellyamp_share'));
    if (!await shareDir.exists()) return;

    final now = DateTime.now();
    await for (final entity in shareDir.list(recursive: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        final age = now.difference(stat.modified);
        if (age.inHours > _shareTempMaxAgeHours) {
          await entity.delete();
          _shareLog.fine('Deleted stale share file: ${entity.path}');
        }
      }
    }
  } catch (e) {
    _shareLog.warning('cleanupOldShareFiles failed', e);
  }
}

/// Helpers for sharing Jellyfin library items (links, metadata, original audio files).
class MediaShareHelper {
  MediaShareHelper._();

  /// Build a Jellyfin web UI details URL for [item].
  ///
  /// Uses the modern hash route (`/web/#/details?id=...`) supported by Jellyfin 10.8+.
  static String? jellyfinDetailsUrl(BaseItemDto item) {
    final user = GetIt.instance<FinampUserHelper>().currentUser;
    if (user == null) return null;

    final base = user.baseURL.replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;

    return '$base/web/#/details?id=${item.id.raw}';
  }

  /// Human-readable one-liner: `Artist — Title` for tracks, otherwise the item name.
  static String itemDisplayLine(BaseItemDto item) {
    final name = item.name?.trim();
    final artists = item.artists?.where((a) => a.trim().isNotEmpty).toList();
    if (artists != null && artists.isNotEmpty && name != null && name.isNotEmpty) {
      return '${artists.join(', ')} — $name';
    }
    if (name != null && name.isNotEmpty) return name;
    if (item.albumArtist != null && item.albumArtist!.trim().isNotEmpty) {
      return item.albumArtist!.trim();
    }
    return 'Unknown item';
  }

  /// Share sheet with name + optional Jellyfin web link.
  static Future<void> shareItem(BaseItemDto item) async {
    final line = itemDisplayLine(item);
    final url = jellyfinDetailsUrl(item);
    final text = url == null ? line : '$line\n$url';

    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: line));
    } catch (e) {
      GlobalSnackbar.error(e);
    }
  }

  /// Copy Jellyfin web details URL to the clipboard.
  static Future<void> copyItemLink(BaseItemDto item) async {
    final url = jellyfinDetailsUrl(item);
    if (url == null) {
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareItemNoServer);
      return;
    }

    try {
      await FlutterClipboard.copy(url);
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareItemLinkCopied);
    } catch (e) {
      GlobalSnackbar.error(e);
    }
  }

  /// Copy `Artist — Title` (or name) to the clipboard.
  static Future<void> copyItemInfo(BaseItemDto item) async {
    final line = itemDisplayLine(item);
    try {
      await FlutterClipboard.copy(line);
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.copyItemInfoCopied);
    } catch (e) {
      GlobalSnackbar.error(e);
    }
  }

  /// Download (if needed) the **original** audio file (e.g. FLAC) and open the system share sheet.
  ///
  /// Prefers an already-downloaded offline original when available; otherwise streams
  /// `/Items/{id}/File` from the Jellyfin server into a temp file, then shares it.
  static Future<void> shareOriginalAudioFile(BaseItemDto item) async {
    try {
      await cleanupOldShareFiles(); // clean stale temp files first
      GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareAudioFilePreparing);

      final localFile = await _resolveLocalOrDownloadOriginal(item);
      if (localFile == null || !await localFile.exists()) {
        GlobalSnackbar.message((ctx) => AppLocalizations.of(ctx)!.shareAudioFileFailed);
        return;
      }

      final ext = path_helper.extension(localFile.path).toLowerCase().replaceFirst('.', '');
      final mime = _mimeForAudioExtension(ext);
      final line = itemDisplayLine(item);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(localFile.path, mimeType: mime, name: path_helper.basename(localFile.path))],
          text: line,
          subject: line,
        ),
      );
    } catch (e, st) {
      _shareLog.severe("shareOriginalAudioFile failed", e, st);
      GlobalSnackbar.error(e);
    }
  }

  static Future<File?> _resolveLocalOrDownloadOriginal(BaseItemDto item) async {
    final downloadsService = GetIt.instance<DownloadsService>();
    final existing = downloadsService.getTrackDownload(item: item);
    final existingFile = existing?.file;
    if (existingFile != null && await existingFile.exists()) {
      final profile = existing?.fileTranscodingProfile;
      final isOriginal = profile == null || profile.codec == FinampTranscodingCodec.original;
      if (isOriginal || FinampSettingsHelper.finampSettings.isOffline) {
        return existingFile;
      }
    }

    if (FinampSettingsHelper.finampSettings.isOffline) {
      return existingFile;
    }

    return _downloadOriginalToTemp(item);
  }

  static Future<File> _downloadOriginalToTemp(BaseItemDto item) async {
    final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
    final userHelper = GetIt.instance<FinampUserHelper>();

    final url = jellyfinApiHelper.getTrackDownloadUrl(
      item: item,
      transcodingProfile: DownloadProfile(transcodeCodec: FinampTranscodingCodec.original),
    );

    final request = http.Request('GET', url);
    request.headers['Authorization'] = userHelper.authorizationHeader;

    final client = http.Client();
    try {
      final response = await client.send(request).timeout(const Duration(seconds: 180));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Jellyfin file download failed (${response.statusCode}) for ${item.id.raw}', uri: url);
      }

      final ext = _extensionForItem(item, response.headers);
      final dir = Directory(path_helper.join((await getTemporaryDirectory()).path, 'jellyamp_share'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final filename = _safeFilename(item, ext);
      final out = File(path_helper.join(dir.path, filename));
      final sink = out.openWrite();
      try {
        await response.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      _shareLog.info("Prepared share file ${out.path} (${await out.length()} bytes)");
      return out;
    } finally {
      client.close();
    }
  }

  static String _extensionForItem(BaseItemDto item, Map<String, String> headers) {
    final cd = headers['content-disposition'] ?? headers['Content-Disposition'];
    if (cd != null) {
      final match = RegExp(r'filename[^*;=\n]*=\s*\"?([^\";\n]+)\"?', caseSensitive: false).firstMatch(cd);
      if (match != null) {
        final name = match.group(1)!;
        final e = path_helper.extension(name).replaceFirst('.', '');
        if (e.isNotEmpty) return e.toLowerCase();
      }
    }

    final contentType = (headers['content-type'] ?? headers['Content-Type'] ?? '').toLowerCase();
    if (contentType.contains('flac')) return 'flac';
    if (contentType.contains('mpeg') || contentType.contains('mp3')) return 'mp3';
    if (contentType.contains('ogg')) return 'ogg';
    if (contentType.contains('mp4') || contentType.contains('m4a') || contentType.contains('aac')) return 'm4a';
    if (contentType.contains('wav')) return 'wav';
    if (contentType.contains('opus')) return 'opus';

    String? container = item.container;
    final sources = item.mediaSources;
    if (sources != null && sources.isNotEmpty) container ??= sources.first.container;
    if (container != null && container.isNotEmpty) {
      final first = container.split(RegExp(r'[,/]')).first.trim().toLowerCase();
      if (first.isNotEmpty && first != 'null') {
        if (first == 'mpeg') return 'mp3';
        if (first == 'mp4') return 'm4a';
        return first;
      }
    }

    return 'flac';
  }

  static String _safeFilename(BaseItemDto item, String ext) {
    final line = itemDisplayLine(item);
    var base = line.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (base.isEmpty) base = item.id.raw;
    if (base.length > 120) base = base.substring(0, 120);
    return '$base.$ext';
  }

  static String _mimeForAudioExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'flac' => 'audio/flac',
      'mp3' => 'audio/mpeg',
      'm4a' || 'aac' || 'mp4' => 'audio/mp4',
      'ogg' || 'oga' => 'audio/ogg',
      'opus' => 'audio/opus',
      'wav' => 'audio/wav',
      'aiff' || 'aif' => 'audio/aiff',
      'wma' => 'audio/x-ms-wma',
      _ => 'audio/*',
    };
  }
}
