import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

const _kSavedPrintersKey = 'pos_printers';
const _kDefaultPrinterKey = 'pos_default_printer';
const _kPaperWidthKey = 'pos_paper_width';

bool get isPosPrinterSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class SavedPrinter {
  final String name;
  final String address;
  final String type;

  const SavedPrinter({
    required this.name,
    required this.address,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'type': type,
      };

  factory SavedPrinter.fromJson(Map<String, dynamic> json) => SavedPrinter(
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        type: json['type'] as String? ?? 'bluetooth',
      );
}

class PosPrinterService {
  PosPrinterService._();
  static final instance = PosPrinterService._();

  final _plugin = FlutterThermalPrinter.instance;

  Stream<List<Printer>> get devicesStream => _plugin.devicesStream;

  Printer? _connectedPrinter;
  Printer? get connectedPrinter => _connectedPrinter;

  Future<void> startScan({
    List<ConnectionType> types = const [ConnectionType.BLE],
  }) async {
    if (!isPosPrinterSupported) return;
    try {
      await _plugin.getPrinters(connectionTypes: types);
    } catch (e) {
      debugPrint('POS scan error: $e');
    }
  }

  Future<void> stopScan() async {
    if (!isPosPrinterSupported) return;
    try {
      await _plugin.stopScan();
    } catch (e) {
      debugPrint('POS stop scan error: $e');
    }
  }

  Future<bool> connectTo(Printer printer) async {
    if (!isPosPrinterSupported) return false;
    try {
      final ok = await _plugin.connect(printer);
      if (ok) _connectedPrinter = printer;
      return ok;
    } catch (e) {
      debugPrint('POS connect error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    final p = _connectedPrinter;
    if (p == null) return;
    try {
      await _plugin.disconnect(p);
    } catch (e) {
      debugPrint('POS disconnect error: $e');
    }
    _connectedPrinter = null;
  }

  Future<bool> printReceipt({
    required Order order,
    required String shopName,
    String? shopPhone,
    required String currencySymbol,
    required int paperWidth,
    Printer? printer,
  }) async {
    final target = printer ?? _connectedPrinter;
    if (target == null || !isPosPrinterSupported) return false;
    try {
      final cols = paperWidth == 58 ? 32 : 48;
      final lines = _buildReceiptLines(
        order: order,
        shopName: shopName,
        shopPhone: shopPhone,
        cols: cols,
      );

      final text = lines.join('\n');
      final bytes = utf8.encode(text);
      await _plugin.printData(target, bytes, longData: true);
      return true;
    } catch (e) {
      debugPrint('POS print error: $e');
      return false;
    }
  }

  Future<bool> printTest({required int paperWidth, Printer? printer}) async {
    final target = printer ?? _connectedPrinter;
    if (target == null || !isPosPrinterSupported) return false;
    try {
      final cols = paperWidth == 58 ? 32 : 48;
      final lines = <String>[
        _center('*** TEST PRINT ***', cols),
        '',
        _center('Micro Seller', cols),
        _center('POS Printer Test', cols),
        '',
        ''.padRight(cols, '-'),
        'Paper: ${paperWidth}mm ($cols cols)',
        ''.padRight(cols, '-'),
        _center('Printer is working!', cols),
        '',
        '',
      ];

      final text = lines.join('\n');
      await _plugin.printData(target, utf8.encode(text), longData: true);
      return true;
    } catch (e) {
      debugPrint('POS test print error: $e');
      return false;
    }
  }

  List<String> _buildReceiptLines({
    required Order order,
    required String shopName,
    String? shopPhone,
    required int cols,
  }) {
    final lines = <String>[];

    lines.add(_center(shopName.toUpperCase(), cols));
    if (shopPhone != null && shopPhone.isNotEmpty) {
      lines.add(_center(shopPhone, cols));
    }
    lines.add(''.padRight(cols, '-'));
    lines.add('Order: ${order.orderNumber}');
    if (order.createdAt != null) {
      lines.add('Date: ${DateFormatter.format(order.createdAt!)}');
    }
    if (order.customerName.isNotEmpty) {
      lines.add('Customer: ${order.customerName}');
    }
    lines.add(''.padRight(cols, '-'));

    for (final item in order.items) {
      final name = item.displayName;
      final qty = 'x${item.qty}';
      final price = CurrencyFormatter.format(item.totalPrice);
      final needed = name.length + qty.length + price.length + 2;
      if (needed <= cols) {
        final gap = cols - name.length - qty.length - price.length - 1;
        lines.add('$name $qty${' ' * gap.clamp(1, cols)}$price');
      } else {
        lines.add(name);
        lines.add(_rightAlign('$qty  $price', cols));
      }
    }

    lines.add(''.padRight(cols, '-'));

    void addRow(String label, double amount) {
      final formatted = CurrencyFormatter.format(amount);
      final gap = cols - label.length - formatted.length;
      lines.add('$label${' ' * gap.clamp(1, cols)}$formatted');
    }

    addRow('Subtotal:', order.subtotal);
    if (order.discountAmount > 0) addRow('Discount:', -order.discountAmount);
    if (order.taxAmount > 0) addRow('Tax:', order.taxAmount);
    if (order.deliveryFee > 0) addRow('Delivery:', order.deliveryFee);
    lines.add(''.padRight(cols, '='));
    addRow('TOTAL:', order.totalAmount);
    lines.add(''.padRight(cols, '='));
    addRow('Paid:', order.amountPaid);
    if (order.balanceDue > 0) addRow('Due:', order.balanceDue);

    lines.add('');
    lines.add(_center('Thank you!', cols));
    lines.add('');
    lines.add('');
    return lines;
  }

  // --- SharedPreferences ---

  Future<List<SavedPrinter>> loadSavedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kSavedPrintersKey);
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => SavedPrinter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePrinters(List<SavedPrinter> printers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSavedPrintersKey,
      jsonEncode(printers.map((e) => e.toJson()).toList()),
    );
  }

  Future<String?> loadDefaultPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDefaultPrinterKey);
  }

  Future<void> saveDefaultPrinterAddress(String? address) async {
    final prefs = await SharedPreferences.getInstance();
    if (address == null) {
      await prefs.remove(_kDefaultPrinterKey);
    } else {
      await prefs.setString(_kDefaultPrinterKey, address);
    }
  }

  Future<int> loadPaperWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPaperWidthKey) ?? 80;
  }

  Future<void> savePaperWidth(int width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPaperWidthKey, width);
  }

  String _center(String text, int cols) {
    if (text.length >= cols) return text;
    final pad = (cols - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  String _rightAlign(String text, int cols) {
    if (text.length >= cols) return text;
    return ' ' * (cols - text.length) + text;
  }
}
