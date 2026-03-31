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
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _deliveryCtrl = TextEditingController(text: '0');
  final _amountPaidCtrl = TextEditingController();

  Customer? _selectedCustomer;
  final List<OrderItem> _items = [];
  OrderStatus _orderStatus = OrderStatus.pending;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _discountCtrl.dispose();
    _deliveryCtrl.dispose();
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _delivery => double.tryParse(_deliveryCtrl.text) ?? 0;
  double get _total => _subtotal - _discount + _delivery;

  Future<void> _addProduct() async {
    final isar = await ref.read(isarProvider.future);
    final products = await isar.products.where().findAll();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(
        products: products,
        onSelected: (product, qty) {
          setState(() {
            final existingIndex =
                _items.indexWhere((i) => i.productId == product.id);
            if (existingIndex >= 0) {
              final existing = _items[existingIndex];
              _items[existingIndex] = existing.copyWith(
                qty: existing.qty + qty,
                totalPrice: existing.unitPrice * (existing.qty + qty),
              );
            } else {
              _items.add(OrderItem(
                productId: product.id,
                productName: product.name,
                productSku: product.sku,
                qty: qty,
                unitPrice: product.sellingPrice,
                totalPrice: product.sellingPrice * qty,
              ));
            }
          });
        },
      ),
    );
  }

  Future<void> _selectCustomer() async {
    final isar = await ref.read(isarProvider.future);
    final customers = await isar.customers.where().findAll();

    if (!mounted) return;

    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CustomerPickerSheet(customers: customers),
    );

    if (selected != null) {
      setState(() => _selectedCustomer = selected);
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(orderNotifierProvider.notifier);
      final orderNumber = await notifier.generateOrderNumber();
      final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? 0;

      final paymentStatus = amountPaid >= _total
          ? PaymentStatus.paid
          : amountPaid > 0
              ? PaymentStatus.partial
              : PaymentStatus.unpaid;

      final order = Order(
        orderNumber: orderNumber,
        customerId: _selectedCustomer?.id ?? 0,
        customerName: _selectedCustomer?.name ?? '',
        customerPhone: _selectedCustomer?.phone ?? '',
        items: _items,
        subtotal: _subtotal,
        discountAmount: _discount,
        deliveryFee: _delivery,
        totalAmount: _total,
        amountPaid: amountPaid,
        paymentStatus: paymentStatus,
        orderStatus: _orderStatus,
        notes: _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notifier.createOrder(order);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addOrder)),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer
                    GestureDetector(
                      onTap: _selectCustomer,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_rounded,
                                  color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _selectedCustomer != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedCustomer!.name,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                        if (_selectedCustomer!.phone.isNotEmpty)
                                          Text(
                                            _selectedCustomer!.phone,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    )
                                  : Text(
                                      'Select Customer (optional)',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.5),
                                      ),
                                    ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: theme.colorScheme.outline),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        TextButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Product'),
                        ),
                      ],
                    ),
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                theme.colorScheme.outline.withOpacity(0.2),
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Tap "Add Product" to add items',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: _items.asMap().entries.map((e) {
                            final idx = e.key;
                            final item = e.value;
                            return Dismissible(
                              key: Key('item_$idx'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child:
                                    const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) {
                                setState(() => _items.removeAt(idx));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.productName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                            '${CurrencyFormatter.format(item.unitPrice)} × ${item.qty}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(item.totalPrice),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Pricing
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Discount',
                            controller: _discountCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d*'))
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
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d*'))
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Amount Paid',
                      controller: _amountPaidCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                      ],
                      helperText: 'Leave empty if unpaid',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: AppStrings.notes,
                      controller: _notesCtrl,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Order status selector
                    DropdownButtonFormField<OrderStatus>(
                      value: _orderStatus,
                      decoration: const InputDecoration(labelText: 'Order Status'),
                      items: OrderStatus.values.map((s) {
                        final label = s.name[0].toUpperCase() + s.name.substring(1);
                        return DropdownMenuItem(value: s, child: Text(label));
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _orderStatus = v ?? _orderStatus),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Order summary footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text(CurrencyFormatter.format(_subtotal)),
                    ],
                  ),
                  if (_discount > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount'),
                        Text(
                          '- ${CurrencyFormatter.format(_discount)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  if (_delivery > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery'),
                        Text(CurrencyFormatter.format(_delivery)),
                      ],
                    ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        CurrencyFormatter.format(_total),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Create Order',
                    onPressed: _submit,
                    isLoading: _isLoading,
                    isFullWidth: true,
                    height: 52,
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;
  final void Function(Product, int qty) onSelected;

  const _ProductPickerSheet(
      {required this.products, required this.onSelected});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final product = filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  title: Text(product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${CurrencyFormatter.format(product.sellingPrice)} · ${product.stockQty} in stock'),
                  trailing: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onSelected(product, 1);
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(60, 36)),
                    child: const Text('Add'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;

  const _CustomerPickerSheet({required this.customers});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.customers
        : widget.customers
            .where((c) =>
                c.name.toLowerCase().contains(_query) ||
                c.phone.contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final customer = filtered[i];
                return ListTile(
                  onTap: () => Navigator.pop(ctx, customer),
                  leading: CircleAvatar(
                    child: Text(customer.name[0]),
                  ),
                  title: Text(customer.name),
                  subtitle: customer.phone.isNotEmpty
                      ? Text(customer.phone)
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
