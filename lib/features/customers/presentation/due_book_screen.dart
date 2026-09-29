import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/debouncer.dart';
import '../../../data/models/customer.dart';
import '../../../data/services/dues_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/dues_provider.dart';
import 'widgets/due_actions.dart';

enum _DueSort { oldest, largest, name }

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
  const DueBookScreen({super.key});

  @override
  ConsumerState<DueBookScreen> createState() => _DueBookScreenState();
}

class _DueBookScreenState extends ConsumerState<DueBookScreen> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer();
  String _query = '';
  _DueSort _sort = _DueSort.oldest;
  _DueFilters _filters = const _DueFilters();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _recalculate() async {
    final s = AppStrings.of(context);
    final isar = await ref.read(isarProvider.future);
    final changed =
        await isar.writeTxn(() => recalculateOutstandingBalancesInTxn(isar));
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
            d.customer.phone.contains(_query))
        .where(_filters.matches)
        .toList();
    switch (_sort) {
      case _DueSort.oldest:
        break; // provider already sorts oldest-first
      case _DueSort.largest:
        visible.sort((a, b) => b.totalDue.compareTo(a.totalDue));
      case _DueSort.name:
        visible.sort((a, b) => a.customer.name
            .toLowerCase()
            .compareTo(b.customer.name.toLowerCase()));
    }
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
              child: const Icon(Icons.filter_list_rounded),
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
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
              icon: Icons.volunteer_activism_rounded,
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (sort, label) in [
                      (_DueSort.oldest, s.sortOldest),
                      (_DueSort.largest, s.sortLargest),
                      (_DueSort.name, s.sortName),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _sort == sort,
                          onSelected: (_) => setState(() => _sort = sort),
                        ),
                      ),
                  ],
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
  late final _minCtrl = TextEditingController(
      text: widget.initial.minDue > 0
          ? widget.initial.minDue.toStringAsFixed(0)
          : '');

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
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
          ],
          decoration:
              InputDecoration(prefixText: '${CurrencyFormatter.symbol} '),
          onChanged: (v) =>
              _set(_f.copyWith(minDue: double.tryParse(v) ?? 0)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.hasPhoneOnly),
          value: _f.phoneOnly,
          onChanged: (v) => _set(_f.copyWith(phoneOnly: v)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _minCtrl.clear();
                  _set(const _DueFilters());
                },
                child: Text(s.clearFilters),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s.done),
              ),
            ),
          ],
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.totalReceivable,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(s.customersOwing(dues.length),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          if (overdue > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(s.overdue30Days,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    CurrencyFormatter.formatCompact(overdue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (customer.phone.isNotEmpty)
                          Text(customer.phone,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
                        if (due.lastPaymentAt != null)
                          Text(
                            s.lastPaid(DateFormatter.timeAgo(due.lastPaymentAt!)),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(due.totalDue),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.paymentUnpaid,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ageColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.daysOutstanding(days),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ageColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        showCollectPaymentSheet(
                  context, customer, due.orderDues, due.totalDue),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: Text(s.collect),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        sendDueReminder(
                  context, ref, customer, due.orderDues, due.totalDue),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(s.remind),
                  ),
                  const Spacer(),
                  if (customer.phone.isNotEmpty)
                    IconButton(
                      tooltip: s.callCustomer,
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:${customer.phone}')),
                      icon: const Icon(Icons.call_rounded, size: 20),
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
