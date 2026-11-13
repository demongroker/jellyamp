// Regression tests for the duplicate-artist / duplicate-album fold.
//
// The complaint this locks down: searching "skid row" listed two artists (one
// with artwork, one with a plain disc) and two albums with the same title that
// could not be told apart. LibraryMerge is pure, so these run as plain VM tests.
//
// Run:  flutter test benchmark/regression_library_merge_test.dart
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/library_merge.dart';
import 'package:flutter_test/flutter_test.dart';

BaseItemDto artist(String id, String name, {bool withImage = false, int? tracks}) => BaseItemDto(
  id: BaseItemId(id),
  name: name,
  type: 'MusicArtist',
  childCount: tracks,
  imageTags: withImage ? {'Primary': 'tag-$id'} : null,
);

BaseItemDto album(
  String id,
  String name, {
  String? artistName,
  int? year,
  int? tracks,
  bool withImage = false,
}) => BaseItemDto(
  id: BaseItemId(id),
  name: name,
  type: 'MusicAlbum',
  productionYear: year,
  childCount: tracks,
  imageTags: withImage ? {'Primary': 'tag-$id'} : null,
  albumArtists: artistName == null ? null : [NameIdPair(name: artistName, id: BaseItemId('artist-$id'))],
);

Set<String> titles(List<String> raw) => raw.map(LibraryMerge.normalize).toSet();

void main() {
  group('normalize', () {
    test('folds case, spacing, punctuation, a leading "The " and &/and', () {
      expect(LibraryMerge.normalize('Skid Row'), LibraryMerge.normalize('skid  row'));
      expect(LibraryMerge.normalize('SKID-ROW'), LibraryMerge.normalize('Skid Row'));
      expect(LibraryMerge.normalize('The Skid Row'), LibraryMerge.normalize('Skid Row'));
      expect(LibraryMerge.normalize('Simon & Garfunkel'), LibraryMerge.normalize('Simon and Garfunkel'));
      expect(LibraryMerge.normalize('  '), isEmpty);
      expect(LibraryMerge.normalize(null), isEmpty);
    });
  });

  group('artists', () {
    test('same artist with different case and spacing merges into one row', () {
      final merged = LibraryMerge.mergeArtists([
        artist('a1', 'Skid Row'),
        artist('a2', 'skid  row'),
        artist('a3', 'Other Band'),
      ]);

      expect(merged, hasLength(2));
      final skid = merged.firstWhere((e) => LibraryMerge.normalize(e.artist.name) == 'skid row');
      expect(skid.mergedIds, unorderedEquals(['a1', 'a2']));
      expect(skid.isMerged, isTrue);
    });

    test('the version with artwork becomes the row the user sees', () {
      final merged = LibraryMerge.mergeArtists([
        artist('no-image', 'Skid Row'),
        artist('with-image', 'The Skid Row', withImage: true),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.artist.id.raw, 'with-image');
      expect(merged.single.artist.imageId, isNotNull);
      expect(merged.single.mergedIds, unorderedEquals(['no-image', 'with-image']));
    });

    test('a nameless artist is never merged into another nameless one', () {
      final merged = LibraryMerge.mergeArtists([artist('n1', ''), artist('n2', '   ')]);
      expect(merged, isEmpty);
    });
  });

  group('albums', () {
    test('same album with mostly overlapping tracks merges into one row', () {
      final albums = [
        album('srv', 'Skid Row', artistName: 'Skid Row', year: 1989, tracks: 11),
        album('loc', 'skid row', artistName: 'SKID ROW', year: 1989, tracks: 11),
      ];
      final tracks = {
        'srv': titles(['Big Guns', 'Sweet Little Sister', 'Can\'t Stand the Heartache', 'Piece of Me']),
        'loc': titles(['Big Guns', 'Sweet Little Sister', "Can't Stand the Heartache", 'Piece of Me']),
      };

      final merged = LibraryMerge.mergeAlbums(albums, trackTitlesByAlbumId: tracks);

      expect(merged, hasLength(1), reason: 'identical track lists are the same album');
      expect(merged.single.mergedIds, unorderedEquals(['srv', 'loc']));
      expect(merged.single.disambiguator, isNull, reason: 'nothing to disambiguate');
    });

    test('same name with different tracks stays separate and is labelled', () {
      final albums = [
        album('local1989', 'Skid Row', artistName: 'Skid Row', year: 1989, tracks: 11),
        album('server2008', 'Skid Row', artistName: 'Skid Row', year: 2008, tracks: 4),
      ];
      final tracks = {
        'local1989': titles(['Big Guns', 'Sweet Little Sister', 'Piece of Me', 'Rattlesnake Shake']),
        'server2008': titles(['Youth Gone Wild', '18 and Life', 'I Remember You', 'Psycho Therapy']),
      };

      final merged = LibraryMerge.mergeAlbums(
        albums,
        trackTitlesByAlbumId: tracks,
        isOnDevice: (a) => a.id.raw == 'local1989',
      );

      expect(merged, hasLength(2), reason: 'a 4-track 2008 release is not the 1989 album');
      final local = merged.firstWhere((e) => e.album.id.raw == 'local1989');
      final server = merged.firstWhere((e) => e.album.id.raw == 'server2008');
      expect(local.disambiguator, allOf(contains('1989'), contains('11 tracks'), contains('On device')));
      expect(server.disambiguator, allOf(contains('2008'), contains('4 tracks'), contains('Server')));
    });

    test('one shared track out of many does not merge two releases', () {
      final albums = [
        album('a', 'Greatest Hits', artistName: 'Skid Row', year: 1998, tracks: 12),
        album('b', 'Greatest Hits', artistName: 'Skid Row', year: 2014, tracks: 12),
      ];
      final tracks = {
        'a': titles(['18 and Life', 'a1', 'a2', 'a3', 'a4', 'a5']),
        'b': titles(['18 and Life', 'b1', 'b2', 'b3', 'b4', 'b5']),
      };

      final merged = LibraryMerge.mergeAlbums(albums, trackTitlesByAlbumId: tracks);

      expect(merged, hasLength(2));
      expect(merged.every((e) => e.disambiguator != null), isTrue);
    });

    test('albums with no track data are never merged on guesswork', () {
      final albums = [
        album('x', 'Skid Row', artistName: 'Skid Row', tracks: 10),
        album('y', 'Skid Row', artistName: 'Skid Row', tracks: 10),
      ];

      final merged = LibraryMerge.mergeAlbums(albums);

      expect(merged, hasLength(2), reason: '"cannot tell" must not collapse rows');
      expect(merged.every((e) => e.disambiguator != null), isTrue);
    });

    test('the same title under different artists is never merged', () {
      final albums = [
        album('one', 'Gold', artistName: 'Skid Row', tracks: 5),
        album('two', 'Gold', artistName: 'Another Band', tracks: 5),
      ];
      final tracks = {
        'one': titles(['Gold 1', 'Gold 2']),
        'two': titles(['Gold 1', 'Gold 2']),
      };

      final merged = LibraryMerge.mergeAlbums(albums, trackTitlesByAlbumId: tracks);

      expect(merged, hasLength(2));
      expect(merged.every((e) => e.disambiguator != null), isTrue, reason: 'same title, two rows: label them');
    });
  });
}
