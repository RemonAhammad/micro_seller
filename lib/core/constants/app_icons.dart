import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderPositionedBox;
import 'package:flutter_svg/flutter_svg.dart' show SvgStringLoader;
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

const double kIconStroke = 1.25;
const double kIconStrokeSelected = 1.75;

typedef ThinIconBuilder = Widget Function({
  Key? key,
  double? strokeWidth,
  double? width,
  double? height,
  Color? color,
});

abstract final class AppIcons {

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
  static const ThinIconBuilder goals = tabler.Target.new;
  static const ThinIconBuilder settings = tabler.Settings.new;

  static const ThinIconBuilder revenue = tabler.TrendingUp.new;
  static const ThinIconBuilder profit = tabler.ReportMoney.new;
  static const ThinIconBuilder pending = tabler.HourglassHigh.new;
  static const ThinIconBuilder collected = tabler.Coins.new;
  static const ThinIconBuilder lowStock = tabler.BoxOff.new;
  static const ThinIconBuilder alert = tabler.AlertTriangle.new;
  static const ThinIconBuilder whatsapp = tabler.BrandWhatsapp.new;

  static const ThinIconBuilder update = tabler.CloudDownload.new;

  static const List<ThinIconBuilder> dashboardSet = [
    revenue, profit, pending, collected, lowStock, alert, whatsapp,
  ];
}

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
