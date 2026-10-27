import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards two iPad fixes, so a new screen can't bring the old behaviour
/// back:
///
/// - **Share sheets open from the control that was tapped.** On an iPad the
///   share sheet is a popover that must point at something; share_plus
///   takes the rect as `sharePositionOrigin` (`shareOriginOf(context)`,
///   lib/core/utils/share_origin.dart), and the printing package's share as
///   `bounds`. Without one, iPadOS has nothing to anchor the popover to. The
///   app's share helpers (reminders, statements, CSV exports, the backup,
///   the PDF save fallback) take it as `shareOrigin`, so every call of one
///   passes it too.
/// - **Calls go through `callPhone`** (lib/shared/widgets/call_phone.dart).
///   An iPad (or an iPod, or an Android tablet without a phone) can't call:
///   iOS answers false and Android throws, and `callPhone` shows the number
///   with Copy number instead. A `tel:` link launched anywhere else does
///   nothing on those devices.

/// The calls that open a share sheet, with the argument that anchors it on
/// an iPad.
const _shareCalls = {
  r'SharePlus\.instance\.share': 'sharePositionOrigin',
  // share_plus' deprecated static API.
  r'\bShare\.(share|shareXFiles|shareUri)': 'sharePositionOrigin',
  r'\bPrinting\.sharePdf': 'bounds',
};

/// The app's own share helpers. Each takes the anchor as an optional
/// `shareOrigin` and passes it on as `sharePositionOrigin`, so each call
/// must give one: one that doesn't opens the sheet with no anchor.
const _shareHelpers = [
  'sendDueReminder',
  'shareCustomerStatement',
  'exportOrders',
  'exportProducts',
  'exportExpenses',
  'exportReport',
  'exportBackup',
  'savePdfWithSystemSheet',
];

/// The end of a line that declares a function, before its name.
final _declaration = RegExp(r'(Future<[^;=]*>|\bvoid)\s+$');

/// A `tel:` link: the scheme in a string, or given to `Uri(scheme:)`.
final _tel = RegExp(r'''['"]tel:|scheme:\s*['"]tel['"]''');

/// The one file that may build a `tel:` link.
const _callPhone = 'lib/shared/widgets/call_phone.dart';

/// Every hand-written Dart file in lib/, as (path, text), by path.
List<(String, String)> _sources() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .map((f) => (f.path.replaceAll(r'\', '/'), f))
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (path, file) in files) (path, file.readAsStringSync())];
}

/// [text] with its comment lines (`//` and `///`) blanked, line numbers kept.
String _code(String text) => text
    .split('\n')
    .map((line) => line.trimLeft().startsWith('//') ? '' : line)
    .join('\n');

/// The 1-based line of [offset] in [text].
int _lineOf(String text, int offset) =>
    '\n'.allMatches(text.substring(0, offset)).length + 1;

/// The argument list of the call whose `(` is at [open] in [code], without
/// the parentheses, or null if it isn't closed. Parentheses inside string
/// literals don't count.
String? _arguments(String code, int open) {
  var depth = 0;
  String? quote;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '(') {
      depth++;
    } else if (c == ')' && --depth == 0) {
      return code.substring(open + 1, i);
    }
  }
  return null;
}

/// Each share call in [text], as (line, the anchor it must pass, its
/// arguments).
List<(int, String, String?)> _shares(String text) {
  final code = _code(text);
  return [
    for (final MapEntry(key: call, value: anchor) in _shareCalls.entries)
      for (final m in RegExp('$call\\s*\\(').allMatches(code))
        (_lineOf(code, m.start), anchor, _arguments(code, m.end - 1)),
  ];
}

/// Whether [arguments] pass [anchor], set to something other than null.
bool _anchored(String arguments, String anchor) =>
    RegExp('\\b$anchor\\s*:\\s*(?!null\\b)\\S').hasMatch(arguments);

/// Each share call in [text] that opens without an anchor, as `path:line`.
List<String> _unanchored(String path, String text) => [
  for (final (line, anchor, arguments) in _shares(text))
    if (arguments == null || !_anchored(arguments, anchor))
      '$path:$line: no $anchor',
];

/// Each call of a share helper in [text], as (line, its arguments). Their
/// declarations don't count.
List<(int, String?)> _helperCalls(String text) {
  final code = _code(text);
  return [
    for (final name in _shareHelpers)
      for (final m in RegExp('\\b$name\\s*\\(').allMatches(code))
        if (!_declaration.hasMatch(
          code.substring(code.lastIndexOf('\n', m.start) + 1, m.start),
        ))
          (_lineOf(code, m.start), _arguments(code, m.end - 1)),
  ];
}

/// Each call of a share helper in [text] that gives no anchor, as
/// `path:line`.
List<String> _helpersUnanchored(String path, String text) => [
  for (final (line, arguments) in _helperCalls(text))
    if (arguments == null || !_anchored(arguments, 'shareOrigin'))
      '$path:$line: no shareOrigin',
];

/// Each `tel:` link in [text], as `path:line`.
List<String> _telLinks(String path, String text) {
  final code = _code(text);
  return [
    for (final m in _tel.allMatches(code)) '$path:${_lineOf(code, m.start)}',
  ];
}

void main() {
  setUpAll(() {
    expect(
      Directory('lib').existsSync(),
      isTrue,
      reason: 'run the tests from the package root',
    );
  });

  test('the guards find what they look for', () {
    // Not vacuous: the checks catch the code they guard against and pass
    // what replaced it.
    const unanchored = '''
    await SharePlus.instance.share(ShareParams(text: text));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], sharePositionOrigin: null),
    );
    await Share.share(text);
    await Printing.sharePdf(bytes: bytes, filename: 'a (1).pdf');
''';
    const anchored = r'''
    await SharePlus.instance.share(ShareParams(
      text: 'Due (${count})',
      sharePositionOrigin: shareOriginOf(context),
    ));
    await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin));
    await Printing.sharePdf(bytes: bytes, bounds: origin);
    // await SharePlus.instance.share(ShareParams(text: text));
''';
    expect(_unanchored('a', unanchored), [
      'a:1: no sharePositionOrigin',
      'a:2: no sharePositionOrigin',
      'a:5: no sharePositionOrigin',
      'a:6: no bounds',
    ]);
    expect(_shares(anchored), hasLength(3));
    expect(_unanchored('a', anchored), isEmpty);

    const helpers = '''
Future<void> sendDueReminder(BuildContext context, {Rect? shareOrigin}) async {
  await CsvExportService().exportOrders(orders);
  await CsvExportService().exportOrders(orders, shareOrigin: null);
  onPressed: () => sendDueReminder(context, ref, customer, dues, total,
      shareOrigin: shareOriginOf(buttonContext)),
  await savePdfWithSystemSheet(
    fileName: name,
    bytes: bytes,
    shareOrigin: origin,
  );
''';
    expect(_helperCalls(helpers), hasLength(4));
    expect(_helpersUnanchored('a', helpers), [
      'a:2: no shareOrigin',
      'a:3: no shareOrigin',
    ]);

    const calls = r'''
    await launchUrl(Uri.parse('tel:$phone'));
    await launchUrl(Uri(scheme: 'tel', path: phone));
    await launchUrlString("tel:$phone");
''';
    expect(_telLinks('a', calls), ['a:1', 'a:2', 'a:3']);
    expect(
      _telLinks('a', "  // a `tel:` link\n  final hotel = 'Hotel: 1';\n"),
      isEmpty,
    );
    expect(
      _telLinks(_callPhone, File(_callPhone).readAsStringSync()),
      isNotEmpty,
      reason: 'callPhone builds its tel: link',
    );
  });

  test('every share sheet opens from the control that was tapped', () {
    final sources = _sources();
    final shares = [for (final (_, text) in sources) ..._shares(text)];
    expect(shares, isNotEmpty, reason: 'the app shares invoices and reports');
    final hits = [
      for (final (path, text) in sources) ..._unanchored(path, text),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'On an iPad the share sheet points at a rect. Pass '
          'sharePositionOrigin: shareOriginOf(buttonContext) '
          '(lib/core/utils/share_origin.dart), read from the tapped '
          "control's context (a Builder around it, or a GlobalKey).\n"
          '${hits.join('\n')}',
    );
  });

  test("every call of the app's share helpers gives the tapped control", () {
    final sources = _sources();
    expect(
      [for (final (_, text) in sources) ..._helperCalls(text)],
      isNotEmpty,
      reason: 'the screens call the share helpers',
    );
    final hits = [
      for (final (path, text) in sources) ..._helpersUnanchored(path, text),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'Pass shareOrigin: shareOriginOf(buttonContext) '
          '(lib/core/utils/share_origin.dart), read from the tapped '
          "control's context (a Builder around it, or a GlobalKey). Without "
          "it the helper's share sheet has nothing to point at on an iPad.\n"
          "${hits.join('\n')}",
    );
  });

  test('only callPhone builds a tel: link', () {
    final hits = [
      for (final (path, text) in _sources())
        if (path != _callPhone) ..._telLinks(path, text),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'Call with callPhone(context, phone) '
          '(lib/shared/widgets/call_phone.dart): it offers Copy number where '
          'the device cannot call.\n'
          '${hits.join('\n')}',
    );
  });
}
