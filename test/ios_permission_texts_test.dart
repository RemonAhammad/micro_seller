// iOS permission prompts (camera, photo library, Face ID) in every app
// language. iOS shows the texts in ios/Runner/Info.plist, which are English
// (the development language), and a language's own from
// ios/Runner/<lang>.lproj/InfoPlist.strings when the app declares the language
// in CFBundleLocalizations. Each strings file must also be in the Xcode
// project, or the build doesn't copy it into the app.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';

/// The permission texts (`NS…UsageDescription`) in Info.plist [source].
Map<String, String> _usageDescriptions(String source) => {
  for (final m in RegExp(
    r'<key>(NS\w+UsageDescription)</key>\s*<string>([^<]*)</string>',
  ).allMatches(source))
    m.group(1)!: m.group(2)!,
};

/// The `"key" = "value";` lines of a .strings file.
Map<String, String> _strings(String source) => {
  for (final m in RegExp(
    r'^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$',
    multiLine: true,
  ).allMatches(source))
    m.group(1)!: m.group(2)!,
};

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final english = _usageDescriptions(plist);
  final languages = [
    for (final m in RegExp(r'<string>([^<]*)</string>').allMatches(
      RegExp(
        r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist)!.group(1)!,
    ))
      m.group(1)!.trim(),
  ];
  // English is Info.plist's own.
  final translated = [
    for (final l in languages)
      if (l != 'en') l,
  ];

  test('Info.plist declares the app languages', () {
    expect(languages, [
      for (final l in AppLocalizations.supportedLocales) l.languageCode,
    ]);
  });

  test('Info.plist has every permission text, in English', () {
    expect(
      english.keys,
      unorderedEquals([
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSPhotoLibraryAddUsageDescription',
        'NSFaceIDUsageDescription',
      ]),
    );
    for (final MapEntry(:key, :value) in english.entries) {
      expect(value.trim(), isNotEmpty, reason: key);
    }
  });

  test('every other app language has every permission text in its own '
      'words', () {
    for (final lang in translated) {
      final file = File('ios/Runner/$lang.lproj/InfoPlist.strings');
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
      final texts = _strings(file.readAsStringSync());
      expect(texts.keys, unorderedEquals(english.keys), reason: lang);
      for (final MapEntry(:key, :value) in texts.entries) {
        expect(value.trim(), isNotEmpty, reason: '$lang: $key');
        expect(value, isNot(english[key]), reason: '$lang: $key');
      }
    }
  });

  test('the Xcode project copies every strings file into the app', () {
    // InfoPlist.strings: one file per language ...
    final group = RegExp(
      r'(\w{24}) /\* InfoPlist\.strings \*/ = \{\s*'
      r'isa = PBXVariantGroup;\s*children = \((.*?)\);',
      dotAll: true,
    ).firstMatch(project);
    expect(group, isNotNull, reason: 'no InfoPlist.strings variant group');
    final groupId = group!.group(1)!;
    final children = [
      for (final m in RegExp(
        r'(\w{24}) /\* ([\w-]+) \*/',
      ).allMatches(group.group(2)!))
        (id: m.group(1)!, lang: m.group(2)!),
    ];
    expect([for (final c in children) c.lang], unorderedEquals(translated));
    for (final (:id, :lang) in children) {
      expect(
        project,
        contains(
          '$id /* $lang */ = {isa = PBXFileReference; '
          'lastKnownFileType = text.plist.strings; name = $lang; '
          'path = $lang.lproj/InfoPlist.strings; sourceTree = "<group>"; };',
        ),
        reason: lang,
      );
    }

    // ... in the Runner target's resources ...
    final buildFile = RegExp(
      r'(\w{24}) /\* InfoPlist\.strings in Resources \*/ = '
      r'\{isa = PBXBuildFile; fileRef = '
      '$groupId ',
    ).firstMatch(project);
    expect(buildFile, isNotNull, reason: 'InfoPlist.strings is not built');
    final runnerPhases = RegExp(
      r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;.*?'
      r'buildPhases = \((.*?)\);',
      dotAll: true,
    ).firstMatch(project)!.group(1)!;
    final resourcesPhase = RegExp(
      r'(\w{24}) /\* Resources \*/',
    ).firstMatch(runnerPhases)!.group(1)!;
    final resources = RegExp(
      '$resourcesPhase ${RegExp.escape('/* Resources */')} = '
      r'\{\s*isa = PBXResourcesBuildPhase;.*?files = \((.*?)\);',
      dotAll: true,
    ).firstMatch(project)!.group(1)!;
    expect(resources, contains(buildFile!.group(1)));

    // ... and every app language is one the project knows.
    final regions = RegExp(
      r'knownRegions = \((.*?)\);',
      dotAll: true,
    ).firstMatch(project)!.group(1)!;
    expect([
      for (final r in regions.split(',')) r.trim(),
    ], containsAll(languages));
  });
}
