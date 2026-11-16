import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_item.dart';
import '../../../data/models/product.dart';
import '../../../data/models/variant_combination.dart';
import '../../../data/models/customer.dart';
import '../providers/order_form_defaults.dart';
import '../providers/order_provider.dart';
import '../providers/quick_add_provider.dart';
import 'widgets/order_feedback.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/number_input.dart';
import '../../../core/utils/quantity.dart';
import '../../../core/utils/scale_barcode.dart';
import '../../../core/utils/share_origin.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/document_brand.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../shared/widgets/entry_date_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/pdf_saved_sheet.dart';
import '../../../shared/widgets/quantity_sheet.dart';
import '../../settings/providers/settings_provider.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/services/device_channel.dart';
import '../../../data/services/pos_printer_service.dart';
import '../../../shared/widgets/scanner_camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_thermal_printer/utils/printer.dart' as pos;

class OrderFormScreen extends ConsumerStatefulWidget {
  final Order? order;
  final int? orderId;

  const OrderFormScreen({super.key, this.order, this.orderId});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _deliveryCtrl = TextEditingController(text: '0');
  final _amountPaidCtrl = TextEditingController();
  final _transactionIdCtrl = TextEditingController();
  final _deliveryAddressCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();

  final _recurringDaysCtrl = TextEditingController(text: '30');

  late final Listenable _moneyFields = Listenable.merge([_discountCtrl, _deliveryCtrl, _taxRateCtrl, _amountPaidCtrl]);

  Customer? _selectedCustomer;
  final List<OrderItem> _items = [];
  OrderStatus _orderStatus = OrderFormDefaults.fallback.orderStatus;
  PaymentMethod _paymentMethod = OrderFormDefaults.fallback.paymentMethod;
  DateTime? _orderDate;
  DateTime? _estimatedDeliveryDate;
  bool _isRecurring = false;
  bool _isLoading = false;

  /// A new order starts as a counter sale: the footer offers Paid in full,
  /// and the amount-paid block appears only after Credit / partial. An edit
  /// always shows it.
  bool _creditMode = false;

  /// Discount, delivery, tax, date, status, notes and recurring live behind
  /// "More options", open from the start only when an edited order uses them.
  bool _showMore = false;

  /// Set once the seller picks a method or status, so the remembered
  /// defaults (loaded asynchronously) never overwrite a choice.
  bool _pickedPaymentMethod = false;
  bool _pickedStatus = false;

  Order? _existingOrder;

  bool get _isEditing => _existingOrder != null;

  bool get _canSetOrderDate {
    final existing = _existingOrder;
    return existing == null ||
        (!existing.isReturn && existing.orderStatus != OrderStatus.cancelled);
  }

  DateTime? get _firstOrderDate {
    final stored = _existingOrder?.createdAt;
    return stored != null && stored.isBefore(kFirstEntryDate) ? stored : null;
  }

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {

    try {
      final settingsTaxRate = ref.read(settingsProvider.notifier).taxRate;
      if (settingsTaxRate > 0) {
        _taxRateCtrl.text = settingsTaxRate.toStringAsFixed(settingsTaxRate == settingsTaxRate.roundToDouble() ? 0 : 2);
      }
    } catch (_) {}

    if (widget.order != null) {
      _populateForm(widget.order!);
    } else if (widget.orderId != null) {
      final isar = await ref.read(isarProvider.future);
      final order = await isar.orders.get(widget.orderId!);
      if (order != null && mounted) {
        _populateForm(order);
      }
    } else {
      final defaults = await OrderFormDefaults.load();
      if (!mounted || _isEditing) return;
      setState(() {
        if (!_pickedPaymentMethod) _paymentMethod = defaults.paymentMethod;
        if (!_pickedStatus) _orderStatus = defaults.orderStatus;
      });
    }
  }

  void _populateForm(Order order) {
    _existingOrder = order;
    final walkIn = order.customerId <= 0 && order.customerName.isEmpty && order.customerPhone.isEmpty;
    _selectedCustomer =
        walkIn ? null : Customer(id: order.customerId, name: order.customerName, phone: order.customerPhone);
    _creditMode = true;
    _showMore = order.discountAmount > 0 ||
        order.deliveryFee > 0 ||
        order.notes.isNotEmpty ||
        order.deliveryAddress.isNotEmpty ||
        order.estimatedDeliveryDate != null ||
        order.isRecurring ||
        !OrderFormDefaults.formStatuses.contains(order.orderStatus);
    _items
      ..clear()
      ..addAll(order.items.map((i) => i.copyWith()));

    _discountCtrl.text = order.discountAmount > 0 ? _amountText(order.discountAmount) : '0';
    _deliveryCtrl.text = order.deliveryFee > 0 ? _amountText(order.deliveryFee) : '0';
    _amountPaidCtrl.text = order.amountPaid > 0 ? _amountText(order.amountPaid) : '';
    _transactionIdCtrl.text = order.transactionId;

    if (order.taxAmount > 0) {
      final taxableAmount = order.subtotal - order.discountAmount;
      if (taxableAmount > 0) {
        final rate = order.taxAmount / taxableAmount * 100;
        _taxRateCtrl.text = rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2);
      }
    }
    _notesCtrl.text = order.notes;
    _deliveryAddressCtrl.text = order.deliveryAddress;
    _orderDate = order.createdAt;
    _estimatedDeliveryDate = order.estimatedDeliveryDate;
    _isRecurring = order.isRecurring;
    _recurringDaysCtrl.text = '${order.recurringIntervalDays > 0 ? order.recurringIntervalDays : 30}';
    _orderStatus = order.orderStatus;
    _paymentMethod = order.paymentMethod;
    setState(() {});
  }

  static String _amountText(double amount) =>
      amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : NumberInput.moneyDecimals);

  @override
  void dispose() {
    _notesCtrl.dispose();
    _discountCtrl.dispose();
    _deliveryCtrl.dispose();
    _amountPaidCtrl.dispose();
    _transactionIdCtrl.dispose();
    _deliveryAddressCtrl.dispose();
    _taxRateCtrl.dispose();
    _recurringDaysCtrl.dispose();
    super.dispose();
  }

  _FormTotals _readTotals() {
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final discount = NumberInput.parseDecimal(_discountCtrl.text) ?? 0;
    final delivery = NumberInput.parseDecimal(_deliveryCtrl.text) ?? 0;
    final taxRate = NumberInput.parseDecimal(_taxRateCtrl.text) ?? 0;
    final totals = orderTotals(subtotal: subtotal, discount: discount, taxRate: taxRate, delivery: delivery);
    return _FormTotals(
      subtotal: subtotal,
      discount: discount,
      delivery: delivery,
      taxRate: taxRate,
      tax: totals.tax,
      total: totals.total,
      paid: NumberInput.parseDecimal(_amountPaidCtrl.text) ?? 0,
    );
  }

  int get _recurringDays {
    final days = NumberInput.parseInteger(_recurringDaysCtrl.text);
    return days != null && days >= 1 ? days : 30;
  }

  Future<void> _pickCustomer() async {
    final isar = await ref.read(isarProvider.future);
    final customers = await isar.customers.where().sortByName().findAll();
    if (!mounted) return;

    final result = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CustomerPickerSheet(customers: customers, isar: isar),
    );

    if (result != null) setState(() => _selectedCustomer = result);
  }

  Future<void> _pickProducts() async {
    final isar = await ref.read(isarProvider.future);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ProductPickerSheet(
        isar: isar,
        currentItems: _items,
        onChanged: (updated) => setState(() {
          _items
            ..clear()
            ..addAll(updated);
        }),
      ),
    );
  }

  Future<void> _scanToAddItem() async {
    final isar = await ref.read(isarProvider.future);
    if (!mounted) return;

    final hit = await showModalBottomSheet<_ScanHit>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ScannerSheet(
        isar: isar,
        deviceChannel: ref.read(deviceChannelProvider),
      ),
    );
    if (hit == null || !mounted) return;
    final labelQty = hit.qty;
    if (labelQty != null) {
      _addLabelQty(hit.product, labelQty, combination: hit.combination);
    } else {
      await _addOneOf(isar, hit.product, combination: hit.combination);
    }
  }

  /// A scale label: its weight (or the weight its price buys) goes straight
  /// into the cart. A second label of the same product adds to its line.
  void _addLabelQty(Product product, double qty, {VariantCombination? combination}) {
    final s = AppStrings.of(context);
    final key = combination?.combinationKey ?? '';
    final name = _lineName(product, combination);
    final stock = combination?.stockQty ?? product.stockQty;
    final idx = _items.indexWhere((i) => i.productId == product.id && i.variantCombinationKey == key);
    final total = roundQty((idx >= 0 ? _items[idx].qty : 0) + qty);
    if (qtyExceeds(total, stock)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.notEnoughStock(s.qty(stock, product.unit), name))),
      );
      return;
    }
    setState(() {
      if (idx >= 0) {
        final existing = _items[idx];
        _items[idx] = existing.copyWith(qty: total, totalPrice: lineTotal(existing.unitPrice, total));
      } else {
        _items.add(_newItem(product, qty, combination: combination));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.scaleLabelAdded(s.qty(qty, product.unit), name))),
    );
  }

  /// "T-Shirt (Size: L)" for a combination, else the product's name.
  static String _lineName(Product product, VariantCombination? combination) =>
      combination == null ? product.name : '${product.name} (${combination.displayLabel})';

  /// A quick-add chip: the product as it is now (its stock may have moved
  /// since the chips were loaded), then the same path as a scan.
  Future<void> _quickAdd(Product chip) async {
    final isar = await ref.read(isarProvider.future);
    final product = await isar.products.get(chip.id);
    if (!mounted) return;
    if (product == null || !product.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).outOfStock)));
      return;
    }
    await _addOneOf(isar, product);
  }

  /// Adds one of [product] (of its [combination], when a scan of that
  /// combination's SKU named it) to the cart: a variant product without one
  /// opens the picker on that product to choose it; otherwise 1 is added
  /// (or, for weighed goods, the quantity sheet asks), refused past stock.
  Future<void> _addOneOf(Isar isar, Product product, {VariantCombination? combination}) async {
    if (product.hasVariants && combination == null) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _ProductPickerSheet(
          isar: isar,
          currentItems: _items,
          filterProductId: product.id,
          onChanged: (updated) => setState(() {
            _items
              ..clear()
              ..addAll(updated);
          }),
        ),
      );
      return;
    }

    final s = AppStrings.of(context);
    final key = combination?.combinationKey ?? '';
    final name = _lineName(product, combination);
    final stock = combination?.stockQty ?? product.stockQty;
    if (stock <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.outOfStock)),
        );
      }
      return;
    }

    final idx = _items.indexWhere(
      (i) => i.productId == product.id && i.variantCombinationKey == key,
    );

    // Weighed / measured goods: ask how much (or for how much money).
    if (product.unit.allowsDecimal) {
      final qty = await showQuantitySheet(
        context,
        productName: name,
        unit: product.unit,
        unitPrice: product.sellingPrice + (combination?.priceAdjustment ?? 0),
        available: stock,
        initial: idx >= 0 ? _items[idx].qty : null,
      );
      if (qty == null || !mounted) return;
      setState(() {
        if (idx >= 0) {
          final existing = _items[idx];
          _items[idx] = existing.copyWith(qty: qty, totalPrice: lineTotal(existing.unitPrice, qty));
        } else {
          _items.add(_newItem(product, qty, combination: combination));
        }
      });
      return;
    }

    if (idx >= 0) {
      final existing = _items[idx];
      if (qtyAtLeast(existing.qty, stock)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.notEnoughStock(s.qty(stock, product.unit), name)),
            ),
          );
        }
        return;
      }
      setState(() {
        _items[idx] = existing.copyWith(
          qty: existing.qty + 1,
          totalPrice: lineTotal(existing.unitPrice, existing.qty + 1),
        );
      });
    } else {
      setState(() => _items.add(_newItem(product, 1, combination: combination)));
    }
  }

  /// A new cart line, priced and labelled as the picker does for a
  /// [combination]: its price adjustment, its own SKU when it has one.
  static OrderItem _newItem(Product product, double qty, {VariantCombination? combination}) {
    final price = product.sellingPrice + (combination?.priceAdjustment ?? 0);
    final comboSku = combination?.sku ?? '';
    return OrderItem(
      productId: product.id,
      productName: product.name,
      productSku: comboSku.isNotEmpty ? comboSku : product.sku,
      qty: qty,
      unit: product.unit,
      unitPrice: price,
      costPrice: product.costPrice,
      totalPrice: lineTotal(price, qty),
      variantCombinationKey: combination?.combinationKey ?? '',
      variantDisplayLabel: combination?.displayLabel ?? '',
    );
  }

  /// The stock a cart line may take: its combination's or the product's, as
  /// it is now in the database. Null when the product is gone.
  Future<({double stock, Product product})?> _stockFor(OrderItem item) async {
    final isar = await ref.read(isarProvider.future);
    final product = await isar.products.get(item.productId);
    if (product == null) return null;
    final stock = item.variantCombinationKey.isNotEmpty
        ? product.findCombination(item.variantCombinationKey)?.stockQty ?? 0
        : product.stockQty;
    return (stock: stock, product: product);
  }

  /// A weighed line's quantity box: reopens the quantity sheet.
  Future<void> _editQty(int index) async {
    final item = _items[index];
    final found = await _stockFor(item);
    if (!mounted) return;
    final qty = await showQuantitySheet(
      context,
      productName: item.displayName,
      unit: item.unit,
      unitPrice: item.unitPrice,
      available: found?.stock,
      initial: item.qty,
    );
    if (qty == null || !mounted || index >= _items.length) return;
    setState(() {
      _items[index] = item.copyWith(qty: qty, totalPrice: lineTotal(item.unitPrice, qty));
    });
  }

  Future<void> _updateQty(int index, int delta) async {
    final item = _items[index];
    final newQty = roundQty(item.qty + delta);
    if (newQty <= 0) {
      setState(() => _items.removeAt(index));
      return;
    }
    if (delta > 0) {
      final found = await _stockFor(item);
      if (found != null && qtyExceeds(newQty, found.stock)) {
        if (mounted) {
          final s = AppStrings.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.notEnoughStock(s.qty(found.stock, item.unit), item.displayName))),
          );
        }
        return;
      }
    }
    if (!mounted || index >= _items.length) return;
    setState(() {
      _items[index] = item.copyWith(qty: newQty, totalPrice: lineTotal(item.unitPrice, newQty));
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  /// The footer's Paid in full: the whole total, paid now, saved.
  Future<void> _submitPaidInFull() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).addAtLeastOneProduct)));
      return;
    }
    _amountPaidCtrl.text = _amountText(_readTotals().total);
    await _submit();
  }

  /// The footer's Credit / partial: shows the amount-paid block. Money left
  /// owing needs someone to owe it, so a walk-in sale asks for a customer.
  Future<void> _startCredit() async {
    setState(() {
      _creditMode = true;
      if (_amountPaidCtrl.text.isNotEmpty && (NumberInput.parseDecimal(_amountPaidCtrl.text) ?? 0) >= _readTotals().total) {
        _amountPaidCtrl.clear();
      }
    });
    if (_selectedCustomer == null) await _pickCustomer();
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).addAtLeastOneProduct)));
      return;
    }

    final t = _readTotals();
    if (t.overpaid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).amountPaidExceedsTotal)));
      return;
    }

    // Only an order with money still owing needs a customer: the Due Book
    // lists dues per customer, and a walk-in due would be lost there.
    if (_selectedCustomer == null && t.due > 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).customerNeededForCredit)));
      await _pickCustomer();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(orderProvider.notifier);
      final amountPaid = t.paid;
      final recurringDays = _recurringDays;

      final paymentStatus = amountPaid >= t.total
          ? PaymentStatus.paid
          : amountPaid > 0
          ? PaymentStatus.partial
          : PaymentStatus.unpaid;

      if (_isEditing) {
        final order = _existingOrder!.copyWith(
          customerId: _selectedCustomer?.id ?? 0,
          customerName: _selectedCustomer?.name ?? '',
          customerPhone: _selectedCustomer?.phone ?? '',
          items: _items,
          subtotal: t.subtotal,
          discountAmount: t.discount,
          deliveryFee: t.delivery,
          taxAmount: t.tax,
          totalAmount: t.total,
          amountPaid: amountPaid,
          paymentStatus: paymentStatus,
          paymentMethod: _paymentMethod,
          transactionId: _transactionIdCtrl.text.trim(),
          orderStatus: _orderStatus,
          notes: _notesCtrl.text.trim(),
          deliveryAddress: _deliveryAddressCtrl.text.trim(),
          estimatedDeliveryDate: _estimatedDeliveryDate,
          isRecurring: _isRecurring,
          recurringIntervalDays: _isRecurring ? recurringDays : 0,
          nextRecurringDate: _isRecurring ? DateTime.now().add(Duration(days: recurringDays)) : null,
          createdAt: _orderDate,
          updatedAt: DateTime.now(),
        );

        await notifier.updateOrder(order);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).orderUpdated), backgroundColor: Colors.green));
          context.pop();
        }
      } else {
        final orderNumber = await notifier.generateOrderNumber();

        final order = Order(
          orderNumber: orderNumber,
          customerId: _selectedCustomer?.id ?? 0,
          customerName: _selectedCustomer?.name ?? '',
          customerPhone: _selectedCustomer?.phone ?? '',
          items: _items,
          subtotal: t.subtotal,
          discountAmount: t.discount,
          deliveryFee: t.delivery,
          taxAmount: t.tax,
          totalAmount: t.total,
          amountPaid: amountPaid,
          paymentStatus: paymentStatus,
          paymentMethod: _paymentMethod,
          transactionId: _transactionIdCtrl.text.trim(),
          orderStatus: _orderStatus,
          notes: _notesCtrl.text.trim(),
          deliveryAddress: _deliveryAddressCtrl.text.trim(),
          estimatedDeliveryDate: _estimatedDeliveryDate,
          isRecurring: _isRecurring,
          recurringIntervalDays: _isRecurring ? recurringDays : 0,
          nextRecurringDate: _isRecurring ? DateTime.now().add(Duration(days: recurringDays)) : null,
          createdAt: _orderDate ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final newId = await notifier.createOrder(order);
        final saved = order.copyWith(id: newId);
        await OrderFormDefaults.remember(paymentMethod: _paymentMethod, orderStatus: _orderStatus);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).orderCreated),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          await _showInvoiceActions(saved);
          if (mounted) context.pop();
        }
      }
    } on OrderDateTooLate catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).orderDateTooLate(formatEntryDateTime(context, e.latest))),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).errorOccurred), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showInvoiceActions(Order order) async {
    final s = AppStrings.of(context);
    final pdfService = PdfService();
    final settings = ref.read(settingsProvider.notifier);
    final shopName = settings.shopName;
    final currencySymbol = settings.currencySymbol;
    final taxRate = settings.taxRate;

    Future<Uint8List>? receipt;
    Object? receiptColors;
    Future<Uint8List> receiptBytes() async {
      final colors = (DocumentBrand.color, DocumentBrand.onColor);
      if (receiptColors != colors) {
        receipt = null;
        receiptColors = colors;
      }
      final pending = receipt ??= pdfService.generateOrderReceipt(
        order,
        shopName: shopName,
        currencySymbol: currencySymbol,
        taxRate: taxRate,
      );
      try {
        return await pending;
      } catch (_) {
        if (identical(receipt, pending)) receipt = null;
        rethrow;
      }
    }

    await AppBottomSheet.show<void>(
      context,
      title: '${s.orderCreated}  ·  ${order.orderNumber}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          _InvoiceActionTile(
            icon: tabler.FileTypePdf.new,
            label: s.sharePdf,
            color: Colors.teal,
            onTap: (origin) async {
              return runWithProgress(context, () async {
                final bytes = await receiptBytes();
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/${order.orderNumber}.pdf');
                await file.writeAsBytes(bytes);
                final result = await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin));
                return result.status == ShareResultStatus.success;
              });
            },
          ),
          const SizedBox(height: 8),
          _InvoiceActionTile(
            icon: tabler.Download.new,
            label: s.downloadPdf,
            color: Colors.blue,
            onTap: (origin) async {

              if (pdfDownloadAsksWhereToSave) {
                final bytes = await runWithProgress(context, receiptBytes);
                return savePdfWithSystemSheet(
                  fileName: '${order.orderNumber}_invoice.pdf',
                  bytes: bytes,
                  shareOrigin: origin,
                );
              }

              var downloadDir = settings.downloadDirectory;
              if (downloadDir.isEmpty) {
                if (!mounted) return false;
                final picked = await FilePicker.getDirectoryPath(dialogTitle: 'Choose download folder');
                if (picked == null) return false;
                downloadDir = picked;
                await ref.read(settingsProvider.notifier).updateDownloadDirectory(downloadDir);
              }
              if (!mounted) return false;

              final path = await runWithProgress(context, () async {
                final file = File('$downloadDir/${order.orderNumber}_invoice.pdf');
                await file.writeAsBytes(await receiptBytes());
                return file.path;
              });

              if (mounted) {
                await showPdfSavedSheet(
                  context: context,
                  filePath: path,
                  savedToDirectory: downloadDir,
                );
              }
              return true;
            },
          ),
          const SizedBox(height: 8),
          _InvoiceActionTile(
            icon: tabler.Printer.new,
            label: s.print,
            color: Colors.indigo,
            onTap: (_) async {
              final bytes = await runWithProgress(context, receiptBytes);
              return Printing.layoutPdf(onLayout: (_) async => bytes);
            },
          ),
          const SizedBox(height: 8),
          _InvoiceActionTile(
            icon: tabler.Message.new,
            label: s.shareViaWhatsApp,
            color: Colors.green,
            onTap: (origin) async {
              final text = pdfService.generateWhatsAppText(order, currencySymbol: currencySymbol);
              final result = await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
              return result.status == ShareResultStatus.success;
            },
          ),
          const SizedBox(height: 8),
          _InvoiceActionTile(
            icon: tabler.Receipt.new,
            label: s.tr('posPrint'),
            color: Colors.deepOrange,
            onTap: (_) async {
              final posService = PosPrinterService.instance;
              final saved = await posService.loadSavedPrinters();
              final defaultAddr = await posService.loadDefaultPrinterAddress();
              if (saved.isEmpty || defaultAddr == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.tr('configurePrinterHint'))),
                  );
                }
                return false;
              }
              final defaultPrinter = saved.firstWhere(
                (p) => p.address == defaultAddr,
                orElse: () => saved.first,
              );
              final target = pos.Printer(
                name: defaultPrinter.name,
                address: defaultPrinter.address,
                connectionType: switch (defaultPrinter.type) {
                  'usb' => pos.ConnectionType.USB,
                  'network' => pos.ConnectionType.NETWORK,
                  _ => pos.ConnectionType.BLE,
                },
              );
              final connected = await posService.connectTo(target);
              if (!connected) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(s.tr('posPrintFailed')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return false;
              }
              final paperWidth = await posService.loadPaperWidth();
              final ok = await posService.printReceipt(
                order: order,
                shopName: settings.shopName,
                shopPhone: settings.shopPhone,
                currencySymbol: currencySymbol,
                paperWidth: paperWidth,
                printer: target,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? s.tr('posPrintSuccess') : s.tr('posPrintFailed')),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              }
              return ok;
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.done)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? s.editOrder : s.addOrder)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                _buildCustomerSection(theme, cs),
                const SizedBox(height: 16),

                _buildItemsSection(theme, cs),
                const SizedBox(height: 16),

                if (_creditMode) _buildPaymentSection(theme, cs) else _buildPaymentMethodSection(theme, cs),
                const SizedBox(height: 16),

                _buildMoreOptionsHeader(theme, cs),
                if (_showMore) ..._buildMoreOptions(theme, cs),

                const SizedBox(height: 24),
              ],
            ),
          ),

          _buildFooter(theme, cs),
        ],
      ),
    );
  }

  /// The fold-out header. Collapsed, it names what is set inside, so a
  /// discount or a Pending status is never hidden from the seller.
  Widget _buildMoreOptionsHeader(ThemeData theme, ColorScheme cs) {
    final s = AppStrings.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_moneyFields, _notesCtrl, _deliveryAddressCtrl]),
      builder: (context, _) {
        final t = _readTotals();
        final set = <String>[
          if (t.discount > 0) '${s.discount} ${CurrencyFormatter.format(t.discount)}',
          if (t.delivery > 0) '${s.deliveryFee} ${CurrencyFormatter.format(t.delivery)}',
          if (t.taxRate > 0) '${s.tax} ${t.taxRate.toStringAsFixed(t.taxRate == t.taxRate.roundToDouble() ? 0 : 1)}%',
          if (!_isEditing && _orderDate != null) formatEntryDateTime(context, _orderDate!),
          orderStatusLabel(context, _orderStatus),
          if (_notesCtrl.text.trim().isNotEmpty) s.notes,
          if (_deliveryAddressCtrl.text.trim().isNotEmpty || _estimatedDeliveryDate != null) s.delivery,
          if (_isRecurring) s.recurringOrder,
        ];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _showMore = !_showMore),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  ThinIcon(tabler.Adjustments.new, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.moreOptions, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (!_showMore)
                          Text(
                            set.join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                          ),
                      ],
                    ),
                  ),
                  ThinIcon(_showMore ? tabler.ChevronUp.new : tabler.ChevronDown.new, size: 20, color: cs.outline),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMoreOptions(ThemeData theme, ColorScheme cs) {
    final s = AppStrings.of(context);
    return [
                const SizedBox(height: 16),
                _buildPricingSection(theme, cs),
                const SizedBox(height: 16),

                if (_canSetOrderDate) ...[
                  EntryDateField(
                    label: s.orderDate,
                    value: _orderDate,
                    first: _firstOrderDate,
                    hint: s.entryDateHint,
                    onChanged: (d) => setState(() => _orderDate = d),
                    onReset: _isEditing ? null : () => setState(() => _orderDate = null),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildStatusSection(theme, cs),
                const SizedBox(height: 16),

                AppTextField(
                  label: s.notes,
                  controller: _notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  hint: s.tr('anySpecialInstructions'),
                ),

                const SizedBox(height: 16),
                Text(
                  s.delivery,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  label: s.deliveryAddress,
                  controller: _deliveryAddressCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  prefixIcon: const ThinIcon(tabler.TruckDelivery.new),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final from = _orderDate != null && _orderDate!.isBefore(now) ? _orderDate! : now;
                    final first = DateTime(from.year, from.month, from.day);
                    final last = now.add(const Duration(days: 365));
                    var initial = _estimatedDeliveryDate ?? now.add(const Duration(days: 3));
                    if (initial.isBefore(first)) initial = first;
                    if (initial.isAfter(last)) initial = last;
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: first,
                      lastDate: last,
                    );
                    if (picked != null) setState(() => _estimatedDeliveryDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        ThinIcon(tabler.Calendar.new, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _estimatedDeliveryDate != null
                                ? '${s.estimatedDelivery}: ${DateFormatter.format(_estimatedDeliveryDate)}'
                                : s.estimatedDelivery,
                            style: TextStyle(
                              color: _estimatedDeliveryDate != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        if (_estimatedDeliveryDate != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _estimatedDeliveryDate = null),
                            child: const ThinIcon(tabler.X.new, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(s.recurringOrder),
                  subtitle: Text(s.autoCreateOrder),
                  value: _isRecurring,
                  onChanged: (v) => setState(() => _isRecurring = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Flexible(child: Text(s.repeatEvery)),
                        const SizedBox(width: 8),

                        SizedBox(
                          width: math.max(60.0, 60 * MediaQuery.textScalerOf(context).scale(16) / 16),
                          child: TextField(
                            keyboardType: TextInputType.number,

                            inputFormatters: [const IntegerInputFormatter(), LengthLimitingTextInputFormatter(3)],
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                            ),
                            controller: _recurringDaysCtrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(s.days),
                      ],
                    ),
                  ),
    ];
  }

  Widget _buildCustomerSection(ThemeData theme, ColorScheme cs) {
    return GestureDetector(
      onTap: _pickCustomer,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ThinIcon(tabler.User.new, color: cs.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: _selectedCustomer != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedCustomer!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (_selectedCustomer!.phone.isNotEmpty)
                          Text(
                            _selectedCustomer!.phone,
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.of(context).walkInCustomer, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          AppStrings.of(context).selectCustomer,
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
            ),
            if (_selectedCustomer != null)
              GestureDetector(
                onTap: () => setState(() => _selectedCustomer = null),
                child: ThinIcon(tabler.X.new, size: 18, color: cs.outline),
              )
            else
              ThinIcon(tabler.ChevronRight.new, size: 20, color: cs.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppStrings.of(context).items,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${cartItemCount(_items)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              onPressed: _scanToAddItem,
              icon: const ThinIcon(tabler.Scan.new, size: 20),
              tooltip: AppStrings.of(context).scanQrBarcode,
            ),
            TextButton.icon(
              onPressed: _pickProducts,
              icon: const ThinIcon(tabler.Plus.new, size: 16),
              label: Text(AppStrings.of(context).add),
            ),
          ],
        ),
        _buildQuickAdd(cs),
        if (_items.isEmpty)
          GestureDetector(
            onTap: _pickProducts,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ThinIcon(tabler.ShoppingCartPlus.new, size: 28, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.of(context).tapToAddProducts,
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 12, endIndent: 12, color: cs.outline.withValues(alpha: 0.1)),
                  _buildItemTile(i, theme, cs),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// One-tap chips of the products sold most often lately. Nothing shows
  /// until there are sales to learn from, or while they load.
  Widget _buildQuickAdd(ColorScheme cs) {
    final products = ref.watch(quickAddProductsProvider).value ?? const <Product>[];
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final p in products)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ActionChip(
                  avatar: ThinIcon(tabler.Plus.new, size: 16, color: cs.primary),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  tooltip: AppStrings.of(context).quickAdd,
                  onPressed: () => _quickAdd(p),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const double _itemControlsWidth =2 + 28 + 20 + 28 + 12 + 70 + 4 + 16;

  static const double _minItemNameWidth = 48;

  Widget _buildItemTile(int index, ThemeData theme, ColorScheme cs) {
    final item = _items[index];
    final s = AppStrings.of(context);
    final unitPrice = s.pricePer(CurrencyFormatter.format(item.unitPrice), item.unit);
    final unitPriceStyle = TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5));
    const nameStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 13);
    const qtyStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 14);
    final qtyText = s.qty(item.qty, item.unit);

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.displayName, style: nameStyle),
        Text(unitPrice, style: unitPriceStyle),
      ],
    );

    final box = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
    );
    // A weighed line has no + / − (a step of 1 kg is rarely what's sold):
    // its box opens the quantity sheet.
    final qty = item.unit.allowsDecimal
        ? InkWell(
            onTap: () => _editQty(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: box,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(qtyText, style: qtyStyle),
                  const SizedBox(width: 6),
                  ThinIcon(tabler.Pencil.new, size: 16, color: cs.primary),
                ],
              ),
            ),
          )
        : Container(
            decoration: box,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qtyButton(tabler.Minus.new, () => _updateQty(index, -1), cs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(qtyText, style: qtyStyle),
                ),
                _qtyButton(tabler.Plus.new, () => _updateQty(index, 1), cs),
              ],
            ),
          );

    final total = Text(
      CurrencyFormatter.format(item.totalPrice),
      textAlign: TextAlign.right,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary),
      maxLines: 1,
    );

    final remove = GestureDetector(
      onTap: () => _removeItem(index),
      child: ThinIcon(tabler.X.new, size: 16, color: cs.error.withValues(alpha: 0.6)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

      child: LayoutBuilder(
        builder: (context, constraints) {
          final nameRoom = constraints.maxWidth - _itemControlsWidth - _lineWidth(context, qtyText, qtyStyle);
          final needed = item.displayName.split(' ').fold(
            math.max(
              MediaQuery.textScalerOf(context).scale(_minItemNameWidth),
              _lineWidth(context, unitPrice, unitPriceStyle),
            ),
            (widest, word) => math.max(widest, _lineWidth(context, word, nameStyle)),
          );
          if (nameRoom >= needed) {
            return Row(
              children: [
                Expanded(child: info),
                qty,
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: total),
                ),
                const SizedBox(width: 4),
                remove,
              ],
            );
          }
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 8),
                  remove,
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  qty,
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: total),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _qtyButton(ThinIconBuilder icon, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ThinIcon(icon, size: 16, color: cs.primary),
      ),
    );
  }

  Widget _buildPricingSection(ThemeData theme, ColorScheme cs) {
    final s = AppStrings.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: s.discount,
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [DecimalInputFormatter.money()],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: s.deliveryFee,
                controller: _deliveryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [DecimalInputFormatter.money()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ListenableBuilder(
          listenable: _moneyFields,
          builder: (context, _) {
            final tax = _readTotals().tax;
            return AppTextField(
              label: s.taxVat,
              controller: _taxRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter.percent()],
              prefixIcon: const ThinIcon(tabler.Percentage.new, size: 18),
              helperText: tax > 0 ? 'Tax: ${CurrencyFormatter.format(tax)}' : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusSection(ThemeData theme, ColorScheme cs) {
    const statuses = [OrderStatus.pending, OrderStatus.confirmed];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.of(context).tr('status'),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          children: statuses.map((s) {
            final selected = _orderStatus == s;
            final label = orderStatusLabel(context, s);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() {
                  _orderStatus = s;
                  _pickedStatus = true;
                }),
                selectedColor: cs.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? cs.primary : cs.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          }).toList(),
        ),
        if (statuses.contains(_orderStatus)) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThinIcon(tabler.InfoCircle.new, size: 16, color: cs.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _orderStatus == OrderStatus.pending
                      ? AppStrings.of(context).statusPendingHint
                      : AppStrings.of(context).statusConfirmedHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentSection(ThemeData theme, ColorScheme cs) {
    final s = AppStrings.of(context);
    const methods = PaymentMethod.values;
    final labels = {
      PaymentMethod.cash: s.cash,
      PaymentMethod.card: s.card,
      PaymentMethod.mfs: s.mfs,
      PaymentMethod.bank: s.bank,
      PaymentMethod.other: s.other,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.payment, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                label: s.amountPaid,
                hint: s.payLaterHint,
                controller: _amountPaidCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [DecimalInputFormatter.money()],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListenableBuilder(
                listenable: _moneyFields,
                builder: (context, child) {
                  final total = _readTotals().total;
                  return TextButton(

                    onPressed: total > 0
                        ? () => _amountPaidCtrl.text = _amountText(total)
                        : null,
                    child: child!,
                  );
                },
                child: Text(s.payFull),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: _moneyFields,
          builder: (context, _) {
            final t = _readTotals();
            if (t.total <= 0) return const SizedBox.shrink();
            if (t.overpaid) return _paymentStatusLine(tabler.AlertCircle.new, s.amountPaidExceedsTotal, cs.error);
            if (t.due <= 0.005) return _paymentStatusLine(tabler.CircleCheck.new, s.paidInFull, AppColors.paymentPaid);
            return _paymentStatusLine(
              tabler.Notebook.new,
              s.goesToDueBook(CurrencyFormatter.format(t.due)),
              AppColors.paymentPartial,
            );
          },
        ),
        const SizedBox(height: 12),
        Text(s.paymentMethod, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _paymentMethodChips(cs, methods, labels),
        const SizedBox(height: 12),
        AppTextField(label: s.transactionId, hint: s.transactionIdHint, controller: _transactionIdCtrl),
      ],
    );
  }

  /// A new counter sale's payment: only how it is paid. The transaction ID
  /// is asked only for a method that has one (not cash).
  Widget _buildPaymentMethodSection(ThemeData theme, ColorScheme cs) {
    final s = AppStrings.of(context);
    final labels = {
      PaymentMethod.cash: s.cash,
      PaymentMethod.card: s.card,
      PaymentMethod.mfs: s.mfs,
      PaymentMethod.bank: s.bank,
      PaymentMethod.other: s.other,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.paymentMethod, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _paymentMethodChips(cs, PaymentMethod.values, labels),
        if (_paymentMethod != PaymentMethod.cash) ...[
          const SizedBox(height: 12),
          AppTextField(label: s.transactionId, hint: s.transactionIdHint, controller: _transactionIdCtrl),
        ],
      ],
    );
  }

  Widget _paymentMethodChips(ColorScheme cs, List<PaymentMethod> methods, Map<PaymentMethod, String> labels) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: methods.map((m) {
        final selected = _paymentMethod == m;
        return ChoiceChip(
          label: Text(labels[m] ?? m.name),
          selected: selected,
          onSelected: (_) => setState(() {
            _paymentMethod = m;
            _pickedPaymentMethod = true;
          }),
          selectedColor: cs.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: selected ? cs.primary : cs.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }

  Widget _paymentStatusLine(ThinIconBuilder icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ThinIcon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, ColorScheme cs) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          ListenableBuilder(
            listenable: _moneyFields,
            builder: (context, _) {
              final t = _readTotals();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _summaryRow(s.subtotal, CurrencyFormatter.format(t.subtotal), theme),
                  if (t.discount > 0)
                    _summaryRow(s.discount, '- ${CurrencyFormatter.format(t.discount)}', theme, valueColor: Colors.green),
                  if (t.taxRate > 0)
                    _summaryRow(
                      '${s.tax} (${t.taxRate.toStringAsFixed(t.taxRate == t.taxRate.roundToDouble() ? 0 : 1)}%)',
                      CurrencyFormatter.format(t.tax),
                      theme,
                    ),
                  if (t.delivery > 0) _summaryRow(s.delivery, CurrencyFormatter.format(t.delivery), theme),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.total, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Flexible(child: _fitAmount(Text(
                        CurrencyFormatter.format(t.total),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary),
                        maxLines: 1,
                      ))),
                    ],
                  ),
                  if (_creditMode && t.total > 0 && t.paid > 0)
                    _summaryRow(s.amountPaid, CurrencyFormatter.format(t.paid), theme,
                        valueColor: AppColors.paymentPaid),
                  if (_creditMode && t.total > 0 && t.due > 0.005)
                    _summaryRow(s.due, CurrencyFormatter.format(t.due), theme,
                        valueColor: AppColors.paymentPartial),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (_creditMode)
            AppButton(
              label: _isEditing ? s.editOrder : s.addOrder,
              onPressed: _submit,
              isLoading: _isLoading,
              isFullWidth: true,
              height: 50,
              icon: tabler.Check.new,
            )
          else
            ButtonPair(
              first: AppButton(
                label: s.creditOrPartial,
                variant: AppButtonVariant.outlined,
                onPressed: _isLoading ? null : _startCredit,
                height: 50,
                icon: tabler.Notebook.new,
              ),
              second: AppButton(
                label: s.paidInFull,
                onPressed: _submitPaidInFull,
                isLoading: _isLoading,
                height: 50,
                icon: tabler.Check.new,
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, ThemeData theme, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          Flexible(child: _fitAmount(Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(color: valueColor, fontWeight: FontWeight.w500),
            maxLines: 1,
          ))),
        ],
      ),
    );
  }

  Widget _fitAmount(Widget amount) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: amount);
}

class _FormTotals {
  final double subtotal;
  final double discount;
  final double delivery;
  final double taxRate;
  final double tax;
  final double total;
  final double paid;

  const _FormTotals({
    required this.subtotal,
    required this.discount,
    required this.delivery,
    required this.taxRate,
    required this.tax,
    required this.total,
    required this.paid,
  });

  double get due => (total - paid).clamp(0, double.infinity);
  bool get overpaid => paid > total + 0.005;
}

class _ProductPickerSheet extends StatefulWidget {
  final Isar isar;
  final List<OrderItem> currentItems;
  final ValueChanged<List<OrderItem>> onChanged;
  final int? filterProductId;

  const _ProductPickerSheet({required this.isar, required this.currentItems, required this.onChanged, this.filterProductId});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  late final List<OrderItem> _items;

  late final Stream<List<Product>> _productsStream;
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<int> _expandedProducts = {};

  List<Product>? _source;
  List<(String, String)>? _searchKeys;
  String? _filteredQuery;
  List<Product> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.currentItems);
    var query = widget.isar.products.where().filter().isActiveEqualTo(true);
    if (widget.filterProductId != null) {
      query = query.and().idEqualTo(widget.filterProductId!);
    }
    _productsStream = query.sortByName().watch(fireImmediately: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _qtyOf(int productId, {String combinationKey = ''}) {
    final idx = _items.indexWhere((i) => i.productId == productId && i.variantCombinationKey == combinationKey);
    return idx >= 0 ? _items[idx].qty : 0;
  }

  void _setQty(
    Product product,
    double qty, {
    String combinationKey = '',
    String displayLabel = '',
    double? priceOverride,
    String? skuOverride,
    required double availableStock,
  }) {
    qty = roundQty(qty);
    if (qtyExceeds(qty, availableStock)) qty = availableStock;
    setState(() {
      final idx = _items.indexWhere((i) => i.productId == product.id && i.variantCombinationKey == combinationKey);
      final unitPrice = priceOverride ?? product.sellingPrice;
      if (qty <= 0) {
        if (idx >= 0) _items.removeAt(idx);
      } else if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(qty: qty, totalPrice: lineTotal(_items[idx].unitPrice, qty));
      } else {
        _items.add(
          OrderItem(
            productId: product.id,
            productName: product.name,
            productSku: skuOverride ?? product.sku,
            qty: qty,
            unit: product.unit,
            unitPrice: unitPrice,
            costPrice: product.costPrice,
            totalPrice: lineTotal(unitPrice, qty),
            variantCombinationKey: combinationKey,
            variantDisplayLabel: displayLabel,
          ),
        );
      }
    });
    widget.onChanged(_items);
  }

  /// A weighed product's Add (or its quantity, once in the cart): asks how
  /// much in the quantity sheet, over this picker.
  Future<void> _askQty(
    Product product, {
    String combinationKey = '',
    String displayLabel = '',
    double? priceOverride,
    String? skuOverride,
    required double availableStock,
  }) async {
    final current = _qtyOf(product.id, combinationKey: combinationKey);
    final qty = await showQuantitySheet(
      context,
      productName: displayLabel.isEmpty ? product.name : '${product.name} ($displayLabel)',
      unit: product.unit,
      unitPrice: priceOverride ?? product.sellingPrice,
      available: availableStock,
      initial: current > 0 ? current : null,
    );
    if (qty == null || !mounted) return;
    _setQty(
      product,
      qty,
      combinationKey: combinationKey,
      displayLabel: displayLabel,
      priceOverride: priceOverride,
      skuOverride: skuOverride,
      availableStock: availableStock,
    );
  }

  List<Product> _filterProducts(List<Product> all) {
    if (!identical(all, _source)) {
      _source = all;
      _searchKeys = null;
      _filteredQuery = null;
    }
    if (_query != _filteredQuery) {
      _filteredQuery = _query;
      if (_query.isEmpty) {
        _filtered = all;
      } else {
        final keys = _searchKeys ??= [for (final p in all) (p.name.toLowerCase(), p.sku.toLowerCase())];
        _filtered = [
          for (var i = 0; i < all.length; i++)
            if (keys[i].$1.contains(_query) || keys[i].$2.contains(_query)) all[i],
        ];
      }
    }
    return _filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, snapshot) {

        final loading = !snapshot.hasData && !snapshot.hasError;
        return _buildSheet(context, theme, cs, loading ? null : snapshot.data ?? const []);
      },
    );
  }

  Widget _buildSheet(BuildContext context, ThemeData theme, ColorScheme cs, List<Product>? allProducts) {
    final filtered = allProducts == null ? const <Product>[] : _filterProducts(allProducts);

    final totalItems = cartItemCount(_items);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [

          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [

                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        AppStrings.of(context).addItems,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (totalItems > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$totalItems item${totalItems == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.of(context).done)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: AppStrings.of(context).searchByNameOrSku,
                prefixIcon: const ThinIcon(tabler.Search.new, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        tooltip: AppStrings.of(context).clearSearch,
                        icon: const ThinIcon(tabler.X.new, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Expanded(
            child: allProducts == null
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.of(context).noProductsFound,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                    ),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
                    itemBuilder: (_, i) {
                      final p = filtered[i];

                      if (p.hasVariants) {

                        final activeCombos = p.variantCombinations
                            .where((c) => c.isActive && (c.stockQty > 0 || c.priceAdjustment != 0 || c.sku.isNotEmpty))
                            .toList();
                        if (activeCombos.isEmpty) {

                          return const SizedBox.shrink();
                        }
                        final isExpanded = _expandedProducts.contains(p.id);
                        return Column(
                          children: [

                            InkWell(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expandedProducts.remove(p.id);
                                } else {
                                  _expandedProducts.add(p.id);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          Text(
                                            '${activeCombos.length} combination${activeCombos.length == 1 ? '' : 's'}',
                                            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ThinIcon(
                                      isExpanded ? tabler.ChevronUp.new : tabler.ChevronDown.new,
                                      size: 20,
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (isExpanded)
                              ...activeCombos.map((c) {
                                final comboPrice = p.sellingPrice + c.priceAdjustment;
                                final comboSku = c.sku.isNotEmpty ? c.sku : p.sku;
                                final outOfStock = c.stockQty <= 0;
                                final qty = _qtyOf(p.id, combinationKey: c.combinationKey);

                                return Padding(
                                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, row) => Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.displayLabel,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: outOfStock ? cs.onSurface.withValues(alpha: 0.4) : null,
                                                  ),
                                                ),

                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        AppStrings.of(context).pricePer(CurrencyFormatter.format(comboPrice), p.unit),
                                                        style: TextStyle(fontSize: 12, color: cs.primary),
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                    Text(
                                                      '  ·  ${AppStrings.of(context).qty(c.stockQty, p.unit)} ${AppStrings.of(context).tr('inStockLabel')}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: outOfStock
                                                            ? cs.error
                                                            : cs.onSurface.withValues(alpha: 0.5),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (qty > 0)
                                            _qtyControl(
                                              p,
                                              qty,
                                              cs,
                                              available: c.stockQty,
                                              onStep: (q) => _setQty(
                                                p,
                                                q,
                                                combinationKey: c.combinationKey,
                                                displayLabel: c.displayLabel,
                                                priceOverride: comboPrice,
                                                skuOverride: comboSku,
                                                availableStock: c.stockQty,
                                              ),
                                              onAsk: () => _askQty(
                                                p,
                                                combinationKey: c.combinationKey,
                                                displayLabel: c.displayLabel,
                                                priceOverride: comboPrice,
                                                skuOverride: comboSku,
                                                availableStock: c.stockQty,
                                              ),
                                            )
                                          else
                                            _addButton(
                                              row.maxWidth,
                                              outOfStock: outOfStock,
                                              onAdd: () => p.unit.allowsDecimal
                                                  ? _askQty(
                                                      p,
                                                      combinationKey: c.combinationKey,
                                                      displayLabel: c.displayLabel,
                                                      priceOverride: comboPrice,
                                                      skuOverride: comboSku,
                                                      availableStock: c.stockQty,
                                                    )
                                                  : _setQty(
                                                      p,
                                                      1,
                                                      combinationKey: c.combinationKey,
                                                      displayLabel: c.displayLabel,
                                                      priceOverride: comboPrice,
                                                      skuOverride: comboSku,
                                                      availableStock: c.stockQty,
                                                    ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        );
                      }

                      final qty = _qtyOf(p.id);
                      final outOfStock = p.stockQty <= 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LayoutBuilder(
                          builder: (context, row) => Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: outOfStock ? cs.onSurface.withValues(alpha: 0.4) : null,
                                      ),
                                    ),

                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            AppStrings.of(context).pricePer(CurrencyFormatter.format(p.sellingPrice), p.unit),
                                            style: TextStyle(fontSize: 12, color: cs.primary),
                                            maxLines: 1,
                                          ),
                                        ),
                                        Text(
                                          '  ·  ${AppStrings.of(context).qty(p.stockQty, p.unit)} ${AppStrings.of(context).tr('inStockLabel')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: outOfStock ? cs.error : cs.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (qty > 0)
                                _qtyControl(
                                  p,
                                  qty,
                                  cs,
                                  available: p.stockQty,
                                  onStep: (q) => _setQty(p, q, availableStock: p.stockQty),
                                  onAsk: () => _askQty(p, availableStock: p.stockQty),
                                )
                              else
                                _addButton(
                                  row.maxWidth,
                                  outOfStock: outOfStock,
                                  onAdd: p.unit.allowsDecimal
                                      ? () => _askQty(p, availableStock: p.stockQty)
                                      : () => _setQty(p, 1, availableStock: p.stockQty),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _addButton(double rowWidth, {required bool outOfStock, required VoidCallback onAdd}) {
    final s = AppStrings.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: rowWidth * 0.55),
      child: SizedBox(
        height: 34,
        child: FilledButton.tonal(
          onPressed: outOfStock ? null : onAdd,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(outOfStock ? s.outOfStock : s.add)),
        ),
      ),
    );
  }

  /// A picked product's quantity: + / − for counted goods, or for weighed
  /// ones a box showing "1.25 kg" that reopens the quantity sheet.
  Widget _qtyControl(
    Product p,
    double qty,
    ColorScheme cs, {
    required double available,
    required ValueChanged<double> onStep,
    required VoidCallback onAsk,
  }) {
    final s = AppStrings.of(context);
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
    );
    final label = Text(
      s.qty(qty, p.unit),
      style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
    );
    if (p.unit.allowsDecimal) {
      return InkWell(
        onTap: onAsk,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [label, const SizedBox(width: 6), ThinIcon(tabler.Pencil.new, size: 16, color: cs.primary)],
          ),
        ),
      );
    }
    return Container(
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetQtyBtn(tabler.Minus.new, () => onStep(qty - 1), cs),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: label),
          _sheetQtyBtn(tabler.Plus.new, qtyAtLeast(qty, available) ? null : () => onStep(qty + 1), cs),
        ],
      ),
    );
  }

  Widget _sheetQtyBtn(ThinIconBuilder icon, VoidCallback? onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ThinIcon(icon, size: 16, color: onTap != null ? cs.primary : cs.onSurface.withValues(alpha: 0.25)),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final Isar isar;

  const _CustomerPickerSheet({required this.customers, required this.isar});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  bool _showForm = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  late List<Customer> _filtered = widget.customers;
  late final List<String> _lowerNames = [for (final c in widget.customers) c.name.toLowerCase()];

  void _setQuery(String query) {
    setState(() {
      _query = query;
      final customers = widget.customers;
      _filtered = query.isEmpty
          ? customers
          : [
              for (var i = 0; i < customers.length; i++)

                if (_lowerNames[i].contains(query) || NumberInput.phoneMatches(customers[i].phone, query)) customers[i],
            ];
    });
  }

  void _openForm() {

    final q = _searchCtrl.text.trim();
    final digits = NumberInput.toAsciiDigits(q);
    final isPhone = RegExp(r'^[0-9]{3,}$').hasMatch(digits);
    setState(() {
      _showForm = true;
      if (isPhone) {
        _phoneCtrl.text = digits;
      } else if (q.isNotEmpty) {
        _nameCtrl.text = q;
      }
    });
  }

  Future<void> _saveCustomer() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty && phone.isEmpty) return;

    final customerName = name.isNotEmpty ? name : phone;

    setState(() => _saving = true);

    try {
      final customer = Customer(
        name: customerName,
        phone: phone,
        address: _addressCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await widget.isar.writeTxn(() async => widget.isar.customers.put(customer));
      final saved = await widget.isar.customers.get(customer.id);
      if (mounted) Navigator.pop(context, saved ?? customer);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).failedToSaveCustomer)));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: _showForm ? 0.55 : 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [

          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_showForm)
                  GestureDetector(
                    onTap: () => setState(() => _showForm = false),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ThinIcon(tabler.ArrowLeft.new, size: 20, color: cs.onSurface),
                    ),
                  ),
                Flexible(
                  child: Text(
                    _showForm ? s.createNewCustomer : s.selectCustomer,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          if (_showForm)

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: s.customerName,
                      prefixIcon: const ThinIcon(tabler.User.new, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [PhoneInputFormatter()],
                    decoration: InputDecoration(
                      labelText: s.phone,
                      prefixIcon: const ThinIcon(tabler.Phone.new, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: s.address,
                      prefixIcon: const ThinIcon(tabler.MapPin.new, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveCustomer,
                    icon: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,

                            child: Builder(
                              builder: (context) => CircularProgressIndicator(
                                strokeWidth: 2,
                                color: IconTheme.of(context).color,
                              ),
                            ),
                          )
                        : const ThinIcon(tabler.Check.new, size: 18),
                    label: Text(_saving ? s.tr('loading') : s.addAndSelect),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ],
              ),
            )
          else ...[

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => _setQuery(v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: s.searchByNameOrPhone,
                  prefixIcon: const ThinIcon(tabler.Search.new, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          tooltip: AppStrings.of(context).clearSearch,
                          icon: const ThinIcon(tabler.X.new, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _setQuery('');
                          },
                        )
                      : null,
                  isDense: true,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: _openForm,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      ThinIcon(tabler.UserPlus.new, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.createNewCustomer,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.primary),
                        ),
                      ),
                      ThinIcon(tabler.ChevronRight.new, size: 14, color: cs.primary.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 2),

            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(s.noCustomersFound, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
                    )
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pop(ctx, c),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: cs.primary.withValues(alpha: 0.1),
                            child: Text(
                              c.name[0].toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary, fontSize: 14),
                            ),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: c.phone.isNotEmpty
                              ? Text(
                                  c.phone,
                                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                                )
                              : null,
                          dense: true,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvoiceActionTile extends StatefulWidget {
  final ThinIconBuilder icon;
  final String label;
  final Color color;

  final Future<bool> Function(Rect? origin) onTap;

  const _InvoiceActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  State<_InvoiceActionTile> createState() => _InvoiceActionTileState();
}

class _InvoiceActionTileState extends State<_InvoiceActionTile> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.label;
    final color = _done ? AppColors.paymentPaid : widget.color;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final done = await widget.onTap(shareOriginOf(context));
          if (done && mounted) setState(() => _done = true);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
              final longestWord = label
                  .split(' ')
                  .fold(0.0, (widest, word) => math.max(widest, _lineWidth(context, word, style)));
              final chevronWidth = IconTheme.of(context).size ?? 24;
              final showChevron = constraints.maxWidth - 40 - 14 - chevronWidth >= longestWord;
              return Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ThinIcon(_done ? tabler.CircleCheck.new : widget.icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(label, style: style)),
                  if (showChevron)
                    ThinIcon(tabler.ChevronRight.new, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What the order form's scanner found: the product, the combination whose
/// own SKU was scanned (if any), and a scale label's quantity (if any).
typedef _ScanHit = ({Product product, VariantCombination? combination, double? qty});

class _ScannerSheet extends ConsumerStatefulWidget {
  final Isar isar;
  final DeviceChannel deviceChannel;

  const _ScannerSheet({required this.isar, required this.deviceChannel});

  @override
  ConsumerState<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends ConsumerState<_ScannerSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  late final CameraSession _session;
  bool _scanned = false;
  final Future<ScaleLabelSettings> _scale = ScaleLabelSettings.load();

  @override
  void initState() {
    super.initState();
    _session = CameraSession(_controller, widget.deviceChannel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session.setVisible(TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _session.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final value = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (value == null) return;
    _scanned = true;

    _scale.then((scale) => ProductRepository(widget.isar).findByScan(value, scale)).then((hit) {
      if (!mounted) return;
      final product = hit?.product;
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).noProductMatched)),
        );
        _scanned = false;
        return;
      }

      final combination = hit!.combination;
      final noStock = combination != null
          ? combination.stockQty <= 0
          : !product.hasVariants && product.stockQty <= 0;
      if (noStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).outOfStock)),
        );
        _scanned = false;
        return;
      }

      if (product.hasVariants) {
        final hasStock = product.variantCombinations.any(
          (c) => c.isActive && c.stockQty > 0,
        );
        if (!hasStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).outOfStock)),
          );
          _scanned = false;
          return;
        }
      }

      Navigator.of(context).pop((
        product: product,
        combination: combination,
        qty: hit.label?.qtyFor(product, combination: combination),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  AppStrings.of(context).scanQrBarcode,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TorchButton(controller: _controller),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const ThinIcon(tabler.X.new),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ScannerPreview(
                    session: _session,
                    onDetect: _onDetect,
                    overlay: Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              AppStrings.of(context).pointCameraAtCode,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _lineWidth(BuildContext context, String text, TextStyle? style) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
