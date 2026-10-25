import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../../core/theme/document_brand.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import 'dues_service.dart';
import 'pdf_assembly.dart';
import 'pdf_service.dart';
import 'widget_capture.dart';

/// Localized labels for the statement. The service has no BuildContext, so
/// the caller resolves these from `AppStrings.of(context)`.
class StatementLabels {
  const StatementLabels({
    required this.title,
    required this.date,
    required this.reference,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.closingBalance,
    required this.payment,
    required this.refund,
    required this.generatedOn,
    required this.pageOf,
  });

  final String title;
  final String date;
  final String reference;
  final String debit;
  final String credit;
  final String balance;
  final String closingBalance;
  final String payment;
  final String refund;
  final String Function(String date) generatedOn;
  final String Function(int page, int total) pageOf;
}

class StatementRow {
  const StatementRow({
    required this.date,
    required this.reference,
    this.debit = 0,
    this.credit = 0,
    this.balance = 0,
  });

  final DateTime? date;
  final String reference;
  final double debit;
  final double credit;
  final double balance;
}

/// Customer statement — a running ledger of what was billed (orders) and
/// what came back (payments, refunded returns). Same widget → PNG → PDF
/// pipeline as [PdfService] and the catalog, for full Unicode shaping.
class StatementService {
  static const double _pageWidth = 794;
  static const double _pageHeight = 1123;
  static const int rowsPerPage = 26;

  /// Builds ledger rows oldest-first with a running balance.
  ///
  /// [orders] must be all of the customer's orders *including returns*;
  /// [payments] all of their Payment rows. Payments made before the history
  /// existed have no rows, so each order's unlogged remainder
  /// (`amountPaid − Σ logged`) is added as a payment on the order's date —
  /// that keeps the closing balance equal to what the orders say.
  List<StatementRow> buildRows(
    List<Order> orders,
    List<Payment> payments, {
    required StatementLabels labels,
  }) {
    final loggedByOrder = <int, double>{};
    for (final p in payments) {
      loggedByOrder[p.orderId] = (loggedByOrder[p.orderId] ?? 0) + p.amount;
    }
    final byId = {for (final o in orders) o.id: o};

    final entries = <({DateTime? date, String ref, double debit, double credit})>[];
    for (final o in orders) {
      if (o.orderStatus == OrderStatus.cancelled) continue;
      if (o.isReturn) {
        final original = byId[o.originalOrderId];
        // Matches computeOrderDues: a return only offsets a live original.
        if (o.returnStatus == ReturnStatus.refunded &&
            original != null &&
            original.orderStatus != OrderStatus.cancelled) {
          entries.add((
            date: o.updatedAt ?? o.createdAt,
            ref: o.orderNumber,
            debit: 0,
            credit: o.totalAmount,
          ));
        }
        continue;
      }
      entries.add((
        date: o.createdAt,
        ref: o.orderNumber,
        debit: o.totalAmount,
        credit: 0,
      ));
      final unlogged = o.amountPaid - (loggedByOrder[o.id] ?? 0);
      if (unlogged.abs() > kDueEpsilon) {
        entries.add((
          date: o.createdAt,
          ref: '${labels.payment} · ${o.orderNumber}',
          debit: unlogged < 0 ? -unlogged : 0,
          credit: unlogged > 0 ? unlogged : 0,
        ));
      }
    }
    for (final p in payments) {
      final order = byId[p.orderId];
      // Payments on cancelled orders net to zero with their cancel refund.
      if (order == null || order.orderStatus == OrderStatus.cancelled) {
        continue;
      }
      final label = p.isRefund ? labels.refund : labels.payment;
      entries.add((
        date: p.paidAt,
        ref: '$label · ${order.orderNumber}',
        debit: p.isRefund ? -p.amount : 0,
        credit: p.isRefund ? 0 : p.amount,
      ));
    }

    entries.sort((a, b) =>
        (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
    var running = 0.0;
    return [
      for (final e in entries)
        StatementRow(
          date: e.date,
          reference: e.ref,
          debit: e.debit,
          credit: e.credit,
          balance: running += e.debit - e.credit,
        ),
    ];
  }

  Future<Uint8List> generateStatementPdf({
    required Customer customer,
    required List<StatementRow> rows,
    required StatementLabels labels,
    required String shopName,
    String shopPhone = '',
    String? currencySymbol,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final sym = currencySymbol ?? CurrencyFormatter.symbol;
    final chunks = <List<StatementRow>>[];
    for (var i = 0; i < rows.length; i += rowsPerPage) {
      chunks.add(rows.sublist(i, (i + rowsPerPage).clamp(0, rows.length)));
    }
    if (chunks.isEmpty) chunks.add(const []);
    final closing = rows.isEmpty ? 0.0 : rows.last.balance;
    final watermarkIcon = await loadPdfWatermarkIcon();

    final pages = <Uint8List>[];
    for (var i = 0; i < chunks.length; i++) {
      pages.add(await captureWidgetPng(
        statementPage(
          customer: customer,
          rows: chunks[i],
          labels: labels,
          shopName: shopName,
          shopPhone: shopPhone,
          sym: sym,
          closing: closing,
          pageIndex: i,
          pageCount: chunks.length,
          textDirection: textDirection,
          watermarkIcon: watermarkIcon,
        ),
        pixelRatio: kPdfCapturePixelRatio,
        // Must be finite — see PdfService.generateOrderReceipt.
        targetSize: const Size(_pageWidth, _pageHeight),
        delay: const Duration(milliseconds: 100),
      ));
    }
    // Every page fills the full canvas on an opaque white Material → JPEG.
    return assemblePdf(pages, jpegPages: (
      width: (_pageWidth * kPdfCapturePixelRatio).round(),
      height: (_pageHeight * kPdfCapturePixelRatio).round(),
    ));
  }

  /// One page as [generateStatementPdf] captures it ([rows] are the page's
  /// rows, [closing] the whole statement's closing balance, shown on the
  /// last page). Public so a test can pump it and check what it draws.
  @visibleForTesting
  static Widget statementPage({
    required Customer customer,
    required List<StatementRow> rows,
    required StatementLabels labels,
    required String shopName,
    required String shopPhone,
    required String sym,
    required double closing,
    required int pageIndex,
    required int pageCount,
    required TextDirection textDirection,
    ui.Image? watermarkIcon,
  }) =>
      _StatementPage(
        customer: customer,
        rows: rows,
        labels: labels,
        shopName: shopName,
        shopPhone: shopPhone,
        sym: sym,
        closing: closing,
        pageIndex: pageIndex,
        pageCount: pageCount,
        textDirection: textDirection,
        watermarkIcon: watermarkIcon,
      );
}

class _StatementPage extends StatelessWidget {
  const _StatementPage({
    required this.customer,
    required this.rows,
    required this.labels,
    required this.shopName,
    required this.shopPhone,
    required this.sym,
    required this.closing,
    required this.pageIndex,
    required this.pageCount,
    required this.textDirection,
    required this.watermarkIcon,
  });

  final Customer customer;
  final List<StatementRow> rows;
  final StatementLabels labels;
  final String shopName;
  final String shopPhone;
  final String sym;
  final double closing;
  final int pageIndex;
  final int pageCount;
  final TextDirection textDirection;
  final ui.Image? watermarkIcon;

  /// The shop name, table header, credits and a settled balance, and the
  /// text on the table header, from the app's color theme. Read when the page
  /// is built, so the next statement follows a theme change. Text on the
  /// white page (the shop name, credits, a settled balance) is [_brandText],
  /// a shade that reads there (a light theme color would be all but
  /// invisible).
  static Color get _brand => DocumentBrand.color;
  static Color get _onBrand => DocumentBrand.onColor;
  static Color get _brandText => DocumentBrand.textColor;
  static const _grey100 = Color(0xFFF5F5F5);
  static const _grey300 = Color(0xFFE0E0E0);
  static const _grey600 = Color(0xFF757575);
  static const _red = Color(0xFFD32F2F);

  String _money(double v) => v == 0 ? '' : CurrencyFormatter.format(v, symbol: sym);

  @override
  Widget build(BuildContext context) {
    // Capture environment only provides Directionality — wire the rest by
    // hand (MaterialApp fails here; see PdfService._ReceiptWidget).
    return MediaQuery(
      data: const MediaQueryData(
          size: Size(StatementService._pageWidth, StatementService._pageHeight)),
      child: Directionality(
        textDirection: textDirection,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.black, fontSize: 12),
          child: Material(
            color: Colors.white,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 36, 40, 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      _tableHeader(),
                      for (var i = 0; i < rows.length; i++) _row(rows[i], i),
                      if (pageIndex == pageCount - 1) ...[
                        const SizedBox(height: 16),
                        _closing(),
                      ],
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: 40,
                  bottom: 24,
                  child: Text(labels.pageOf(pageIndex + 1, pageCount),
                      style: const TextStyle(color: _grey600, fontSize: 10)),
                ),
                PositionedDirectional(
                  end: 40,
                  bottom: 22,
                  child: PdfWatermark(icon: watermarkIcon),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shopName,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _brandText)),
              if (shopPhone.isNotEmpty)
                Text(shopPhone,
                    style: const TextStyle(color: _grey600, fontSize: 12)),
              const SizedBox(height: 14),
              Text(customer.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              if (customer.phone.isNotEmpty)
                Text(customer.phone,
                    style: const TextStyle(color: _grey600, fontSize: 12)),
              if (customer.address.isNotEmpty)
                Text(customer.address,
                    style: const TextStyle(color: _grey600, fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(labels.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(labels.generatedOn(DateFormatter.format(DateTime.now())),
                style: const TextStyle(color: _grey600, fontSize: 11)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (closing > kDueEpsilon ? _red : _brand)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(labels.closingBalance,
                      style: const TextStyle(color: _grey600, fontSize: 10)),
                  Text(CurrencyFormatter.format(closing, symbol: sym),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: closing > kDueEpsilon ? _red : _brandText)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _flex = [3, 5, 3, 3, 3];

  Widget _cells(List<String> values,
      {TextStyle? style, Color? background, List<Color?>? colors}) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(
                values[i],
                textAlign: i >= 2 ? TextAlign.end : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (style ?? const TextStyle(fontSize: 11))
                    .copyWith(color: colors?[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader() => _cells(
        [
          labels.date,
          labels.reference,
          labels.debit,
          labels.credit,
          labels.balance,
        ],
        background: _brand,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: _onBrand),
      );

  Widget _row(StatementRow r, int i) => Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _grey300, width: 0.5))),
        child: _cells(
          [
            DateFormatter.format(r.date),
            r.reference,
            _money(r.debit),
            _money(r.credit),
            CurrencyFormatter.format(r.balance, symbol: sym),
          ],
          background: i.isOdd ? _grey100 : null,
          colors: [null, null, null, _brandText, null],
        ),
      );

  Widget _closing() => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          '${labels.closingBalance}: ${CurrencyFormatter.format(closing, symbol: sym)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      );
}
