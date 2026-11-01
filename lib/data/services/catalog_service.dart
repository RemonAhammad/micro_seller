import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' show SvgStringLoader, vg;

import '../../core/constants/app_strings.dart';
import '../../core/theme/document_brand.dart';
import '../../core/utils/currency_formatter.dart';
import '../models/product.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';
import 'pdf_assembly.dart';
import 'pdf_service.dart';
import 'product_image_store.dart';
import 'widget_capture.dart';

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

class _CatalogItem {
  final Product product;

  final ui.Image? photo;

  final bool photoUnreadable;

  const _CatalogItem(this.product, {this.photo, this.photoUnreadable = false});

  bool get needsPlaceholder => photo == null && !photoUnreadable;
}

class _CatalogArt {

  final ui.Image? watermarkIcon;

  final ui.Image? placeholderIcon;

  const _CatalogArt({this.watermarkIcon, this.placeholderIcon});
}

class CatalogService {

  static const double _pageWidth = 794;
  static const double _pageHeight = 1123;

  static const int perPage = 6;

  static const double _photoSize = 84;

  Future<Uint8List> generateCatalogImage(
    List<Product> products, {
    required String shopName,
    String? shopPhone,
    String? currencySymbol,
    CatalogOptions options = const CatalogOptions(),
  }) async {
    final items = await _load(products.take(perPage).toList(), options);
    ui.Image? placeholder;
    try {
      if (options.includePhotos &&
          items.any((item) => item.needsPlaceholder)) {
        placeholder = await _rasterizePlaceholderIcon();
      }
      return await _capture(
        items,
        shopName: shopName,
        shopPhone: shopPhone,
        sym: currencySymbol ?? CurrencyFormatter.symbol,
        options: options,
        pageIndex: 0,
        pageCount: 1,
        art: _CatalogArt(
          watermarkIcon: await loadPdfWatermarkIcon(),
          placeholderIcon: placeholder,
        ),
      );
    } finally {
      _dispose(items);
      placeholder?.dispose();
    }
  }

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

    final watermarkIcon = await loadPdfWatermarkIcon();
    ui.Image? placeholder;
    var placeholderTried = false;
    final pages = <Uint8List>[];
    try {
      for (var i = 0; i < chunks.length; i++) {

        final items = await _load(chunks[i], options);
        try {
          if (!placeholderTried &&
              options.includePhotos &&
              items.any((item) => item.needsPlaceholder)) {
            placeholderTried = true;
            placeholder = await _rasterizePlaceholderIcon();
          }
          pages.add(await _capture(
            items,
            shopName: shopName,
            shopPhone: shopPhone,
            sym: sym,
            options: options,
            pageIndex: i,
            pageCount: chunks.length,
            art: _CatalogArt(
              watermarkIcon: watermarkIcon,
              placeholderIcon: placeholder,
            ),
          ));
        } finally {
          _dispose(items);
        }
      }
    } finally {
      placeholder?.dispose();
    }

    return assemblePdf(pages, jpegPages: (
      width: (_pageWidth * kPdfCapturePixelRatio).round(),
      height: (_pageHeight * kPdfCapturePixelRatio).round(),
    ));
  }

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

  Future<List<_CatalogItem>> _load(
    List<Product> products,
    CatalogOptions options,
  ) async {
    final px = (_photoSize * kPdfCapturePixelRatio).round();
    final out = <_CatalogItem>[];
    for (final p in products) {
      Uint8List? bytes;
      final photo = resolveProductImagePath(p.imagePath);
      if (options.includePhotos && photo != null) {
        try {
          final file = File(photo);
          if (await file.exists()) bytes = await file.readAsBytes();
        } catch (_) {
          bytes = null;
        }
      }
      if (bytes == null) {
        out.add(_CatalogItem(p));
        continue;
      }
      try {
        final photo = await decodeImageForBox(
          await ui.ImmutableBuffer.fromUint8List(bytes),
          width: px,
          height: px,
          fit: BoxFit.cover,
        );
        out.add(_CatalogItem(p, photo: photo));
      } catch (_) {
        out.add(_CatalogItem(p, photoUnreadable: true));
      }
    }
    return out;
  }

  void _dispose(List<_CatalogItem> items) {
    for (final item in items) {
      item.photo?.dispose();
    }
  }

  Future<ui.Image?> _rasterizePlaceholderIcon() async {
    try {
      final svg = const tabler.Package()
          .svgTemplate
          .replaceAll('<STROKE_WIDTH>', kIconStroke.toString());
      final info = await vg.loadPicture(SvgStringLoader(svg), null);
      try {
        final px = (_photoSize * kPdfCapturePixelRatio).round();
        final viewBox = info.size;
        final scale = math.min(px / viewBox.width, px / viewBox.height);
        final recorder = ui.PictureRecorder();
        Canvas(recorder)
          ..translate((px - viewBox.width * scale) / 2,
              (px - viewBox.height * scale) / 2)
          ..scale(scale)
          ..saveLayer(
            Offset.zero & viewBox,
            Paint()
              ..colorFilter = const ColorFilter.mode(
                  _CatalogPageWidget._grey600, BlendMode.srcIn),
          )
          ..drawPicture(info.picture)
          ..restore();
        final picture = recorder.endRecording();
        try {
          return await picture.toImage(px, px);
        } finally {
          picture.dispose();
        }
      } finally {
        info.picture.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _capture(
    List<_CatalogItem> items, {
    required String shopName,
    required String? shopPhone,
    required String sym,
    required CatalogOptions options,
    required int pageIndex,
    required int pageCount,
    required _CatalogArt art,
  }) {
    return captureWidgetPng(
      _CatalogPageWidget(
        items: items,
        shopName: shopName,
        shopPhone: shopPhone,
        sym: sym,
        options: options,
        pageIndex: pageIndex,
        pageCount: pageCount,
        art: art,
      ),
      pixelRatio: kPdfCapturePixelRatio,
      targetSize: const Size(_pageWidth, _pageHeight),

      delay: const Duration(milliseconds: 100),
    );
  }
}

class _CatalogPageWidget extends StatelessWidget {
  final List<_CatalogItem> items;
  final String shopName;
  final String? shopPhone;
  final String sym;
  final CatalogOptions options;
  final int pageIndex;
  final int pageCount;
  final _CatalogArt art;

  const _CatalogPageWidget({
    required this.items,
    required this.shopName,
    required this.shopPhone,
    required this.sym,
    required this.options,
    required this.pageIndex,
    required this.pageCount,
    required this.art,
  });

  static Color get _brand => DocumentBrand.color;
  static Color get _onBrand => DocumentBrand.onColor;
  static Color get _brandText => DocumentBrand.textColor;
  static const _grey100 = Color(0xFFF5F5F5);
  static const _grey300 = Color(0xFFE0E0E0);
  static const _grey600 = Color(0xFF757575);

  @override
  Widget build(BuildContext context) {

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
        color: _brand,
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
                  style: TextStyle(
                    color: _onBrand,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                if (shopPhone != null && shopPhone!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    shopPhone!,

                    style: TextStyle(
                        color: _onBrand.withAlpha(0xB3), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'PRODUCT CATALOG',
            style: TextStyle(
              color: _onBrand,
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
                  style: TextStyle(
                    color: _brandText,
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
    const size = CatalogService._photoSize;
    final photo = item.photo;
    if (photo == null && !item.photoUnreadable) {
      final icon = art.placeholderIcon;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _grey100,
          borderRadius: BorderRadius.circular(8),
        ),

        child: icon != null
            ? SizedBox.square(
                dimension: 30,
                child: RawImage(image: icon, fit: BoxFit.contain),
              )
            : const ThinIcon(tabler.Package.new, color: _grey600, size: 30),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: photo != null
          ? RawImage(
              image: photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )

          : Container(
              width: size,
              height: size,
              color: _grey100,
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
              PdfWatermarkIcon(icon: art.watermarkIcon),
              const SizedBox(width: 4),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  color: kPdfWatermarkColor,
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
