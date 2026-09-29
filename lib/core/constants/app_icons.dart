import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

/// Stroke widths for the thin Tabler outline icons (Tabler's own default is
/// 2.0). The sidebar bumps the selected tab to [kIconStrokeSelected] so the
/// active screen still reads clearly while the rail stays light.
const double kIconStroke = 1.25;
const double kIconStrokeSelected = 1.75;

/// Draws one thin icon. Tabler icons are SVG widgets (not font `IconData`),
/// so each is a builder taking color, size and stroke width.
typedef ThinIconBuilder = Widget Function(
    Color color, double size, double strokeWidth);

/// The app's thin line icons (Tabler, via `tabler_icons_next`). Static
/// methods, so their tear-offs are constants — `SidebarItem` lists can stay
/// `const`.
abstract final class AppIcons {
  // ── Sidebar ──
  static Widget dashboard(Color c, double s, double w) =>
      tabler.LayoutDashboard(color: c, width: s, height: s, strokeWidth: w);
  static Widget products(Color c, double s, double w) =>
      tabler.Box(color: c, width: s, height: s, strokeWidth: w);
  static Widget orders(Color c, double s, double w) =>
      tabler.Receipt(color: c, width: s, height: s, strokeWidth: w);
  static Widget returns(Color c, double s, double w) =>
      tabler.ArrowBackUp(color: c, width: s, height: s, strokeWidth: w);
  static Widget customers(Color c, double s, double w) =>
      tabler.Users(color: c, width: s, height: s, strokeWidth: w);
  static Widget dueBook(Color c, double s, double w) =>
      tabler.Notebook(color: c, width: s, height: s, strokeWidth: w);
  static Widget inventory(Color c, double s, double w) =>
      tabler.BuildingWarehouse(color: c, width: s, height: s, strokeWidth: w);
  static Widget suppliers(Color c, double s, double w) =>
      tabler.Truck(color: c, width: s, height: s, strokeWidth: w);
  static Widget expenses(Color c, double s, double w) =>
      tabler.Wallet(color: c, width: s, height: s, strokeWidth: w);
  static Widget cashRegister(Color c, double s, double w) =>
      tabler.CashRegister(color: c, width: s, height: s, strokeWidth: w);
  static Widget categories(Color c, double s, double w) =>
      tabler.Tag(color: c, width: s, height: s, strokeWidth: w);
  static Widget reports(Color c, double s, double w) =>
      tabler.ChartLine(color: c, width: s, height: s, strokeWidth: w);
  static Widget scanner(Color c, double s, double w) =>
      tabler.Barcode(color: c, width: s, height: s, strokeWidth: w);
  static Widget settings(Color c, double s, double w) =>
      tabler.Settings(color: c, width: s, height: s, strokeWidth: w);

  // ── Dashboard ──
  static Widget revenue(Color c, double s, double w) =>
      tabler.TrendingUp(color: c, width: s, height: s, strokeWidth: w);
  static Widget profit(Color c, double s, double w) =>
      tabler.PigMoney(color: c, width: s, height: s, strokeWidth: w);
  static Widget pending(Color c, double s, double w) =>
      tabler.HourglassHigh(color: c, width: s, height: s, strokeWidth: w);
  static Widget collected(Color c, double s, double w) =>
      tabler.Coins(color: c, width: s, height: s, strokeWidth: w);
  static Widget lowStock(Color c, double s, double w) =>
      tabler.BoxOff(color: c, width: s, height: s, strokeWidth: w);
  static Widget alert(Color c, double s, double w) =>
      tabler.AlertTriangle(color: c, width: s, height: s, strokeWidth: w);
  static Widget whatsapp(Color c, double s, double w) =>
      tabler.BrandWhatsapp(color: c, width: s, height: s, strokeWidth: w);
}

/// Renders a [ThinIconBuilder] like Material's `Icon`: [color] defaults to the
/// ambient `IconTheme` (Tabler's own fallback is black, so always resolve it).
class ThinIcon extends StatelessWidget {
  const ThinIcon(
    this.builder, {
    super.key,
    this.color,
    this.size = 24,
    this.strokeWidth = kIconStroke,
  });

  final ThinIconBuilder builder;
  final Color? color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(dimension: size, child: builder(c, size, strokeWidth));
  }
}
