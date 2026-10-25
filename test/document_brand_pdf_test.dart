import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/theme/app_color_theme.dart';
import 'package:micro_seller/core/theme/document_brand.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/services/catalog_service.dart';
import 'package:micro_seller/data/services/pdf_service.dart';
import 'package:micro_seller/data/services/report_pdf_service.dart';
import 'package:micro_seller/data/services/report_service.dart';
import 'package:micro_seller/data/services/statement_service.dart';

/// The documents' color before color themes, and still the default.
const _teal = Color(0xFF00897B);

/// A light theme color: black text reads on it (12.9:1), white doesn't
/// (1.6:1).
const _amber = Color(0xFFFFC107);

const _shopName = 'Rahim Store';
const _sym = '৳';

/// Documents follow the app's color theme ([DocumentBrand]): headers and
/// accents in its color, the text on a header in its White or Black text
/// color, and brand-colored text on the white page in a shade of it that
/// reads there. The "Powered by Micro Seller" watermark stays teal.
void main() {
  tearDown(DocumentBrand.reset);

  test('the light theme color used below takes black text', () {
    expect(recommendedOnColor(_amber), OnColor.black);
    expect(readability(_amber, OnColor.black), Readability.easy);
    expect(readability(_amber, OnColor.white), Readability.hard);
    expect(kPdfWatermarkColor, _teal);
  });

  test('until a theme is set, documents are teal with white on it', () {
    expect(DocumentBrand.color, _teal);
    expect(DocumentBrand.onColor, Colors.white);
    expect(DocumentBrand.textColor, _teal);
  });

  group('brand-colored text on the white page', () {
    test("reads at least as well as teal's always did", () {
      expect(DocumentBrand.minTextContrast, closeTo(4.32, 0.01));
      expect(
        DocumentBrand.minTextContrast,
        contrastRatio(_teal, Colors.white),
      );
      // Teal, and any color that reads as well, is used as it is.
      for (final color in const [
        _teal,
        Color(0xFF1976D2),
        Color(0xFF000080),
        Color(0xFF000000),
      ]) {
        DocumentBrand.set(color);
        expect(DocumentBrand.textColor, color, reason: _hex(color));
      }
    });

    test('a light theme color is darkened until it reads, no further', () {
      for (final color in const [_amber, Color(0xFFFFEB3B), Colors.white]) {
        final where = _hex(color);
        DocumentBrand.set(color, onColor: Colors.black);
        final text = DocumentBrand.textColor;
        expect(contrastRatio(color, Colors.white), lessThan(2), reason: where);
        expect(
          contrastRatio(text, Colors.white),
          greaterThanOrEqualTo(DocumentBrand.minTextContrast),
          reason: where,
        );
        expect(
          contrastRatio(text, Colors.white),
          lessThan(DocumentBrand.minTextContrast + 0.1),
          reason: '$where: no darker than it takes',
        );
        // Mixed toward black: the same hue, darker.
        expect(
          HSVColor.fromColor(text).hue,
          closeTo(HSVColor.fromColor(color).hue, 2),
          reason: where,
        );
        // Header bands keep the theme color and its text color.
        expect(DocumentBrand.color, color, reason: where);
        expect(DocumentBrand.onColor, Colors.black, reason: where);
      }
    });
  });

  group('receipt', () {
    final order = Order(
      id: 7,
      orderNumber: 'ORD-007',
      customerName: 'Karim',
      items: [
        OrderItem(productName: 'Tea', qty: 2, unitPrice: 50, totalPrice: 100),
      ],
      subtotal: 100,
      totalAmount: 100,
      amountPaid: 100,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime(2026, 10, 25),
    );

    Future<Finder> pumpReceipt(WidgetTester tester) async {
      await _pumpPage(
        tester,
        PdfService.receiptPage(
          order,
          shopName: _shopName,
          sym: _sym,
          taxRate: 0,
        ),
        const Size(794, 1400),
      );
      return _boxAround(find.text(_shopName));
    }

    testWidgets('the header is the theme color, its text the chosen color', (
      tester,
    ) async {
      DocumentBrand.set(_amber, onColor: OnColor.black.color);
      final header = await pumpReceipt(tester);

      expect(_boxColor(tester, header), _amber);
      _expectTextColors(tester, header, Colors.black, count: 4);
      expect(_textColor(tester, find.text('Micro Seller')), _teal);
    });

    testWidgets("by default it's today's teal header with white text", (
      tester,
    ) async {
      final header = await pumpReceipt(tester);

      expect(_boxColor(tester, header), _teal);
      _expectTextColors(tester, header, Colors.white, count: 4);
      expect(_textColor(tester, find.text('Micro Seller')), _teal);
    });
  });

  testWidgets(
    "a statement's table header is the theme color; its shop name and "
    'credits a shade of it that reads on white',
    (tester) async {
      DocumentBrand.set(_amber, onColor: OnColor.black.color);
      final text = DocumentBrand.textColor;
      expect(text, isNot(_amber));
      await _pumpPage(
        tester,
        StatementService.statementPage(
          customer: Customer(name: 'Karim'),
          rows: [
            StatementRow(
              date: DateTime(2026, 10, 1),
              reference: 'ORD-007',
              debit: 150,
              balance: 150,
            ),
            StatementRow(
              date: DateTime(2026, 10, 2),
              reference: 'Payment · ORD-007',
              credit: 40,
              balance: 110,
            ),
          ],
          labels: StatementLabels(
            title: 'Statement',
            date: 'Date',
            reference: 'Reference',
            debit: 'Debit',
            credit: 'Credit',
            balance: 'Balance',
            closingBalance: 'Closing balance',
            payment: 'Payment',
            refund: 'Refund',
            generatedOn: (date) => 'Generated $date',
            pageOf: (page, total) => 'Page $page of $total',
          ),
          shopName: _shopName,
          shopPhone: '',
          sym: _sym,
          closing: 110,
          pageIndex: 0,
          pageCount: 1,
          textDirection: TextDirection.ltr,
        ),
        const Size(794, 1123),
      );

      expect(_textColor(tester, find.text(_shopName)), text);
      final tableHeader = _boxAround(find.text('Reference'));
      expect(_boxColor(tester, tableHeader), _amber);
      _expectTextColors(tester, tableHeader, Colors.black, count: 5);
      expect(
        _textColor(
          tester,
          find.text(CurrencyFormatter.format(40, symbol: _sym)),
        ),
        text,
      );
      expect(_textColor(tester, find.text('Micro Seller')), _teal);
    },
  );

  testWidgets(
    "a report's header rows are the theme color; its shop name and table "
    'titles a shade of it that reads on white',
    (tester) async {
      DocumentBrand.set(_amber, onColor: OnColor.black.color);
      final text = DocumentBrand.textColor;
      expect(text, isNot(_amber));
      await _pumpPage(
        tester,
        ReportPdfService.reportPage(
          shopName: _shopName,
          reportTitle: 'Profit & Sales',
          periodLabel: 'October 2026',
          tables: const [
            ReportTable(
              'Top products',
              ['Product', 'Qty'],
              [
                ['Tea', 2],
              ],
            ),
          ],
          showHeader: true,
          footer: 'Page 1 of 1',
          textDirection: TextDirection.ltr,
        ),
        const Size(794, 1123),
      );

      expect(_textColor(tester, find.text(_shopName)), text);
      expect(_textColor(tester, find.text('Top products')), text);
      final headerRow = _boxAround(find.text('Product'));
      expect(_boxColor(tester, headerRow), _amber);
      _expectTextColors(tester, headerRow, Colors.black, count: 2);
      expect(_textColor(tester, find.text('Tea')), Colors.black);
      expect(_textColor(tester, find.text('Micro Seller')), _teal);
    },
  );

  group('a captured catalog page', () {
    // Logical points on the 2× capture. The header is the page's 28 px
    // margin in, with 18 / 14 px of padding; the shop name's first glyph
    // (the test font draws each as a full 1 em square) is 22 px.
    const headerPadding = Offset(40, 34);
    const shopNameGlyph = Offset(57, 57);
    // The footer's "Micro Seller" wordmark (11 px glyphs, 12 of them, at the
    // right margin), right of the watermark icon.
    const wordmark = Rect.fromLTRB(640, 1070, 766, 1095);
    // Everything between the header and the footer: the price is the only
    // thing there in a brand color.
    const tiles = Rect.fromLTRB(0, 120, 794, 1060);

    testWidgets('draws the theme color with the chosen text color on it, '
        'and prices in a shade of it that reads on white', (tester) async {
      DocumentBrand.set(_amber, onColor: OnColor.black.color);
      final text = DocumentBrand.textColor;
      final page = (await tester.runAsync(_captureCatalog))!;

      expect(page.at(headerPadding), _amber);
      expect(page.at(shopNameGlyph), Colors.black);
      expect(
        page.count(tiles, (c) => c == text),
        greaterThan(0),
        reason: 'the price is drawn in the readable shade',
      );
      expect(
        page.count(tiles, (c) => c == _amber),
        0,
        reason: 'amber itself is all but invisible on white (1.6:1)',
      );
      // The watermark is drawn at 55% opacity on white.
      expect(
        page.count(wordmark, (c) => _near(c, _onWhite(_teal, 0.55))),
        greaterThan(0),
      );
      expect(
        page.count(wordmark, (c) => _near(c, _onWhite(_amber, 0.55))),
        0,
        reason: 'the watermark stays teal',
      );
    });

    testWidgets("by default it's today's teal with white on it", (
      tester,
    ) async {
      final page = (await tester.runAsync(_captureCatalog))!;

      expect(page.at(headerPadding), _teal);
      expect(page.at(shopNameGlyph), Colors.white);
      expect(page.count(tiles, (c) => c == _teal), greaterThan(0));
    });
  });
}

/// Pumps a document page at its capture size, under nothing but the
/// Directionality the capture gives it.
Future<void> _pumpPage(WidgetTester tester, Widget page, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: page),
  );
}

/// The nearest box around [text] that paints a color: a header's.
Finder _boxAround(Finder text) => find
    .ancestor(
      of: text,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            (widget.color != null ||
                (widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).color != null)),
      ),
    )
    .first;

Color? _boxColor(WidgetTester tester, Finder box) {
  final container = tester.widget<Container>(box);
  return container.color ?? (container.decoration! as BoxDecoration).color;
}

Color? _textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

/// Every one of the [count] texts in [box] is drawn in [color].
void _expectTextColors(
  WidgetTester tester,
  Finder box,
  Color color, {
  required int count,
}) {
  final texts = tester
      .widgetList<Text>(find.descendant(of: box, matching: find.byType(Text)))
      .toList();
  expect(texts, hasLength(count));
  for (final text in texts) {
    expect(text.style?.color, color, reason: text.data);
  }
}

/// [color] drawn at [opacity] over white, as the capture blends it.
Color _onWhite(Color color, double opacity) {
  final a = (opacity * 255).round() / 255;
  int blend(double channel) => (channel * 255 * a + 255 * (1 - a)).round();
  return Color.fromARGB(255, blend(color.r), blend(color.g), blend(color.b));
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

bool _near(Color a, Color b) =>
    ((a.r - b.r) * 255).abs() <= 6 &&
    ((a.g - b.g) * 255).abs() <= 6 &&
    ((a.b - b.b) * 255).abs() <= 6;

/// A one-product catalog image ([CatalogService.generateCatalogImage]), as
/// it would be shared.
Future<_Pixels> _captureCatalog() async {
  final png = await CatalogService().generateCatalogImage(
    [Product(name: 'Tea', sellingPrice: 50)],
    shopName: _shopName,
    currencySymbol: _sym,
    options: const CatalogOptions(includePhotos: false),
  );
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return _Pixels(image.width, image.height, data!);
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// RGBA pixels of a capture taken at [kPdfCapturePixelRatio], addressed in
/// logical points.
class _Pixels {
  _Pixels(this.width, this.height, this.data);

  final int width;
  final int height;
  final ByteData data;

  Color _pixel(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  Color at(Offset point) => _pixel(
    (point.dx * kPdfCapturePixelRatio).floor(),
    (point.dy * kPdfCapturePixelRatio).floor(),
  );

  /// How many pixels in [area] match [test].
  int count(Rect area, bool Function(Color) test) {
    var n = 0;
    final left = (area.left * kPdfCapturePixelRatio).floor();
    final right = math.min(width, (area.right * kPdfCapturePixelRatio).ceil());
    final top = (area.top * kPdfCapturePixelRatio).floor();
    final bottom = math.min(
      height,
      (area.bottom * kPdfCapturePixelRatio).ceil(),
    );
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        if (test(_pixel(x, y))) n++;
      }
    }
    return n;
  }
}
