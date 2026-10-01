import 'package:flutter/material.dart';
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
  static const ThinIconBuilder profit = tabler.PigMoney.new;
  static const ThinIconBuilder pending = tabler.HourglassHigh.new;
  static const ThinIconBuilder collected = tabler.Coins.new;
  static const ThinIconBuilder lowStock = tabler.BoxOff.new;
  static const ThinIconBuilder alert = tabler.AlertTriangle.new;
  static const ThinIconBuilder whatsapp = tabler.BrandWhatsapp.new;
}

/// Drop-in for Material's `Icon`, drawing a thin Tabler icon. [color] and
/// [size] default to the ambient `IconTheme`, exactly like `Icon` (so icons
/// inside `IconButton`, `AppBar`, `ListTile`… inherit correctly). Tabler's own
/// fallback color is black, which is why the color is always resolved here.
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
    return SizedBox.square(
      dimension: s,
      child: builder(color: c, width: s, height: s, strokeWidth: strokeWidth),
    );
  }
}
