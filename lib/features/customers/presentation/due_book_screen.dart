import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/number_input.dart';
import '../../../core/utils/share_origin.dart';
import '../../../data/models/customer.dart';
import '../../../data/services/dues_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../shared/widgets/call_phone.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../providers/dues_provider.dart';
import 'widgets/due_actions.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

enum _DueSort {
  oldest,
  newest,
  largest,
  smallest,
  mostOrders,
  longestSincePaid,
  recentlyPaid,
  nameAsc,
  nameDesc,
}

String _sortLabel(BuildContext context, _DueSort sort) {
  final s = AppStrings.of(context);
  return switch (sort) {
    _DueSort.oldest => s.sortOldest,
    _DueSort.newest => s.sortNewest,
    _DueSort.largest => s.sortLargest,
    _DueSort.smallest => s.sortSmallest,
    _DueSort.mostOrders => s.sortMostOrders,
    _DueSort.longestSincePaid => s.sortLongestSincePaid,
    _DueSort.recentlyPaid => s.sortRecentlyPaid,
    _DueSort.nameAsc => s.sortName,
    _DueSort.nameDesc => s.sortNameDesc,
  };
}

ThinIconBuilder _sortIcon(_DueSort sort) => switch (sort) {
      _DueSort.oldest || _DueSort.newest => tabler.Clock.new,
      _DueSort.largest || _DueSort.smallest => tabler.Cash.new,
      _DueSort.mostOrders => tabler.Receipt.new,
      _DueSort.longestSincePaid ||
      _DueSort.recentlyPaid =>
        tabler.History.new,
      _DueSort.nameAsc || _DueSort.nameDesc => tabler.SortAscendingLetters.new,
    };

/// Sorts in place. Ties fall back to the larger due, so the list is stable
/// and the most money is always nearer the top.
void _sortDues(List<CustomerDue> list, _DueSort sort) {
  int byDue(CustomerDue a, CustomerDue b) => b.totalDue.compareTo(a.totalDue);
  int byName(CustomerDue a, CustomerDue b) => a.customer.name
      .toLowerCase()
      .compareTo(b.customer.name.toLowerCase());
  // Never-paid customers count as "paid at the dawn of time".
  DateTime paidAt(CustomerDue d) => d.lastPaymentAt ?? DateTime(0);

  int Function(CustomerDue, CustomerDue) cmp = switch (sort) {
    _DueSort.oldest => (a, b) => b.daysOutstanding.compareTo(a.daysOutstanding),
    _DueSort.newest => (a, b) => a.daysOutstanding.compareTo(b.daysOutstanding),
    _DueSort.largest => byDue,
    _DueSort.smallest => (a, b) => a.totalDue.compareTo(b.totalDue),
    _DueSort.mostOrders => (a, b) =>
        b.orderDues.length.compareTo(a.orderDues.length),
    _DueSort.longestSincePaid => (a, b) => paidAt(a).compareTo(paidAt(b)),
    _DueSort.recentlyPaid => (a, b) => paidAt(b).compareTo(paidAt(a)),
    _DueSort.nameAsc => byName,
    _DueSort.nameDesc => (a, b) => byName(b, a),
  };
  list.sort((a, b) {
    final c = cmp(a, b);
    return c != 0 ? c : byDue(a, b);
  });
}

enum _AgeBucket { under30, from30to60, over60 }

enum _Activity { any, neverPaid, noPaymentIn30Days }

/// Due Book filters. All are AND-ed; an empty set means "don't filter".
class _DueFilters {
  const _DueFilters({
    this.ages = const {},
    this.tags = const {},
    this.activity = _Activity.any,
    this.phoneOnly = false,
    this.minDue = 0,
  });

  final Set<_AgeBucket> ages;
  final Set<CustomerTag> tags;
  final _Activity activity;
  final bool phoneOnly;
  final double minDue;

  int get activeCount =>
      (ages.isNotEmpty ? 1 : 0) +
      (tags.isNotEmpty ? 1 : 0) +
      (activity != _Activity.any ? 1 : 0) +
      (phoneOnly ? 1 : 0) +
      (minDue > 0 ? 1 : 0);

  _DueFilters copyWith({
    Set<_AgeBucket>? ages,
    Set<CustomerTag>? tags,
    _Activity? activity,
    bool? phoneOnly,
    double? minDue,
  }) =>
      _DueFilters(
        ages: ages ?? this.ages,
        tags: tags ?? this.tags,
        activity: activity ?? this.activity,
        phoneOnly: phoneOnly ?? this.phoneOnly,
        minDue: minDue ?? this.minDue,
      );

  static _AgeBucket bucketOf(CustomerDue d) {
    final days = d.daysOutstanding;
    if (days >= 60) return _AgeBucket.over60;
    if (days >= 30) return _AgeBucket.from30to60;
    return _AgeBucket.under30;
  }

  bool matches(CustomerDue d) {
    if (ages.isNotEmpty && !ages.contains(bucketOf(d))) return false;
    if (tags.isNotEmpty && !tags.contains(d.customer.tag)) return false;
    if (phoneOnly && d.customer.phone.trim().isEmpty) return false;
    if (minDue > 0 && d.totalDue < minDue) return false;
    switch (activity) {
      case _Activity.any:
        break;
      case _Activity.neverPaid:
        if (d.lastPaymentAt != null) return false;
      case _Activity.noPaymentIn30Days:
        final last = d.lastPaymentAt;
        if (last != null && DateTime.now().difference(last).inDays < 30) {
          return false;
        }
    }
    return true;
  }
}

String _ageLabel(BuildContext context, _AgeBucket b) {
  final s = AppStrings.of(context);
  return switch (b) {
    _AgeBucket.under30 => s.ageUnder30,
    _AgeBucket.from30to60 => s.age30to60,
    _AgeBucket.over60 => s.age60plus,
  };
}

String _tagLabel(BuildContext context, CustomerTag t) {
  final s = AppStrings.of(context);
  return switch (t) {
    CustomerTag.newCustomer => s.tagNew,
    CustomerTag.regular => s.regular,
    CustomerTag.vip => s.vip,
  };
}

String _activityLabel(BuildContext context, _Activity a) {
  final s = AppStrings.of(context);
  return switch (a) {
    _Activity.any => s.all,
    _Activity.neverPaid => s.neverPaid,
    _Activity.noPaymentIn30Days => s.noPaymentIn30Days,
  };
}

/// Due Book ("baki khata"): every customer who owes money, with one-tap
/// collect / WhatsApp reminder / call. Dues are computed from orders — see
/// `computeOrderDues` — not from the stored outstandingBalance counter.
class DueBookScreen extends ConsumerStatefulWidget {
  const DueBookScreen({super.key, this.initialOver60 = false});

  /// Start filtered to the 60+ days bucket (dashboard overdue banner).
  final bool initialOver60;

  @override
  ConsumerState<DueBookScreen> createState() => _DueBookScreenState();
}

class _DueBookScreenState extends ConsumerState<DueBookScreen> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer();
  String _query = '';
  _DueSort _sort = _DueSort.oldest;
  late _DueFilters _filters = widget.initialOver60
      ? const _DueFilters(ages: {_AgeBucket.over60})
      : const _DueFilters();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _recalculate() async {
    final s = AppStrings.of(context);
    final isar = await ref.read(isarProvider.future);
    if (!mounted) return;
    // Load, compute and write in one transaction on a worker isolate — with
    // thousands of orders, doing it here froze the spinner.
    final changed = await runWithProgress(
        context, () => recalculateOutstandingBalances(isar));
    if (mounted) context.showSuccessSnackBar(s.balancesRecalculated(changed));
  }

  Future<void> _openFilters() async {
    await AppBottomSheet.show(
      context,
      title: AppStrings.of(context).filter,
      child: _FilterSheet(
        initial: _filters,
        // Live: the list behind the sheet updates as chips are toggled.
        onChanged: (f) => setState(() => _filters = f),
      ),
    );
  }

  List<CustomerDue> _apply(List<CustomerDue> all) {
    final visible = all
        .where((d) =>
            _query.isEmpty ||
            d.customer.name.toLowerCase().contains(_query) ||
            NumberInput.phoneMatches(d.customer.phone, _query))
        .where(_filters.matches)
        .toList();
    _sortDues(visible, _sort);
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final duesAsync = ref.watch(duesProvider);
    final active = _filters.activeCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.dueBook),
        actions: [
          IconButton(
            tooltip: s.filter,
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: active > 0,
              label: Text('$active'),
              child: const ThinIcon(tabler.Filter.new),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _recalculate(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'recalc',
                child: Text(s.recalculateBalances),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => _debouncer.run(
                  () => setState(() => _query = v.toLowerCase())),
              decoration: InputDecoration(
                hintText: s.searchCustomers,
                prefixIcon: const ThinIcon(tabler.Search.new, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const ThinIcon(tabler.X.new),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: duesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${s.error}: $e')),
        data: (all) {
          if (all.isEmpty) {
            return EmptyState(
              icon: tabler.HeartHandshake.new,
              title: s.noDues,
              subtitle: s.noDuesSubtitle,
            );
          }

          final visible = _apply(all);
          final narrowed = active > 0 || _query.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // Totals follow the filters — "how much do my VIPs owe?"
              _SummaryCard(dues: visible),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _SortButton(
                  value: _sort,
                  onChanged: (v) => setState(() => _sort = v),
                ),
              ),
              if (active > 0) ...[
                const SizedBox(height: 8),
                _ActiveFilterChips(
                  filters: _filters,
                  onChanged: (f) => setState(() => _filters = f),
                ),
              ],
              if (narrowed) ...[
                const SizedBox(height: 8),
                Text(
                  s.showingOf(visible.length, all.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                ),
              ],
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    children: [
                      Text(active > 0 ? s.noDuesMatchFilters : s.noCustomersFound),
                      if (active > 0)
                        TextButton(
                          onPressed: () =>
                              setState(() => _filters = const _DueFilters()),
                          child: Text(s.clearFilters),
                        ),
                    ],
                  ),
                ),
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedEntrance(
                    index: i,
                    child: _DueCard(due: visible[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "Sort by: Oldest first ▾" — opens a menu of every sort option.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final _DueSort value;
  final ValueChanged<_DueSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<_DueSort>(
      initialValue: value,
      tooltip: s.sortBy,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final sort in _DueSort.values)
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == value,
            child: Text(_sortLabel(context, sort)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThinIcon(_sortIcon(value), size: 18, color: cs.primary),
            const SizedBox(width: 6),
            // A long sort name, a narrow layout or large text wraps the
            // label (the pill grows taller) instead of overflowing.
            Flexible(
              child: Text(
                '${s.sortBy}: ${_sortLabel(context, value)}',
                style:
                    TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
              ),
            ),
            ThinIcon(tabler.CaretDown.new, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

/// Deletable chips for each active filter, plus "Clear filters".
class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({required this.filters, required this.onChanged});

  final _DueFilters filters;
  final ValueChanged<_DueFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    Widget chip(String label, _DueFilters without) => InputChip(
          label: Text(label),
          onDeleted: () => onChanged(without),
          visualDensity: VisualDensity.compact,
        );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final a in filters.ages)
          chip(_ageLabel(context, a),
              filters.copyWith(ages: {...filters.ages}..remove(a))),
        for (final t in filters.tags)
          chip(_tagLabel(context, t),
              filters.copyWith(tags: {...filters.tags}..remove(t))),
        if (filters.activity != _Activity.any)
          chip(_activityLabel(context, filters.activity),
              filters.copyWith(activity: _Activity.any)),
        if (filters.phoneOnly)
          chip(s.hasPhoneOnly, filters.copyWith(phoneOnly: false)),
        if (filters.minDue > 0)
          chip('≥ ${CurrencyFormatter.format(filters.minDue)}',
              filters.copyWith(minDue: 0)),
        TextButton(
          onPressed: () => onChanged(const _DueFilters()),
          child: Text(s.clearFilters),
        ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.onChanged});

  final _DueFilters initial;
  final ValueChanged<_DueFilters> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _DueFilters _f = widget.initial;
  late final _minCtrl =
      TextEditingController(text: _amountText(widget.initial.minDue));

  /// [amount] as it was typed: 12.5 stays 12.5 (rounding it to a whole
  /// number showed 13 while the filter was 12.5), 100 shows as 100. Empty
  /// for none.
  static String _amountText(double amount) {
    if (amount <= 0) return '';
    final fixed = amount.toStringAsFixed(NumberInput.moneyDecimals);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    super.dispose();
  }

  void _set(_DueFilters f) {
    setState(() => _f = f);
    widget.onChanged(f);
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _section(s.dueAge),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final b in _AgeBucket.values)
              FilterChip(
                label: Text(_ageLabel(context, b)),
                selected: _f.ages.contains(b),
                onSelected: (on) => _set(_f.copyWith(
                    ages: on ? {..._f.ages, b} : ({..._f.ages}..remove(b)))),
              ),
          ],
        ),
        _section(s.customerType),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in CustomerTag.values)
              FilterChip(
                label: Text(_tagLabel(context, t)),
                selected: _f.tags.contains(t),
                onSelected: (on) => _set(_f.copyWith(
                    tags: on ? {..._f.tags, t} : ({..._f.tags}..remove(t)))),
              ),
          ],
        ),
        _section(s.paymentActivity),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final a in _Activity.values)
              ChoiceChip(
                label: Text(_activityLabel(context, a)),
                selected: _f.activity == a,
                onSelected: (_) => _set(_f.copyWith(activity: a)),
              ),
          ],
        ),
        _section(s.minimumDue),
        TextField(
          controller: _minCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [DecimalInputFormatter.money()],
          decoration:
              InputDecoration(prefixText: '${CurrencyFormatter.symbol} '),
          onChanged: (v) =>
              _set(_f.copyWith(minDue: NumberInput.parseDecimal(v) ?? 0)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.hasPhoneOnly),
          value: _f.phoneOnly,
          onChanged: (v) => _set(_f.copyWith(phoneOnly: v)),
        ),
        const SizedBox(height: 8),
        // Side by side at equal widths; stacked when a label's word wouldn't
        // fit its half (a narrow layout, large text).
        ButtonPair(
          first: OutlinedButton(
            onPressed: () {
              _minCtrl.clear();
              _set(const _DueFilters());
            },
            child: Text(s.clearFilters),
          ),
          second: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.done),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.dues});

  final List<CustomerDue> dues;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final total = dues.fold<double>(0, (sum, d) => sum + d.totalDue);
    final overdue = dues
        .expand((d) => d.orderDues)
        .where((od) =>
            od.order.createdAt != null &&
            DateTime.now().difference(od.order.createdAt!).inDays > 30)
        .fold<double>(0, (sum, od) => sum + od.due);
    // The theme's main color and its text color (white and white70 on Teal).
    final brand = context.brand;
    final onBrand = brand.onPrimary;
    final onBrandSoft = onBrand.withAlpha(0xB3);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brand.primary, brand.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.totalReceivable,
                      style: TextStyle(color: onBrandSoft, fontSize: 12)),
                  const SizedBox(height: 4),
                  // Shrinks to fit rather than wrapping mid-number.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      CurrencyFormatter.format(total),
                      style: TextStyle(
                        color: onBrand,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(s.customersOwing(dues.length),
                      style: TextStyle(color: onBrandSoft, fontSize: 12)),
                ],
              ),
            ),
            if (overdue > 0)
              // At most 45% of the card, so the total keeps the room it
              // needs; its label wraps and its amount shrinks instead.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: onBrand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(s.overdue30Days,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: onBrandSoft, fontSize: 11)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.formatCompact(overdue),
                          style: TextStyle(
                            color: onBrand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The least a due card's Collect / Remind pair is scaled to stay on one
/// line; needing more, Remind wraps under Collect instead.
const _kActionsMinScale = 0.97;

/// What [text] needs drawn by a [Text] here with [style]: the width of its
/// longest word, and of the whole text on one line (rounded up).
({double word, double line}) _textWidths(
    BuildContext context, String text, TextStyle? style) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  final widths = (
    word: painter.minIntrinsicWidth.ceilToDouble(),
    line: painter.maxIntrinsicWidth.ceilToDouble(),
  );
  painter.dispose();
  return widths;
}

class _DueCard extends ConsumerWidget {
  const _DueCard({required this.due});

  final CustomerDue due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final days = due.daysOutstanding;
    final ageColor = days >= 60
        ? AppColors.paymentUnpaid
        : days >= 30
            ? AppColors.paymentPartial
            : theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final customer = due.customer;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/customers/${customer.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(builder: (context, constraints) {
                final amount = CurrencyFormatter.format(due.totalDue);
                final age = s.daysOutstanding(days);
                final lastPaid = due.lastPaymentAt == null
                    ? null
                    : s.lastPaid(DateFormatter.timeAgo(due.lastPaymentAt!));
                final nameStyle = theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700);
                final phoneStyle = theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6));
                final paidStyle = theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5));
                const amountStyle = TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.paymentUnpaid,
                );
                final ageStyle = TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ageColor,
                );
                // The amount column keeps its own width while the name
                // column beside it still fits its longest word, as it always
                // did. Past that (a huge amount, a narrow layout, large text)
                // it takes at most 45% of the row, so the name keeps room: its
                // amount shrinks and its age label wraps.
                final amountWidth = math.max(
                        _textWidths(context, amount, amountStyle).line,
                        _textWidths(context, age, ageStyle).line + 16) +
                    8;
                final nameWidth = [
                  _textWidths(context, customer.name, nameStyle).word,
                  if (customer.phone.isNotEmpty)
                    _textWidths(context, customer.phone, phoneStyle).word,
                  if (lastPaid != null)
                    _textWidths(context, lastPaid, paidStyle).word,
                ].reduce(math.max);
                final fits = amountWidth + nameWidth <= constraints.maxWidth;

                Widget amountText = Text(amount, style: amountStyle);
                if (!fits) {
                  amountText =
                      FittedBox(fit: BoxFit.scaleDown, child: amountText);
                }
                Widget amountColumn = Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      amountText,
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ageColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(age, style: ageStyle),
                      ),
                    ],
                  ),
                );
                if (!fits) {
                  amountColumn = ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                    child: amountColumn,
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: nameStyle),
                          if (customer.phone.isNotEmpty)
                            Text(customer.phone, style: phoneStyle),
                          if (lastPaid != null) Text(lastPaid, style: paidStyle),
                        ],
                      ),
                    ),
                    amountColumn,
                  ],
                );
              }),
              const SizedBox(height: 4),
              Row(
                children: [
                  // Collect and Remind side by side at their own widths, as
                  // always. A few pixels short (360 dp at 100% text is under
                  // 1 px short), the pair scales down a hair; short of more
                  // (a narrow layout, large text), Remind moves under
                  // Collect.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth:
                                  constraints.maxWidth / _kActionsMinScale),
                          child: Wrap(
                            children: [
                              TextButton.icon(
                                onPressed: () => showCollectPaymentSheet(
                                    context,
                                    customer,
                                    due.orderDues,
                                    due.totalDue),
                                icon:
                                    const ThinIcon(tabler.Cash.new, size: 18),
                                label: Text(s.collect),
                              ),
                              // Its own context: an iPad's share sheet
                              // points at the button.
                              Builder(
                                builder: (buttonContext) => TextButton.icon(
                                  onPressed: () => sendDueReminder(context, ref,
                                      customer, due.orderDues, due.totalDue,
                                      shareOrigin:
                                          shareOriginOf(buttonContext)),
                                  icon: const ThinIcon(
                                      tabler.MessageCircle.new,
                                      size: 18),
                                  label: Text(s.remind),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (customer.phone.isNotEmpty)
                    IconButton(
                      tooltip: s.callCustomer,
                      // A device that can't call shows the number instead.
                      onPressed: () => callPhone(context, customer.phone),
                      icon: const ThinIcon(tabler.Phone.new, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
