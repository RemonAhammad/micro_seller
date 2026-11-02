import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:isar_community/isar.dart';
import '../../../data/models/product.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/variant_attribute.dart';
import '../../../data/models/variant_combination.dart';
import '../providers/product_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../../data/services/device_channel.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/product_image_store.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/number_input.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/variant_utils.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/scanner_camera.dart';
import '../../../shared/screens/qr_scanner_screen.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final int? productId;

  final String? initialQrCode;

  final String? initialSku;

  const ProductFormScreen({
    super.key,
    this.product,
    this.productId,
    this.initialQrCode,
    this.initialSku,
  });

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
  bool _isCompressing = false;
  bool _isLoading = false;
  Product? _existingProduct;
  Supplier? _selectedSupplier;

  final List<_AttributeEntry> _attributes = [];
  List<_CombinationEntry> _combinations = [];

  final _regenDebouncer = Debouncer(delay: const Duration(milliseconds: 300));
  bool _regenPending = false;

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
    } else {

      if (widget.initialQrCode != null && widget.initialQrCode!.isNotEmpty) {
        _qrCtrl.text = widget.initialQrCode!;
      }
      if (widget.initialSku != null && widget.initialSku!.isNotEmpty) {
        _skuCtrl.text = widget.initialSku!;
      }
    }
  }

  void _populateForm(Product product) async {
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

    if (product.supplierId > 0) {
      try {
        final isar = await ref.read(isarProvider.future);
        final supplier = await isar.suppliers.get(product.supplierId);
        if (supplier != null && mounted) {
          setState(() => _selectedSupplier = supplier);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _imagePath = product.imagePath.isNotEmpty ? product.imagePath : null;

      for (final a in _attributes) {
        a.dispose();
      }
      _attributes.clear();
      for (final c in _combinations) {
        c.dispose();
      }

      for (final attr in product.variantAttributes) {
        _attributes.add(_AttributeEntry(
          name: attr.name,
          options: List<String>.from(attr.options),
        ));
      }

      _combinations = product.variantCombinations
          .map(_CombinationEntry.fromCombination)
          .toList();
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
    _regenDebouncer.dispose();
    for (final a in _attributes) {
      a.dispose();
    }
    for (final c in _combinations) {
      c.dispose();
    }
    super.dispose();
  }

  void _addAttribute() {
    setState(() {
      _attributes.add(_AttributeEntry());
    });
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes[index].dispose();
      _attributes.removeAt(index);
    });
    _regenerateCombinations();
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
    });
    _regenerateCombinations();
  }

  void _scheduleRegeneration() {
    _regenPending = true;
    _regenDebouncer.run(() {
      if (mounted && _regenPending) _regenerateCombinations();
    });
  }

  void _regenerateCombinations() {
    _regenPending = false;

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

    final generated = generateCombinations(
      attrs,
      baseSku: _skuCtrl.text.trim(),
    );

    final reusable = <String, List<_CombinationEntry>>{};
    for (final c in _combinations) {
      (reusable[c.key] ??= []).add(c);
    }
    final lastByKey = {for (final c in _combinations) c.key: c};

    final next = <_CombinationEntry>[];
    for (final combo in generated) {
      final pool = reusable[combo.combinationKey];
      final previous = lastByKey[combo.combinationKey];
      if (pool != null && pool.isNotEmpty) {
        next.add(pool.removeAt(0)..displayLabel = combo.displayLabel);
      } else if (previous != null) {

        next.add(_CombinationEntry.copyOf(previous, combo.displayLabel));
      } else {
        next.add(_CombinationEntry.fromCombination(combo));
      }
    }

    final removed = [for (final pool in reusable.values) ...pool];
    setState(() => _combinations = next);

    if (removed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in removed) {
          c.dispose();
        }
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final s = AppStrings.of(context);
    final XFile? picked;
    try {

      picked = await ref.read(imagePickerProvider).pickImage(
            source: source,
            maxWidth: 1600,
            maxHeight: 1600,
          );
    } on PlatformException catch (e) {
      await _pickFailed(e.code);
      return;
    } catch (_) {
      if (mounted) context.showErrorSnackBar(s.error);
      return;
    }
    if (picked == null) return;

    if (mounted) setState(() => _isCompressing = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final folder = '${dir.path}/$kProductImagesFolder';
      final targetPath = '$folder/$fileName';

      await Directory(folder).create(recursive: true);

      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        targetPath,
        quality: 80,
        minWidth: 600,
        minHeight: 600,
      );

      if (compressed != null && mounted) {

        ProductImageStore.documentsDirectory ??= dir.path;
        setState(() => _imagePath = storedProductImagePath(compressed.path));
      }
    } catch (_) {

      if (mounted) context.showErrorSnackBar(s.error);
    } finally {
      if (mounted) setState(() => _isCompressing = false);

      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await File(picked.path).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _pickFailed(String code) async {

    if (!mounted) return;
    final s = AppStrings.of(context);
    switch (code) {
      case 'camera_access_denied' || 'camera_access_restricted':
        final device = ref.read(deviceChannelProvider);
        final access = await device.cameraAccess();
        if (!mounted) return;
        if (access
            case CameraAccess.permanentlyDenied ||
                CameraAccess.restricted ||
                CameraAccess.unknown) {
          await showCameraBlockedDialog(context, access, device);
        }
      case 'no_available_camera':
        context.showErrorSnackBar(s.noCameraAvailable);
      default:
        context.showErrorSnackBar(s.error);
    }
  }

  void _showImageSourceSheet() {
    final s = AppStrings.of(context);
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
              leading: const ThinIcon(tabler.Camera.new),
              title: Text(s.takePhoto),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickImage(ImageSource.camera));
              },
            ),
            ListTile(
              leading: const ThinIcon(tabler.Photo.new),
              title: Text(s.chooseFromGallery),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickImage(ImageSource.gallery));
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const ThinIcon(tabler.Trash.new,
                    color: Colors.red),
                title: Text(s.removePhoto,
                    style: const TextStyle(color: Colors.red)),
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

  Future<void> _pickSupplier() async {
    final isar = await ref.read(isarProvider.future);
    final suppliers = await isar.suppliers.where().sortByName().findAll();
    if (!mounted) return;

    final result = await showModalBottomSheet<Supplier?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SupplierPickerSheet(suppliers: suppliers),
    );

    if (result != null) {
      setState(() => _selectedSupplier = result);
    }
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

    if (_regenPending) _regenerateCombinations();

    if (!_formKey.currentState!.validate()) {

      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final categoryName = _categoryCtrl.text.trim();

      await ref
          .read(categoryProvider.notifier)
          .ensureExists(categoryName);

      final isEdit = _existingProduct != null || widget.product != null;
      final existing = _existingProduct ?? widget.product;

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

      final variantCombinations = _combinations.map((c) => VariantCombination(
        combinationKey: c.key,
        displayLabel: c.displayLabel,
        stockQty: NumberInput.parseInteger(c.stockCtrl.text) ?? 0,
        priceAdjustment: NumberInput.parseDecimal(c.priceCtrl.text) ?? 0,
        sku: c.skuCtrl.text.trim(),
        isActive: c.isActive,
      )).toList();

      final product = Product(
        id: existing?.id ?? Isar.autoIncrement,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim(),
        description: _descCtrl.text.trim(),

        imagePath: storedProductImagePath(_imagePath ?? ''),

        sellingPrice: NumberInput.parseDecimal(_sellingPriceCtrl.text)!,
        costPrice: NumberInput.parseDecimal(_costPriceCtrl.text) ?? 0.0,
        stockQty: NumberInput.parseInteger(_stockCtrl.text)!,
        lowStockThreshold: NumberInput.parseInteger(_thresholdCtrl.text) ?? 10,
        category: categoryName,
        qrCode: _qrCtrl.text.trim(),
        isActive: existing?.isActive ?? true,
        variantAttributes: variantAttributes,
        variantCombinations: variantCombinations,
        supplierId: _selectedSupplier?.id ?? 0,
        createdAt: existing?.createdAt,
      );

      if (isEdit) {
        await ref
            .read(productProvider.notifier)
            .updateProduct(product);
      } else {
        await ref.read(productProvider.notifier).addProduct(product);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final successMsg = isEdit
          ? AppStrings.of(context).productUpdated
          : AppStrings.of(context).productAdded;
      context.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
      );
    } catch (e, st) {

      developer.log('Product save failed', name: 'ProductForm', error: e, stackTrace: st);
      if (kDebugMode) {
        debugPrint('[ProductForm] save failed: $e');
        debugPrintStack(stackTrace: st, label: 'ProductForm._submit');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                kDebugMode
                    ? 'Save failed: $e'
                    : AppStrings.of(context).failedToSaveProduct),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
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
    final isEdit = widget.product != null || widget.productId != null;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final combinations = _combinations;
    final photo = resolveProductImagePath(_imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? s.editProduct : s.addProduct),
      ),

      body: Form(
        key: _formKey,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Center(
                      child: GestureDetector(
                        onTap: _isCompressing ? null : _showImageSourceSheet,
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
                          child: _isCompressing
                              ? const Center(child: CircularProgressIndicator())
                              : photo != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(photo),
                                    fit: BoxFit.cover,

                                    errorBuilder: (_, _, _) => ThinIcon(
                                      tabler.PhotoOff.new,
                                      size: 36,
                                      color: cs.primary.withValues(alpha: 0.5),
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ThinIcon(
                                      tabler.PhotoPlus.new,
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

                    const _SectionLabel('Basic Info'),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: s.productName,
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => Validators.required(v, 'Product name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: s.category,
                      controller: _categoryCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => Validators.required(v, 'Category'),
                      textInputAction: TextInputAction.next,
                    ),
                    _CategoryChips(controller: _categoryCtrl),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: _pickSupplier,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: cs.outline.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            ThinIcon(tabler.TruckDelivery.new,
                                color: cs.onSurface.withValues(alpha: 0.5),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _selectedSupplier != null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.suppliers,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.5))),
                                        Text(_selectedSupplier!.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14)),
                                      ],
                                    )
                                  : Text(s.supplierOptional,
                                      style: TextStyle(
                                          color: cs.onSurface.withValues(alpha: 0.5),
                                          fontSize: 14)),
                            ),
                            if (_selectedSupplier != null)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedSupplier = null),
                                child: ThinIcon(tabler.X.new,
                                    size: 18,
                                    color: cs.onSurface.withValues(alpha: 0.5)),
                              )
                            else
                              ThinIcon(tabler.ChevronRight.new,
                                  size: 14,
                                  color: cs.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: s.sku,
                      controller: _skuCtrl,
                      textCapitalization: TextCapitalization.characters,
                      validator: Validators.sku,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: s.qrBarcode,
                      controller: _qrCtrl,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        icon: const ThinIcon(tabler.Scan.new),
                        tooltip: s.scan,
                        onPressed: _scanQr,
                      ),
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: s.description,
                      controller: _descCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 20),

                    const _SectionLabel('Pricing'),
                    const SizedBox(height: 12),
                    _FieldRow(
                      chrome: _kAppFieldChrome,
                      spacing: 12,
                      children: [
                        AppTextField(
                          label: s.sellingPrice,
                          controller: _sellingPriceCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: const [DecimalInputFormatter.money()],
                          validator: (v) =>
                              Validators.positiveNumber(v, 'Selling price'),
                          textInputAction: TextInputAction.next,
                        ),
                        AppTextField(
                          label: s.costPrice,
                          controller: _costPriceCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: const [DecimalInputFormatter.money()],
                          validator: (v) => Validators.costPriceNotExceedingSelling(
                              v, _sellingPriceCtrl.text),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const _SectionLabel('Inventory'),
                    const SizedBox(height: 12),
                    _FieldRow(
                      chrome: _kAppFieldChrome,
                      spacing: 12,
                      children: [
                        AppTextField(
                          label: s.stockQuantity,
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [IntegerInputFormatter()],
                          validator: (v) =>
                              Validators.nonNegativeInt(v, 'Stock quantity'),
                          textInputAction: TextInputAction.next,
                        ),
                        AppTextField(
                          label: s.lowStockThreshold,
                          controller: _thresholdCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [IntegerInputFormatter()],
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _SectionLabel(s.variantAttributes),
                          if (_attributes.length < 3)
                            TextButton.icon(
                              onPressed: _addAttribute,
                              icon: const ThinIcon(tabler.Plus.new, size: 16),
                              label: Text(s.add, style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    if (_attributes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          s.tr('noVariantsHint'),
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
                                      decoration: InputDecoration(
                                        labelText: s.attributeName,
                                        hintText: s.tr('variantName'),
                                        isDense: true,
                                      ),
                                      controller: attr.nameCtrl,
                                      autofocus: i == _attributes.length - 1 && attr.nameCtrl.text.isEmpty,
                                      onChanged: (_) => _scheduleRegeneration(),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: AppStrings.of(context).remove,
                                    icon: ThinIcon(tabler.X.new,
                                        size: 18, color: cs.error),
                                    onPressed: () => _removeAttribute(i),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(s.tr('option'),
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
                                      child: TextField(
                                        controller: attr.optionCtrls[oi],
                                        decoration: InputDecoration(
                                          hintText: s.option,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),

                                          constraints:
                                              const BoxConstraints(minHeight: 36),
                                          suffixIcon: GestureDetector(
                                            onTap: () => _removeOption(i, oi),
                                            child: ThinIcon(tabler.X.new,
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
                                          _scheduleRegeneration();
                                        },
                                      ),
                                    );
                                  }),
                                  SizedBox(
                                    height: 36,
                                    child: TextButton.icon(
                                      onPressed: () => _addOption(i),
                                      icon: const ThinIcon(tabler.Plus.new, size: 14),
                                      label: Text(s.add,
                                          style: const TextStyle(fontSize: 11)),
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

                    if (combinations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _SectionLabel(
                                '${s.combinations} (${combinations.length})'),
                            TextButton(
                              onPressed: _regenerateCombinations,
                              child: Text(s.regenerate,
                                  style: const TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Expanded(
                            child: _BulkSetField(
                              label: s.setAllStock,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [IntegerInputFormatter()],
                              onApply: (val) {
                                final v = NumberInput.parseInteger(val);
                                if (v == null || v < 0) return false;
                                setState(() {
                                  for (final c in _combinations) {
                                    c.stockCtrl.text = '$v';
                                  }
                                });
                                return true;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BulkSetField(
                              label: s.setAllPrice,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                              inputFormatters: const [
                                DecimalInputFormatter.money(signed: true),
                              ],
                              onApply: (val) {

                                if (NumberInput.parseDecimal(val) == null) {
                                  return false;
                                }
                                setState(() {
                                  for (final c in _combinations) {
                                    c.priceCtrl.text = val;
                                  }
                                });
                                return true;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            if (combinations.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: combinations.length,

                  findChildIndexCallback: (key) {
                    if (key is! ObjectKey) return null;
                    final i = combinations
                        .indexWhere((c) => identical(c, key.value));
                    return i < 0 ? null : i;
                  },
                  itemBuilder: (context, i) => _CombinationRow(
                    key: ObjectKey(combinations[i]),
                    entry: combinations[i],
                  ),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 36),
              sliver: SliverToBoxAdapter(
                child: AppButton(
                  label: isEdit ? 'Update Product' : 'Add Product',
                  onPressed: _submit,
                  isLoading: _isLoading,
                  isFullWidth: true,
                  height: 52,
                  icon: isEdit ? tabler.DeviceFloppy.new : tabler.Plus.new,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombinationRow extends StatefulWidget {
  final _CombinationEntry entry;

  const _CombinationRow({super.key, required this.entry});

  @override
  State<_CombinationRow> createState() => _CombinationRowState();
}

class _CombinationRowState extends State<_CombinationRow> {
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final combo = widget.entry;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: combo.isActive ? null : cs.onSurface.withValues(alpha: 0.04),
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
                    onChanged: (v) =>
                        setState(() => combo.isActive = v ?? true),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              _FieldRow(
                chrome: _kDenseFieldChrome,
                spacing: 8,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: s.stock,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: const [IntegerInputFormatter()],
                    controller: combo.stockCtrl,
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: s.priceAdjustment,
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    inputFormatters: const [
                      DecimalInputFormatter.money(signed: true),
                    ],
                    controller: combo.priceCtrl,
                  ),
                  TextField(
                    decoration: InputDecoration(
                      labelText: s.sku,
                      isDense: true,
                    ),
                    controller: combo.skuCtrl,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  final TextEditingController controller;

  const _CategoryChips({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => categoriesAsync.when(
        data: (cats) {
          final query = value.text.trim().toLowerCase();
          final filtered = cats
              .where((c) =>
                  query.isEmpty || c.name.toLowerCase().contains(query))
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
                        onPressed: () => controller.text = c.name,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

const _kAppFieldChrome = 72.0;

const _kDenseFieldChrome = 40.0;

class _FieldRow extends StatelessWidget {
  final List<Widget> children;

  final double chrome;
  final double spacing;

  const _FieldRow({
    required this.children,
    required this.chrome,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final minWidth = chrome + MediaQuery.textScalerOf(context).scale(48);
    return LayoutBuilder(builder: (context, constraints) {
      double widthFor(int perRow) =>
          (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
      var perRow = children.length;
      while (perRow > 1 && widthFor(perRow) < minWidth) {
        perRow--;
      }
      if (perRow == children.length) {
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: children[i]),
            ],
          ],
        );
      }
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: widthFor(perRow), child: child),
        ],
      );
    });
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

class _BulkSetField extends StatefulWidget {
  final String label;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  final bool Function(String) onApply;

  const _BulkSetField({
    required this.label,
    required this.keyboardType,
    required this.inputFormatters,
    required this.onApply,
  });

  @override
  State<_BulkSetField> createState() => _BulkSetFieldState();
}

class _BulkSetFieldState extends State<_BulkSetField> {

  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final label = widget.label;
    final onApply = widget.onApply;
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
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            if (onApply(ctrl.text)) ctrl.clear();
          },
          child: ThinIcon(tabler.CircleCheck.new,
              size: 20, color: Theme.of(context).colorScheme.primary),
        ),
      ],
    );
  }
}

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
  String displayLabel;
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

  factory _CombinationEntry.fromCombination(VariantCombination combo) =>
      _CombinationEntry(
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

  factory _CombinationEntry.copyOf(
          _CombinationEntry other, String displayLabel) =>
      _CombinationEntry.fromCombination(VariantCombination(
        combinationKey: other.key,
        displayLabel: displayLabel,
        stockQty: NumberInput.parseInteger(other.stockCtrl.text) ?? 0,
        priceAdjustment: NumberInput.parseDecimal(other.priceCtrl.text) ?? 0,
        sku: other.skuCtrl.text,
        isActive: other.isActive,
      ));

  void dispose() {
    stockCtrl.dispose();
    priceCtrl.dispose();
    skuCtrl.dispose();
  }
}

class _SupplierPickerSheet extends StatefulWidget {
  final List<Supplier> suppliers;

  const _SupplierPickerSheet({required this.suppliers});

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _query.isEmpty
        ? widget.suppliers
        : widget.suppliers
            .where((s) =>
                s.name.toLowerCase().contains(_query) ||
                s.company.toLowerCase().contains(_query) ||
                NumberInput.phoneMatches(s.phone, _query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, ctrl) => Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(AppStrings.of(context).tr('selectSupplier'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: '${AppStrings.of(context).search}...',
                prefixIcon: const ThinIcon(tabler.Search.new, size: 20),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ThinIcon(tabler.TruckDelivery.new,
                            size: 48,
                            color: cs.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(AppStrings.of(context).tr('noSuppliersFound'),
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.4))),
                        const SizedBox(height: 4),
                        Text(AppStrings.of(context).addSuppliersHint,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(
                        height: 1, color: cs.outline.withValues(alpha: 0.1)),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.pop(ctx, s),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.1),
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                                fontSize: 14),
                          ),
                        ),
                        title: Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        subtitle: s.company.isNotEmpty
                            ? Text(s.company,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5)))
                            : null,
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
