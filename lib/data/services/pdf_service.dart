import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import '../models/order.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

/// Generates the order receipt PDF by:
///   1. Building the receipt as a Flutter widget tree.
///   2. Rendering it off-screen to a PNG via Skia (`screenshot` package).
///      Skia uses HarfBuzz for OpenType shaping, so Bengali conjuncts,
///      Arabic ligatures, Thai marks, CJK, and emoji all render correctly.
///   3. Embedding that PNG into a single-page `pw.Document` at A4 size.
///
/// Trade-off vs. native pw widgets: the resulting PDF text is not selectable
/// (it's a rasterised image). For a receipt that's an acceptable price for
/// guaranteed Unicode correctness across every script the user might type.
class PdfService {
  Future<Uint8List> generateOrderReceipt(
    Order order, {
    String shopName = 'SellerBook',
    String? currencySymbol,
    double taxRate = 0.0,
  }) async {
    final sym = currencySymbol ?? CurrencyFormatter.symbol;

    // Capture the Flutter-rendered receipt to a PNG. We have to pass a
    // FINITE targetSize — the screenshot package multiplies it by pixelRatio
    // to get the buffer size, and `infinity * pixelRatio` produces an
    // unrenderable image (the symptom: a red error placeholder when the PDF
    // tries to decode the broken PNG bytes).
    //
    // 794×1400 logical px ≈ A4 portrait at 96 DPI with extra height for tall
    // invoices. Anything taller gets clipped — for now this is more than
    // enough for the receipt layout (header + items table + totals + footer).
    final controller = ScreenshotController();
    final pngBytes = await controller.captureFromWidget(
      _ReceiptWidget(
        order: order,
        shopName: shopName,
        sym: sym,
        taxRate: taxRate,
      ),
      pixelRatio: 2.0,
      targetSize: const Size(794, 1400),
      delay: const Duration(milliseconds: 100),
    );

    // Wrap in a single-page A4 PDF document.
    final pdf = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(
          image,
          fit: pw.BoxFit.fitWidth,
          alignment: pw.Alignment.topCenter,
        ),
      ),
    );
    return pdf.save();
  }

  String generateWhatsAppText(Order order, {String? currencySymbol}) {
    final waSym = currencySymbol ?? CurrencyFormatter.symbol;
    final sb = StringBuffer();
    sb.writeln('📦 Order ${order.orderNumber}');
    sb.writeln('📅 ${DateFormatter.format(order.createdAt)}');
    if (order.customerName.isNotEmpty) {
      sb.writeln('👤 ${order.customerName}');
    }
    sb.writeln();
    sb.writeln('Products:');
    for (final item in order.items) {
      sb.writeln(
          '• ${item.displayName} x${item.qty} — ${CurrencyFormatter.format(item.totalPrice, symbol: waSym)}');
    }
    sb.writeln();
    sb.writeln('Subtotal: ${CurrencyFormatter.format(order.subtotal, symbol: waSym)}');
    if (order.discountAmount > 0) {
      sb.writeln('Discount: -${CurrencyFormatter.format(order.discountAmount, symbol: waSym)}');
    }
    if (order.deliveryFee > 0) {
      sb.writeln('Delivery: ${CurrencyFormatter.format(order.deliveryFee, symbol: waSym)}');
    }
    if (order.taxAmount > 0) {
      sb.writeln('Tax: ${CurrencyFormatter.format(order.taxAmount, symbol: waSym)}');
    }
    sb.writeln('*Total: ${CurrencyFormatter.format(order.totalAmount, symbol: waSym)}*');
    sb.writeln();
    final statusStr = order.paymentStatus == PaymentStatus.paid
        ? '✅ Paid'
        : order.paymentStatus == PaymentStatus.partial
            ? '⚠️ Partially Paid'
            : '❌ Unpaid';
    sb.writeln('Status: $statusStr');

    if (order.notes.isNotEmpty) {
      sb.writeln();
      sb.writeln('Notes: ${order.notes}');
    }

    return sb.toString();
  }
}

/// Pure Flutter receipt — gets rasterised to PNG via `screenshot.captureFromWidget`.
/// Looks like the on-screen order detail screen (teal header, bill-to card,
/// items table, totals, payment badge, footer) but in a fixed A4-friendly width.
class _ReceiptWidget extends StatelessWidget {
  final Order order;
  final String shopName;
  final String sym;
  final double taxRate;

  const _ReceiptWidget({
    required this.order,
    required this.shopName,
    required this.sym,
    required this.taxRate,
  });

  static const _teal = Color(0xFF00897B);
  static const _grey100 = Color(0xFFF5F5F5);
  static const _grey200 = Color(0xFFEEEEEE);
  static const _grey300 = Color(0xFFE0E0E0);
  static const _grey600 = Color(0xFF757575);
  static const _red = Color(0xFFD32F2F);

  Color get _badgeColor {
    switch (order.paymentStatus) {
      case PaymentStatus.paid:
        return const Color(0xFF4CAF50);
      case PaymentStatus.partial:
        return const Color(0xFFFF9800);
      case PaymentStatus.unpaid:
        return const Color(0xFFF44336);
    }
  }

  String get _badgeText {
    switch (order.paymentStatus) {
      case PaymentStatus.paid:
        return 'PAID';
      case PaymentStatus.partial:
        return 'PARTIALLY PAID';
      case PaymentStatus.unpaid:
        return 'UNPAID';
    }
  }

  @override
  Widget build(BuildContext context) {
    // `screenshot.captureFromWidget` only injects Directionality, not the
    // MediaQuery / Material context that real Material widgets need. So we
    // wire those up by hand at the minimum level required for Text/Table/
    // Container to render. (Using MaterialApp here fails because it tries
    // to resolve a MediaQuery ancestor that doesn't exist in the off-screen
    // capture environment.)
    return MediaQuery(
      data: const MediaQueryData(size: Size(794, 2000)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.black, fontSize: 12),
          child: Material(
            color: Colors.white,
            // Stack so we can paint the watermark on top of the canvas
            // anchored to the bottom-right, regardless of how tall the
            // receipt content is.
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      _billToCard(),
                      const SizedBox(height: 20),
                      _itemsTitle(),
                      const SizedBox(height: 8),
                      _itemsTable(),
                      const SizedBox(height: 16),
                      _summary(),
                      const SizedBox(height: 20),
                      _paymentBadge(),
                      if (order.notes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _notes(),
                      ],
                      const SizedBox(height: 40),
                      _footer(),
                    ],
                  ),
                ),
                const Positioned(
                  right: 24,
                  bottom: 20,
                  child: PdfWatermark(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  )),
              const SizedBox(height: 4),
              const Text('Invoice',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(order.orderNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
              const SizedBox(height: 4),
              Text(DateFormatter.format(order.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billToCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _grey100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bill To:',
              style: TextStyle(
                color: _grey600,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              )),
          const SizedBox(height: 4),
          Text(
              order.customerName.isNotEmpty
                  ? order.customerName
                  : 'Walk-in Customer',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13)),
          if (order.customerPhone.isNotEmpty)
            Text(order.customerPhone, style: const TextStyle(fontSize: 11)),
          if (order.deliveryAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(order.deliveryAddress,
                  style: const TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _itemsTitle() => const Text('Order Items',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13));

  Widget _itemsTable() {
    final headerStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
    final cellStyle = const TextStyle(fontSize: 10);

    Widget cell(String text, {bool numeric = false, TextStyle? style}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(text,
            style: style ?? cellStyle,
            textAlign: numeric ? TextAlign.right : TextAlign.left),
      );
    }

    return Table(
      border: TableBorder.all(color: _grey300),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _grey200),
          children: [
            cell('Item', style: headerStyle),
            cell('Qty', numeric: true, style: headerStyle),
            cell('Unit Price', numeric: true, style: headerStyle),
            cell('Total', numeric: true, style: headerStyle),
          ],
        ),
        for (final item in order.items)
          TableRow(children: [
            cell(item.displayName),
            cell('${item.qty}', numeric: true),
            cell(CurrencyFormatter.format(item.unitPrice, symbol: sym),
                numeric: true),
            cell(CurrencyFormatter.format(item.totalPrice, symbol: sym),
                numeric: true),
          ]),
      ],
    );
  }

  Widget _summary() {
    Widget row(String label, String value,
        {bool isTotal = false, bool isRed = false}) {
      final style = TextStyle(
        fontSize: isTotal ? 13 : 11,
        fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
        color: isRed ? _red : null,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: style), Text(value, style: style)],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 220,
        child: Column(
          children: [
            row('Subtotal',
                CurrencyFormatter.format(order.subtotal, symbol: sym)),
            if (order.discountAmount > 0)
              row('Discount',
                  '- ${CurrencyFormatter.format(order.discountAmount, symbol: sym)}'),
            if (order.deliveryFee > 0)
              row('Delivery Fee',
                  CurrencyFormatter.format(order.deliveryFee, symbol: sym)),
            if (taxRate > 0 && order.taxAmount > 0)
              row('Tax (${taxRate.toString()}%)',
                  CurrencyFormatter.format(order.taxAmount, symbol: sym)),
            const Divider(height: 12),
            row('Total',
                CurrencyFormatter.format(order.totalAmount, symbol: sym),
                isTotal: true),
            row('Paid', CurrencyFormatter.format(order.amountPaid, symbol: sym)),
            if (order.balanceDue > 0)
              row('Balance Due',
                  CurrencyFormatter.format(order.balanceDue, symbol: sym),
                  isTotal: true, isRed: true),
          ],
        ),
      ),
    );
  }

  Widget _paymentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _badgeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(_badgeText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          )),
    );
  }

  Widget _notes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _grey100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes',
              style: TextStyle(
                color: _grey600,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              )),
          const SizedBox(height: 2),
          Text(order.notes, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text('Thank you for your business!',
            style: TextStyle(color: _grey600, fontSize: 11)),
      ],
    );
  }
}

/// Bottom-right watermark: app icon + "Micro Seller" wordmark. Subtle
/// (slightly faded) so it reads as branding rather than competing with the
/// invoice content.
class PdfWatermark extends StatelessWidget {
  const PdfWatermark();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Powered by',
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 9,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Image.asset(
            'assets/icons/app_icon.png',
            width: 16,
            height: 16,
            // If the asset can't be found at runtime, just skip the icon
            // rather than painting a broken-image placeholder onto the PDF.
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
          const Text(
            AppStrings.appName,
            style: TextStyle(
              color: Color(0xFF00897B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
