// The forms a scanned code is looked up in. iOS (Apple Vision) reports a
// 12-digit UPC-A barcode as the 13-digit EAN-13 with a leading 0, Android
// (ML Kit) as the 12 digits; a lookup asks for both, so a product saved
// from one phone's scan is found by the other's.
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/utils/barcode.dart';

void main() {
  test('a UPC-A is looked up as both 12 and 13 digits', () {
    // Android's reading of a UPC-A, and iOS's.
    expect(barcodeLookupForms('036000291452'), [
      '036000291452',
      '0036000291452',
    ]);
    expect(barcodeLookupForms('0036000291452'), [
      '0036000291452',
      '036000291452',
    ]);
    expect(barcodeLookupForms('123456789012'), [
      '123456789012',
      '0123456789012',
    ]);
  });

  test('other codes are looked up as scanned', () {
    // An EAN-13 that isn't a UPC-A: its first digit isn't 0.
    expect(barcodeLookupForms('5901234123457'), ['5901234123457']);
    // EAN-8, UPC-E, a GTIN-14.
    expect(barcodeLookupForms('96385074'), ['96385074']);
    expect(barcodeLookupForms('01234565'), ['01234565']);
    expect(barcodeLookupForms('00036000291452'), ['00036000291452']);
    // Letters: a SKU or a QR code's text.
    expect(barcodeLookupForms('ABC-123'), ['ABC-123']);
    expect(barcodeLookupForms('A36000291452'), ['A36000291452']);
    expect(barcodeLookupForms('https://example.com/p/12'), [
      'https://example.com/p/12',
    ]);
  });

  test('whitespace around a code is trimmed', () {
    expect(barcodeLookupForms(' 036000291452\n'), [
      '036000291452',
      '0036000291452',
    ]);
    expect(barcodeLookupForms('\tabc-1 '), ['abc-1']);
    // Inside a code it stays: that is another code.
    expect(barcodeLookupForms('0360 00291452'), ['0360 00291452']);
  });

  test('a blank code has no forms', () {
    expect(barcodeLookupForms(''), isEmpty);
    expect(barcodeLookupForms('   \n'), isEmpty);
  });
}
