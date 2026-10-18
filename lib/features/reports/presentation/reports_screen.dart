import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
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
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: title));
      } else {
        await CsvExportService().exportReport(
          shopName: settings.shopName,
          reportTitle: title,
          periodLabel: period,
          tables: tables,
          fileName: fileName,
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            centerTitle: false,
            title: Text(
              s.reports,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              _exporting
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : IconButton(
                      tooltip: s.tr('export'),
                      icon: const ThinIcon(tabler.Share.new),
                      onPressed: _openExportSheet,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.dashboardGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: kToolbarHeight + 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 36,
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
                          child: Text(
                            '${DateFormatter.format(_from)}  ${s.tr('dateRangeTo')}  ${DateFormatter.format(_to)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [for (final k in _tabKeys) Tab(text: s.tr(k))],
            ),
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
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
