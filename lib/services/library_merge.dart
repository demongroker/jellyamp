import 'dart:math' as math;

import 'package:diacritic/diacritic.dart';
import 'package:finamp/models/jellyfin_models.dart';

/// One artist row after merging every server entry that denotes the same artist.
class MergedArtist {
  const MergedArtist({required this.artist, required this.mergedIds});

  /// The entry shown to the user — the one that carries artwork when any does.
  final BaseItemDto artist;

  /// Every server id folded into this row (primary first).
  final List<String> mergedIds;

  bool get isMerged => mergedIds.length > 1;
}

/// One album row after merging releases that are the same album.
class MergedAlbum {
  const MergedAlbum({required this.album, required this.mergedIds, this.disambiguator});

  /// The entry shown (and opened) for this album.
  ///
  /// When releases are merged this is the server copy, which carries the full
  /// metadata and artwork. Playback still uses the downloaded file for any
  /// track that is downloaded — downloads are keyed by server id, so merging
  /// never changes which bytes play.
  final BaseItemDto album;

  final List<String> mergedIds;

  /// Set only when another, *different* album shares this title, so the two
  /// rows can be told apart: `1989 · 11 tracks · On device`.
  final String? disambiguator;
}

/// Merges duplicate library entries that Jellyfin reports as separate items.
///
/// The server does not guarantee one row per real-world artist/album: a
/// re-import, a feature credit or a different capitalisation produces an
/// artist with no image next to the "real" one, and a compilation can sit next
/// to a studio album under the same title. Nothing here touches server data —
/// it is a pure view-layer fold over the items the server already returned.
class LibraryMerge {
  LibraryMerge._();

  /// Two releases are the same album when at least half of their combined
  /// distinct track titles match (Jaccard). Half, not "any overlap": a 4-track
  /// EP that reuses two songs of an 11-track album must stay separate, while a
  /// duplicate copy of the same release (identical or near-identical listings)
  /// collapses.
  static const double albumOverlapThreshold = 0.5;

  /// Folds case, spacing, punctuation, diacritics, a leading "The " and
  /// `&`/`+` vs "and" so "The Skid Row", "skid  row" and "SKID-ROW" are one key.
  static String normalize(String? value) {
    if (value == null) return '';
    var text = removeDiacritics(value).toLowerCase().trim();
    // "A & B" / "A + B" behave like "A and B".
    text = text.replaceAll(RegExp(r'\s*[&+]\s*'), ' and ');
    // Drop anything that is not a letter, digit or space ("SKID-ROW" == "Skid Row").
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Leading article, once ("the the who" is nonsense, but harmless).
    if (text.startsWith('the ')) text = text.substring(4).trim();
    return text;
  }

  /// The artist a release is filed under, normalised for grouping.
  static String albumArtistKey(BaseItemDto album) {
    final names = album.albumArtists?.map((e) => e.name).whereType<String>().toList() ?? const <String>[];
    if (names.isNotEmpty) {
      final sorted = names.map(normalize).toList()..sort();
      return sorted.join(', ');
    }
    return normalize(album.albumArtist);
  }

  /// Merges artists whose normalised names match. Order follows first
  /// appearance, so the list does not jump around between refreshes.
  static List<MergedArtist> mergeArtists(Iterable<BaseItemDto> artists) {
    final groups = <String, List<BaseItemDto>>{};
    for (final artist in artists) {
      final key = normalize(artist.name);
      if (key.isEmpty) continue; // nameless rows are never merged into each other
      groups.putIfAbsent(key, () => []).add(artist);
    }

    final merged = <MergedArtist>[];
    for (final group in groups.values) {
      final primary = _bestArtist(group);
      merged.add(
        MergedArtist(
          artist: primary,
          mergedIds: [primary.id.raw, ...group.where((a) => a.id.raw != primary.id.raw).map((a) => a.id.raw)],
        ),
      );
    }
    return merged;
  }

  /// Prefers the entry that actually has artwork (that is the one the user
  /// recognises), then the one with the most tracks, then server order.
  static BaseItemDto _bestArtist(List<BaseItemDto> group) {
    if (group.length == 1) return group.first;
    var best = group.first;
    var bestScore = _artistScore(best);
    for (final candidate in group.skip(1)) {
      final score = _artistScore(candidate);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  static int _artistScore(BaseItemDto artist) {
    final image = artist.imageId != null ? 2 : 0;
    final tracks = math.min(artist.childCount ?? 0, 1);
    return image + tracks;
  }

  /// Merges albums that share a normalised artist + title AND whose track lists
  /// mostly overlap. Same title with different tracks stays separate but gains a
  /// [MergedAlbum.disambiguator].
  ///
  /// [trackTitlesByAlbumId] maps a server album id to its normalised track
  /// titles; an album with no entry is treated as "unknown", which never merges.
  static List<MergedAlbum> mergeAlbums(
    Iterable<BaseItemDto> albums, {
    Map<String, Set<String>> trackTitlesByAlbumId = const {},
    bool Function(BaseItemDto album)? isOnDevice,
  }) {
    final clusters = <_AlbumCluster>[];

    for (final album in albums) {
      final key = '${albumArtistKey(album)}\u0000${normalize(album.name)}';
      final titles = trackTitlesByAlbumId[album.id.raw] ?? const <String>{};

      _AlbumCluster? target;
      for (final cluster in clusters) {
        if (cluster.key != key) continue;
        if (_overlaps(cluster, titles)) {
          target = cluster;
          break;
        }
      }

      if (target == null) {
        clusters.add(_AlbumCluster(key: key, album: album, titles: titles));
      } else {
        target.absorb(album, titles);
      }
    }

    // A title that ends up on more than one cluster is ambiguous: label each row
    // so "Skid Row (1989, 11 tracks, on device)" cannot be confused with
    // "Skid Row (2008, 4 tracks, server)".
    final clustersPerTitle = <String, int>{};
    for (final cluster in clusters) {
      final title = normalize(cluster.album.name);
      clustersPerTitle[title] = (clustersPerTitle[title] ?? 0) + 1;
    }

    return clusters.map((cluster) {
      final ambiguous = (clustersPerTitle[normalize(cluster.album.name)] ?? 0) > 1;
      return MergedAlbum(
        album: cluster.album,
        mergedIds: cluster.mergedIds,
        disambiguator: ambiguous ? _describe(cluster, isOnDevice) : null,
      );
    }).toList();
  }

  static String _describe(_AlbumCluster cluster, bool Function(BaseItemDto album)? isOnDevice) {
    final album = cluster.album;
    final parts = <String>[];
    if (album.productionYear != null) parts.add('${album.productionYear}');
    final tracks = album.childCount ?? (cluster.titles.isNotEmpty ? cluster.titles.length : null);
    if (tracks != null && tracks > 0) parts.add('$tracks tracks');
    parts.add((isOnDevice?.call(album) ?? false) ? 'On device' : 'Server');
    return parts.join(' · ');
  }

  static bool _overlaps(_AlbumCluster cluster, Set<String> titles) {
    // No track data on either side means "cannot tell" — never merge on guesswork.
    if (cluster.titles.isEmpty || titles.isEmpty) return false;
    final intersection = cluster.titles.intersection(titles).length;
    if (intersection == 0) return false;
    final union = cluster.titles.union(titles).length;
    return union > 0 && intersection / union >= albumOverlapThreshold;
  }
}

class _AlbumCluster {
  _AlbumCluster({required this.key, required this.album, required Set<String> titles})
    : titles = {...titles},
      mergedIds = [album.id.raw];

  final String key;
  BaseItemDto album;
  final List<String> mergedIds;
  Set<String> titles;

  void absorb(BaseItemDto other, Set<String> otherTitles) {
    mergedIds.add(other.id.raw);
    titles = titles.union(otherTitles);
    // Keep the entry with artwork as the visible row; otherwise keep the first.
    if (album.imageId == null && other.imageId != null) {
      album = other;
    }
  }
}
