import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/debouncer.dart';
import '../../../data/services/dues_service.dart';
import '../../../data/services/isar_service.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/dues_provider.dart';
import 'widgets/due_actions.dart';

enum _DueSort { oldest, largest }

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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final duesAsync = ref.watch(duesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.dueBook),
        actions: [
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

          final visible = all
              .where((d) =>
                  _query.isEmpty ||
                  d.customer.name.toLowerCase().contains(_query) ||
                  d.customer.phone.contains(_query))
              .toList();
          if (_sort == _DueSort.largest) {
            visible.sort((a, b) => b.totalDue.compareTo(a.totalDue));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SummaryCard(dues: all),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(s.sortOldest),
                    selected: _sort == _DueSort.oldest,
                    onSelected: (_) => setState(() => _sort = _DueSort.oldest),
                  ),
                  ChoiceChip(
                    label: Text(s.sortLargest),
                    selected: _sort == _DueSort.largest,
                    onSelected: (_) =>
                        setState(() => _sort = _DueSort.largest),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(child: Text(s.noCustomersFound)),
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
