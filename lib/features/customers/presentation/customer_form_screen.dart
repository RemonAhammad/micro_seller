import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../data/models/customer.dart';
import '../providers/customer_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final Customer? customer;
  final int? customerId;

  const CustomerFormScreen({super.key, this.customer, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() =>
      _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  CustomerTag _tag = CustomerTag.newCustomer;
  bool _isLoading = false;
  Customer? _existing;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.customer != null) {
      _populate(widget.customer!);
    } else if (widget.customerId != null) {
      final isar = await ref.read(isarProvider.future);
      final c = await isar.customers.get(widget.customerId!);
      if (c != null && mounted) {
        _existing = c;
        _populate(c);
      }
    }
  }

  void _populate(Customer c) {
    _nameCtrl.text = c.name;
    _phoneCtrl.text = c.phone;
    _addressCtrl.text = c.address;
    _notesCtrl.text = c.notes;
    setState(() => _tag = c.tag);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final existing = _existing ?? widget.customer;
      final customer = Customer(
        id: existing?.id ?? Isar.autoIncrement,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        tag: _tag,
        totalOrders: existing?.totalOrders ?? 0,
        totalSpent: existing?.totalSpent ?? 0,
        outstandingBalance: existing?.outstandingBalance ?? 0,
        createdAt: existing?.createdAt,
      );

      if (existing != null) {
        await ref.read(customerProvider.notifier).updateCustomer(customer);
      } else {
        await ref.read(customerProvider.notifier).addCustomer(customer);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).savedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).failedToSaveCustomer),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isEdit = widget.customer != null || widget.customerId != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? s.editCustomer : s.addCustomer),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: s.customerName,
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Name'),
                textInputAction: TextInputAction.next,
                prefixIcon: const ThinIcon(tabler.User.new),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.phone,
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
                ],
                validator: Validators.phone,
                textInputAction: TextInputAction.next,
                prefixIcon: const ThinIcon(tabler.Phone.new),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.address,
                controller: _addressCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                prefixIcon: const ThinIcon(tabler.MapPin.new),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.notes,
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              Text(s.tr('customerType'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )),
              const SizedBox(height: 10),
              Row(
                children: CustomerTag.values.map((tag) {
                  final label = switch (tag) {
                    CustomerTag.newCustomer => s.tagNew,
                    CustomerTag.regular => s.regular,
                    CustomerTag.vip => s.vip,
                  };
                  final isSelected = _tag == tag;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _tag = tag),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          // A third of a narrow row: a large text size
                          // shrinks the label to fit rather than breaking
                          // the word.
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              AppButton(
                label: isEdit ? s.editCustomer : s.addCustomer,
                onPressed: _submit,
                isLoading: _isLoading,
                isFullWidth: true,
                height: 52,
                icon: isEdit ? tabler.DeviceFloppy.new : tabler.UserPlus.new,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
