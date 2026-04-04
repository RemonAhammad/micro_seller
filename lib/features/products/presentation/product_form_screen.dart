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
import '../../../data/models/product_variant.dart';
import '../providers/product_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
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
  final List<ProductVariant> _variants = [];
  final List<_VariantControllers> _variantControllers = [];

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
      _variants
        ..clear()
        ..addAll(product.variants.map((v) => v.copyWith()));
      for (final vc in _variantControllers) {
        vc.dispose();
      }
      _variantControllers.clear();
      for (final v in _variants) {
        _variantControllers.add(_VariantControllers(
          nameText: v.name,
          valueText: v.value,
          stockText: v.stockQty > 0 ? v.stockQty.toString() : '',
          priceText: v.priceAdjustment != 0 ? v.priceAdjustment.toString() : '',
          skuText: v.sku,
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
    for (final vc in _variantControllers) {
      vc.dispose();
    }
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final categoryName = _categoryCtrl.text.trim();

      // Ensure category exists (creates if new)
      await ref
          .read(categoryNotifierProvider.notifier)
          .ensureExists(categoryName);

      final isEdit = _existingProduct != null || widget.product != null;
      final existing = _existingProduct ?? widget.product;

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
        variants: _variants.where((v) => v.name.isNotEmpty && v.value.isNotEmpty).toList(),
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
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? AppStrings.editProduct : AppStrings.addProduct),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.2),
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
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.6),
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

              // ── Variants ──────────────────────────────────────────────────
              Row(
                children: [
                  const _SectionLabel('Variants'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _variants.add(
                          ProductVariant(name: '', value: '', stockQty: 0));
                      _variantControllers.add(_VariantControllers());
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (_variants.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No variants. Add variants for sizes, colors, etc.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ..._variants.asMap().entries.map((entry) {
                final i = entry.key;
                final vc = _variantControllers[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Attribute',
                                  hintText: 'e.g. Size',
                                  isDense: true,
                                ),
                                controller: vc.name,
                                onChanged: (val) => _variants[i] =
                                    _variants[i].copyWith(name: val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Value',
                                  hintText: 'e.g. Large',
                                  isDense: true,
                                ),
                                controller: vc.value,
                                onChanged: (val) => _variants[i] =
                                    _variants[i].copyWith(value: val),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() {
                                _variantControllers[i].dispose();
                                _variantControllers.removeAt(i);
                                _variants.removeAt(i);
                              }),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
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
                                controller: vc.stock,
                                onChanged: (val) => _variants[i] =
                                    _variants[i].copyWith(
                                        stockQty: int.tryParse(val) ?? 0),
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
                                controller: vc.price,
                                onChanged: (val) => _variants[i] =
                                    _variants[i].copyWith(
                                        priceAdjustment:
                                            double.tryParse(val) ?? 0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'SKU',
                                  isDense: true,
                                ),
                                controller: vc.sku,
                                onChanged: (val) => _variants[i] =
                                    _variants[i].copyWith(sku: val),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
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

class _VariantControllers {
  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController stock;
  final TextEditingController price;
  final TextEditingController sku;

  _VariantControllers({
    String nameText = '',
    String valueText = '',
    String stockText = '',
    String priceText = '',
    String skuText = '',
  })  : name = TextEditingController(text: nameText),
        value = TextEditingController(text: valueText),
        stock = TextEditingController(text: stockText),
        price = TextEditingController(text: priceText),
        sku = TextEditingController(text: skuText);

  void dispose() {
    name.dispose();
    value.dispose();
    stock.dispose();
    price.dispose();
    sku.dispose();
  }
}
