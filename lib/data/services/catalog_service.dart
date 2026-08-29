import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../models/product.dart';

/// What to include on each catalog tile. Sellers share these into chat
/// threads, so the defaults lean toward "customer-facing": photo and price
/// yes, internal SKU no.
class CatalogOptions {
  final bool includePhotos;
  final bool includeStock;
  final bool includeSku;

  const CatalogOptions({
    this.includePhotos = true,
    this.includeStock = false,
    this.includeSku = false,
  });

  CatalogOptions copyWith({
    bool? includePhotos,
    bool? includeStock,
    bool? includeSku,
  }) =>
      CatalogOptions(
        includePhotos: includePhotos ?? this.includePhotos,
        includeStock: includeStock ?? this.includeStock,
        includeSku: includeSku ?? this.includeSku,
      );
}

/// A product paired with its already-decoded image bytes.
///
/// The decoding has to happen *before* the widget is handed to
/// `captureFromWidget` — see [CatalogService._load].
class _CatalogItem {
  final Product product;
  final Uint8List? image;

  const _CatalogItem(this.product, this.image);
}

/// Generates a shareable product catalog.
///
/// Uses the same widget → PNG → PDF pipeline as `PdfService`: the catalog is
/// built as a Flutter widget tree and rasterised through Skia, which shapes
/// Bengali conjuncts, Arabic ligatures and CJK correctly. Native `pw` widgets
/// do not, and product names hit that problem just as hard as invoice text.
class CatalogService {
  /// A4 portrait at 96 DPI — the same logical canvas `PdfService` targets.
  static const double _pageWidth = 794;
  static const double _pageHeight = 1123;

  /// Tiles per page (2 columns × 3 rows).
  ///
  /// Pagination is not cosmetic: `captureFromWidget` multiplies `targetSize`
  /// by `pixelRatio` to size its buffer, so the size must be finite and the
  /// content must fit it. A scrolling/unbounded page silently produces an
  /// undecodable PNG.
  static const int perPage = 6;

  /// Single PNG of the first page — the most shareable form in a chat thread.
  ///
  /// If [products] overflows one page the extra items are omitted; callers
  /// wanting everything should use [generateCatalogPdf].
  Future<Uint8List> generateCatalogImage(
    List<Product> products, {
    required String shopName,
    String? shopPhone,
    String? currencySymbol,
    CatalogOptions options = const CatalogOptions(),
  }) async {
    final items = await _load(products.take(perPage).toList(), options);
    return _capture(
      items,
      shopName: shopName,
      shopPhone: shopPhone,
      sym: currencySymbol ?? CurrencyFormatter.symbol,
      options: options,
      pageIndex: 0,
      pageCount: 1,
    );
  }

  /// Multi-page PDF — one `pw.Page` per rasterised chunk of [perPage] items.
  Future<Uint8List> generateCatalogPdf(
    List<Product> products, {
    required String shopName,
    String? shopPhone,
    String? currencySymbol,
    CatalogOptions options = const CatalogOptions(),
  }) async {
    final sym = currencySymbol ?? CurrencyFormatter.symbol;
    final chunks = <List<Product>>[];
    for (var i = 0; i < products.length; i += perPage) {
      chunks.add(products.sublist(
        i,
        (i + perPage).clamp(0, products.length),
      ));
    }
    if (chunks.isEmpty) chunks.add(const []);

    final pdf = pw.Document();
    for (var i = 0; i < chunks.length; i++) {
      final items = await _load(chunks[i], options);
      final png = await _capture(
        items,
        shopName: shopName,
        shopPhone: shopPhone,
        sym: sym,
        options: options,
        pageIndex: i,
        pageCount: chunks.length,
      );
      final image = pw.MemoryImage(png);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(
            image,
            fit: pw.BoxFit.fitWidth,
            alignment: pw.Alignment.topCenter,
          ),
        ),
      );
    }
    return pdf.save();
  }

  /// Plain-text price list, for pasting straight into a chat message.
  String generateCatalogText(
    List<Product> products, {
    required String shopName,
    String? shopPhone,
    String? currencySymbol,
    CatalogOptions options = const CatalogOptions(),
  }) {
    final sym = currencySymbol ?? CurrencyFormatter.symbol;
    final sb = StringBuffer();
    sb.writeln('🛍️ *$shopName*');
    if (shopPhone != null && shopPhone.isNotEmpty) {
      sb.writeln('📞 $shopPhone');
    }
    sb.writeln();

    for (final p in products) {
      final price = CurrencyFormatter.format(p.sellingPrice, symbol: sym);
      sb.write('• ${p.name} — *$price*');
      if (options.includeSku && p.sku.isNotEmpty) sb.write(' [${p.sku}]');
      if (options.includeStock) {
        sb.write(p.isOutOfStock ? ' (out of stock)' : ' (${p.totalStock} in stock)');
      }
      sb.writeln();

      // Variant rows carry their own price via priceAdjustment, so a flat
      // list would misquote them.
      if (p.hasVariants) {
        for (final c in p.variantCombinations.where((c) => c.isActive)) {
          final vPrice = CurrencyFormatter.format(
            p.sellingPrice + c.priceAdjustment,
            symbol: sym,
          );
          sb.writeln('   ◦ ${c.displayLabel} — $vPrice');
        }
      }
    }

    sb.writeln();
    sb.writeln('_Powered by ${AppStrings.appName}_');
    return sb.toString();
  }

  // ── internals ──────────────────────────────────────────────────────────

  /// Decodes every product image to bytes up front.
  ///
  /// `Image.file` resolves its bytes asynchronously, so an off-screen capture
  /// races it and paints empty tiles. `Image.memory` over pre-read bytes has
  /// no such race. Unreadable or missing files degrade to a placeholder tile
  /// rather than failing the whole catalog.
  Future<List<_CatalogItem>> _load(
    List<Product> products,
    CatalogOptions options,
  ) async {
    final out = <_CatalogItem>[];
    for (final p in products) {
      Uint8List? bytes;
      if (options.includePhotos && p.imagePath.isNotEmpty) {
        try {
          final file = File(p.imagePath);
          if (await file.exists()) bytes = await file.readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      out.add(_CatalogItem(p, bytes));
    }
    return out;
  }

  Future<Uint8List> _capture(
    List<_CatalogItem> items, {
    required String shopName,
    required String? shopPhone,
    required String sym,
    required CatalogOptions options,
    required int pageIndex,
    required int pageCount,
  }) {
    return ScreenshotController().captureFromWidget(
      _CatalogPageWidget(
        items: items,
        shopName: shopName,
        shopPhone: shopPhone,
        sym: sym,
        options: options,
        pageIndex: pageIndex,
        pageCount: pageCount,
      ),
      pixelRatio: 2.0,
      targetSize: const Size(_pageWidth, _pageHeight),
      // Longer than PdfService's 100ms: this tree decodes several embedded
      // images, and the capture must not run before they've been painted.
      delay: const Duration(milliseconds: 300),
    );
  }
}

/// One fixed-size A4 catalog page. Rasterised via `captureFromWidget`.
class _CatalogPageWidget extends StatelessWidget {
  final List<_CatalogItem> items;
  final String shopName;
  final String? shopPhone;
  final String sym;
  final CatalogOptions options;
  final int pageIndex;
  final int pageCount;

  const _CatalogPageWidget({
    required this.items,
    required this.shopName,
    required this.shopPhone,
    required this.sym,
    required this.options,
    required this.pageIndex,
    required this.pageCount,
  });

  static const _teal = Color(0xFF00897B);
  static const _grey100 = Color(0xFFF5F5F5);
  static const _grey300 = Color(0xFFE0E0E0);
  static const _grey600 = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {
    // Same scaffolding PdfService documents: captureFromWidget injects only
    // Directionality, so MediaQuery / DefaultTextStyle / Material are wired
    // by hand. MaterialApp cannot be used — it looks for a MediaQuery
    // ancestor that doesn't exist off-screen.
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(CatalogService._pageWidth, CatalogService._pageHeight),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.black, fontSize: 12),
          child: Material(
            color: Colors.white,
            child: SizedBox(
              width: CatalogService._pageWidth,
              height: CatalogService._pageHeight,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    Expanded(child: _grid()),
                    const SizedBox(height: 10),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                if (shopPhone != null && shopPhone!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    shopPhone!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Text(
            'PRODUCT CATALOG',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    // Fixed 2×3 layout built from Rows rather than GridView: the page has a
    // hard height budget and a scrollable would let content escape the
    // capture area instead of being laid out inside it.
    final rows = <Widget>[];
    for (var i = 0; i < CatalogService.perPage; i += 2) {
      final left = i < items.length ? items[i] : null;
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left == null ? const SizedBox() : _tile(left)),
              const SizedBox(width: 14),
              Expanded(child: right == null ? const SizedBox() : _tile(right)),
            ],
          ),
        ),
      );
      if (i + 2 < CatalogService.perPage) {
        rows.add(const SizedBox(height: 14));
      }
    }
    return Column(children: rows);
  }

  Widget _tile(_CatalogItem item) {
    final p = item.product;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _grey300),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (options.includePhotos) ...[
            _photo(item),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  CurrencyFormatter.format(p.sellingPrice, symbol: sym),
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                if (options.includeSku && p.sku.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(p.sku,
                      style: const TextStyle(color: _grey600, fontSize: 10)),
                ],
                if (options.includeStock) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.isOutOfStock
                        ? 'Out of stock'
                        : '${p.totalStock} in stock',
                    style: TextStyle(
                      color: p.isOutOfStock
                          ? const Color(0xFFD32F2F)
                          : _grey600,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (p.hasVariants) ...[
                  const SizedBox(height: 4),
                  Text(
                    _variantSummary(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _grey600, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _variantSummary(Product p) {
    final names = p.variantAttributes.map((a) => a.name).join(' · ');
    return names.isEmpty ? '' : 'Options: $names';
  }

  Widget _photo(_CatalogItem item) {
    const size = 84.0;
    if (item.image == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2_outlined,
            color: _grey600, size: 30),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        item.image!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: _grey100,
        ),
      ),
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (pageCount > 1)
          Text(
            'Page ${pageIndex + 1} of $pageCount',
            style: const TextStyle(color: _grey600, fontSize: 10),
          )
        else
          const SizedBox(),
        Opacity(
          opacity: 0.55,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Powered by',
                style: TextStyle(color: _grey600, fontSize: 9),
              ),
              const SizedBox(width: 6),
              Image.asset(
                'assets/icons/app_icon.png',
                width: 16,
                height: 16,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 4),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  color: _teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
