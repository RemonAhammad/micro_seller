// The Roboto the app bundles so iPhones and iPads draw text as Android does
// (iOS ships San Francisco): every file pubspec.yaml declares is in the
// repository with its license, the family is RobotoStatic (a bundled family
// named Roboto would replace Android's variable system Roboto), iOS names it
// and the other platforms keep the system's, and the files measure exactly
// like the Roboto the layout tests have always used.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/theme/app_fonts.dart';

import 'support/layout_harness.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('every font file pubspec.yaml declares is in the repository', () {
    final assets = RegExp(r'^\s*-\s*asset:\s*(\S+)\s*$', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m[1]!)
        .toList();
    expect(assets, [
      'assets/fonts/roboto/Roboto-Regular.ttf',
      'assets/fonts/roboto/Roboto-Medium.ttf',
      'assets/fonts/roboto/Roboto-Bold.ttf',
      'assets/fonts/roboto/Roboto-Black.ttf',
    ]);
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
    expect(
      RegExp(r'^\s*weight:\s*(\d+)\s*$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => int.parse(m[1]!)),
      [400, 500, 700, 900],
    );
  });

  test('the family is RobotoStatic, never Roboto', () {
    final families = RegExp(r'^\s*-\s*family:\s*(\S+)\s*$', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m[1])
        .toList();
    expect(families, [kBundledRobotoFamily]);
    expect(kBundledRobotoFamily, 'RobotoStatic');
    expect(kSystemRobotoFamily, 'Roboto');
  });

  test('the license ships beside the fonts', () {
    final license = File('assets/fonts/roboto/Roboto_LICENSE.txt');
    expect(license.existsSync(), isTrue);
    expect(license.readAsStringSync(), contains('Apache License'));
  });

  testWidgets('the app bundles the family', (tester) async {
    final manifest = await tester.runAsync(
      () => rootBundle.loadString('FontManifest.json'),
    );
    final family = (jsonDecode(manifest!) as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((f) => f['family'] == kBundledRobotoFamily);
    expect(
      [for (final font in family['fonts'] as List) font['asset']],
      [
        'assets/fonts/roboto/Roboto-Regular.ttf',
        'assets/fonts/roboto/Roboto-Medium.ttf',
        'assets/fonts/roboto/Roboto-Bold.ttf',
        'assets/fonts/roboto/Roboto-Black.ttf',
      ],
    );
  });

  test('iOS draws the bundled Roboto, the rest the system Roboto', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        appFontFamily,
        platform == TargetPlatform.iOS ? 'RobotoStatic' : 'Roboto',
        reason: platform.name,
      );
    }
  });

  group('measured', () {
    setUpAll(loadRoboto);

    testWidgets('the layout tests load the repository files', (tester) async {
      requireRoboto();
      expect(robotoSource, 'assets/fonts/roboto');
    });

    testWidgets('RobotoStatic measures exactly like Roboto, at every weight',
        (tester) async {
      requireRoboto();
      const text = 'Micro Seller 1,234,567.89 — Wgjy ÀÉÎõü ĞŞİ ạệ';
      double width(String family, FontWeight weight) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
                fontFamily: family, fontWeight: weight, fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        addTearDown(painter.dispose);
        return painter.width;
      }

      final widths = <double>{};
      for (final weight in FontWeight.values) {
        final roboto = width('Roboto', weight);
        expect(width('RobotoStatic', weight), roboto, reason: '$weight');
        widths.add(roboto);
      }
      // Real glyphs, not the test font's squares, in four weights.
      expect(widths, hasLength(4));
      expect(width('RobotoStatic', FontWeight.w400),
          lessThan(text.length * 14 * 0.7));
    });
  });
}
