import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-app logo matches the teal-green launcher equalizer', () {
    final svg = File('images/jellyamp_icon.svg').readAsStringSync();
    expect(svg, contains('#0F766E'));
    expect(svg, contains('#22C55E'));
    expect(svg, isNot(contains('#0EA5E9')));
    expect(RegExp(r'<rect ').allMatches(svg).length, 4);
    expect(svg, contains('clip-path="url(#launcherMask)"'));
  });
}
