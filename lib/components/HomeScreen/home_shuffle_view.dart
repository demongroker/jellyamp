import 'package:flutter/material.dart';

/// Plain snapshot of what's playing. Deliberately free of audio/Jellyfin types
/// so the homepage widget stays unit-testable without mocking.
class NowPlaying {
  const NowPlaying({
    required this.title,
    this.artist,
    this.imageUrl,
    required this.isPlaying,
    this.position = Duration.zero,
    this.duration,
  });

  final String title;
  final String? artist;
  final String? imageUrl;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;

  /// 0..1 when a duration is known, otherwise null (no bar shown).
  double? get progress {
    final d = duration;
    if (d == null || d.inMilliseconds <= 0) return null;
    final p = position.inMilliseconds.clamp(0, d.inMilliseconds);
    return p / d.inMilliseconds;
  }
}

/// Search + Shuffle homepage (JAMP-002 / JAMP-004).
///
/// Self-contained: plain callbacks + library names + an optional [NowPlaying]
/// snapshot, so it can be tested without Hive, Riverpod or a Jellyfin backend.
class HomeShuffleView extends StatelessWidget {
  const HomeShuffleView({
    super.key,
    required this.libraries,
    this.onSearch,
    this.onShuffleAll,
    this.onShuffleLibrary,
    this.onBrowse,
    this.nowPlaying,
    this.onNowPlayingTap,
    this.onTogglePlayPause,
  });

  final List<String> libraries;
  final VoidCallback? onSearch;
  final VoidCallback? onShuffleAll;
  final void Function(String library)? onShuffleLibrary;
  final VoidCallback? onBrowse;
  final NowPlaying? nowPlaying;
  final VoidCallback? onNowPlayingTap;
  final VoidCallback? onTogglePlayPause;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Always-visible search bar.
          Semantics(
            button: true,
            label: 'Search',
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search songs, artists, albums',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Huge SHUFFLE ALL.
          _GradientShuffleButton(onTap: onShuffleAll),
          const SizedBox(height: 16),

          // Quick shuffle chips, one per library.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final library in libraries)
                ActionChip(
                  avatar: const Icon(Icons.shuffle, size: 18),
                  label: Text(library),
                  onPressed: () => onShuffleLibrary?.call(library),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Live now-playing card; hidden entirely when nothing is queued.
          if (nowPlaying != null) ...[
            _NowPlayingCard(
              data: nowPlaying!,
              onTap: onNowPlayingTap,
              onToggle: onTogglePlayPause,
            ),
            const SizedBox(height: 8),
          ],

          // Everything else collapses into one small link.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.grid_view, size: 18),
              label: const Text('Browse'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientShuffleButton extends StatelessWidget {
  const _GradientShuffleButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Shuffle all',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7A1FA2), Color(0xFFD81B60), Color(0xFFFF7043)],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shuffle, color: theme.colorScheme.onPrimary, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'SHUFFLE ALL',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Icon(Icons.play_arrow, color: theme.colorScheme.onPrimary, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.data, this.onTap, this.onToggle});

  final NowPlaying data;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = data.progress;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHigh,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Art(url: data.imageUrl, title: data.title),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                      if (data.artist != null)
                        Text(data.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: data.isPlaying ? 'Pause' : 'Play',
                  onPressed: onToggle,
                  icon: Icon(data.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = 48.0;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF4527A0), Color(0xFF00897B)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (url == null || url!.isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
