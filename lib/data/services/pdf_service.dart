import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

class PdfService {
  Future<Uint8List> generateOrderReceipt(
    Order order, {
    String shopName = 'SellerBook',
    String? currencySymbol,
    double taxRate = 0.0,
  }) async {
    final sym = currencySymbol ?? CurrencyFormatter.symbol;
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

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
                          font: boldFont,
                          fontSize: 20,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Receipt',
                        style: pw.TextStyle(
                          font: font,
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
                          font: boldFont,
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateFormatter.format(order.createdAt),
                        style: pw.TextStyle(
                          font: font,
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
                      font: boldFont,
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    order.customerName.isNotEmpty
                        ? order.customerName
                        : 'Walk-in Customer',
                    style: pw.TextStyle(font: boldFont, fontSize: 13),
                  ),
                  if (order.customerPhone.isNotEmpty)
                    pw.Text(
                      order.customerPhone,
                      style: pw.TextStyle(font: font, fontSize: 11),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Items table
            pw.Text(
              'Order Items',
              style: pw.TextStyle(font: boldFont, fontSize: 13),
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
                    _tableCell('Item', boldFont, isHeader: true),
                    _tableCell('Qty', boldFont, isHeader: true),
                    _tableCell('Unit Price', boldFont, isHeader: true),
                    _tableCell('Total', boldFont, isHeader: true),
                  ],
                ),
                // Item rows
                ...order.items.map(
                  (item) => pw.TableRow(
                    children: [
                      _tableCell(item.productName, font),
                      _tableCell('${item.qty}', font),
                      _tableCell(
                        CurrencyFormatter.format(item.unitPrice,
                            symbol: sym),
                        font,
                      ),
                      _tableCell(
                        CurrencyFormatter.format(item.totalPrice,
                            symbol: sym),
                        font,
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
                        CurrencyFormatter.format(order.subtotal, symbol: sym), font, boldFont),
                    if (order.discountAmount > 0)
                      _summaryRow('Discount',
                          '- ${CurrencyFormatter.format(order.discountAmount, symbol: sym)}', font, boldFont),
                    if (order.deliveryFee > 0)
                      _summaryRow('Delivery Fee',
                          CurrencyFormatter.format(order.deliveryFee, symbol: sym), font, boldFont),
                    if (taxRate > 0 && order.taxAmount > 0)
                      _summaryRow('Tax ($taxRate%)',
                          CurrencyFormatter.format(order.taxAmount, symbol: sym), font, boldFont),
                    pw.Divider(),
                    _summaryRow('Total',
                        CurrencyFormatter.format(order.totalAmount, symbol: sym), boldFont, boldFont,
                        isTotal: true),
                    _summaryRow('Paid',
                        CurrencyFormatter.format(order.amountPaid, symbol: sym), font, boldFont),
                    if (order.balanceDue > 0)
                      _summaryRow('Balance Due',
                          CurrencyFormatter.format(order.balanceDue, symbol: sym), boldFont, boldFont,
                          isRed: true),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Payment status badge
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  font: boldFont,
                  fontSize: 11,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Spacer(),

            // Footer
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'Thank you for your business! 🙏',
                style: pw.TextStyle(
                  font: font,
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

  pw.Widget _tableCell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
      String label, String value, pw.Font labelFont, pw.Font valueFont,
      {bool isTotal = false, bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                font: labelFont,
                fontSize: isTotal ? 13 : 11,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                font: valueFont,
                fontSize: isTotal ? 13 : 11,
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
          '• ${item.productName} x${item.qty} — ${CurrencyFormatter.format(item.totalPrice, symbol: waSym)}');
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
