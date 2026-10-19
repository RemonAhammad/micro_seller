import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderPositionedBox;
import 'package:flutter_svg/flutter_svg.dart' show SvgStringLoader;
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

/// Stroke widths for the thin Tabler outline icons (Tabler's own default is
/// 2.0). The sidebar bumps the selected tab to [kIconStrokeSelected] so the
/// active screen still reads clearly while the rail stays light.
const double kIconStroke = 1.25;
const double kIconStrokeSelected = 1.75;

/// One thin icon: a Tabler widget constructor tear-off such as
/// `tabler.Box.new`. Tabler icons are SVG widgets (not font `IconData`);
/// constructor tear-offs are compile-time constants, so they work in `const`
/// lists and `const ThinIcon(...)`. Any Tabler class fits this type.
typedef ThinIconBuilder = Widget Function({
  Key? key,
  double? strokeWidth,
  double? width,
  double? height,
  Color? color,
});

/// Named icons shared across screens (sidebar, dashboard, reports). One-off
/// icons elsewhere use a Tabler class directly: `ThinIcon(tabler.Plus.new)`.
abstract final class AppIcons {
  // ── Sidebar ──
  static const ThinIconBuilder dashboard = tabler.LayoutDashboard.new;
  static const ThinIconBuilder products = tabler.Box.new;
  static const ThinIconBuilder orders = tabler.Receipt.new;
  static const ThinIconBuilder returns = tabler.ArrowBackUp.new;
  static const ThinIconBuilder customers = tabler.Users.new;
  static const ThinIconBuilder dueBook = tabler.Notebook.new;
  static const ThinIconBuilder inventory = tabler.BuildingWarehouse.new;
  static const ThinIconBuilder suppliers = tabler.Truck.new;
  static const ThinIconBuilder expenses = tabler.Wallet.new;
  static const ThinIconBuilder cashRegister = tabler.CashRegister.new;
  static const ThinIconBuilder categories = tabler.Tag.new;
  static const ThinIconBuilder reports = tabler.ChartLine.new;
  static const ThinIconBuilder scanner = tabler.Barcode.new;
  static const ThinIconBuilder settings = tabler.Settings.new;

  // ── Dashboard ──
  static const ThinIconBuilder revenue = tabler.TrendingUp.new;
  static const ThinIconBuilder profit = tabler.ReportMoney.new;
  static const ThinIconBuilder pending = tabler.HourglassHigh.new;
  static const ThinIconBuilder collected = tabler.Coins.new;
  static const ThinIconBuilder lowStock = tabler.BoxOff.new;
  static const ThinIconBuilder alert = tabler.AlertTriangle.new;
  static const ThinIconBuilder whatsapp = tabler.BrandWhatsapp.new;

  // ── Warmed into the SVG cache after the first frame (main.dart); the
  // sidebar's icons come from sidebarItems so the two can't drift apart ──
  static const List<ThinIconBuilder> dashboardSet = [
    revenue, profit, pending, collected, lowStock, alert, whatsapp,
  ];
}

/// Parses [icons] at [strokeWidth] into flutter_svg's cache, one at a time,
/// so a screen that shows them later draws them in its first frame instead
/// of a frame late, after an isolate parse.
///
/// The cache key has to match what a [ThinIcon] asks for. Tabler's `Icon`
/// hands `SvgPicture.string` its `svgTemplate` with the `<STROKE_WIDTH>`
/// placeholder replaced by `strokeWidth.toString()` and no theme;
/// flutter_svg keys that on the string, the theme (the default `SvgTheme()`,
/// since the app sets no `DefaultSvgTheme`) and the color mapper (none).
/// Size and color aren't in the key: the color is a paint-time `ColorFilter`.
Future<void> warmThinIcons(
  Iterable<ThinIconBuilder> icons, {
  double strokeWidth = kIconStroke,
}) async {
  for (final builder in icons) {
    final icon = builder(strokeWidth: strokeWidth);
    if (icon is! tabler.Icon) continue;
    final svg = icon.svgTemplate
        .replaceAll('<STROKE_WIDTH>', strokeWidth.toString());
    await SvgStringLoader(svg).loadBytes(null);
  }
}

/// Drop-in for Material's `Icon`, drawing a thin Tabler icon. [color] and
/// [size] default to the ambient `IconTheme`, exactly like `Icon` (so icons
/// inside `IconButton`, `AppBar`, `ListTile`… inherit correctly). Tabler's own
/// fallback color is black, which is why the color is always resolved here.
///
/// Like `Icon`, it is drawn at [size], centered in whatever box its parent
/// forces on it (see `_CenteredIcon`), so no call site needs a `Center` or an
/// alignment to keep a 20 dp icon at 20.
class ThinIcon extends StatelessWidget {
  const ThinIcon(
    this.builder, {
    super.key,
    this.color,
    this.size,
    this.strokeWidth = kIconStroke,
  });

  final ThinIconBuilder builder;
  final Color? color;
  final double? size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    return _CenteredIcon(
      child: SizedBox.square(
        dimension: s,
        child: builder(color: c, width: s, height: s, strokeWidth: strokeWidth),
      ),
    );
  }
}

/// Lays the icon out at its own size and centers it in the box its parent
/// forces, as `Icon` centers its glyph. The SVG fills whatever box it gets,
/// so a tight or minimum constraint bigger than the icon used to draw it
/// that big: an InputDecoration prefix icon's 48 dp slot drew a 20 dp icon at
/// 48, a 40 × 40 Container without an alignment at 40. Under loose
/// constraints the box is the icon's size, as before; under forced ones it
/// is the forced size, as before. Only the drawing changed.
///
/// The whole box still takes hits, as the stretched icon did, so a
/// GestureDetector around an icon in a bigger box keeps its tap area.
class _CenteredIcon extends SingleChildRenderObjectWidget {
  const _CenteredIcon({required super.child});

  @override
  RenderPositionedBox createRenderObject(BuildContext context) =>
      _RenderCenteredIcon();
}

class _RenderCenteredIcon extends RenderPositionedBox {
  _RenderCenteredIcon() : super(widthFactor: 1, heightFactor: 1);

  @override
  bool hitTestSelf(Offset position) => true;
}
