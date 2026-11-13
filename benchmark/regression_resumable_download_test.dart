// Regression: resumable, stall-tolerant downloads (ResumableDownload).
//
// These run against a real HttpServer on loopback, so they exercise the actual
// package:http client path, not a mock: the interesting bugs here (a stall that
// never errors, a resume that appends to bytes the server already replaced, a
// 206 whose Content-Range is ignored) only appear with a real socket.
//
// Run:  flutter test benchmark/regression_resumable_download_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:finamp/services/resumable_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('resumable_download_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  final payload = Uint8List.fromList(List<int>.generate(64 * 1024, (i) => i % 251));

  test('a dropped connection resumes with Range and the file ends up complete', () async {
    var requests = 0;
    final rangeHeaders = <String>[];

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) rangeHeaders.add(range);

      final offset = range == null ? 0 : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      final body = payload.sublist(offset);

      request.response.statusCode = range == null ? HttpStatus.ok : HttpStatus.partialContent;
      request.response.headers.contentLength = body.length;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $offset-${payload.length - 1}/${payload.length}',
      );
      request.response.add(body.sublist(0, 4096));

      if (requests == 1) {
        // First attempt: promise the whole asset, deliver 4 KB, then close the
        // response early — the client sees a truncated body, exactly what a
        // dropped ship-wifi link looks like.
        await request.response.flush();
        try {
          await request.response.close();
        } catch (_) {
          // close() rejects a short write; the connection is already gone.
        }
        return;
      }

      request.response.add(body.sublist(4096));
      await request.response.close();
    });

    final destination = File('${tempDir.path}/resumed.bin');

    await ResumableDownload.toFile(
      Uri.parse('http://127.0.0.1:${server.port}/asset'),
      destination: destination,
      stallTimeout: const Duration(seconds: 5),
      maxAttempts: 3,
    );

    await server.close(force: true);

    expect(requests, greaterThanOrEqualTo(2), reason: 'the drop must trigger a retry');
    expect(rangeHeaders, isNotEmpty, reason: 'the retry must resume with Range, not restart');
    expect(rangeHeaders.first, startsWith('bytes=4096-'), reason: 'resume from the bytes already on disk');
    expect(await destination.length(), payload.length);
    expect(await destination.readAsBytes(), payload);
    expect(File('${destination.path}.part').existsSync(), isFalse, reason: '.part promoted, not left behind');
  });

  test('a stalled stream fails fast instead of hanging, and keeps .part for the next tap', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var closed = false;
    server.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentLength = 1024;
      request.response.add(Uint8List.fromList(List<int>.filled(10, 7)));
      await request.response.flush();
      // Never send anything else and never close: a dead-but-open link.
      closed = true;
    });

    final destination = File('${tempDir.path}/stalled.bin');

    await expectLater(
      ResumableDownload.toFile(
        Uri.parse('http://127.0.0.1:${server.port}/asset'),
        destination: destination,
        stallTimeout: const Duration(seconds: 1),
        maxAttempts: 1,
      ),
      throwsA(isA<TimeoutException>()),
    );

    final part = File('${destination.path}.part');
    expect(closed, isTrue);
    expect(part.existsSync(), isTrue, reason: 'partial bytes are the resume point; they must survive');
    expect(part.lengthSync(), 10);
    expect(destination.existsSync(), isFalse, reason: 'a stalled transfer must never produce a "complete" file');

    await server.close(force: true);
  });

  test('a server that ignores Range restarts the file instead of appending twice', () async {
    // First request drops after 4096 bytes; the retry gets a plain 200 (no Range
    // support), which must discard the partial file and download from zero.
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentLength = payload.length;
      request.response.add(requests == 1 ? payload.sublist(0, 4096) : payload);
      if (requests == 1) {
        await request.response.flush();
        try {
          await request.response.close();
        } catch (_) {
          // short write: the client already saw the connection drop
        }
        return;
      }
      await request.response.close();
    });

    final destination = File('${tempDir.path}/restarted.bin');

    await ResumableDownload.toFile(
      Uri.parse('http://127.0.0.1:${server.port}/asset'),
      destination: destination,
      stallTimeout: const Duration(seconds: 5),
      maxAttempts: 3,
    );

    await server.close(force: true);

    expect(requests, greaterThanOrEqualTo(2));
    expect(await destination.length(), payload.length, reason: 'no duplicated prefix');
    expect(await destination.readAsBytes(), payload);
  });

  test('416 on a resumed request promotes the partial file (nothing left to fetch)', () async {
    final destination = File('${tempDir.path}/satisfied.bin');
    final part = File('${destination.path}.part');
    await part.writeAsBytes(payload);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await request.response.close();
    });

    final result = await ResumableDownload.toFile(
      Uri.parse('http://127.0.0.1:${server.port}/asset'),
      destination: destination,
      stallTimeout: const Duration(seconds: 5),
      maxAttempts: 1,
    );

    await server.close(force: true);

    expect(result.path, destination.path);
    expect(await destination.readAsBytes(), payload);
    expect(part.existsSync(), isFalse);
  });

  test('discardPartial removes the resume point so a bad file is never resumed', () async {
    final destination = File('${tempDir.path}/discarded.bin');
    final part = File('${destination.path}.part');
    await part.writeAsBytes(Uint8List.fromList([1, 2, 3]));

    await ResumableDownload.discardPartial(destination);

    expect(part.existsSync(), isFalse);
  });
}
