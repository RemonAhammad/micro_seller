import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:isar/isar.dart';
import '../../../data/models/product.dart';
import '../../../data/models/variant_attribute.dart';
import '../../../data/models/variant_combination.dart';
import '../providers/product_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/variant_utils.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/screens/qr_scanner_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final int? productId;

  const ProductFormScreen({super.key, this.product, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();

  String? _imagePath;
  bool _isLoading = false;
  Product? _existingProduct;

  // ── Hierarchical Variant State ──
  final List<_AttributeEntry> _attributes = [];
  List<_CombinationEntry> _combinations = [];

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    if (widget.product != null) {
      _populateForm(widget.product!);
    } else if (widget.productId != null) {
      final isar = await ref.read(isarProvider.future);
      final product = await isar.products.get(widget.productId!);
      if (product != null && mounted) {
        _existingProduct = product;
        _populateForm(product);
      }
    }
  }

  void _populateForm(Product product) {
    _nameCtrl.text = product.name;
    _skuCtrl.text = product.sku;
    _descCtrl.text = product.description;
    _sellingPriceCtrl.text =
        product.sellingPrice > 0 ? product.sellingPrice.toString() : '';
    _costPriceCtrl.text =
        product.costPrice > 0 ? product.costPrice.toString() : '';
    _stockCtrl.text = product.stockQty.toString();
    _thresholdCtrl.text =
        product.lowStockThreshold > 0 ? product.lowStockThreshold.toString() : '';
    _categoryCtrl.text = product.category;
    _qrCtrl.text = product.qrCode;
    setState(() {
      _imagePath = product.imagePath.isNotEmpty ? product.imagePath : null;

      // Populate hierarchical variant data
      for (final a in _attributes) {
        a.dispose();
      }
      _attributes.clear();
      _combinations.clear();

      for (final attr in product.variantAttributes) {
        _attributes.add(_AttributeEntry(
          name: attr.name,
          options: List<String>.from(attr.options),
        ));
      }

      // Populate combinations
      for (final combo in product.variantCombinations) {
        _combinations.add(_CombinationEntry(
          key: combo.combinationKey,
          displayLabel: combo.displayLabel,
          stockCtrl: TextEditingController(
              text: combo.stockQty > 0 ? combo.stockQty.toString() : ''),
          priceCtrl: TextEditingController(
              text: combo.priceAdjustment != 0
                  ? combo.priceAdjustment.toString()
                  : ''),
          skuCtrl: TextEditingController(text: combo.sku),
          isActive: combo.isActive,
        ));
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _descCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _costPriceCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _categoryCtrl.dispose();
    _qrCtrl.dispose();
    _scrollCtrl.dispose();
    for (final a in _attributes) {
      a.dispose();
    }
    for (final c in _combinations) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Variant helpers ──

  void _addAttribute() {
    setState(() {
      _attributes.add(_AttributeEntry());
    });
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes[index].dispose();
      _attributes.removeAt(index);
      _regenerateCombinations();
    });
  }

  void _addOption(int attrIndex) {
    setState(() {
      _attributes[attrIndex].options.add('');
      _attributes[attrIndex].optionCtrls.add(TextEditingController());
    });
  }

  void _removeOption(int attrIndex, int optIndex) {
    setState(() {
      _attributes[attrIndex].optionCtrls[optIndex].dispose();
      _attributes[attrIndex].optionCtrls.removeAt(optIndex);
      _attributes[attrIndex].options.removeAt(optIndex);
      _regenerateCombinations();
    });
  }

  void _regenerateCombinations() {
    // Build VariantAttribute list from current state
    final attrs = _attributes
        .where((a) =>
            a.nameCtrl.text.trim().isNotEmpty &&
            a.options.any((o) => o.trim().isNotEmpty))
        .map((a) => VariantAttribute(
              name: a.nameCtrl.text.trim(),
              options: a.options
                  .where((o) => o.trim().isNotEmpty)
                  .map((o) => o.trim())
                  .toList(),
            ))
        .toList();

    // Get existing combination values to preserve
    final existingCombos = _combinations.map((c) => VariantCombination(
      combinationKey: c.key,
      displayLabel: c.displayLabel,
      stockQty: int.tryParse(c.stockCtrl.text) ?? 0,
      priceAdjustment: double.tryParse(c.priceCtrl.text) ?? 0,
      sku: c.skuCtrl.text,
      isActive: c.isActive,
    )).toList();

    final newCombos = generateCombinations(
      attrs,
      existing: existingCombos,
      baseSku: _skuCtrl.text.trim(),
    );

    // Dispose old controllers
    for (final c in _combinations) {
      c.dispose();
    }

    setState(() {
      _combinations = newCombos.map((combo) {
        return _CombinationEntry(
          key: combo.combinationKey,
          displayLabel: combo.displayLabel,
          stockCtrl: TextEditingController(
              text: combo.stockQty > 0 ? combo.stockQty.toString() : ''),
          priceCtrl: TextEditingController(
              text: combo.priceAdjustment != 0
                  ? combo.priceAdjustment.toString()
                  : ''),
          skuCtrl: TextEditingController(text: combo.sku),
          isActive: combo.isActive,
        );
      }).toList();
    });
  }

  // ── Image ──

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}.jpg';
    final targetPath = '${dir.path}/product_images/$fileName';

    await Directory('${dir.path}/product_images').create(recursive: true);

    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      quality: 80,
      minWidth: 600,
      minHeight: 600,
    );

    if (compressed != null && mounted) {
      setState(() => _imagePath = compressed.path);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                title: const Text('Remove Photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _imagePath = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() => _qrCtrl.text = result);
    }
  }

  // ── Submit ──

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      // Scroll to top so user can see validation errors
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final categoryName = _categoryCtrl.text.trim();

      await ref
          .read(categoryNotifierProvider.notifier)
          .ensureExists(categoryName);

      final isEdit = _existingProduct != null || widget.product != null;
      final existing = _existingProduct ?? widget.product;

      // Build variant attributes
      final variantAttributes = _attributes
          .where((a) =>
              a.nameCtrl.text.trim().isNotEmpty &&
              a.options.any((o) => o.trim().isNotEmpty))
          .map((a) => VariantAttribute(
                name: a.nameCtrl.text.trim(),
                options: a.options
                    .where((o) => o.trim().isNotEmpty)
                    .map((o) => o.trim())
                    .toList(),
              ))
          .toList();

      // Build variant combinations
      final variantCombinations = _combinations.map((c) => VariantCombination(
        combinationKey: c.key,
        displayLabel: c.displayLabel,
        stockQty: int.tryParse(c.stockCtrl.text) ?? 0,
        priceAdjustment: double.tryParse(c.priceCtrl.text) ?? 0,
        sku: c.skuCtrl.text.trim(),
        isActive: c.isActive,
      )).toList();

      final product = Product(
        id: existing?.id ?? Isar.autoIncrement,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imagePath: _imagePath ?? '',
        sellingPrice: double.parse(_sellingPriceCtrl.text),
        costPrice: double.tryParse(_costPriceCtrl.text) ?? 0.0,
        stockQty: int.parse(_stockCtrl.text),
        lowStockThreshold: int.tryParse(_thresholdCtrl.text) ?? 10,
        category: categoryName,
        qrCode: _qrCtrl.text.trim(),
        isActive: existing?.isActive ?? true,
        variantAttributes: variantAttributes,
        variantCombinations: variantCombinations,
        createdAt: existing?.createdAt,
      );

      if (isEdit) {
        await ref
            .read(productNotifierProvider.notifier)
            .updateProduct(product);
      } else {
        await ref.read(productNotifierProvider.notifier).addProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Product updated!' : 'Product added!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save product. Please try again.'),
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
    final isEdit = widget.product != null || widget.productId != null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? AppStrings.editProduct : AppStrings.addProduct),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image picker ───────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceSheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: _imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_imagePath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 36,
                                color: cs.primary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Basic Info ─────────────────────────────────────────────────
              const _SectionLabel('Basic Info'),
              const SizedBox(height: 12),
              AppTextField(
                label: AppStrings.productName,
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Product name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── Category with chips ────────────────────────────────────────
              AppTextField(
                label: AppStrings.category,
                controller: _categoryCtrl,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Category'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              categoriesAsync.when(
                data: (cats) {
                  final query = _categoryCtrl.text.trim().toLowerCase();
                  final filtered = cats
                      .where((c) =>
                          query.isEmpty ||
                          c.name.toLowerCase().contains(query))
                      .toList();
                  if (filtered.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: filtered
                          .map((c) => ActionChip(
                                label: Text(c.name,
                                    style: const TextStyle(fontSize: 12)),
                                onPressed: () => setState(
                                    () => _categoryCtrl.text = c.name),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              AppTextField(
                label: AppStrings.productSku,
                controller: _skuCtrl,
                textCapitalization: TextCapitalization.characters,
                validator: Validators.sku,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── QR / Barcode ───────────────────────────────────────────────
              AppTextField(
                label: 'QR / Barcode',
                controller: _qrCtrl,
                textInputAction: TextInputAction.next,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan',
                  onPressed: _scanQr,
                ),
              ),
              const SizedBox(height: 12),

              AppTextField(
                label: AppStrings.productDescription,
                controller: _descCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // ── Pricing ────────────────────────────────────────────────────
              const _SectionLabel('Pricing'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: AppStrings.sellingPrice,
                      controller: _sellingPriceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                      ],
                      validator: (v) =>
                          Validators.positiveNumber(v, 'Selling price'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: AppStrings.costPrice,
                      controller: _costPriceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                      ],
                      validator: (v) => Validators.costPriceNotExceedingSelling(
                          v, _sellingPriceCtrl.text),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Inventory ──────────────────────────────────────────────────
              const _SectionLabel('Inventory'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: AppStrings.stockQuantity,
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) =>
                          Validators.nonNegativeInt(v, 'Stock quantity'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: AppStrings.lowStockThreshold,
                      controller: _thresholdCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Variant Attributes ─────────────────────────────────────────
              Row(
                children: [
                  const _SectionLabel('Variant Attributes'),
                  const Spacer(),
                  if (_attributes.length < 3)
                    TextButton.icon(
                      onPressed: _addAttribute,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              if (_attributes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No variants. Add attributes like Size, Color, etc.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ..._attributes.asMap().entries.map((entry) {
                final i = entry.key;
                final attr = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Attribute Name',
                                  hintText: 'e.g. Size',
                                  isDense: true,
                                ),
                                controller: attr.nameCtrl,
                                autofocus: i == _attributes.length - 1 && attr.nameCtrl.text.isEmpty,
                                onChanged: (_) {
                                  // Update options list and regenerate
                                  _regenerateCombinations();
                                },
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  size: 18, color: cs.error),
                              onPressed: () => _removeAttribute(i),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Options',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...attr.options.asMap().entries.map((optEntry) {
                              final oi = optEntry.key;
                              return SizedBox(
                                width: 100,
                                height: 36,
                                child: TextField(
                                  controller: attr.optionCtrls[oi],
                                  decoration: InputDecoration(
                                    hintText: 'Option',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    suffixIcon: GestureDetector(
                                      onTap: () => _removeOption(i, oi),
                                      child: Icon(Icons.close,
                                          size: 14,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.4)),
                                    ),
                                    suffixIconConstraints:
                                        const BoxConstraints(
                                            maxWidth: 24, maxHeight: 24),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  onChanged: (val) {
                                    attr.options[oi] = val;
                                    _regenerateCombinations();
                                  },
                                ),
                              );
                            }),
                            SizedBox(
                              height: 36,
                              child: TextButton.icon(
                                onPressed: () => _addOption(i),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Add',
                                    style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // ── Combinations ───────────────────────────────────────────────
              if (_combinations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SectionLabel(
                        'Combinations (${_combinations.length})'),
                    const Spacer(),
                    TextButton(
                      onPressed: _regenerateCombinations,
                      child: const Text('Regenerate',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Bulk actions
                Row(
                  children: [
                    Expanded(
                      child: _BulkSetField(
                        label: 'Set All Stock',
                        onApply: (val) {
                          final v = int.tryParse(val);
                          if (v == null) return;
                          setState(() {
                            for (final c in _combinations) {
                              c.stockCtrl.text = val;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BulkSetField(
                        label: 'Set All Price +/-',
                        onApply: (val) {
                          setState(() {
                            for (final c in _combinations) {
                              c.priceCtrl.text = val;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._combinations.asMap().entries.map((entry) {
                  final ci = entry.key;
                  final combo = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: combo.isActive
                            ? null
                            : cs.onSurface.withValues(alpha: 0.04),
                        border: Border.all(
                          color: combo.isActive
                              ? cs.outline.withValues(alpha: 0.2)
                              : cs.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: combo.isActive,
                                  onChanged: (v) => setState(
                                      () => _combinations[ci].isActive =
                                          v ?? true),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  combo.displayLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: combo.isActive
                                        ? null
                                        : cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (combo.isActive) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Stock',
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    controller: combo.stockCtrl,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Price +/-',
                                      isDense: true,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true, signed: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^-?\d*\.?\d*')),
                                    ],
                                    controller: combo.priceCtrl,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'SKU',
                                      isDense: true,
                                    ),
                                    controller: combo.skuCtrl,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 32),

              AppButton(
                label: isEdit ? 'Update Product' : 'Add Product',
                onPressed: _submit,
                isLoading: _isLoading,
                isFullWidth: true,
                height: 52,
                icon: isEdit ? Icons.save_rounded : Icons.add_rounded,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _BulkSetField extends StatelessWidget {
  final String label;
  final void Function(String) onApply;

  const _BulkSetField({required this.label, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: label,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            onApply(ctrl.text);
            ctrl.clear();
          },
          child: Icon(Icons.check_circle_outline,
              size: 20, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }
}

// ─── State Classes ───────────────────────────────────────────────────────────

class _AttributeEntry {
  final TextEditingController nameCtrl;
  final List<String> options;
  final List<TextEditingController> optionCtrls;

  _AttributeEntry({String name = '', List<String>? options})
      : nameCtrl = TextEditingController(text: name),
        options = options ?? [''],
        optionCtrls = (options ?? [''])
            .map((o) => TextEditingController(text: o))
            .toList();

  void dispose() {
    nameCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
  }
}

class _CombinationEntry {
  final String key;
  final String displayLabel;
  final TextEditingController stockCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController skuCtrl;
  bool isActive;

  _CombinationEntry({
    required this.key,
    required this.displayLabel,
    required this.stockCtrl,
    required this.priceCtrl,
    required this.skuCtrl,
    this.isActive = true,
  });

  void dispose() {
    stockCtrl.dispose();
    priceCtrl.dispose();
    skuCtrl.dispose();
  }
}
