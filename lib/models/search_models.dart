import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';

/// A parsed JellyAmp search query.
///
/// Supports a free-text term plus optional power-user syntax:
///
///   artist:metallica          scope results to artists matching "metallica"
///   album:master of puppets   scope results to albums
///   track:one                 scope results to tracks
///   playlist:metal            scope results to playlists
///   genre:metal               keep only items tagged with genre "metal"
///   year:1986                 exact year
///   year:1983-1991            inclusive year range
///   codec:flac                keep only items whose audio codec is "flac"
///   bit:24  (or bitdepth:24)  keep only 24-bit items
///   favorite:true             keep only favorites
///   downloaded:true           keep only downloaded items (false = not downloaded)
///
/// Free text and `key:value` terms can be mixed freely. Quoted phrases are
/// supported, e.g. `album:"master of puppets"`.
class SearchQuery {
  const SearchQuery({
    required this.searchTerm,
    this.yearMin,
    this.yearMax,
    this.codec,
    this.bitDepth,
    this.favoriteOnly = false,
    this.genreFilter,
    this.onlyShowArtists = false,
    this.onlyShowAlbums = false,
    this.onlyShowTracks = false,
    this.onlyShowPlaylists = false,
    this.onlyShowGenres = false,
    this.downloadedFilter,
  });

  final String searchTerm;
  final int? yearMin;
  final int? yearMax;
  final String? codec;
  final int? bitDepth;
  final bool favoriteOnly;
  final String? genreFilter;
  final bool onlyShowArtists;
  final bool onlyShowAlbums;
  final bool onlyShowTracks;
  final bool onlyShowPlaylists;
  final bool onlyShowGenres;

  /// Whether to keep only downloaded (`true`) or non-downloaded (`false`)
  /// items. Null when no `downloaded:` term was given.
  final bool? downloadedFilter;

  /// Whether any type-scoping term (`artist:`, `album:`, …) was present.
  bool get hasTypeScope => onlyShowArtists || onlyShowAlbums || onlyShowTracks || onlyShowPlaylists || onlyShowGenres;

  /// Whether any filter term (year/codec/bit/genre/favorite/downloaded) was present.
  bool get hasFilters =>
      yearMin != null ||
      yearMax != null ||
      codec != null ||
      bitDepth != null ||
      favoriteOnly ||
      genreFilter != null ||
      downloadedFilter != null;

  factory SearchQuery.parse(String raw) {
    final free = <String>[];
    int? yearMin;
    int? yearMax;
    String? codec;
    int? bitDepth;
    var favoriteOnly = false;
    String? genreFilter;
    var onlyArtists = false;
    var onlyAlbums = false;
    var onlyTracks = false;
    var onlyPlaylists = false;
    var onlyGenres = false;
    bool? downloadedFilter;

    for (final token in _tokenize(raw)) {
      final kv = _splitKeyValue(token);
      if (kv == null) {
        free.add(token);
        continue;
      }
      final (key, value) = kv;
      switch (key.toLowerCase()) {
        case 'year':
          final range = _parseYearRange(value);
          if (range != null) {
            yearMin = range.$1;
            yearMax = range.$2;
          }
        case 'codec':
          codec = value.toLowerCase();
        case 'bit':
        case 'bitdepth':
          bitDepth = int.tryParse(value);
        case 'favorite':
        case 'favourite':
          favoriteOnly = _parseBool(value);
        case 'genre':
          genreFilter = value;
        case 'artist':
          onlyArtists = true;
          free.add(value);
        case 'album':
          onlyAlbums = true;
          free.add(value);
        case 'track':
          onlyTracks = true;
          free.add(value);
        case 'playlist':
          onlyPlaylists = true;
          free.add(value);
        case 'downloaded':
          downloadedFilter = _parseBool(value);
        default:
          // Unknown key: keep it as literal search text rather than dropping it.
          free.add(token);
      }
    }

    return SearchQuery(
      searchTerm: free.join(' ').trim(),
      yearMin: yearMin,
      yearMax: yearMax,
      codec: codec,
      bitDepth: bitDepth,
      favoriteOnly: favoriteOnly,
      genreFilter: genreFilter,
      onlyShowArtists: onlyArtists,
      onlyShowAlbums: onlyAlbums,
      onlyShowTracks: onlyTracks,
      onlyShowPlaylists: onlyPlaylists,
      onlyShowGenres: onlyGenres,
      downloadedFilter: downloadedFilter,
    );
  }

  /// Client-side filter for a single result item.
  ///
  /// Codec/bit-depth only apply to media-bearing types (tracks and albums);
  /// artists, playlists and genres have no audio stream to inspect.
  bool matches(BaseItemDto item) {
    if (yearMin != null && (item.productionYear ?? 0) < yearMin!) return false;
    if (yearMax != null && (item.productionYear ?? 0) > yearMax!) return false;
    if (genreFilter != null && !(item.genres?.any((g) => g.toLowerCase() == genreFilter!.toLowerCase()) ?? false)) {
      return false;
    }
    final type = BaseItemDtoType.fromItem(item);
    if (type == BaseItemDtoType.track) {
      if (codec != null && _audioCodec(item) != codec) return false;
      if (bitDepth != null && _audioBitDepth(item) != bitDepth) return false;
    }
    return true;
  }

  /// Whether every one of [tracks] matches the codec / bit-depth filter.
  /// An album matches `codec:flac` only when ALL its tracks are FLAC; an empty
  /// track list is treated as non-matching (an empty album is not a "FLAC album").
  bool matchesAllTracks(List<BaseItemDto> tracks) {
    if (tracks.isEmpty) return false;
    return tracks.every((t) {
      if (codec != null && _audioCodec(t) != codec) return false;
      if (bitDepth != null && _audioBitDepth(t) != bitDepth) return false;
      return true;
    });
  }

  static String? _audioCodec(BaseItemDto item) {
    return _firstAudioStream(item)?.codec?.toLowerCase();
  }

  static int? _audioBitDepth(BaseItemDto item) {
    return _firstAudioStream(item)?.bitDepth;
  }

  static MediaStream? _firstAudioStream(BaseItemDto item) {
    for (final source in item.mediaSources ?? const <MediaSourceInfo>[]) {
      for (final stream in source.mediaStreams) {
        if (stream.type == 'Audio') return stream;
      }
    }
    return null;
  }

  /// Split on whitespace while keeping double-quoted phrases intact.
  static List<String> _tokenize(String raw) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && char == ' ') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(char);
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  static (String, String)? _splitKeyValue(String token) {
    final index = token.indexOf(':');
    if (index <= 0 || index == token.length - 1) return null;
    return (token.substring(0, index), token.substring(index + 1));
  }

  static bool _parseBool(String value) {
    final v = value.trim().toLowerCase();
    return v == 'true' || v == '1' || v == 'yes' || v == 'on';
  }

  static (int, int)? _parseYearRange(String value) {
    final parts = value.split('-');
    if (parts.length == 1) {
      final year = int.tryParse(parts[0].trim());
      return year == null ? null : (year, year);
    }
    if (parts.length == 2) {
      final a = int.tryParse(parts[0].trim());
      final b = int.tryParse(parts[1].trim());
      if (a == null || b == null) return null;
      return a < b ? (a, b) : (b, a);
    }
    return null;
  }
}

/// Grouped search results, one bucket per content type.
class SearchResults {
  const SearchResults({
    this.artists = const [],
    this.albums = const [],
    this.tracks = const [],
    this.playlists = const [],
    this.genres = const [],
  });

  final List<BaseItemDto> artists;
  final List<BaseItemDto> albums;
  final List<BaseItemDto> tracks;
  final List<BaseItemDto> playlists;
  final List<BaseItemDto> genres;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && tracks.isEmpty && playlists.isEmpty && genres.isEmpty;

  int get totalCount => artists.length + albums.length + tracks.length + playlists.length + genres.length;
}
