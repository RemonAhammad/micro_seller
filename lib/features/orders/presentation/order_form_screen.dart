import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_item.dart';
import '../../../data/models/product.dart';
import '../../../data/models/customer.dart';
import '../providers/order_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../../settings/providers/settings_provider.dart';
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
  final _deliveryAddressCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();

  Customer? _selectedCustomer;
  final List<OrderItem> _items = [];
  OrderStatus _orderStatus = OrderStatus.pending;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DateTime? _estimatedDeliveryDate;
  bool _isRecurring = false;
  int _recurringDays = 30;
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
        _taxRateCtrl.text = settingsTaxRate.toStringAsFixed(
            settingsTaxRate == settingsTaxRate.roundToDouble() ? 0 : 2);
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
    _selectedCustomer = Customer(
      id: order.customerId,
      name: order.customerName,
      phone: order.customerPhone,
    );
    _items
      ..clear()
      ..addAll(order.items.map((i) => i.copyWith()));
    _discountCtrl.text = order.discountAmount > 0
        ? order.discountAmount.toStringAsFixed(
            order.discountAmount == order.discountAmount.roundToDouble() ? 0 : 2)
        : '0';
    _deliveryCtrl.text = order.deliveryFee > 0
        ? order.deliveryFee.toStringAsFixed(
            order.deliveryFee == order.deliveryFee.roundToDouble() ? 0 : 2)
        : '0';
    _amountPaidCtrl.text = order.amountPaid > 0
        ? order.amountPaid.toStringAsFixed(
            order.amountPaid == order.amountPaid.roundToDouble() ? 0 : 2)
        : '';
    // Back-calculate tax rate from stored taxAmount
    if (order.taxAmount > 0) {
      final taxableAmount = order.subtotal - order.discountAmount;
      if (taxableAmount > 0) {
        final rate = order.taxAmount / taxableAmount * 100;
        _taxRateCtrl.text = rate.toStringAsFixed(
            rate == rate.roundToDouble() ? 0 : 2);
      }
    }
    _notesCtrl.text = order.notes;
    _deliveryAddressCtrl.text = order.deliveryAddress;
    _estimatedDeliveryDate = order.estimatedDeliveryDate;
    _isRecurring = order.isRecurring;
    _recurringDays = order.recurringIntervalDays > 0 ? order.recurringIntervalDays : 30;
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
    _deliveryAddressCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _delivery => double.tryParse(_deliveryCtrl.text) ?? 0;

  double get _taxRate => double.tryParse(_taxRateCtrl.text) ?? 0;

  double get _taxAmount =>
      _taxRate > 0 ? (_subtotal - _discount).clamp(0, double.infinity) * _taxRate / 100 : 0;

  double get _total =>
      (_subtotal - _discount + _taxAmount + _delivery).clamp(0, double.infinity);

  // ─── Customer ────────────────────────────────────────────────────────

  Future<void> _pickCustomer() async {
    final isar = await ref.read(isarProvider.future);
    final customers = await isar.customers.where().sortByName().findAll();
    if (!mounted) return;

    final result = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CustomerPickerSheet(
        customers: customers,
        isar: isar,
      ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Only $stock in stock for ${item.displayName}')),
            );
          }
          return;
        }
      }
    }
    setState(() {
      _items[index] = item.copyWith(
        qty: newQty,
        totalPrice: item.unitPrice * newQty,
      );
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  // ─── Submit ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(orderNotifierProvider.notifier);
      final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? 0;

      final paymentStatus = amountPaid >= _total
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
          subtotal: _subtotal,
          discountAmount: _discount,
          deliveryFee: _delivery,
          taxAmount: _taxAmount,
          totalAmount: _total,
          amountPaid: amountPaid,
          paymentStatus: paymentStatus,
          paymentMethod: _paymentMethod,
          orderStatus: _orderStatus,
          notes: _notesCtrl.text.trim(),
          deliveryAddress: _deliveryAddressCtrl.text.trim(),
          estimatedDeliveryDate: _estimatedDeliveryDate,
          isRecurring: _isRecurring,
          recurringIntervalDays: _isRecurring ? _recurringDays : 0,
          nextRecurringDate: _isRecurring ? DateTime.now().add(Duration(days: _recurringDays)) : null,
          updatedAt: DateTime.now(),
        );

        await notifier.updateOrder(order);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order updated'),
              backgroundColor: Colors.green,
            ),
          );
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
          subtotal: _subtotal,
          discountAmount: _discount,
          deliveryFee: _delivery,
          taxAmount: _taxAmount,
          totalAmount: _total,
          amountPaid: amountPaid,
          paymentStatus: paymentStatus,
          paymentMethod: _paymentMethod,
          orderStatus: _orderStatus,
          notes: _notesCtrl.text.trim(),
          deliveryAddress: _deliveryAddressCtrl.text.trim(),
          estimatedDeliveryDate: _estimatedDeliveryDate,
          isRecurring: _isRecurring,
          recurringIntervalDays: _isRecurring ? _recurringDays : 0,
          nextRecurringDate: _isRecurring ? DateTime.now().add(Duration(days: _recurringDays)) : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await notifier.createOrder(order);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order created'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Failed to update order. Please try again.'
                : 'Failed to create order. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Order' : s.addOrder)),
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

                // ── Order status ──
                _buildStatusSection(theme, cs),
                const SizedBox(height: 16),

                // ── Payment method ──
                _buildPaymentMethodSection(theme, cs),
                const SizedBox(height: 16),

                // ── Notes ──
                AppTextField(
                  label: s.notes,
                  controller: _notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  hint: 'Any special instructions...',
                ),

                // ── Delivery ──
                const SizedBox(height: 16),
                Text('Delivery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
                const SizedBox(height: 8),
                AppTextField(
                  label: 'Delivery Address',
                  controller: _deliveryAddressCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
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
                        Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          _estimatedDeliveryDate != null
                              ? 'Est. Delivery: ${DateFormatter.format(_estimatedDeliveryDate)}'
                              : 'Set Estimated Delivery Date',
                          style: TextStyle(
                            color: _estimatedDeliveryDate != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        if (_estimatedDeliveryDate != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _estimatedDeliveryDate = null),
                            child: const Icon(Icons.clear, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Recurring ──
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Recurring Order'),
                  subtitle: const Text('Auto-create this order periodically'),
                  value: _isRecurring,
                  onChanged: (v) => setState(() => _isRecurring = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Text('Repeat every'),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(isDense: true),
                            controller: TextEditingController(text: '$_recurringDays'),
                            onChanged: (v) => _recurringDays = int.tryParse(v) ?? 30,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('days'),
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
            Icon(Icons.person_outline, color: cs.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: _selectedCustomer != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomer!.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_selectedCustomer!.phone.isNotEmpty)
                          Text(
                            _selectedCustomer!.phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    )
                  : Text(
                      'Select or create customer',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
            ),
            if (_selectedCustomer != null)
              GestureDetector(
                onTap: () => setState(() => _selectedCustomer = null),
                child: Icon(Icons.close, size: 18, color: cs.outline),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: cs.outline),
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
            Text('Items',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _pickProducts,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
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
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_shopping_cart,
                      size: 28, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to add products',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
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

  Widget _buildItemTile(int index, ThemeData theme, ColorScheme cs) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  CurrencyFormatter.format(item.unitPrice),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Qty controls
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qtyButton(Icons.remove, () => _updateQty(index, -1), cs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.qty}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                _qtyButton(Icons.add, () => _updateQty(index, 1), cs),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Total
          SizedBox(
            width: 70,
            child: Text(
              CurrencyFormatter.format(item.totalPrice),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: cs.primary,
              ),
            ),
          ),

          // Delete
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeItem(index),
            child: Icon(Icons.close, size: 16, color: cs.error.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: cs.primary),
      ),
    );
  }

  // ─── Pricing ─────────────────────────────────────────────────────────

  Widget _buildPricingSection(ThemeData theme, ColorScheme cs) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Discount',
                controller: _discountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Delivery Fee',
                controller: _deliveryCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Tax / VAT (%)',
          controller: _taxRateCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
          ],
          onChanged: (_) => setState(() {}),
          prefixIcon: const Icon(Icons.percent, size: 18),
          helperText: _taxAmount > 0
              ? 'Tax: ${CurrencyFormatter.format(_taxAmount)}'
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Amount Paid',
                controller: _amountPaidCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextButton(
                onPressed: _total > 0
                    ? () => setState(() => _amountPaidCtrl.text =
                        _total.toStringAsFixed(_total == _total.roundToDouble() ? 0 : 2))
                    : null,
                child: const Text('Pay Full'),
              ),
            ),
          ],
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
        Text('Status',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
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

  Widget _buildPaymentMethodSection(ThemeData theme, ColorScheme cs) {
    const methods = PaymentMethod.values;
    const labels = {
      PaymentMethod.cash: 'Cash',
      PaymentMethod.card: 'Card',
      PaymentMethod.mfs: 'MFS',
      PaymentMethod.bank: 'Bank',
      PaymentMethod.other: 'Other',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
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
      ],
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────────

  Widget _buildFooter(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary rows
          _summaryRow('Subtotal', CurrencyFormatter.format(_subtotal), theme),
          if (_discount > 0)
            _summaryRow(
              'Discount',
              '- ${CurrencyFormatter.format(_discount)}',
              theme,
              valueColor: Colors.green,
            ),
          if (_taxRate > 0)
            _summaryRow(
              'Tax (${_taxRate.toStringAsFixed(_taxRate == _taxRate.roundToDouble() ? 0 : 1)}%)',
              CurrencyFormatter.format(_taxAmount),
              theme,
            ),
          if (_delivery > 0)
            _summaryRow('Delivery', CurrencyFormatter.format(_delivery), theme),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                CurrencyFormatter.format(_total),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: _isEditing ? 'Update Order' : 'Create Order',
            onPressed: _submit,
            isLoading: _isLoading,
            isFullWidth: true,
            height: 50,
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, ThemeData theme,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: valueColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Product Picker — stays open, multi-add, shows stock
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductPickerSheet extends StatefulWidget {
  final Isar isar;
  final List<OrderItem> currentItems;
  final ValueChanged<List<OrderItem>> onChanged;

  const _ProductPickerSheet({
    required this.isar,
    required this.currentItems,
    required this.onChanged,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  late final List<OrderItem> _items;
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<int> _expandedProducts = {};
  // Per-product attribute selections for stepped variant picker
  final Map<int, Map<String, String>> _selections = {};

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.currentItems);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _qtyOf(int productId, {String combinationKey = ''}) {
    final idx = _items.indexWhere((i) =>
        i.productId == productId &&
        i.variantCombinationKey == combinationKey);
    return idx >= 0 ? _items[idx].qty : 0;
  }

  void _setQty(Product product, int qty,
      {String combinationKey = '', String displayLabel = '',
       double? priceOverride, String? skuOverride,
       required int availableStock}) {
    if (qty > availableStock) qty = availableStock;
    setState(() {
      final idx = _items.indexWhere((i) =>
          i.productId == product.id &&
          i.variantCombinationKey == combinationKey);
      final unitPrice = priceOverride ?? product.sellingPrice;
      if (qty <= 0) {
        if (idx >= 0) _items.removeAt(idx);
      } else if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(
          qty: qty,
          totalPrice: _items[idx].unitPrice * qty,
        );
      } else {
        _items.add(OrderItem(
          productId: product.id,
          productName: product.name,
          productSku: skuOverride ?? product.sku,
          qty: qty,
          unitPrice: unitPrice,
          costPrice: product.costPrice,
          totalPrice: unitPrice * qty,
          variantCombinationKey: combinationKey,
          variantDisplayLabel: displayLabel,
        ));
      }
    });
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<List<Product>>(
      stream: widget.isar.products
          .where()
          .filter()
          .isActiveEqualTo(true)
          .sortByName()
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        final allProducts = snapshot.data ?? [];
        return _buildSheet(context, theme, cs, allProducts);
      },
    );
  }

  Widget _buildSheet(BuildContext context, ThemeData theme, ColorScheme cs, List<Product> allProducts) {
    final filtered = _query.isEmpty
        ? allProducts
        : allProducts
            .where((p) =>
                p.name.toLowerCase().contains(_query) ||
                p.sku.toLowerCase().contains(_query))
            .toList();

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
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Add Products',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (totalItems > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalItems item${totalItems == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
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
                hintText: 'Search by name or SKU...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
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
            child: filtered.isEmpty
                ? Center(
                    child: Text('No products found',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4))))
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
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
                                          Text(p.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              )),
                                          Text(
                                            '${activeCombos.length} combination${activeCombos.length == 1 ? '' : 's'}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface.withValues(alpha: 0.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
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
                                final qty = _qtyOf(p.id,
                                    combinationKey: c.combinationKey);

                                return Padding(
                                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(c.displayLabel,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: outOfStock
                                                        ? cs.onSurface
                                                            .withValues(alpha: 0.4)
                                                        : null,
                                                  )),
                                              Row(
                                                children: [
                                                  Text(
                                                      CurrencyFormatter.format(
                                                          comboPrice),
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: cs.primary)),
                                                  Text(
                                                    '  ·  ${c.stockQty} in stock',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: outOfStock
                                                          ? cs.error
                                                          : cs.onSurface
                                                              .withValues(alpha: 0.5),
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
                                              border: Border.all(
                                                  color: cs.primary
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _sheetQtyBtn(
                                                    Icons.remove,
                                                    () => _setQty(p, qty - 1,
                                                        combinationKey: c.combinationKey,
                                                        displayLabel: c.displayLabel,
                                                        priceOverride: comboPrice,
                                                        skuOverride: comboSku,
                                                        availableStock: c.stockQty),
                                                    cs),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 10),
                                                  child: Text('$qty',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: cs.primary)),
                                                ),
                                                _sheetQtyBtn(
                                                    Icons.add,
                                                    qty >= c.stockQty ? null : () => _setQty(p, qty + 1,
                                                        combinationKey: c.combinationKey,
                                                        displayLabel: c.displayLabel,
                                                        priceOverride: comboPrice,
                                                        skuOverride: comboSku,
                                                        availableStock: c.stockQty),
                                                    cs),
                                              ],
                                            ),
                                          )
                                        else
                                          SizedBox(
                                            height: 34,
                                            child: FilledButton.tonal(
                                              onPressed: outOfStock
                                                  ? null
                                                  : () => _setQty(p, 1,
                                                      combinationKey: c.combinationKey,
                                                      displayLabel: c.displayLabel,
                                                      priceOverride: comboPrice,
                                                      skuOverride: comboSku,
                                                      availableStock: c.stockQty),
                                              style: FilledButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                              ),
                                              child: Text(outOfStock
                                                  ? 'Out of stock'
                                                  : 'Add'),
                                            ),
                                          ),
                                      ],
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: outOfStock
                                            ? cs.onSurface.withValues(alpha: 0.4)
                                            : null,
                                      )),
                                  Row(
                                    children: [
                                      Text(
                                          CurrencyFormatter.format(
                                              p.sellingPrice),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: cs.primary)),
                                      Text(
                                        '  ·  ${p.stockQty} in stock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: outOfStock
                                              ? cs.error
                                              : cs.onSurface
                                                  .withValues(alpha: 0.5),
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
                                  border: Border.all(
                                      color: cs.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _sheetQtyBtn(Icons.remove,
                                        () => _setQty(p, qty - 1, availableStock: p.stockQty), cs),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text('$qty',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: cs.primary)),
                                    ),
                                    _sheetQtyBtn(Icons.add,
                                        qty >= p.stockQty ? null : () => _setQty(p, qty + 1, availableStock: p.stockQty), cs),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                height: 34,
                                child: FilledButton.tonal(
                                  onPressed:
                                      outOfStock ? null : () => _setQty(p, 1, availableStock: p.stockQty),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  child: Text(
                                      outOfStock ? 'Out of stock' : 'Add'),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sheetQtyBtn(IconData icon, VoidCallback? onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16,
            color: onTap != null ? cs.primary : cs.onSurface.withValues(alpha: 0.25)),
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

  List<Customer> get _filtered => _query.isEmpty
      ? widget.customers
      : widget.customers
          .where((c) =>
              c.name.toLowerCase().contains(_query) ||
              c.phone.contains(_query))
          .toList();

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

      await widget.isar
          .writeTxn(() async => widget.isar.customers.put(customer));
      final saved = await widget.isar.customers.get(customer.id);
      if (mounted) Navigator.pop(context, saved ?? customer);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create customer')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
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
                      child: Icon(Icons.arrow_back, size: 20, color: cs.onSurface),
                    ),
                  ),
                Text(
                  _showForm ? 'New Customer' : 'Select Customer',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
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
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveCustomer,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Add & Select'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
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
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
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
                      Icon(Icons.person_add_outlined,
                          size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Create New Customer',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: cs.primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: cs.primary.withValues(alpha: 0.6)),
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
                      child: Text('No customers found',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4))))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: cs.outline.withValues(alpha: 0.1)),
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pop(ctx, c),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                cs.primary.withValues(alpha: 0.1),
                            child: Text(
                              c.name[0].toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                  fontSize: 14),
                            ),
                          ),
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: c.phone.isNotEmpty
                              ? Text(c.phone,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5)))
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
