import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/customer_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/debouncer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'widgets/customer_card.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() =>
      _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.customers),
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
      body: customersAsync.when(
        data: (allCustomers) {
          final customers = _query.isEmpty
              ? allCustomers
              : allCustomers
                  .where((c) =>
                      c.name.toLowerCase().contains(_query) ||
                      c.phone.contains(_query))
                  .toList();

          if (customers.isEmpty) {
            return EmptyState(
              icon: Icons.people_rounded,
              title: _query.isNotEmpty ? s.noCustomersFound : s.noDataFound,
              subtitle: _query.isEmpty ? s.addFirstCustomer : null,
              actionLabel: _query.isEmpty ? s.addCustomer : null,
              onAction: _query.isEmpty ? () => context.push('/customers/add') : null,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => AnimatedEntrance(
              index: i,
              child: CustomerCard(customer: customers[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('${AppStrings.of(context).error}: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/customers/add'),
        tooltip: s.addCustomer,
        child: const Icon(Icons.add),
      ),
    );
  }
}
