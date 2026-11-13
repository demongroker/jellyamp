import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Resumable, stall-tolerant HTTP file download.
///
/// One implementation for the two places Jellyamp pulls a large file from a
/// network that can vanish mid-transfer (the APK update, and sharing an
/// original audio file). Both used to call `client.send()` once and pipe the
/// body: a stalled stream then hung forever with no way back, and any drop
/// restarted the whole file.
///
/// Guarantees:
///  * bytes land in `<file>.part`, never in [file] directly, so a half
///    download can never be mistaken for a complete one;
///  * a retry resumes with an HTTP `Range` request from the current length;
///  * the stream is aborted with [TimeoutException] after [stallTimeout] with
///    no bytes (ship wifi, hotspot death, a tunnel);
///  * a server that ignores `Range` (200 on a resumed request) restarts the
///    file instead of appending to it, so the result can still hash correctly;
///  * `416 Range Not Satisfiable` promotes the partial file, because the only
///    remaining check is the caller's own (SHA-256 for the APK).
class ResumableDownload {
  ResumableDownload._();

  static const Duration defaultStallTimeout = Duration(seconds: 30);
  static const int defaultMaxAttempts = 4;

  /// Downloads [url] into [destination], resuming any existing
  /// `<destination>.part`. Throws the last error when every attempt fails; the
  /// `.part` file is kept in that case so the next call resumes.
  static Future<File> toFile(
    Uri url, {
    required File destination,
    Map<String, String> headers = const {},
    void Function(double progress)? onProgress,
    Duration stallTimeout = defaultStallTimeout,
    int maxAttempts = defaultMaxAttempts,
    bool resume = true,
  }) async {
    final part = File('${destination.path}.part');

    var received = 0;
    if (await part.exists()) {
      if (resume) {
        received = await part.length();
      } else {
        await part.delete();
      }
    }

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = http.Client();
      try {
        final request = http.Request('GET', url);
        request.headers.addAll(headers);
        if (received > 0) request.headers['Range'] = 'bytes=$received-';

        final response = await client.send(request).timeout(stallTimeout);
        final status = response.statusCode;

        if (status == 416 && received > 0) {
          await _promote(part, destination);
          onProgress?.call(1.0);
          return destination;
        }

        if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
          throw HttpException('Download failed: HTTP $status', uri: url);
        }

        if (status == HttpStatus.ok && received > 0) {
          // Server ignored `Range` (or the asset changed under us): start over
          // rather than append, which would corrupt the file.
          received = 0;
          if (await part.exists()) await part.delete();
        }

        final total = _totalBytes(response, received);
        final sink = part.openWrite(mode: received > 0 ? FileMode.append : FileMode.write);
        try {
          // `.timeout` on the byte stream is what turns a silent stall into an
          // error; a bare await-for would simply never complete.
          await for (final chunk in response.stream.timeout(stallTimeout)) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        } finally {
          await sink.flush();
          await sink.close();
        }

        await _promote(part, destination);
        onProgress?.call(1.0);
        return destination;
      } on Object catch (e) {
        // Keep the `.part` file: it is the resume point for the next attempt.
        lastError = e;
        if (attempt >= maxAttempts) break;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      } finally {
        client.close();
      }
    }

    throw lastError ?? SocketException('Download failed: transfer never completed');
  }

  /// Deletes `<destination>.part` (called when bytes are known to be bad, e.g.
  /// a failed checksum, so the next attempt cannot resume from them).
  static Future<void> discardPartial(File destination) async {
    final part = File('${destination.path}.part');
    if (await part.exists()) await part.delete();
  }

  static Future<void> _promote(File part, File destination) async {
    if (await destination.exists()) await destination.delete();
    await part.rename(destination.path);
  }

  /// Total asset size, accounting for a resumed (206) response where
  /// `contentLength` covers only the remainder.
  static int _totalBytes(http.StreamedResponse response, int alreadyHave) {
    final contentRange = _headerValue(response.headers, 'content-range');
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)\s*$').firstMatch(contentRange);
      final parsed = int.tryParse(match?.group(1) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final length = response.contentLength;
    if (length == null || length <= 0) return 0;
    return alreadyHave > 0 ? alreadyHave + length : length;
  }

  static String? _headerValue(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }
}
