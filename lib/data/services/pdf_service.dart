import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

class _PdfFonts {
  final pw.Font base;
  final pw.Font bold;
  final List<pw.Font> fallback;
  _PdfFonts(this.base, this.bold, this.fallback);
}

class PdfService {
  // Cached across calls so subsequent invoice generation is instant.
  static _PdfFonts? _cachedFonts;

  static Future<_PdfFonts> _loadFonts() async {
    if (_cachedFonts != null) return _cachedFonts!;

    // Noto Sans covers Latin, Cyrillic, Greek, Vietnamese diacritics.
    // The fallback list extends coverage to every other script a seller
    // might type into a product/customer/category field.
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    // Order matters: pdf walks the chain in order until a glyph matches.
    final fallback = await Future.wait<pw.Font>([
      PdfGoogleFonts.notoSansBengaliRegular(),     // bn
      PdfGoogleFonts.notoSansArabicRegular(),      // ar
      PdfGoogleFonts.notoNastaliqUrduRegular(),    // ur
      PdfGoogleFonts.notoSansThaiRegular(),        // th
      PdfGoogleFonts.notoSansDevanagariRegular(),  // hi
      PdfGoogleFonts.notoSansSCRegular(),          // zh-CN
      PdfGoogleFonts.notoSansTCRegular(),          // zh-TW
      PdfGoogleFonts.notoSansJPRegular(),          // ja
      PdfGoogleFonts.notoSansKRRegular(),          // ko
      PdfGoogleFonts.notoColorEmoji(),             // 🙏 ✅ ⚠️
    ]);

    _cachedFonts = _PdfFonts(base, bold, fallback);
    return _cachedFonts!;
  }

  Future<Uint8List> generateOrderReceipt(
    Order order, {
    String shopName = 'SellerBook',
    String? currencySymbol,
    double taxRate = 0.0,
  }) async {
    final sym = currencySymbol ?? CurrencyFormatter.symbol;
    final fonts = await _loadFonts();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fonts.base,
        bold: fonts.bold,
        fontFallback: fonts.fallback,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#00897B'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shopName,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 20,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Invoice',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        order.orderNumber,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateFormatter.format(order.createdAt),
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Customer info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Bill To:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    order.customerName.isNotEmpty
                        ? order.customerName
                        : 'Walk-in Customer',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13),
                  ),
                  if (order.customerPhone.isNotEmpty)
                    pw.Text(
                      order.customerPhone,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  if (order.deliveryAddress.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        order.deliveryAddress,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Items table
            pw.Text(
              'Order Items',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 13),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    _tableCell('Item', isHeader: true),
                    _tableCell('Qty', isHeader: true),
                    _tableCell('Unit Price', isHeader: true),
                    _tableCell('Total', isHeader: true),
                  ],
                ),
                // Item rows
                ...order.items.map(
                  (item) => pw.TableRow(
                    children: [
                      _tableCell(item.displayName),
                      _tableCell('${item.qty}'),
                      _tableCell(
                        CurrencyFormatter.format(item.unitPrice, symbol: sym),
                      ),
                      _tableCell(
                        CurrencyFormatter.format(item.totalPrice, symbol: sym),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Totals
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                child: pw.Column(
                  children: [
                    _summaryRow('Subtotal',
                        CurrencyFormatter.format(order.subtotal, symbol: sym)),
                    if (order.discountAmount > 0)
                      _summaryRow('Discount',
                          '- ${CurrencyFormatter.format(order.discountAmount, symbol: sym)}'),
                    if (order.deliveryFee > 0)
                      _summaryRow('Delivery Fee',
                          CurrencyFormatter.format(order.deliveryFee, symbol: sym)),
                    if (taxRate > 0 && order.taxAmount > 0)
                      _summaryRow('Tax ($taxRate%)',
                          CurrencyFormatter.format(order.taxAmount, symbol: sym)),
                    pw.Divider(),
                    _summaryRow('Total',
                        CurrencyFormatter.format(order.totalAmount, symbol: sym),
                        isTotal: true),
                    _summaryRow('Paid',
                        CurrencyFormatter.format(order.amountPaid, symbol: sym)),
                    if (order.balanceDue > 0)
                      _summaryRow('Balance Due',
                          CurrencyFormatter.format(order.balanceDue, symbol: sym),
                          isTotal: true, isRed: true),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Payment status badge
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: order.paymentStatus == PaymentStatus.paid
                    ? PdfColor.fromHex('#4CAF50')
                    : order.paymentStatus == PaymentStatus.partial
                        ? PdfColor.fromHex('#FF9800')
                        : PdfColor.fromHex('#F44336'),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                order.paymentStatus == PaymentStatus.paid
                    ? 'PAID'
                    : order.paymentStatus == PaymentStatus.partial
                        ? 'PARTIALLY PAID'
                        : 'UNPAID',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.white,
                ),
              ),
            ),

            if (order.notes.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Notes',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: PdfColors.grey600,
                        )),
                    pw.SizedBox(height: 2),
                    pw.Text(order.notes,
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],

            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value,
      {bool isTotal = false, bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: isTotal ? 13 : 11,
                fontWeight:
                    isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: isTotal ? 13 : 11,
                fontWeight:
                    isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isRed ? PdfColors.red : null,
              )),
        ],
      ),
    );
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
