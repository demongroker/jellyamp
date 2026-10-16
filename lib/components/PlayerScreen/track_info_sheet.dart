import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/components/PlayerScreen/feature_chips.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/server_info_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Power-user track information sheet (JellyAmp fork feature).
///
/// Opened from the playback-mode feature chip on the player screen. Shows the
/// technical details of the currently playing track: playback mode (Direct
/// Play / Direct Stream / Transcoding / Local), codec, bitrate, bit depth,
/// sample rate, channels, container, file size, path, and server.
///
/// When transcoding, it also shows the source → output chain and the reason,
/// so "TRANSCODING" always explains itself.
class TrackInfoSheet extends ConsumerWidget {
  const TrackInfoSheet({super.key, required this.featureState});

  final FeatureState featureState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverName = ref.watch(currentServerInfoProvider).value?.publicServerInfo.serverName;

    final audioStream = featureState.audioStream;
    final mediaSource = featureState.metadata?.mediaSourceInfo;

    String playbackModeLabel() {
      if (featureState.isDownloaded) return l10n.playbackModeLocal;
      if (featureState.isTranscodingAndStreaming) return l10n.playbackModeTranscoding;
      // Direct Streaming vs Direct Playing: the server reports whether the
      // media source can be direct-played. If not, a container remux
      // (direct stream) is used instead of a full transcode.
      final supportsDirectPlay = mediaSource?.supportsDirectPlay ?? true;
      final supportsDirectStream = mediaSource?.supportsDirectStream ?? false;
      if (supportsDirectPlay) return l10n.playbackModeDirectPlaying;
      if (supportsDirectStream) return l10n.playbackModeDirectStreaming;
      return l10n.playbackModeDirectPlaying;
    }

    final rows = <(IconData, String, String)>[
      (TablerIcons.player_play, l10n.playbackMode, playbackModeLabel()),
      if (featureState.isTranscodingAndStreaming) ..._transcodingRows(featureState, mediaSource, l10n),
      (TablerIcons.music, l10n.codec, featureState.codec.toUpperCase()),
      if (featureState.bitrate != null)
        (TablerIcons.gauge, l10n.bitRate, l10n.kiloBitsPerSecondLabel(featureState.bitrate! ~/ 1000)),
      if (featureState.bitDepth != null) (TablerIcons.binary, l10n.bitDepth, l10n.numberAsBit(featureState.bitDepth!)),
      if (featureState.sampleRate != null)
        (TablerIcons.wave_sine, l10n.sampleRate, l10n.numberAsKiloHertz(featureState.sampleRate! / 1000.0)),
      if (audioStream?.channels != null)
        (TablerIcons.adjustments_horizontal, l10n.channels, '${audioStream?.channels}'),
      (TablerIcons.box, l10n.container, featureState.container.toUpperCase()),
      if (featureState.size != null) (TablerIcons.database, l10n.fileSize, FileSize.getSize(featureState.size!)),
      if (mediaSource?.path != null) (TablerIcons.folder, l10n.path, mediaSource!.path!),
      if (serverName != null) (TablerIcons.server, l10n.server, serverName),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              featureState.currentTrack?.item.title ?? '',
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
            if (featureState.currentTrack?.baseItem.artists?.isNotEmpty ?? false)
              Text(
                featureState.currentTrack!.baseItem.artists!.join(', '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(row.$1, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(row.$2, style: Theme.of(context).textTheme.bodyMedium)),
                    Text(
                      row.$3,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Source → output → reason rows, shown only while transcoding.
  List<(IconData, String, String)> _transcodingRows(
    FeatureState fs,
    MediaSourceInfo? mediaSource,
    AppLocalizations l10n,
  ) {
    final source = _sourceAudioStream(mediaSource);
    final output = [
      fs.codec.toUpperCase(),
      if (fs.bitrate != null) l10n.kiloBitsPerSecondLabel(fs.bitrate! ~/ 1000),
    ].join(' · ');
    return [
      (TablerIcons.music, l10n.transcodingSource, source == null ? l10n.unknown : _describeStream(source, l10n)),
      (TablerIcons.arrow_right, l10n.transcodingOutput, output),
      (TablerIcons.help, l10n.transcodingReason, l10n.transcodingReasonStreamingQuality),
    ];
  }
}

/// The original (pre-transcode) audio stream from the media source.
MediaStream? _sourceAudioStream(MediaSourceInfo? mediaSource) {
  final streams = mediaSource?.mediaStreams ?? const <MediaStream>[];
  for (final s in streams) {
    if (s.type == 'Audio') return s;
  }
  return streams.isNotEmpty ? streams.first : null;
}

String _describeStream(MediaStream s, AppLocalizations l10n) {
  final parts = <String>[
    (s.codec ?? '?').toUpperCase(),
    if (s.bitDepth != null) l10n.numberAsBit(s.bitDepth!),
    if (s.sampleRate != null) l10n.numberAsKiloHertz(s.sampleRate! / 1000.0),
    if (s.bitRate != null) l10n.kiloBitsPerSecondLabel(s.bitRate! ~/ 1000),
  ];
  return parts.join(' · ');
}

Future<void> showTrackInfoSheet(BuildContext context, FeatureState featureState) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => TrackInfoSheet(featureState: featureState),
  );
}
