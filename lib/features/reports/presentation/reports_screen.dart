import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/share_origin.dart';
import '../../../data/services/csv_export_service.dart';
import '../../../data/services/report_pdf_service.dart';
import '../../../data/services/report_service.dart';
import '../../../shared/widgets/bottom_sheet_handle.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/reports_provider.dart';
import 'widgets/report_tabs.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

enum _Range { today, thisWeek, thisMonth, lastMonth, thisYear, custom }

// The header under the toolbar, top to bottom: 4 px, the range chips, 6 px,
// the date line, 4 px, then the TabBar. Both text rows grow with the text
// size, and the header with them, so nothing clips or slides under the tabs.

/// Height of the range-chip row: 36 at the default text size. The chips are
/// 8 px of padding around a 12 px label (bodyMedium's 1.43 line height).
@visibleForTesting
double reportsChipRowHeight(TextScaler textScaler) =>
    36 + (textScaler.scale(12) - 12) * 1.43;

/// The header's expanded height for a TabBar [tabBarHeight] tall.
@visibleForTesting
double reportsHeaderHeight(TextScaler textScaler, double tabBarHeight) =>
    kToolbarHeight +
    4 +
    reportsChipRowHeight(textScaler) +
    6 +
    textScaler.scale(12) * 1.43 +
    4 +
    tabBarHeight;

/// Business reports: one date range, four tabs (Profit & Sales, Dues &
/// Payments, Stock & Returns, Purchases & Expenses), each exportable as PDF
/// or CSV. All numbers come from `report_service.dart`.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  _Range _range = _Range.thisMonth;
  late DateTime _from;
  late DateTime _to;
  bool _exporting = false;

  /// The app bar's export slot (the button, or its spinner while
  /// exporting): an iPad's share sheet points at it.
  final _exportSlot = GlobalKey();

  static const _tabKeys = [
    'tabProfitSales',
    'tabDuesPayments',
    'tabInventoryReturns',
    'tabPurchasesExpenses',
  ];

  @override
  void initState() {
    super.initState();
    _applyRange(_Range.thisMonth);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _applyRange(_Range r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final (from, to) = switch (r) {
      _Range.today => (today, today),
      _Range.thisWeek => (today.subtract(Duration(days: today.weekday - 1)), today),
      _Range.thisMonth => (DateTime(now.year, now.month), today),
      _Range.lastMonth => (
          DateTime(now.year, now.month - 1),
          DateTime(now.year, now.month, 0), // last day of previous month
        ),
      _Range.thisYear => (DateTime(now.year), today),
      _Range.custom => (_from, _to),
    };
    _range = r;
    _from = from;
    _to = to;
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _range = _Range.custom;
      _from = picked.start;
      _to = picked.end;
    });
  }

  String _rangeLabel(BuildContext context, _Range r) {
    final s = AppStrings.of(context);
    return switch (r) {
        _Range.today => s.tr('today'),
        _Range.thisWeek => s.tr('thisWeek'),
        _Range.thisMonth => s.tr('thisMonth'),
        _Range.lastMonth => s.tr('lastMonth'),
        _Range.thisYear => s.tr('thisYear'),
        _Range.custom => s.tr('custom'),
      };
  }

  // ─── Export ──

  Future<List<ReportTable>> _currentTables(ReportTr tr) async {
    return switch (_tabs.index) {
      0 => (await ref.read(salesReportProvider(_from, _to).future)).toTables(tr),
      1 => (await ref.read(duesReportProvider(_from, _to).future)).toTables(tr),
      2 => (await ref.read(inventoryReportProvider(_from, _to).future)).toTables(tr),
      _ => (await ref.read(purchasesReportProvider(_from, _to).future)).toTables(tr),
    };
  }

  Future<void> _export({required bool pdf}) async {
    final s = AppStrings.of(context);
    final settings = ref.read(settingsProvider.notifier);
    final title = s.tr(_tabKeys[_tabs.index]);
    final period =
        '${DateFormatter.format(_from)} ${s.tr('dateRangeTo')} ${DateFormatter.format(_to)}';
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final fileName = 'report_${_tabKeys[_tabs.index]}_${d(_from)}_${d(_to)}';
    final direction = Directionality.of(context);

    setState(() => _exporting = true);
    try {
      // Paint the spinner before any work: each page capture starts with a
      // synchronous build/layout on this isolate. After that the work yields
      // (PNG encode, PDF assembly on a background isolate), so it keeps
      // animating until the share sheet opens.
      await WidgetsBinding.instance.endOfFrame;
      final tables = await _currentTables(s.tr);
      final origin = shareOriginOf(_exportSlot.currentContext);
      if (pdf) {
        final bytes = await ReportPdfService().generate(
          shopName: settings.shopName,
          reportTitle: title,
          periodLabel: period,
          tables: tables,
          pageOf: s.pageOf,
          textDirection: direction,
        );
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName.pdf');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          subject: title,
          sharePositionOrigin: origin,
        ));
      } else {
        await CsvExportService().exportReport(
          shopName: settings.shopName,
          reportTitle: title,
          periodLabel: period,
          tables: tables,
          fileName: fileName,
          shareOrigin: origin,
        );
      }
    } catch (_) {
      if (mounted) context.showErrorSnackBar(s.errorOccurred);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openExportSheet() {
    final s = AppStrings.of(context);
    AppBottomSheet.show(
      context,
      title: '${s.tr('export')} · ${s.tr(_tabKeys[_tabs.index])}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const ThinIcon(tabler.FileTypePdf.new, color: Color(0xFFE53935)),
            title: Text(s.shareAsPdf),
            onTap: () {
              Navigator.pop(context);
              _export(pdf: true);
            },
          ),
          ListTile(
            leading: const ThinIcon(tabler.Table.new, color: AppColors.paymentPaid),
            title: Text(s.tr('shareAsCsv')),
            onTap: () {
              Navigator.pop(context);
              _export(pdf: false);
            },
          ),
        ],
      ),
    );
  }

  // ─── UI ──

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    // The theme's main color and its text color (white and white70 on Teal).
    final brand = context.brand;
    final onBrand = brand.onPrimary;
    final onBrandSoft = onBrand.withAlpha(0xB3);
    final tabBar = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: onBrand,
      unselectedLabelColor: onBrandSoft,
      indicatorColor: onBrand,
      tabs: [for (final k in _tabKeys) Tab(text: s.tr(k))],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight:
                reportsHeaderHeight(textScaler, tabBar.preferredSize.height),
            backgroundColor: brand.primary,
            foregroundColor: onBrand,
            centerTitle: false,
            title: Text(
              s.reports,
              style: TextStyle(
                color: onBrand,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              KeyedSubtree(
                key: _exportSlot,
                child: _exporting
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: onBrand),
                        ),
                      )
                    : IconButton(
                        tooltip: s.tr('export'),
                        icon: const ThinIcon(tabler.Share.new),
                        onPressed: _openExportSheet,
                      ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: brand.gradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: kToolbarHeight + 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: reportsChipRowHeight(textScaler),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              for (final r in _Range.values)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 6),
                                  child: _RangeChip(
                                    label: _rangeLabel(context, r),
                                    selected: _range == r,
                                    onTap: () => r == _Range.custom
                                        ? _pickCustom()
                                        : setState(() => _applyRange(r)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                          // One line, shrunk rather than wrapped: the header
                          // has room for exactly one above the tabs.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '${DateFormatter.format(_from)}  ${s.tr('dateRangeTo')}  ${DateFormatter.format(_to)}',
                              style: TextStyle(color: onBrandSoft, fontSize: 12),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: tabBar,
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            SalesReportTab(from: _from, to: _to),
            DuesReportTab(from: _from, to: _to),
            InventoryReportTab(from: _from, to: _to),
            PurchasesReportTab(from: _from, to: _to),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // On the header: the selected chip swaps the main color and its text
    // color (white on Teal).
    final brand = context.brand;
    return Material(
      color: selected
          ? brand.onPrimary
          : brand.onPrimary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? brand.primary : brand.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
