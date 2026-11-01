
final _upcA = RegExp(r'^\d{12}$');

final _upcAAsEan13 = RegExp(r'^0\d{12}$');

List<String> barcodeLookupForms(String raw) {
  final code = raw.trim();
  if (code.isEmpty) return const [];
  if (_upcAAsEan13.hasMatch(code)) return [code, code.substring(1)];
  if (_upcA.hasMatch(code)) return [code, '0$code'];
  return [code];
}
