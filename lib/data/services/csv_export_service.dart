import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/expense.dart';

class CsvExportService {
  /// Export orders to CSV and share via system share sheet.
  Future<void> exportOrders(List<Order> orders) async {
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
    await _shareAsCsv(rows, 'orders_export');
  }

  /// Export products to CSV and share via system share sheet.
  Future<void> exportProducts(List<Product> products) async {
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
    await _shareAsCsv(rows, 'products_export');
  }

  /// Export expenses to CSV and share via system share sheet.
  Future<void> exportExpenses(List<Expense> expenses) async {
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
    await _shareAsCsv(rows, 'expenses_export');
  }

  Future<void> _shareAsCsv(List<List<dynamic>> rows, String fileName) async {
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], subject: fileName);
  }
}
