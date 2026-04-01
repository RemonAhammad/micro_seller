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
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();

  String? _imagePath;
  bool _isLoading = false;
  Product? _existingProduct;

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
    _stockCtrl.text = product.stockQty.toString();
    _thresholdCtrl.text =
        product.lowStockThreshold > 0 ? product.lowStockThreshold.toString() : '';
    _categoryCtrl.text = product.category;
    _qrCtrl.text = product.qrCode;
    setState(() => _imagePath = product.imagePath.isNotEmpty ? product.imagePath : null);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _descCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _categoryCtrl.dispose();
    _qrCtrl.dispose();
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
        costPrice: existing?.costPrice ?? 0.0,
        stockQty: int.parse(_stockCtrl.text),
        lowStockThreshold: int.tryParse(_thresholdCtrl.text) ?? 10,
        category: categoryName,
        qrCode: _qrCtrl.text.trim(),
        isActive: existing?.isActive ?? true,
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
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
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
              AppTextField(
                label: AppStrings.sellingPrice,
                controller: _sellingPriceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                ],
                validator: (v) =>
                    Validators.positiveNumber(v, 'Selling price'),
                prefixIcon:
                    const Icon(Icons.monetization_on_outlined, size: 18),
                textInputAction: TextInputAction.next,
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
