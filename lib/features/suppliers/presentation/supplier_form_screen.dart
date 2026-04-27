import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../data/models/supplier.dart';
import '../providers/supplier_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final Supplier? supplier;
  final int? supplierId;

  const SupplierFormScreen({super.key, this.supplier, this.supplierId});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;
  Supplier? _existing;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    if (widget.supplier != null) {
      _populate(widget.supplier!);
    } else if (widget.supplierId != null) {
      final isar = await ref.read(isarProvider.future);
      final s = await isar.suppliers.get(widget.supplierId!);
      if (s != null && mounted) {
        _existing = s;
        _populate(s);
      }
    }
  }

  void _populate(Supplier s) {
    _existing = s;
    _nameCtrl.text = s.name;
    _phoneCtrl.text = s.phone;
    _emailCtrl.text = s.email;
    _addressCtrl.text = s.address;
    _companyCtrl.text = s.company;
    _notesCtrl.text = s.notes;
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _companyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final supplier = Supplier(
        id: _existing?.id ?? Isar.autoIncrement,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        totalPurchases: _existing?.totalPurchases ?? 0,
        totalPaid: _existing?.totalPaid ?? 0,
        totalDue: _existing?.totalDue ?? 0,
        createdAt: _existing?.createdAt,
      );
      if (_existing != null) {
        await ref.read(supplierProvider.notifier).updateSupplier(supplier);
      } else {
        await ref.read(supplierProvider.notifier).addSupplier(supplier);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.of(context).savedSuccessfully),
          backgroundColor: Colors.green,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).tr('failedToSaveSupplier')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isEdit = _existing != null || widget.supplierId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? s.editSupplier : s.addSupplier)),
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
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.company,
                controller: _companyCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.phone,
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+\-\s]')),
                ],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.tr('email'),
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.address,
                controller: _addressCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: s.notes,
                controller: _notesCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: isEdit ? s.editSupplier : s.addSupplier,
                onPressed: _submit,
                isLoading: _isLoading,
                isFullWidth: true,
                height: 52,
                icon: isEdit ? Icons.save_rounded : Icons.add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
