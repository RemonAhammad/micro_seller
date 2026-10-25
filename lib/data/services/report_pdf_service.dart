import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/document_brand.dart';
import 'pdf_assembly.dart';
import 'pdf_service.dart';
import 'report_service.dart';
import 'widget_capture.dart';

/// Renders a Reports tab ([ReportTable]s) to a multi-page PDF. Same widget →
/// PNG → PDF pipeline as the invoice and statement (Skia/HarfBuzz shaping,
/// so Bengali, Arabic, Thai… render correctly).
class ReportPdfService {
  static const double _pageWidth = 794;
  static const double _pageHeight = 1123;

  /// Row budget per page. A table title + header costs 2, and the report
  /// header on the first page costs [_firstPageHeader].
  static const int _rowsPerPage = 34;
  static const int _firstPageHeader = 5;

  Future<Uint8List> generate({
    required String shopName,
    required String reportTitle,
    required String periodLabel,
    required List<ReportTable> tables,
    required String Function(int page, int total) pageOf,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    // Split tables into page-sized chunks, repeating a table's header when it
    // continues onto the next page.
    final pages = <List<ReportTable>>[[]];
    var budget = _rowsPerPage - _firstPageHeader;
    for (final t in tables.where((t) => t.rows.isNotEmpty)) {
      var rows = t.rows;
      while (rows.isNotEmpty) {
        if (budget < 4) {
          pages.add([]);
          budget = _rowsPerPage;
        }
        final take = (budget - 2).clamp(1, rows.length);
        pages.last.add(ReportTable(t.title, t.headers, rows.sublist(0, take)));
        budget -= take + 2;
        rows = rows.sublist(take);
      }
    }

    final watermarkIcon = await loadPdfWatermarkIcon();
    final images = <Uint8List>[];
    for (var i = 0; i < pages.length; i++) {
      images.add(await captureWidgetPng(
        reportPage(
          shopName: shopName,
          reportTitle: reportTitle,
          periodLabel: periodLabel,
          tables: pages[i],
          showHeader: i == 0,
          footer: pageOf(i + 1, pages.length),
          textDirection: textDirection,
          watermarkIcon: watermarkIcon,
        ),
        pixelRatio: kPdfCapturePixelRatio,
        // Must be finite — see PdfService.generateOrderReceipt.
        targetSize: const Size(_pageWidth, _pageHeight),
        delay: const Duration(milliseconds: 100),
      ));
    }
    // A page with a table spans the full canvas on an opaque white Material
    // → JPEG. A table-less page is only as wide as its header text and keeps
    // its PNG (see assemblePdf).
    return assemblePdf(images, jpegPages: (
      width: (_pageWidth * kPdfCapturePixelRatio).round(),
      height: (_pageHeight * kPdfCapturePixelRatio).round(),
    ));
  }

  /// One page as [generate] captures it ([showHeader] on the first page
  /// only). Public so a test can pump it and check what it draws.
  @visibleForTesting
  static Widget reportPage({
    required String shopName,
    required String reportTitle,
    required String periodLabel,
    required List<ReportTable> tables,
    required bool showHeader,
    required String footer,
    required TextDirection textDirection,
    ui.Image? watermarkIcon,
  }) =>
      _ReportPage(
        shopName: shopName,
        reportTitle: reportTitle,
        periodLabel: periodLabel,
        tables: tables,
        showHeader: showHeader,
        footer: footer,
        textDirection: textDirection,
        watermarkIcon: watermarkIcon,
      );
}

class _ReportPage extends StatelessWidget {
  const _ReportPage({
    required this.shopName,
    required this.reportTitle,
    required this.periodLabel,
    required this.tables,
    required this.showHeader,
    required this.footer,
    required this.textDirection,
    required this.watermarkIcon,
  });

  final String shopName;
  final String reportTitle;
  final String periodLabel;
  final List<ReportTable> tables;
  final bool showHeader;
  final String footer;
  final TextDirection textDirection;
  final ui.Image? watermarkIcon;

  /// The shop name, table titles and header rows, and the text on the header
  /// rows, from the app's color theme. Read when the page is built, so the
  /// next report follows a theme change. The shop name and table titles are
  /// text on the white page: [_brandText], a shade that reads there (a light
  /// theme color would be all but invisible).
  static Color get _brand => DocumentBrand.color;
  static Color get _onBrand => DocumentBrand.onColor;
  static Color get _brandText => DocumentBrand.textColor;
  static const _grey100 = Color(0xFFF5F5F5);
  static const _grey300 = Color(0xFFE0E0E0);
  static const _grey600 = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    // Capture environment only provides Directionality — wire the rest by
    // hand (MaterialApp fails here; see PdfService._ReceiptWidget).
    return MediaQuery(
      data: const MediaQueryData(
          size: Size(ReportPdfService._pageWidth, ReportPdfService._pageHeight)),
      child: Directionality(
        textDirection: textDirection,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.black, fontSize: 11),
          child: Material(
            color: Colors.white,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 36, 40, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) ...[
                        Text(shopName,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800, color: _brandText)),
                        const SizedBox(height: 2),
                        Text(reportTitle,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(periodLabel, style: const TextStyle(color: _grey600)),
                        const SizedBox(height: 16),
                      ],
                      for (final t in tables) ...[
                        Text(t.title,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: _brandText)),
                        const SizedBox(height: 4),
                        _row(t.headers, header: true),
                        for (var i = 0; i < t.rows.length; i++)
                          _row(t.rows[i], shaded: i.isOdd),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: 40,
                  bottom: 24,
                  child: Text(footer,
                      style: const TextStyle(color: _grey600, fontSize: 10)),
                ),
                PositionedDirectional(
                    end: 40, bottom: 22, child: PdfWatermark(icon: watermarkIcon)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(List<Object> cells, {bool header = false, bool shaded = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: header ? _brand : (shaded ? _grey100 : null),
        border: header
            ? null
            : const Border(bottom: BorderSide(color: _grey300, width: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 3 : 2,
              child: Text(
                formatCell(cells[i]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: header ? FontWeight.w700 : FontWeight.w400,
                  color: header ? _onBrand : Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
