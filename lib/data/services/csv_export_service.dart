import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/expense.dart';
import 'report_service.dart';

class CsvExportService {

  Future<void> exportOrders(List<Order> orders, {Rect? shareOrigin}) async {
    final rows = [
      [
        'Order #',
        'Customer',
        'Phone',
        'Items',
        'Subtotal',
        'Discount',
        'Delivery',
        'Tax',
        'Total',
        'Paid',
        'Balance',
        'Payment Status',
        'Payment Method',
        'Order Status',
        'Date',
      ],
      ...orders.map((o) => [
            o.orderNumber,
            o.customerName,
            o.customerPhone,
            o.totalItems,
            o.subtotal,
            o.discountAmount,
            o.deliveryFee,
            o.taxAmount,
            o.totalAmount,
            o.amountPaid,
            o.balanceDue,
            o.paymentStatus.name,
            o.paymentMethod.name,
            o.orderStatus.name,
            o.createdAt?.toIso8601String() ?? '',
          ]),
    ];
    await _shareAsCsv(rows, 'orders_export', shareOrigin: shareOrigin);
  }

  Future<void> exportProducts(
    List<Product> products, {
    Rect? shareOrigin,
  }) async {
    final rows = [
      [
        'Name',
        'SKU',
        'Category',
        'Selling Price',
        'Cost Price',
        'Stock',
        'Low Stock Threshold',
        'Profit Margin %',
        'Active',
      ],
      ...products.map((p) => [
            p.name,
            p.sku,
            p.category,
            p.sellingPrice,
            p.costPrice,
            p.stockQty,
            p.lowStockThreshold,
            p.profitMargin.toStringAsFixed(1),
            p.isActive ? 'Yes' : 'No',
          ]),
    ];
    await _shareAsCsv(rows, 'products_export', shareOrigin: shareOrigin);
  }

  Future<void> exportExpenses(
    List<Expense> expenses, {
    Rect? shareOrigin,
  }) async {
    final rows = [
      ['Title', 'Amount', 'Category', 'Date', 'Notes'],
      ...expenses.map((e) => [
            e.title,
            e.amount,
            e.category.name,
            e.date?.toIso8601String() ?? '',
            e.notes,
          ]),
    ];
    await _shareAsCsv(rows, 'expenses_export', shareOrigin: shareOrigin);
  }

  Future<void> exportReport({
    required String shopName,
    required String reportTitle,
    required String periodLabel,
    required List<ReportTable> tables,
    required String fileName,
    Rect? shareOrigin,
  }) async {
    final rows = <List<dynamic>>[
      [shopName],
      [reportTitle],
      [periodLabel],
      [],
      for (final t in tables) ...[
        [t.title],
        t.headers,
        for (final r in t.rows) [for (final c in r) _safeCell(c)],
        [],
      ],
    ];

    await _shareAsCsv(rows, fileName, bom: true, shareOrigin: shareOrigin);
  }

  static Object _safeCell(Object c) {
    if (c is num) return c;
    final s = c.toString();
    return s.isNotEmpty && '=+-@'.contains(s[0]) ? "'$s" : s;
  }

  Future<void> _shareAsCsv(List<List<dynamic>> rows, String fileName,
      {bool bom = false, Rect? shareOrigin}) async {

    final bytes = await compute(_encodeCsv, (rows, bom));
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: fileName,
      sharePositionOrigin: shareOrigin,
    ));
  }
}

Uint8List _encodeCsv((List<List<dynamic>>, bool) args) {
  final (rows, bom) = args;
  final text = csv.encode(rows);
  return utf8.encode(bom ? '\uFEFF$text' : text);
}
