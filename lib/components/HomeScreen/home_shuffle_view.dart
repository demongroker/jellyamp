import 'package:flutter/material.dart';

/// Search + Shuffle homepage (JAMP-002).
///
/// Deliberately self-contained: it takes plain callbacks and a list of library
/// names, so it can be tested without Hive, Riverpod or a Jellyfin backend.
class HomeShuffleView extends StatelessWidget {
  const HomeShuffleView({
    super.key,
    required this.libraries,
    this.onSearch,
    this.onShuffleAll,
    this.onShuffleLibrary,
    this.onBrowse,
    this.nowPlayingTitle,
    this.nowPlayingArtist,
    this.onNowPlayingTap,
  });

  final List<String> libraries;
  final VoidCallback? onSearch;
  final VoidCallback? onShuffleAll;
  final void Function(String library)? onShuffleLibrary;
  final VoidCallback? onBrowse;
  final String? nowPlayingTitle;
  final String? nowPlayingArtist;
  final VoidCallback? onNowPlayingTap;

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

          if (nowPlayingTitle != null) ...[
            _NowPlayingCard(
              title: nowPlayingTitle!,
              artist: nowPlayingArtist,
              onTap: onNowPlayingTap,
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
  const _NowPlayingCard({required this.title, this.artist, this.onTap});

  final String title;
  final String? artist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHigh,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                  if (artist != null)
                    Text(artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                ],
              ),
            ),
            Icon(Icons.queue_music, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
