import 'dart:convert';
import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// A named network profile that rewrites the settings deciding how much data
/// playback and downloads cost.
class NetworkPresetConfig {
  const NetworkPresetConfig({
    required this.id,
    required this.label,
    required this.description,
    required this.bitrateBitsPerSecond,
    required this.bufferDurationSeconds,
  });

  final String id;
  final String label;
  final String description;

  /// Transcode bitrate in bits per second (128000 = 128 kbps).
  final int bitrateBitsPerSecond;

  /// How much audio the player buffers ahead of the current position.
  final int bufferDurationSeconds;

  /// Opus on Android, AAC on iOS/macOS — the same platform choice
  /// [DownloadProfile] already makes when no codec is given, because Android
  /// decodes Opus in software and Apple's stack does not (and vice versa for AAC).
  FinampTranscodingCodec get codec =>
      Platform.isIOS || Platform.isMacOS ? FinampTranscodingCodec.aac : FinampTranscodingCodec.opus;
}

/// One-tap network presets (⑤).
///
/// The settings that matter on a bad link are spread over three screens — the
/// download codec, the download bitrate and the audio buffer. Applying them in
/// one place is the difference between "sounds great at home" and "stutters at
/// sea".
class NetworkPresets {
  NetworkPresets._();

  /// At sea / low-data: 128 kbps Opus/AAC and a 90 s buffer.
  ///
  /// 128 kbps is ~1 MB per minute, so an album is a few MB instead of hundreds
  /// of MB of FLAC, and 90 s of buffer rides out the multi-second gaps a
  /// saturated satellite link produces without the player running dry.
  static const atSea = NetworkPresetConfig(
    id: 'atSea',
    label: 'At sea / low-data',
    description: 'Opus 128 kbps (AAC on iOS) and a 90 s buffer — for ship wifi, '
        'mobile data or any metered link.',
    bitrateBitsPerSecond: 128000,
    bufferDurationSeconds: 90,
  );

  /// Opened in lib/bootstrap/database.dart. Holds one JSON string per preset id.
  static const _backupBoxName = 'NetworkPresetBackup';

  static Box<String> get _backupBox => Hive.box<String>(_backupBoxName);

  /// Whether [preset] is currently in force (bitrate and buffer both match).
  static bool isActive(NetworkPresetConfig preset) {
    final settings = FinampSettingsHelper.finampSettings;
    return settings.downloadTranscodeBitrate == preset.bitrateBitsPerSecond &&
        settings.bufferDurationSeconds == preset.bufferDurationSeconds;
  }

  /// Applies [preset], remembering the previous codec/bitrate/buffer so
  /// [revert] can put them back exactly.
  static Future<void> apply(NetworkPresetConfig preset) async {
    final box = Hive.box<FinampSettings>('FinampSettings');
    final settings = FinampSettingsHelper.finampSettings;

    await _backupBox.put(
      preset.id,
      jsonEncode({
        'codec': settings.downloadTranscodingCodec?.name,
        'bitrate': settings.downloadTranscodeBitrate,
        'bufferSeconds': settings.bufferDurationSeconds,
      }),
    );

    settings.downloadTranscodingCodec = preset.codec;
    settings.downloadTranscodeBitrate = preset.bitrateBitsPerSecond;
    settings.bufferDurationSeconds = preset.bufferDurationSeconds;
    await box.put('FinampSettings', settings);
  }

  /// Restores whatever was configured before [preset] was applied. Falls back to
  /// app defaults when no backup was recorded (fresh install, cleared box).
  static Future<void> revert(NetworkPresetConfig preset) async {
    final box = Hive.box<FinampSettings>('FinampSettings');
    final settings = FinampSettingsHelper.finampSettings;

    FinampTranscodingCodec? codec;
    int? bitrate;
    var bufferSeconds = DefaultSettings.bufferDurationSeconds;

    final raw = _backupBox.get(preset.id);
    if (raw != null) {
      try {
        final saved = jsonDecode(raw);
        if (saved is Map) {
          final savedCodec = saved['codec'];
          if (savedCodec is String) {
            codec = FinampTranscodingCodec.values.firstWhere(
              (value) => value.name == savedCodec,
              orElse: () => DownloadProfile().codec,
            );
          }
          final savedBitrate = saved['bitrate'];
          if (savedBitrate is int) bitrate = savedBitrate;
          final savedBuffer = saved['bufferSeconds'];
          if (savedBuffer is int) bufferSeconds = savedBuffer;
        }
      } catch (_) {
        // Corrupt backup: fall through to the defaults above.
      }
    }

    settings.downloadTranscodingCodec = codec;
    settings.downloadTranscodeBitrate = bitrate;
    settings.bufferDurationSeconds = bufferSeconds;
    await box.put('FinampSettings', settings);
    await _backupBox.delete(preset.id);
  }
}
