/// A UPC-A barcode: 12 digits, as Android (ML Kit) reports one.
final _upcA = RegExp(r'^\d{12}$');

/// The same barcode as an EAN-13 with a leading 0, as iOS (Apple Vision)
/// reports a UPC-A.
final _upcAAsEan13 = RegExp(r'^0\d{12}$');

/// The forms a scanned [raw] code is looked up in: the code trimmed, and for
/// a UPC-A its other spelling. iOS reads a 12-digit UPC-A as the 13-digit
/// EAN-13 `0` + 12 digits, Android as the 12 digits, so a product saved from
/// one scan is found by the other phone's scan only when both are asked for.
/// Empty for a blank code.
List<String> barcodeLookupForms(String raw) {
  final code = raw.trim();
  if (code.isEmpty) return const [];
  if (_upcAAsEan13.hasMatch(code)) return [code, code.substring(1)];
  if (_upcA.hasMatch(code)) return [code, '0$code'];
  return [code];
}
