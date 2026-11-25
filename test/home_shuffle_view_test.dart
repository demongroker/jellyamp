import 'package:finamp/components/HomeScreen/home_shuffle_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('builds: search bar, SHUFFLE ALL and library chips render',
      (tester) async {
    await tester.pumpWidget(_wrap(HomeShuffleView(
      libraries: const ['Music', 'Karaoke'],
      onSearch: () {},
      onShuffleAll: () {},
      onShuffleLibrary: (_) {},
      onBrowse: () {},
    )));

    expect(find.text('Search songs, artists, albums'), findsOneWidget);
    expect(find.text('SHUFFLE ALL'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Karaoke'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(2));
  });

  testWidgets('Shuffle All fires its callback exactly once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(HomeShuffleView(
      libraries: const [],
      onShuffleAll: () => taps++,
    )));

    await tester.tap(find.text('SHUFFLE ALL'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('library chips fire onShuffleLibrary with their name',
      (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(_wrap(HomeShuffleView(
      libraries: const ['Music', 'Karaoke'],
      onShuffleLibrary: seen.add,
    )));

    await tester.tap(find.text('Music'));
    await tester.pump();
    await tester.tap(find.text('Karaoke'));
    await tester.pump();
    expect(seen, ['Music', 'Karaoke']);
  });

  testWidgets('search bar fires onSearch', (tester) async {
    var searched = 0;
    await tester.pumpWidget(_wrap(HomeShuffleView(
      libraries: const [],
      onSearch: () => searched++,
    )));

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    expect(searched, 1);
  });

  group('now playing card', () {
    const data = NowPlaying(
      title: 'Midnight City',
      artist: 'M83',
      isPlaying: true,
      position: Duration(seconds: 30),
      duration: Duration(minutes: 4),
    );

    testWidgets('hidden when nowPlaying is null', (tester) async {
      await tester.pumpWidget(_wrap(HomeShuffleView(libraries: const [])));
      expect(find.text('Midnight City'), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('shows title, artist, progress and pause icon',
        (tester) async {
      await tester.pumpWidget(_wrap(HomeShuffleView(
        libraries: const [],
        nowPlaying: data,
      )));
      await tester.pump();

      expect(find.text('Midnight City'), findsOneWidget);
      expect(find.text('M83'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('play/pause fires onTogglePlayPause', (tester) async {
      var toggles = 0;
      await tester.pumpWidget(_wrap(HomeShuffleView(
        libraries: const [],
        nowPlaying: data,
        onTogglePlayPause: () => toggles++,
      )));

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(toggles, 1);
    });

    testWidgets('tapping the card fires onNowPlayingTap', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_wrap(HomeShuffleView(
        libraries: const [],
        nowPlaying: data,
        onNowPlayingTap: () => opened++,
      )));

      await tester.tap(find.text('Midnight City'));
      await tester.pump();
      expect(opened, 1);
    });
  });

  testWidgets('homepage golden', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 420,
      child: HomeShuffleView(
        libraries: const ['Music', 'Karaoke'],
        onSearch: () {},
        onShuffleAll: () {},
        onShuffleLibrary: (_) {},
        onBrowse: () {},
        nowPlaying: const NowPlaying(
          title: 'Midnight City',
          artist: 'M83',
          isPlaying: true,
          position: Duration(seconds: 30),
          duration: Duration(minutes: 4),
        ),
      ),
    )));
    await expectLater(
      find.byType(HomeShuffleView),
      matchesGoldenFile('home_shuffle_view.png'),
    );
  });
}
