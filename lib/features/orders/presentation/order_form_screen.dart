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
import '../../../data/models/customer.dart';
import '../providers/order_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/document_brand.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/pdf_saved_sheet.dart';
import '../../settings/providers/settings_provider.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

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
  // Held in State: one made in build was swapped on every rebuild (resetting
  // the cursor) and never disposed.
  final _recurringDaysCtrl = TextEditingController(text: '30');

  /// The fields the totals depend on. Only the widgets that show totals listen
  /// to them, so a keystroke doesn't rebuild the whole form.
  late final Listenable _moneyFields = Listenable.merge([_discountCtrl, _deliveryCtrl, _taxRateCtrl, _amountPaidCtrl]);

  Customer? _selectedCustomer;
  final List<OrderItem> _items = [];
  OrderStatus _orderStatus = OrderStatus.pending;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DateTime? _estimatedDeliveryDate;
  bool _isRecurring = false;
  bool _isLoading = false;

  Order? _existingOrder;

  bool get _isEditing => _existingOrder != null;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    // Default tax rate from settings
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
    }
  }

  void _populateForm(Order order) {
    _existingOrder = order;
    _selectedCustomer = Customer(id: order.customerId, name: order.customerName, phone: order.customerPhone);
    _items
      ..clear()
      ..addAll(order.items.map((i) => i.copyWith()));
    _discountCtrl.text = order.discountAmount > 0
        ? order.discountAmount.toStringAsFixed(order.discountAmount == order.discountAmount.roundToDouble() ? 0 : 2)
        : '0';
    _deliveryCtrl.text = order.deliveryFee > 0
        ? order.deliveryFee.toStringAsFixed(order.deliveryFee == order.deliveryFee.roundToDouble() ? 0 : 2)
        : '0';
    _amountPaidCtrl.text = order.amountPaid > 0
        ? order.amountPaid.toStringAsFixed(order.amountPaid == order.amountPaid.roundToDouble() ? 0 : 2)
        : '';
    _transactionIdCtrl.text = order.transactionId;
    // Back-calculate tax rate from stored taxAmount
    if (order.taxAmount > 0) {
      final taxableAmount = order.subtotal - order.discountAmount;
      if (taxableAmount > 0) {
        final rate = order.taxAmount / taxableAmount * 100;
        _taxRateCtrl.text = rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2);
      }
    }
    _notesCtrl.text = order.notes;
    _deliveryAddressCtrl.text = order.deliveryAddress;
    _estimatedDeliveryDate = order.estimatedDeliveryDate;
    _isRecurring = order.isRecurring;
    _recurringDaysCtrl.text = '${order.recurringIntervalDays > 0 ? order.recurringIntervalDays : 30}';
    _orderStatus = order.orderStatus;
    _paymentMethod = order.paymentMethod;
    setState(() {});
  }

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

  /// Parses the money fields and sums the items once. Each place that shows a
  /// total reads one of these instead of a chain of getters.
  _FormTotals _readTotals() {
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final delivery = double.tryParse(_deliveryCtrl.text) ?? 0;
    final taxRate = double.tryParse(_taxRateCtrl.text) ?? 0;
    final totals = orderTotals(subtotal: subtotal, discount: discount, taxRate: taxRate, delivery: delivery);
    return _FormTotals(
      subtotal: subtotal,
      discount: discount,
      delivery: delivery,
      taxRate: taxRate,
      tax: totals.tax,
      total: totals.total,
      paid: double.tryParse(_amountPaidCtrl.text) ?? 0,
    );
  }

  int get _recurringDays => int.tryParse(_recurringDaysCtrl.text) ?? 30;

  // ─── Customer ────────────────────────────────────────────────────────

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

  // ─── Products ────────────────────────────────────────────────────────

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

  Future<void> _updateQty(int index, int delta) async {
    final item = _items[index];
    final newQty = item.qty + delta;
    if (newQty <= 0) {
      setState(() => _items.removeAt(index));
      return;
    }
    if (delta > 0) {
      final isar = await ref.read(isarProvider.future);
      final product = await isar.products.get(item.productId);
      if (product != null) {
        int stock;
        if (item.variantCombinationKey.isNotEmpty) {
          final combo = product.findCombination(item.variantCombinationKey);
          stock = combo?.stockQty ?? 0;
        } else {
          stock = product.stockQty;
        }
        if (newQty > stock) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).notEnoughStock(stock, item.displayName))));
          }
          return;
        }
      }
    }
    setState(() {
      _items[index] = item.copyWith(qty: newQty, totalPrice: item.unitPrice * newQty);
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  // ─── Submit ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).pleaseSelectCustomer)));
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).addAtLeastOneProduct)));
      return;
    }

    final t = _readTotals();
    if (t.overpaid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).amountPaidExceedsTotal)));
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final newId = await notifier.createOrder(order);
        final saved = order.copyWith(id: newId);

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

  // ─── Post-creation invoice actions ───────────────────────────────────

  Future<void> _showInvoiceActions(Order order) async {
    final s = AppStrings.of(context);
    final pdfService = PdfService();
    final settings = ref.read(settingsProvider.notifier);
    final shopName = settings.shopName;
    final currencySymbol = settings.currencySymbol;
    final taxRate = settings.taxRate;

    // Rendered once per sheet and shared by Share / Download / Print. Dropped
    // on failure so the next tap retries instead of replaying the error, and
    // when the color theme's document colors it's drawn in have changed.
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
          // Each action keeps its own fixed color, as each sidebar tab does:
          // following the color theme, this one would be Print's very color
          // under Indigo, and close to Download's under Blue.
          _InvoiceActionTile(
            icon: tabler.FileTypePdf.new,
            label: s.sharePdf,
            color: Colors.teal,
            onTap: () async {
              await runWithProgress(context, () async {
                final bytes = await receiptBytes();
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/${order.orderNumber}.pdf');
                await file.writeAsBytes(bytes);
                await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
              });
            },
          ),
          const SizedBox(height: 8),
          _InvoiceActionTile(
            icon: tabler.Download.new,
            label: s.downloadPdf,
            color: Colors.blue,
            onTap: () async {
              // iOS: no folder to keep (pdfDownloadAsksWhereToSave); the
              // system's save sheet asks where, each time.
              if (pdfDownloadAsksWhereToSave) {
                final bytes = await runWithProgress(context, receiptBytes);
                await savePdfWithSystemSheet(
                  fileName: '${order.orderNumber}_invoice.pdf',
                  bytes: bytes,
                );
                return;
              }
              // Folder first: cancelling the picker shouldn't cost a render.
              var downloadDir = settings.downloadDirectory;
              if (downloadDir.isEmpty) {
                if (!mounted) return;
                final picked = await FilePicker.getDirectoryPath(dialogTitle: 'Choose download folder');
                if (picked == null) return;
                downloadDir = picked;
                await ref.read(settingsProvider.notifier).updateDownloadDirectory(downloadDir);
              }
              if (!mounted) return;

              final path = await runWithProgress(context, () async {
                final file = File('$downloadDir/${order.orderNumber}_invoice.pdf');
                await file.writeAsBytes(await receiptBytes());
                return file.path;
              });
              // After the spinner closes: runWithProgress pops the top route.
              if (mounted) {
                await showPdfSavedSheet(
                  context: context,
                  filePath: path,
                  savedToDirectory: downloadDir,
                );
              }
            },
          ),
          const SizedBox(height: 8),
          _InvoiceActionTile(
            icon: tabler.Printer.new,
            label: s.print,
            color: Colors.indigo,
            onTap: () async {
              final bytes = await runWithProgress(context, receiptBytes);
              await Printing.layoutPdf(onLayout: (_) async => bytes);
            },
          ),
          const SizedBox(height: 8),
          _InvoiceActionTile(
            icon: tabler.Message.new,
            label: s.shareViaWhatsApp,
            color: Colors.green,
            onTap: () async {
              final text = pdfService.generateWhatsAppText(order, currencySymbol: currencySymbol);
              await SharePlus.instance.share(ShareParams(text: text));
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.done)),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────

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
                // ── Customer selector ──
                _buildCustomerSection(theme, cs),
                const SizedBox(height: 16),

                // ── Items ──
                _buildItemsSection(theme, cs),
                const SizedBox(height: 16),

                // ── Pricing fields ──
                _buildPricingSection(theme, cs),
                const SizedBox(height: 16),

                // ── Payment: amount paid → rest goes to the Due Book ──
                _buildPaymentSection(theme, cs),
                const SizedBox(height: 16),

                // ── Order status ──
                _buildStatusSection(theme, cs),
                const SizedBox(height: 16),


                // ── Notes ──
                AppTextField(
                  label: s.notes,
                  controller: _notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  hint: s.tr('anySpecialInstructions'),
                ),

                // ── Delivery ──
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
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _estimatedDeliveryDate ?? DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
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

                // ── Recurring ──
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
                        // Room for three digits at any text size: the
                        // theme's 16 px side padding left them 20 px.
                        SizedBox(
                          width: math.max(60.0, 60 * MediaQuery.textScalerOf(context).scale(16) / 16),
                          child: TextField(
                            keyboardType: TextInputType.number,
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

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Footer ──
          _buildFooter(theme, cs),
        ],
      ),
    );
  }

  // ─── Customer Section ────────────────────────────────────────────────

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
                  : Text(
                      AppStrings.of(context).selectCustomer,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
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

  // ─── Items Section ───────────────────────────────────────────────────

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
                  '${_items.fold<int>(0, (s, i) => s + i.qty)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
                ),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _pickProducts,
              icon: const ThinIcon(tabler.Plus.new, size: 16),
              label: Text(AppStrings.of(context).add),
            ),
          ],
        ),
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

  /// What an item row puts beside the name, less the quantity's digits: the
  /// quantity box (two 28 px buttons, 20 px around the number, its border)
  /// and the 12 + 70 px total, 4 px and the 16 px remove icon.
  static const double _itemControlsWidth = 2 + 28 + 20 + 28 + 12 + 70 + 4 + 16;

  /// The narrowest the name gets beside them at 100% text.
  static const double _minItemNameWidth = 48;

  Widget _buildItemTile(int index, ThemeData theme, ColorScheme cs) {
    final item = _items[index];
    final unitPrice = CurrencyFormatter.format(item.unitPrice);
    final unitPriceStyle = TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5));
    const nameStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 13);
    const qtyStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 14);
    // Product info
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.displayName, style: nameStyle),
        Text(unitPrice, style: unitPriceStyle),
      ],
    );

    // Qty controls
    final qty = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(tabler.Minus.new, () => _updateQty(index, -1), cs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${item.qty}', style: qtyStyle),
          ),
          _qtyButton(tabler.Plus.new, () => _updateQty(index, 1), cs),
        ],
      ),
    );

    // Total: shrunk to fit rather than broken over two lines.
    final total = Text(
      CurrencyFormatter.format(item.totalPrice),
      textAlign: TextAlign.right,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary),
      maxLines: 1,
    );

    // Delete
    final remove = GestureDetector(
      onTap: () => _removeItem(index),
      child: ThinIcon(tabler.X.new, size: 16, color: cs.error.withValues(alpha: 0.6)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // One row while the name keeps some room (its longest word, and the
      // unit price, each on a line); otherwise (narrow layout, large text, a
      // long quantity) the quantity and total go under the name, which keeps
      // the full width.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nameRoom = constraints.maxWidth - _itemControlsWidth - _lineWidth(context, '${item.qty}', qtyStyle);
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

  // ─── Pricing ─────────────────────────────────────────────────────────

  Widget _buildPricingSection(ThemeData theme, ColorScheme cs) {
    final s = AppStrings.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: s.discount,
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: s.deliveryFee,
                controller: _deliveryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Rebuilt on its own: the helper text shows the computed tax.
        ListenableBuilder(
          listenable: _moneyFields,
          builder: (context, _) {
            final tax = _readTotals().tax;
            return AppTextField(
              label: s.taxVat,
              controller: _taxRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
              prefixIcon: const ThinIcon(tabler.Percentage.new, size: 18),
              helperText: tax > 0 ? 'Tax: ${CurrencyFormatter.format(tax)}' : null,
            );
          },
        ),
      ],
    );
  }

  // ─── Status ──────────────────────────────────────────────────────────

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
            final label = s.name[0].toUpperCase() + s.name.substring(1);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _orderStatus = s),
                selectedColor: cs.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? cs.primary : cs.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Payment Method ──────────────────────────────────────────────────

  /// Amount paid (with Pay Full), a live paid / due readout, method, and
  /// transaction id. Whatever isn't paid here goes to the Due Book.
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
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
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
                    // Setting the text notifies _moneyFields; no setState needed.
                    onPressed: total > 0
                        ? () => _amountPaidCtrl.text = total.toStringAsFixed(total == total.roundToDouble() ? 0 : 2)
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
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: methods.map((m) {
            final selected = _paymentMethod == m;
            return ChoiceChip(
              label: Text(labels[m] ?? m.name),
              selected: selected,
              onSelected: (_) => setState(() => _paymentMethod = m),
              selectedColor: cs.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: selected ? cs.primary : cs.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        AppTextField(label: s.transactionId, hint: s.transactionIdHint, controller: _transactionIdCtrl),
      ],
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

  // ─── Footer ──────────────────────────────────────────────────────────

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
          // Summary rows — the only part of the footer that follows the money fields.
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
                  if (t.total > 0 && t.paid > 0)
                    _summaryRow(s.amountPaid, CurrencyFormatter.format(t.paid), theme,
                        valueColor: AppColors.paymentPaid),
                  if (t.total > 0 && t.due > 0.005)
                    _summaryRow(s.due, CurrencyFormatter.format(t.due), theme,
                        valueColor: AppColors.paymentPartial),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          AppButton(
            label: _isEditing ? s.editOrder : s.addOrder,
            onPressed: _submit,
            isLoading: _isLoading,
            isFullWidth: true,
            height: 50,
            icon: tabler.Check.new,
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

  /// [amount] at the end of its row, shrunk when it doesn't fit beside its
  /// label (narrow layout, large text) — never cut off.
  Widget _fitAmount(Widget amount) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: amount);
}

/// One read of the order form's money: items subtotal, the parsed discount /
/// delivery / tax-rate / amount-paid fields, and [orderTotals]' tax and total.
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

  /// What the customer still owes on this order — goes to the Due Book.
  double get due => (total - paid).clamp(0, double.infinity);
  bool get overpaid => paid > total + 0.005;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Product Picker — stays open, multi-add, shows stock
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductPickerSheet extends StatefulWidget {
  final Isar isar;
  final List<OrderItem> currentItems;
  final ValueChanged<List<OrderItem>> onChanged;

  const _ProductPickerSheet({required this.isar, required this.currentItems, required this.onChanged});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  late final List<OrderItem> _items;
  // Created once: a new watch() per build restarts the watcher and re-reads every product.
  late final Stream<List<Product>> _productsStream;
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<int> _expandedProducts = {};

  // Search memo, rebuilt only when the stream emits a new list or the query changes.
  List<Product>? _source;
  List<(String, String)>? _searchKeys;
  String? _filteredQuery;
  List<Product> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.currentItems);
    _productsStream = widget.isar.products
        .where()
        .filter()
        .isActiveEqualTo(true)
        .sortByName()
        .watch(fireImmediately: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _qtyOf(int productId, {String combinationKey = ''}) {
    final idx = _items.indexWhere((i) => i.productId == productId && i.variantCombinationKey == combinationKey);
    return idx >= 0 ? _items[idx].qty : 0;
  }

  void _setQty(
    Product product,
    int qty, {
    String combinationKey = '',
    String displayLabel = '',
    double? priceOverride,
    String? skuOverride,
    required int availableStock,
  }) {
    if (qty > availableStock) qty = availableStock;
    setState(() {
      final idx = _items.indexWhere((i) => i.productId == product.id && i.variantCombinationKey == combinationKey);
      final unitPrice = priceOverride ?? product.sellingPrice;
      if (qty <= 0) {
        if (idx >= 0) _items.removeAt(idx);
      } else if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(qty: qty, totalPrice: _items[idx].unitPrice * qty);
      } else {
        _items.add(
          OrderItem(
            productId: product.id,
            productName: product.name,
            productSku: skuOverride ?? product.sku,
            qty: qty,
            unitPrice: unitPrice,
            costPrice: product.costPrice,
            totalPrice: unitPrice * qty,
            variantCombinationKey: combinationKey,
            variantDisplayLabel: displayLabel,
          ),
        );
      }
    });
    widget.onChanged(_items);
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
        // null until the first emission (spinner); an error still falls back to the empty state.
        final loading = !snapshot.hasData && !snapshot.hasError;
        return _buildSheet(context, theme, cs, loading ? null : snapshot.data ?? const []);
      },
    );
  }

  Widget _buildSheet(BuildContext context, ThemeData theme, ColorScheme cs, List<Product>? allProducts) {
    final filtered = allProducts == null ? const <Product>[] : _filterProducts(allProducts);

    final totalItems = _items.fold<int>(0, (s, i) => s + i.qty);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // The count wraps under the title when both don't fit
                // beside Done.
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

          // Search
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

          // Product list
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
                        // Only show combinations that are active and have been configured
                        final activeCombos = p.variantCombinations
                            .where((c) => c.isActive && (c.stockQty > 0 || c.priceAdjustment != 0 || c.sku.isNotEmpty))
                            .toList();
                        if (activeCombos.isEmpty) {
                          // No configured combos — skip this product
                          return const SizedBox.shrink();
                        }
                        final isExpanded = _expandedProducts.contains(p.id);
                        return Column(
                          children: [
                            // Parent product row (tap to expand)
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
                            // Expanded combination rows
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
                                                // Stock wraps under the price when
                                                // both don't fit; the price shrinks
                                                // rather than being cut off.
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        CurrencyFormatter.format(comboPrice),
                                                        style: TextStyle(fontSize: 12, color: cs.primary),
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                    Text(
                                                      '  ·  ${c.stockQty} in stock',
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
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _sheetQtyBtn(
                                                    tabler.Minus.new,
                                                    () => _setQty(
                                                      p,
                                                      qty - 1,
                                                      combinationKey: c.combinationKey,
                                                      displayLabel: c.displayLabel,
                                                      priceOverride: comboPrice,
                                                      skuOverride: comboSku,
                                                      availableStock: c.stockQty,
                                                    ),
                                                    cs,
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    child: Text(
                                                      '$qty',
                                                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
                                                    ),
                                                  ),
                                                  _sheetQtyBtn(
                                                    tabler.Plus.new,
                                                    qty >= c.stockQty
                                                        ? null
                                                        : () => _setQty(
                                                            p,
                                                            qty + 1,
                                                            combinationKey: c.combinationKey,
                                                            displayLabel: c.displayLabel,
                                                            priceOverride: comboPrice,
                                                            skuOverride: comboSku,
                                                            availableStock: c.stockQty,
                                                          ),
                                                    cs,
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            _addButton(
                                              row.maxWidth,
                                              outOfStock: outOfStock,
                                              onAdd: () => _setQty(
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

                      // Non-variant product (original behavior)
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
                                    // As for a combination above.
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            CurrencyFormatter.format(p.sellingPrice),
                                            style: TextStyle(fontSize: 12, color: cs.primary),
                                            maxLines: 1,
                                          ),
                                        ),
                                        Text(
                                          '  ·  ${p.stockQty} in stock',
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
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _sheetQtyBtn(
                                        tabler.Minus.new,
                                        () => _setQty(p, qty - 1, availableStock: p.stockQty),
                                        cs,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          '$qty',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
                                        ),
                                      ),
                                      _sheetQtyBtn(
                                        tabler.Plus.new,
                                        qty >= p.stockQty ? null : () => _setQty(p, qty + 1, availableStock: p.stockQty),
                                        cs,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                _addButton(
                                  row.maxWidth,
                                  outOfStock: outOfStock,
                                  onAdd: () => _setQty(p, 1, availableStock: p.stockQty),
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

  /// Add (or a disabled Out of stock). It takes at most a bit over half the
  /// [rowWidth]: with large text its label shrinks rather than squeezing
  /// the name beside it down to a few letters a line.
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

// ═══════════════════════════════════════════════════════════════════════════════
// Customer Picker — search, pick, or create via inline form
// ═══════════════════════════════════════════════════════════════════════════════

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

  // Inline form state
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

  // Rebuilt only when the query changes, not on every read in build.
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
                if (_lowerNames[i].contains(query) || customers[i].phone.contains(query)) customers[i],
            ];
    });
  }

  void _openForm() {
    // Pre-fill from search query
    final q = _searchCtrl.text.trim();
    final isPhone = RegExp(r'^\d{3,}$').hasMatch(q);
    setState(() {
      _showForm = true;
      if (isPhone) {
        _phoneCtrl.text = q;
      } else if (q.isNotEmpty) {
        _nameCtrl.text = q;
      }
    });
  }

  Future<void> _saveCustomer() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty && phone.isEmpty) return;

    // If only phone provided, use phone as name placeholder
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
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
          ),

          // Title
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
            // ── Inline create form ──
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
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]'))],
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
                            // The button's own icon color, like the check it
                            // replaces: white was all but invisible on the
                            // disabled button while saving.
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
            // ── Search ──
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

            // ── Always-visible create button ──
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

            // ── Customer list ──
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

class _InvoiceActionTile extends StatelessWidget {
  final ThinIconBuilder icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;

  const _InvoiceActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          // The chevron gives way when the label's longest word wouldn't fit
          // beside it (narrow layout, large text): a word broken in two reads
          // worse than a missing arrow.
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
                    child: ThinIcon(icon, color: color, size: 20),
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

/// The width [text] takes on one line in [style] as a [Text] draws it here:
/// over the ambient text style, at the ambient text size, bold if the phone
/// asks for it (the Bold text setting).
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
