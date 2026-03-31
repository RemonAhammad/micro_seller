import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/order.dart';
import '../providers/order_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/order_item_row.dart';

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarAsync = ref.watch(isarProvider);

    return isarAsync.when(
      data: (isar) => _OrderDetailBody(orderId: orderId),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  final int orderId;

  const _OrderDetailBody({required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final theme = Theme.of(context);

    return ordersAsync.when(
      data: (orders) {
        final order = orders.where((o) => o.id == orderId).firstOrNull;
        if (order == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Order not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(order.orderNumber),
            actions: [
              PopupMenuButton<String>(
                onSelected: (action) =>
                    _handleAction(context, ref, order, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'share_text',
                      child: ListTile(
                        leading: Icon(Icons.message_rounded),
                        title: Text('Share via WhatsApp'),
                        contentPadding: EdgeInsets.zero,
                      )),
                  const PopupMenuItem(
                      value: 'share_pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_rounded),
                        title: Text('Share PDF'),
                        contentPadding: EdgeInsets.zero,
                      )),
                  const PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                        leading: Icon(Icons.print_rounded),
                        title: Text('Print'),
                        contentPadding: EdgeInsets.zero,
                      )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_rounded, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      )),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status row
                Row(
                  children: [
                    OrderStatusBadge(status: order.orderStatus),
                    const SizedBox(width: 8),
                    PaymentStatusBadge(status: order.paymentStatus),
                    const Spacer(),
                    Text(
                      DateFormatter.formatWithTime(order.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Customer info
                if (order.customerName.isNotEmpty)
                  _InfoCard(children: [
                    _InfoRow(label: 'Customer', value: order.customerName),
                    if (order.customerPhone.isNotEmpty)
                      _InfoRow(label: 'Phone', value: order.customerPhone),
                  ]),
                const SizedBox(height: 12),

                // Items
                _SectionLabel('Order Items'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: order.items.asMap().entries.map((e) {
                      return OrderItemRow(
                        item: e.value,
                        showDivider: e.key < order.items.length - 1,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Totals
                _InfoCard(children: [
                  _InfoRow(
                      label: 'Subtotal',
                      value: CurrencyFormatter.format(order.subtotal)),
                  if (order.discountAmount > 0)
                    _InfoRow(
                      label: 'Discount',
                      value:
                          '- ${CurrencyFormatter.format(order.discountAmount)}',
                      valueColor: Colors.green,
                    ),
                  if (order.deliveryFee > 0)
                    _InfoRow(
                        label: 'Delivery',
                        value: CurrencyFormatter.format(order.deliveryFee)),
                  const Divider(height: 16),
                  _InfoRow(
                    label: 'Total',
                    value: CurrencyFormatter.format(order.totalAmount),
                    isBold: true,
                    valueColor: theme.colorScheme.primary,
                  ),
                  _InfoRow(
                      label: 'Paid',
                      value: CurrencyFormatter.format(order.amountPaid)),
                  if (order.balanceDue > 0)
                    _InfoRow(
                      label: 'Balance Due',
                      value: CurrencyFormatter.format(order.balanceDue),
                      isBold: true,
                      valueColor: AppColors.paymentUnpaid,
                    ),
                ]),
                const SizedBox(height: 12),

                if (order.notes.isNotEmpty)
                  _InfoCard(children: [
                    Text('Notes',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        )),
                    const SizedBox(height: 4),
                    Text(order.notes),
                  ]),

                const SizedBox(height: 20),

                // Status actions
                _StatusActions(order: order),

                const SizedBox(height: 12),

                // Pay button
                if (order.paymentStatus != PaymentStatus.paid)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showPaymentDialog(context, ref, order),
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Record Payment'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, Order order, String action) async {
    final pdfService = PdfService();

    switch (action) {
      case 'share_text':
        final text = pdfService.generateWhatsAppText(order);
        await Share.share(text);
        break;

      case 'share_pdf':
        final bytes = await pdfService.generateOrderReceipt(order);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${order.orderNumber}.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)]);
        break;

      case 'print':
        final bytes = await pdfService.generateOrderReceipt(order);
        await Printing.layoutPdf(onLayout: (_) async => bytes);
        break;

      case 'delete':
        if (!context.mounted) return;
        final ok = await ConfirmDialog.show(
          context,
          title: 'Delete Order',
          message: 'Delete ${order.orderNumber}? This cannot be undone.',
          confirmText: 'Delete',
          isDestructive: true,
          icon: Icons.delete_rounded,
        );
        if (ok == true && context.mounted) {
          await ref
              .read(orderNotifierProvider.notifier)
              .deleteOrder(order.id);
          context.pop();
        }
        break;
    }
  }

  void _showPaymentDialog(
      BuildContext context, WidgetRef ref, Order order) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Balance due: ${CurrencyFormatter.format(order.balanceDue)}'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
              ],
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '৳ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              if (amount <= 0) return;
              await ref
                  .read(orderNotifierProvider.notifier)
                  .recordPayment(order.id, amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatusActions extends ConsumerWidget {
  final Order order;

  const _StatusActions({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextStatus = switch (order.orderStatus) {
      OrderStatus.pending => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.shipped,
      OrderStatus.shipped => OrderStatus.completed,
      _ => null,
    };

    final nextLabel = switch (nextStatus) {
      OrderStatus.confirmed => 'Confirm Order',
      OrderStatus.shipped => 'Mark as Shipped',
      OrderStatus.completed => 'Mark as Completed',
      _ => null,
    };

    if (nextLabel == null || nextStatus == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref
              .read(orderNotifierProvider.notifier)
              .updateStatus(order.id, nextStatus);
        },
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(nextLabel),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InfoRow(
      {required this.label,
      required this.value,
      this.valueColor,
      this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6))),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14));
  }
}
