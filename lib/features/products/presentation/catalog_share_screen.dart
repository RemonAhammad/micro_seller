import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/share_origin.dart';
import '../../../data/models/product.dart';
import '../../../data/services/catalog_service.dart';
import '../../../data/services/product_image_store.dart';
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

  // The share buttons, which an iPad's share sheet points at. Read when the
  // catalog is ready, wherever the button is drawn by then.
  final _imageButton = GlobalKey();
  final _pdfButton = GlobalKey();

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
                      // An amount is shrunk to fit, never wrapped.
                      subtitle: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          CurrencyFormatter.format(p.sellingPrice),
                          style: TextStyle(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
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

  static const _thumbRadius = 20.0;

  Widget _thumb(Product p) {
    final photo = resolveProductImagePath(p.imagePath);
    if (photo == null) {
      return const CircleAvatar(
        radius: _thumbRadius,
        child: ThinIcon(tabler.Package.new, size: 18),
      );
    }
    // Decode at the avatar's pixel size, not the stored photo's.
    final width =
        (_thumbRadius * 2 * MediaQuery.devicePixelRatioOf(context) * 1.4)
            .ceil();
    return CircleAvatar(
      radius: _thumbRadius,
      backgroundImage: ResizeImage(FileImage(File(photo)), width: width),
      // The file is gone (a backup restored on another phone carries no
      // photos): the plain avatar, without reporting an error.
      onBackgroundImageError: (_, _) {},
    );
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
            // Side by side while each label can wrap between its words;
            // one above the other once large text on a narrow layout would
            // split a word across lines.
            LayoutBuilder(builder: (context, constraints) {
              final image = FilledButton.icon(
                key: _imageButton,
                onPressed: _busy || count == 0
                    ? null
                    : () => _shareImage(all),
                icon: const ThinIcon(tabler.Photo.new, size: 18),
                label: Text(s.shareAsImage),
              );
              final pdf = OutlinedButton.icon(
                key: _pdfButton,
                onPressed:
                    _busy || count == 0 ? null : () => _sharePdf(all),
                icon: const ThinIcon(tabler.FileTypePdf.new, size: 18),
                label: Text(s.shareAsPdf),
              );
              final theme = Theme.of(context);
              final half = (constraints.maxWidth - 8) / 2;
              final sideBySide = _wordsFit(context,
                      theme.filledButtonTheme.style, s.shareAsImage, half) &&
                  _wordsFit(context,
                      theme.outlinedButtonTheme.style, s.shareAsPdf, half);
              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [image, const SizedBox(height: 8), pdf],
                );
              }
              return Row(
                children: [
                  Expanded(child: image),
                  const SizedBox(width: 8),
                  Expanded(child: pdf),
                ],
              );
            }),
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
      await _shareBytes(bytes, 'catalog.png', _imageButton);
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
      await _shareBytes(bytes, 'catalog.pdf', _pdfButton);
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

  /// Shares the catalog file from [button]: an iPad's share sheet points at
  /// it.
  Future<void> _shareBytes(
      Uint8List bytes, String fileName, GlobalKey button) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: fileName,
      sharePositionOrigin: shareOriginOf(button.currentContext),
    ));
  }

  /// Runs a generation task with the progress bar up, surfacing failures as a
  /// snackbar rather than an unhandled exception — rasterising can fail on
  /// low-memory devices.
  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      // Paint the progress bar before any work (each page capture starts
      // with a synchronous build/layout on this isolate); after that the
      // work yields — photo decode, PNG/JPEG encode, PDF assembly on a
      // background isolate — so the bar keeps animating.
      await WidgetsBinding.instance.endOfFrame;
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

/// Whether every word of [label] fits on one line of an icon button [width]
/// wide in [style] (its padding, the 18 px icon and the gap taken off), at
/// the current text size and bold-text setting. A label may wrap between its
/// words; a word split across lines is what reads as broken.
bool _wordsFit(
    BuildContext context, ButtonStyle? style, String label, double width) {
  final padding = style?.padding?.resolve(const {})?.horizontal ?? 48;
  var textStyle = style?.textStyle?.resolve(const {}) ??
      Theme.of(context).textTheme.labelLarge;
  if (MediaQuery.boldTextOf(context)) {
    textStyle = (textStyle ?? const TextStyle())
        .merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: label, style: textStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final longestWord = painter.minIntrinsicWidth;
  painter.dispose();
  return longestWord <= width - padding - 18 - 8;
}
