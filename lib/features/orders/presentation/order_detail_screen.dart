import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/order.dart';
import '../providers/order_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../settings/providers/settings_provider.dart';
import '../../returns/presentation/create_return_screen.dart';
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
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => context.push('/orders/${order.id}/edit'),
              ),
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
                      value: 'download_pdf',
                      child: ListTile(
                        leading: Icon(Icons.download_rounded),
                        title: Text('Download PDF'),
                        contentPadding: EdgeInsets.zero,
                      )),
                  const PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                        leading: Icon(Icons.print_rounded),
                        title: Text('Print'),
                        contentPadding: EdgeInsets.zero,
                      )),
                  if (!order.isReturn)
                    const PopupMenuItem(
                        value: 'return',
                        child: ListTile(
                          leading: Icon(Icons.assignment_return_rounded),
                          title: Text('Create Return'),
                          contentPadding: EdgeInsets.zero,
                        )),
                  if (order.orderStatus != OrderStatus.cancelled) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'cancel',
                        child: ListTile(
                          leading: Icon(Icons.cancel_rounded, color: Colors.orange),
                          title: Text('Cancel Order',
                              style: TextStyle(color: Colors.orange)),
                          contentPadding: EdgeInsets.zero,
                        )),
                  ],
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
                // Status row + forward/backward controls
                Row(
                  children: [
                    OrderStatusBadge(status: order.orderStatus),
                    const SizedBox(width: 8),
                    PaymentStatusBadge(status: order.paymentStatus),
                    if (order.isReturn) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_return_rounded,
                                size: 14, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              'Return',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      DateFormatter.formatWithTime(order.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                if (order.orderStatus != OrderStatus.cancelled && !order.isReturn) ...[
                  const SizedBox(height: 12),
                  _StatusStepperBar(order: order, ref: ref),
                ],
                // ── Return order 3-step flow ──
                if (order.isReturn) ...[
                  const SizedBox(height: 12),
                  _ReturnFlowCard(order: order, ref: ref),
                ],
                const SizedBox(height: 16),

                // Customer info
                if (order.customerName.isNotEmpty)
                  _InfoCard(children: [
                    _InfoRow(label: 'Customer', value: order.customerName),
                    if (order.customerPhone.isNotEmpty)
                      _InfoRow(label: 'Phone', value: order.customerPhone),
                  ]),
                // Delivery tracking
                if (order.deliveryAddress.isNotEmpty || order.estimatedDeliveryDate != null)
                  _DeliveryTrackingCard(order: order, ref: ref),

                const SizedBox(height: 12),

                // Items
                const _SectionLabel('Order Items'),
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
                  if (order.taxAmount > 0)
                    _InfoRow(
                        label: 'Tax',
                        value: CurrencyFormatter.format(order.taxAmount)),
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
                  _InfoRow(
                      label: 'Payment Method',
                      value: _paymentMethodLabel(order.paymentMethod)),
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

  String _paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.card => 'Card',
      PaymentMethod.mfs => 'MFS',
      PaymentMethod.bank => 'Bank',
      PaymentMethod.other => 'Other',
    };
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, Order order, String action) async {
    final pdfService = PdfService();
    final settings = ref.read(settingsProvider.notifier);
    final shopName = settings.shopName;
    final currencySymbol = settings.currencySymbol;
    final taxRate = settings.taxRate;

    switch (action) {
      case 'share_text':
        final text = pdfService.generateWhatsAppText(order,
            currencySymbol: currencySymbol);
        await Share.share(text);
        break;

      case 'share_pdf':
        final bytes = await pdfService.generateOrderReceipt(order,
            shopName: shopName,
            currencySymbol: currencySymbol,
            taxRate: taxRate);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${order.orderNumber}.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)]);
        break;

      case 'download_pdf':
        final bytes = await pdfService.generateOrderReceipt(order,
            shopName: shopName,
            currencySymbol: currencySymbol,
            taxRate: taxRate);

        // Get saved download directory or ask user to pick one
        var downloadDir = settings.downloadDirectory;
        if (downloadDir.isEmpty) {
          if (!context.mounted) break;
          final picked = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Choose download folder',
          );
          if (picked == null || !context.mounted) break;
          downloadDir = picked;
          // Save for future use
          await ref
              .read(settingsProvider.notifier)
              .updateDownloadDirectory(downloadDir);
        }

        final fileName = '${order.orderNumber}_receipt.pdf';
        final file = File('$downloadDir/$fileName');
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to $downloadDir'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () => Share.shareXFiles([XFile(file.path)]),
              ),
            ),
          );
        }
        break;

      case 'print':
        final bytes = await pdfService.generateOrderReceipt(order,
            shopName: shopName,
            currencySymbol: currencySymbol,
            taxRate: taxRate);
        await Printing.layoutPdf(onLayout: (_) async => bytes);
        break;

      case 'return':
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateReturnScreen(originalOrder: order),
          ),
        );
        break;

      case 'cancel':
        if (!context.mounted) return;
        final ok = await ConfirmDialog.show(
          context,
          title: 'Cancel Order',
          message:
              'Cancel ${order.orderNumber}? Stock will be restored if it was deducted.',
          confirmText: 'Cancel Order',
          isDestructive: true,
          icon: Icons.cancel_rounded,
        );
        if (ok == true && context.mounted) {
          await ref
              .read(orderNotifierProvider.notifier)
              .updateStatus(order.id, OrderStatus.cancelled);
        }
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

class _DeliveryTrackingCard extends StatelessWidget {
  final Order order;
  final WidgetRef ref;

  const _DeliveryTrackingCard({required this.order, required this.ref});

  int get _stepIndex => switch (order.orderStatus) {
        OrderStatus.pending => 0,
        OrderStatus.confirmed => 1,
        OrderStatus.shipped => 2,
        OrderStatus.completed => 3,
        OrderStatus.cancelled => 0,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Delivery Tracking',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress stepper
          _buildProgressStepper(cs),
          const SizedBox(height: 12),

          if (order.deliveryAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (order.estimatedDeliveryDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Est. Delivery: ${DateFormatter.format(order.estimatedDeliveryDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

          if (order.actualDeliveryDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.statusCompleted),
                  const SizedBox(width: 8),
                  Text(
                    'Delivered: ${DateFormatter.format(order.actualDeliveryDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.statusCompleted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (order.orderStatus != OrderStatus.cancelled &&
              order.orderStatus != OrderStatus.completed)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(orderNotifierProvider.notifier).updateOrder(
                        order.copyWith(
                          actualDeliveryDate: DateTime.now(),
                          orderStatus: OrderStatus.completed,
                          updatedAt: DateTime.now(),
                        ),
                      );
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Mark as Delivered'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(ColorScheme cs) {
    const steps = ['Placed', 'Confirmed', 'Shipped', 'Delivered'];
    final current = _stepIndex;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepBefore = i ~/ 2;
          final isActive = stepBefore < current;
          return Expanded(
            child: Container(
              height: 2,
              color: isActive ? cs.primary : cs.outline.withOpacity(0.2),
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final isCompleted = stepIdx < current;
        final isCurrent = stepIdx == current;
        final isActive = isCompleted || isCurrent;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? cs.primary
                    : isCurrent
                        ? cs.primary.withOpacity(0.15)
                        : cs.outline.withOpacity(0.1),
                border: isCurrent ? Border.all(color: cs.primary, width: 2) : null,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Center(
                      child: Text(
                        '${stepIdx + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive ? cs.primary : cs.onSurface.withOpacity(0.3),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIdx],
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? cs.primary : cs.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Status Stepper with Forward / Backward Buttons ─────────────────────────

class _StatusStepperBar extends StatelessWidget {
  final Order order;
  final WidgetRef ref;

  const _StatusStepperBar({required this.order, required this.ref});

  static const _flow = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.shipped,
    OrderStatus.completed,
  ];

  static const _labels = {
    OrderStatus.pending: 'Pending',
    OrderStatus.confirmed: 'Confirmed',
    OrderStatus.shipped: 'Shipped',
    OrderStatus.completed: 'Completed',
  };

  int get _currentIndex => _flow.indexOf(order.orderStatus).clamp(0, _flow.length - 1);
  bool get _canGoBack => _currentIndex > 0;
  bool get _canGoForward => _currentIndex < _flow.length - 1;

  Future<void> _changeStatus(BuildContext context, OrderStatus newStatus) async {
    await ref.read(orderNotifierProvider.notifier).updateStatus(order.id, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Step indicators
          Row(
            children: List.generate(_flow.length, (i) {
              final isActive = i <= _currentIndex;
              final isCurrent = i == _currentIndex;
              return Expanded(
                child: Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isActive
                              ? AppColors.primary
                              : cs.onSurface.withValues(alpha: 0.15),
                        ),
                      ),
                    Container(
                      width: isCurrent ? 28 : 20,
                      height: isCurrent ? 28 : 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? AppColors.primary
                            : cs.onSurface.withValues(alpha: 0.1),
                        border: isCurrent
                            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3)
                            : null,
                      ),
                      child: Center(
                        child: isActive
                            ? Icon(
                                i < _currentIndex ? Icons.check : Icons.circle,
                                size: isCurrent ? 12 : 10,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          // Labels
          Row(
            children: _flow.map((s) {
              final isActive = _flow.indexOf(s) <= _currentIndex;
              return Expanded(
                child: Text(
                  _labels[s] ?? s.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive
                        ? AppColors.primary
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Forward / Backward buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canGoBack
                      ? () => _changeStatus(context, _flow[_currentIndex - 1])
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(
                    _canGoBack ? _labels[_flow[_currentIndex - 1]]! : 'Back',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _canGoForward
                      ? () => _changeStatus(context, _flow[_currentIndex + 1])
                      : null,
                  icon: Text(
                    _canGoForward ? _labels[_flow[_currentIndex + 1]]! : 'Done',
                    style: const TextStyle(fontSize: 12),
                  ),
                  label: const Icon(Icons.arrow_forward_rounded, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Return Flow Card (3-step: Requested → Received → Refunded) ─────────────

class _ReturnFlowCard extends StatelessWidget {
  final Order order;
  final WidgetRef ref;

  const _ReturnFlowCard({required this.order, required this.ref});

  static const _reasonLabels = {
    ReturnReason.defective: 'Defective',
    ReturnReason.wrongItem: 'Wrong Item',
    ReturnReason.damaged: 'Damaged',
    ReturnReason.changedMind: 'Changed Mind',
    ReturnReason.other: 'Other',
  };

  static const _statusLabels = {
    ReturnStatus.requested: 'Requested',
    ReturnStatus.approved: 'Approved',
    ReturnStatus.received: 'Items Received',
    ReturnStatus.refunded: 'Refunded',
    ReturnStatus.rejected: 'Rejected',
  };

  Color _statusColor(ReturnStatus s) => switch (s) {
        ReturnStatus.requested => Colors.orange,
        ReturnStatus.approved => Colors.blue,
        ReturnStatus.received => Colors.blue,
        ReturnStatus.refunded => Colors.green,
        ReturnStatus.rejected => Colors.red,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final status = order.returnStatus;
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Return info + status
          Row(
            children: [
              Icon(Icons.assignment_return_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                'Return for #${order.originalOrderId}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabels[status] ?? status.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          // Reason
          const SizedBox(height: 8),
          Text(
            'Reason: ${_reasonLabels[order.returnReason] ?? order.returnReason.name}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),

          // Refund amount
          if (order.refundAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Refund amount: ${CurrencyFormatter.format(order.refundAmount)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: cs.onSurface,
              ),
            ),
          ],

          if (order.returnNotes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${order.returnNotes}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],

          // 3-step progress
          const SizedBox(height: 12),
          _ReturnStepIndicator(status: status),

          // Action buttons based on current status
          if (status == ReturnStatus.requested) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: 'Reject Return',
                        message: 'Reject this return request?',
                        confirmText: 'Reject',
                        isDestructive: true,
                        icon: Icons.close_rounded,
                      );
                      if (ok == true) {
                        await ref
                            .read(orderNotifierProvider.notifier)
                            .rejectReturn(order.id);
                      }
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: 'Approve & Receive Items',
                        message:
                            'Approve this return and mark items as received? Stock will be restored.',
                        confirmText: 'Approve',
                        icon: Icons.check_rounded,
                      );
                      if (ok == true) {
                        await ref
                            .read(orderNotifierProvider.notifier)
                            .approveReturn(order.id);
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve & Receive',
                        style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue),
                  ),
                ),
              ],
            ),
          ],

          if (status == ReturnStatus.received) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final ok = await ConfirmDialog.show(
                    context,
                    title: 'Process Refund',
                    message:
                        'Refund ${CurrencyFormatter.format(order.refundAmount)} to ${order.customerName.isNotEmpty ? order.customerName : "customer"}?',
                    confirmText: 'Refund',
                    icon: Icons.currency_exchange_rounded,
                  );
                  if (ok == true) {
                    await ref
                        .read(orderNotifierProvider.notifier)
                        .processRefund(order.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refund processed'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                label: Text(
                    'Process Refund (${CurrencyFormatter.format(order.refundAmount)})',
                    style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],

          if (status == ReturnStatus.refunded) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Refunded ${CurrencyFormatter.format(order.refundAmount)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == ReturnStatus.rejected) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_rounded, color: Colors.red, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Return Rejected',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReturnStepIndicator extends StatelessWidget {
  final ReturnStatus status;

  const _ReturnStepIndicator({required this.status});

  static const _steps = ['Requested', 'Received', 'Refunded'];

  int get _activeIndex => switch (status) {
        ReturnStatus.requested => 0,
        ReturnStatus.approved => 1,
        ReturnStatus.received => 1,
        ReturnStatus.refunded => 2,
        _ => -1,
      };

  @override
  Widget build(BuildContext context) {
    if (_activeIndex < 0) return const SizedBox.shrink();

    return Row(
      children: List.generate(_steps.length, (i) {
        final isActive = i <= _activeIndex;
        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isActive
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? AppColors.primary : Colors.grey.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.withValues(alpha: 0.5))),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _steps[i],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? AppColors.primary
                          : Colors.grey.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}
