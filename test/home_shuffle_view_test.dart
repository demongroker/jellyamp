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

  testWidgets('shows a now-playing card when a track is set', (tester) async {
    await tester.pumpWidget(_wrap(HomeShuffleView(
      libraries: const [],
      nowPlayingTitle: 'Midnight City',
      nowPlayingArtist: 'M83',
    )));

    expect(find.text('Midnight City'), findsOneWidget);
    expect(find.text('M83'), findsOneWidget);
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
        nowPlayingTitle: 'Midnight City',
        nowPlayingArtist: 'M83',
      ),
    )));
    await expectLater(
      find.byType(HomeShuffleView),
      matchesGoldenFile('home_shuffle_view.png'),
    );
  });
}
