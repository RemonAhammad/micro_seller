import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../data/services/catalog_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/product_provider.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

/// Builds a shareable product catalog: pick products, choose what each tile
/// shows, then push it into a chat as an image, a PDF, or plain text.
class CatalogShareScreen extends ConsumerStatefulWidget {
  const CatalogShareScreen({super.key});

  @override
  ConsumerState<CatalogShareScreen> createState() => _CatalogShareScreenState();
}

class _CatalogShareScreenState extends ConsumerState<CatalogShareScreen> {
  final _selected = <int>{};
  final _service = CatalogService();
  var _options = const CatalogOptions();
  var _busy = false;

  /// Only active products — a soft-deleted item shouldn't be advertised.
  List<Product> _visible(List<Product> all) =>
      all.where((p) => p.isActive).toList();

  List<Product> _chosen(List<Product> all) {
    final visible = _visible(all);
    // Preserve list order rather than selection order, so the catalog reads
    // the same way the seller sees it on screen.
    return visible.where((p) => _selected.contains(p.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.shareCatalog),
        actions: [
          productsAsync.maybeWhen(
            data: (all) {
              final visible = _visible(all);
              if (visible.isEmpty) return const SizedBox.shrink();
              final allSelected = _selected.length == visible.length;
              return TextButton(
                onPressed: () => setState(() {
                  if (allSelected) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(visible.map((p) => p.id));
                  }
                }),
                child: Text(allSelected ? s.clearSelection : s.selectAll),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final visible = _visible(all);
          if (visible.isEmpty) {
            return EmptyState(
              icon: tabler.Package.new,
              title: s.noProducts,
            );
          }
          return Column(
            children: [
              _optionsBar(s),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final p = visible[i];
                    return CheckboxListTile(
                      value: _selected.contains(p.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(p.id);
                        } else {
                          _selected.remove(p.id);
                        }
                      }),
                      secondary: _thumb(p),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        CurrencyFormatter.format(p.sellingPrice),
                        style: TextStyle(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: productsAsync.maybeWhen(
        data: (all) => _actionBar(s, all),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _thumb(Product p) {
    if (p.imagePath.isEmpty) {
      return const CircleAvatar(child: ThinIcon(tabler.Package.new, size: 18));
    }
    return CircleAvatar(backgroundImage: FileImage(File(p.imagePath)));
  }

  Widget _optionsBar(dynamic s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: Text(s.includePhotos),
            selected: _options.includePhotos,
            onSelected: (v) =>
                setState(() => _options = _options.copyWith(includePhotos: v)),
          ),
          FilterChip(
            label: Text(s.includeStock),
            selected: _options.includeStock,
            onSelected: (v) =>
                setState(() => _options = _options.copyWith(includeStock: v)),
          ),
          FilterChip(
            label: Text(s.includeSku),
            selected: _options.includeSku,
            onSelected: (v) =>
                setState(() => _options = _options.copyWith(includeSku: v)),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(dynamic s, List<Product> all) {
    final count = _selected.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy || count == 0
                        ? null
                        : () => _shareImage(all),
                    icon: const ThinIcon(tabler.Photo.new, size: 18),
                    label: Text(s.shareAsImage),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _busy || count == 0 ? null : () => _sharePdf(all),
                    icon: const ThinIcon(tabler.FileTypePdf.new, size: 18),
                    label: Text(s.shareAsPdf),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _busy || count == 0 ? null : () => _copyText(all),
              icon: const ThinIcon(tabler.Copy.new, size: 16),
              label: Text(s.copyPriceList),
            ),
          ],
        ),
      ),
    );
  }

  // ── actions ────────────────────────────────────────────────────────────

  ({String name, String? phone}) get _shop {
    final settings = ref.read(settingsProvider.notifier);
    final phone = settings.shopPhone;
    return (name: settings.shopName, phone: phone.isEmpty ? null : phone);
  }

  Future<void> _shareImage(List<Product> all) async {
    final chosen = _chosen(all);
    final s = AppStrings.of(context);
    // One PNG holds a single page. Say so rather than silently dropping the
    // overflow — the PDF path is the one that carries everything.
    if (chosen.length > CatalogService.perPage) {
      context.showSnackBar(s.catalogImageTruncated(CatalogService.perPage));
    }
    await _run(() async {
      final shop = _shop;
      final bytes = await _service.generateCatalogImage(
        chosen,
        shopName: shop.name,
        shopPhone: shop.phone,
        options: _options,
      );
      await _shareBytes(bytes, 'catalog.png');
    });
  }

  Future<void> _sharePdf(List<Product> all) async {
    await _run(() async {
      final shop = _shop;
      final bytes = await _service.generateCatalogPdf(
        _chosen(all),
        shopName: shop.name,
        shopPhone: shop.phone,
        options: _options,
      );
      await _shareBytes(bytes, 'catalog.pdf');
    });
  }

  Future<void> _copyText(List<Product> all) async {
    final shop = _shop;
    final text = _service.generateCatalogText(
      _chosen(all),
      shopName: shop.name,
      shopPhone: shop.phone,
      options: _options,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) context.showSuccessSnackBar(AppStrings.of(context).priceListCopied);
  }

  Future<void> _shareBytes(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: fileName));
  }

  /// Runs a generation task with the progress bar up, surfacing failures as a
  /// snackbar rather than an unhandled exception — rasterising can fail on
  /// low-memory devices.
  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(
          AppStrings.of(context).catalogGenerationFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
