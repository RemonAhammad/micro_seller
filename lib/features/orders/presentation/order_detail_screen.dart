import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/pdf_saved_sheet.dart';
import '../../../data/models/order.dart';
import '../providers/order_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/pdf_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/payment_method_chips.dart';
import '../../settings/providers/settings_provider.dart';
import '../../returns/presentation/create_return_screen.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/order_item_row.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

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
    final s = AppStrings.of(context);
    final ordersAsync = ref.watch(ordersProvider);
    final theme = Theme.of(context);

    return ordersAsync.when(
      data: (orders) {
        final order = orders.where((o) => o.id == orderId).firstOrNull;
        if (order == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(s.orderNotFound)),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(order.orderNumber),
            actions: [
              IconButton(
                icon: const ThinIcon(tabler.Pencil.new),
                onPressed: () => context.push('/orders/${order.id}/edit'),
              ),
              PopupMenuButton<String>(
                onSelected: (action) =>
                    _handleAction(context, ref, order, action),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'share_text',
                      child: ListTile(
                        leading: const ThinIcon(tabler.Message.new),
                        title: Text(s.shareViaWhatsApp),
                        contentPadding: EdgeInsets.zero,
                      )),
                  PopupMenuItem(
                      value: 'share_pdf',
                      child: ListTile(
                        leading: const ThinIcon(tabler.FileTypePdf.new),
                        title: Text(s.sharePdf),
                        contentPadding: EdgeInsets.zero,
                      )),
                  PopupMenuItem(
                      value: 'download_pdf',
                      child: ListTile(
                        leading: const ThinIcon(tabler.Download.new),
                        title: Text(s.downloadPdf),
                        contentPadding: EdgeInsets.zero,
                      )),
                  PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                        leading: const ThinIcon(tabler.Printer.new),
                        title: Text(s.print),
                        contentPadding: EdgeInsets.zero,
                      )),
                  if (!order.isReturn)
                    PopupMenuItem(
                        value: 'return',
                        child: ListTile(
                          leading: const ThinIcon(tabler.ArrowBackUp.new),
                          title: Text(s.createReturn),
                          contentPadding: EdgeInsets.zero,
                        )),
                  if (order.orderStatus != OrderStatus.cancelled) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                        value: 'cancel',
                        child: ListTile(
                          leading: const ThinIcon(tabler.CircleX.new, color: Colors.orange),
                          title: Text(s.cancelOrder,
                              style: const TextStyle(color: Colors.orange)),
                          contentPadding: EdgeInsets.zero,
                        )),
                  ],
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const ThinIcon(tabler.Trash.new, color: Colors.red),
                        title: Text(s.delete, style: const TextStyle(color: Colors.red)),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ThinIcon(tabler.ArrowBackUp.new,
                                size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              s.returns,
                              style: const TextStyle(
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
                if (order.customerName.isNotEmpty) ...[
                  _InfoCard(children: [
                    _InfoRow(label: s.customer, value: order.customerName),
                    if (order.customerPhone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.phone,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  order.customerPhone,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => launchUrl(Uri.parse('tel:${order.customerPhone}')),
                                  child: ThinIcon(
                                    tabler.Phone.new,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                ],
                // Delivery tracking
                if (order.deliveryAddress.isNotEmpty || order.estimatedDeliveryDate != null)
                  _DeliveryTrackingCard(order: order, ref: ref),

                const SizedBox(height: 12),

                // Items
                _SectionLabel(s.orderItems),
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
                      label: s.subtotal,
                      value: CurrencyFormatter.format(order.subtotal)),
                  if (order.discountAmount > 0)
                    _InfoRow(
                      label: s.discount,
                      value:
                          '- ${CurrencyFormatter.format(order.discountAmount)}',
                      valueColor: Colors.green,
                    ),
                  if (order.taxAmount > 0)
                    _InfoRow(
                        label: s.tax,
                        value: CurrencyFormatter.format(order.taxAmount)),
                  if (order.deliveryFee > 0)
                    _InfoRow(
                        label: s.delivery,
                        value: CurrencyFormatter.format(order.deliveryFee)),
                  const Divider(height: 16),
                  _InfoRow(
                    label: s.total,
                    value: CurrencyFormatter.format(order.totalAmount),
                    isBold: true,
                    valueColor: theme.colorScheme.primary,
                  ),
                  _InfoRow(
                      label: s.paid,
                      value: CurrencyFormatter.format(order.amountPaid)),
                  _InfoRow(
                      label: s.paymentMethod,
                      value: _paymentMethodLabel(context, order.paymentMethod)),
                  if (order.balanceDue > 0)
                    _InfoRow(
                      label: s.balanceDue,
                      value: CurrencyFormatter.format(order.balanceDue),
                      isBold: true,
                      valueColor: AppColors.paymentUnpaid,
                    ),
                ]),
                const SizedBox(height: 12),

                if (order.notes.isNotEmpty)
                  _InfoCard(children: [
                    Text(s.notes,
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
                      icon: const ThinIcon(tabler.CreditCard.new),
                      label: Text(s.recordPayment),
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

  String _paymentMethodLabel(BuildContext context, PaymentMethod method) {
    final s = AppStrings.of(context);
    return switch (method) {
      PaymentMethod.cash => s.cash,
      PaymentMethod.card => s.card,
      PaymentMethod.mfs => s.mfs,
      PaymentMethod.bank => s.bank,
      PaymentMethod.other => s.other,
    };
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, Order order, String action) async {
    final pdfService = PdfService();
    final settings = ref.read(settingsProvider.notifier);
    final shopName = settings.shopName;
    final currencySymbol = settings.currencySymbol;
    final taxRate = settings.taxRate;

    try {
    switch (action) {
      case 'share_text':
        final text = pdfService.generateWhatsAppText(order,
            currencySymbol: currencySymbol);
        await SharePlus.instance.share(ShareParams(text: text));
        break;

      case 'share_pdf':
        final bytes = await pdfService.generateOrderReceipt(order,
            shopName: shopName,
            currencySymbol: currencySymbol,
            taxRate: taxRate);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${order.orderNumber}.pdf');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
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
          final picked = await FilePicker.getDirectoryPath(
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
          await showPdfSavedSheet(
            context: context,
            filePath: file.path,
            savedToDirectory: downloadDir,
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
        final s = AppStrings.of(context);
        final ok = await ConfirmDialog.show(
          context,
          title: s.cancelOrder,
          message:
              '${s.cancelOrder} ${order.orderNumber}? ${s.cancelOrderConfirm}',
          confirmText: s.cancelOrder,
          isDestructive: true,
          icon: tabler.CircleX.new,
        );
        if (ok == true && context.mounted) {
          await ref
              .read(orderProvider.notifier)
              .updateStatus(order.id, OrderStatus.cancelled);
        }
        break;

      case 'delete':
        if (!context.mounted) return;
        final sd = AppStrings.of(context);
        final ok = await ConfirmDialog.show(
          context,
          title: sd.deleteOrder,
          message: '${sd.deleteOrder} ${order.orderNumber}? ${sd.deleteOrderConfirm}',
          confirmText: sd.delete,
          isDestructive: true,
          icon: tabler.Trash.new,
        );
        if (ok == true && context.mounted) {
          await ref
              .read(orderProvider.notifier)
              .deleteOrder(order.id);
          context.pop();
        }
        break;
    }
    } catch (e, st) {
      // The whole action handler used to swallow errors silently — every PDF
      // failure (WebView crash, file write denied, etc.) just looked like
      // "nothing happened". Log + show the actual error so future regressions
      // are visible.
      developer.log(
        'Order action "$action" failed',
        name: 'OrderDetail',
        error: e,
        stackTrace: st,
      );
      if (kDebugMode) {
        debugPrint('[OrderDetail] action="$action" failed: $e');
        debugPrintStack(stackTrace: st, label: 'OrderDetail._handleAction');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kDebugMode
                ? 'Action failed: $e'
                : AppStrings.of(context).errorOccurred),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  void _showPaymentDialog(
      BuildContext context, WidgetRef ref, Order order) {
    final s = AppStrings.of(context);
    final amountCtrl = TextEditingController();
    final txnCtrl = TextEditingController();
    PaymentMethod method = order.paymentMethod;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(s.recordPayment),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    '${s.balanceDue}: ${CurrencyFormatter.format(order.balanceDue)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                  ],
                  decoration: InputDecoration(
                    labelText: s.paymentAmount,
                    prefixText: '${CurrencyFormatter.symbol} ',
                  ),
                ),
                const SizedBox(height: 12),
                PaymentMethodChips(
                  selected: method,
                  onChanged: (m) => setLocal(() => method = m),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: txnCtrl,
                  decoration: InputDecoration(
                    labelText: s.transactionId,
                    hintText: s.transactionIdHint,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                await ref.read(orderProvider.notifier).recordPayment(
                      order.id,
                      amount,
                      method: method,
                      transactionId: txnCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }

}

class _StatusActions extends ConsumerWidget {
  final Order order;

  const _StatusActions({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final nextStatus = switch (order.orderStatus) {
      OrderStatus.pending => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.shipped,
      OrderStatus.shipped => OrderStatus.completed,
      _ => null,
    };

    final nextLabel = switch (nextStatus) {
      OrderStatus.confirmed => s.tr('confirmOrder'),
      OrderStatus.shipped => s.tr('markAsShipped'),
      OrderStatus.completed => s.tr('markAsCompleted'),
      _ => null,
    };

    if (nextLabel == null || nextStatus == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref
              .read(orderProvider.notifier)
              .updateStatus(order.id, nextStatus);
        },
        icon: const ThinIcon(tabler.ArrowRight.new),
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
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
    final s = AppStrings.of(context);
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
              ThinIcon(tabler.TruckDelivery.new, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                s.delivery,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress stepper
          _buildProgressStepper(context, cs),
          const SizedBox(height: 12),

          if (order.deliveryAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThinIcon(tabler.MapPin.new, size: 16, color: cs.onSurface.withOpacity(0.5)),
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
                  ThinIcon(tabler.Clock.new, size: 16, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    '${s.estimatedDelivery}: ${DateFormatter.format(order.estimatedDeliveryDate)}',
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
                  const ThinIcon(tabler.CircleCheck.new, size: 16, color: AppColors.statusCompleted),
                  const SizedBox(width: 8),
                  Text(
                    '${s.delivered}: ${DateFormatter.format(order.actualDeliveryDate)}',
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
                  await ref.read(orderProvider.notifier).updateOrder(
                        order.copyWith(
                          actualDeliveryDate: DateTime.now(),
                          orderStatus: OrderStatus.completed,
                          updatedAt: DateTime.now(),
                        ),
                      );
                },
                icon: const ThinIcon(tabler.Check.new, size: 18),
                label: Text(s.markAsDelivered),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(BuildContext context, ColorScheme cs) {
    final s = AppStrings.of(context);
    final steps = [s.tr('placed'), s.confirmed, s.shipped, s.delivered];
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
                  ? const ThinIcon(tabler.Check.new, size: 14, color: Colors.white)
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

  Map<OrderStatus, String> _labels(BuildContext context) {
    final s = AppStrings.of(context);
    return {
      OrderStatus.pending: s.pending,
      OrderStatus.confirmed: s.confirmed,
      OrderStatus.shipped: s.shipped,
      OrderStatus.completed: s.completed,
    };
  }

  int get _currentIndex => _flow.indexOf(order.orderStatus).clamp(0, _flow.length - 1);
  bool get _canGoBack => _currentIndex > 0;
  bool get _canGoForward => _currentIndex < _flow.length - 1;

  Future<void> _changeStatus(BuildContext context, OrderStatus newStatus) async {
    await ref.read(orderProvider.notifier).updateStatus(order.id, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final labels = _labels(context);
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
                            ? ThinIcon(
                                i < _currentIndex ? tabler.Check.new : tabler.Circle.new,
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
            children: _flow.map((status) {
              final isActive = _flow.indexOf(status) <= _currentIndex;
              return Expanded(
                child: Text(
                  labels[status] ?? status.name,
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
                  icon: const ThinIcon(tabler.ArrowLeft.new, size: 16),
                  label: Text(
                    _canGoBack ? labels[_flow[_currentIndex - 1]]! : s.tr('back'),
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
                    _canGoForward ? labels[_flow[_currentIndex + 1]]! : s.done,
                    style: const TextStyle(fontSize: 12),
                  ),
                  label: const ThinIcon(tabler.ArrowRight.new, size: 16),
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

class _RefundDialogResult {
  final PaymentMethod method;
  final String transactionId;
  _RefundDialogResult({required this.method, required this.transactionId});
}

class _ReturnFlowCard extends StatelessWidget {
  final Order order;
  final WidgetRef ref;

  const _ReturnFlowCard({required this.order, required this.ref});

  Map<ReturnReason, String> _reasonLabels(BuildContext context) {
    final s = AppStrings.of(context);
    return {
      ReturnReason.defective: s.defective,
      ReturnReason.wrongItem: s.wrongItem,
      ReturnReason.damaged: s.tr('damaged'),
      ReturnReason.changedMind: s.changedMind,
      ReturnReason.other: s.other,
    };
  }

  Future<_RefundDialogResult?> _showRefundDialog(
      BuildContext context, Order returnOrder) {
    final s = AppStrings.of(context);
    final txnCtrl = TextEditingController();
    PaymentMethod method = returnOrder.paymentMethod;
    return showDialog<_RefundDialogResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(s.processRefund),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${s.tr("refund")} ${CurrencyFormatter.format(returnOrder.refundAmount)}'
                  '${returnOrder.customerName.isNotEmpty ? " → ${returnOrder.customerName}" : ""}',
                ),
                const SizedBox(height: 16),
                Text(s.refundMethod,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                PaymentMethodChips(
                  selected: method,
                  onChanged: (m) => setLocal(() => method = m),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: txnCtrl,
                  decoration: InputDecoration(
                    labelText: s.refundTransactionId,
                    hintText: s.transactionIdHint,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                  ctx,
                  _RefundDialogResult(
                      method: method, transactionId: txnCtrl.text.trim())),
              icon: const ThinIcon(tabler.Exchange.new, size: 16),
              label: Text(s.tr('refund')),
            ),
          ],
        ),
      ),
    );
  }

  Map<ReturnStatus, String> _statusLabels(BuildContext context) {
    final s = AppStrings.of(context);
    return {
      ReturnStatus.requested: s.tr('requested'),
      ReturnStatus.approved: s.tr('approved'),
      ReturnStatus.received: s.tr('itemsReceived'),
      ReturnStatus.refunded: s.tr('refunded'),
      ReturnStatus.rejected: s.tr('rejected'),
    };
  }

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
    final s = AppStrings.of(context);
    final statusLbls = _statusLabels(context);
    final reasonLbls = _reasonLabels(context);
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
              ThinIcon(tabler.ArrowBackUp.new, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                '${s.returns} #${order.originalOrderId}',
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
                  statusLbls[status] ?? status.name,
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
            '${s.returnReason}: ${reasonLbls[order.returnReason] ?? order.returnReason.name}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),

          // Refund amount
          if (order.refundAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${s.refundAmount}: ${CurrencyFormatter.format(order.refundAmount)}',
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
              '${s.notes}: ${order.returnNotes}',
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
                        title: s.rejectReturn,
                        message: s.tr('rejectReturnConfirm'),
                        confirmText: s.tr('reject'),
                        isDestructive: true,
                        icon: tabler.X.new,
                      );
                      if (ok == true) {
                        await ref
                            .read(orderProvider.notifier)
                            .rejectReturn(order.id);
                      }
                    },
                    icon: const ThinIcon(tabler.X.new, size: 16),
                    label: Text(s.tr('reject'), style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: s.tr('approveAndReceiveItems'),
                        message: s.tr('approveReturnConfirm'),
                        confirmText: s.tr('approve'),
                        icon: tabler.Check.new,
                      );
                      if (ok == true) {
                        await ref
                            .read(orderProvider.notifier)
                            .approveReturn(order.id);
                      }
                    },
                    icon: const ThinIcon(tabler.Check.new, size: 16),
                    label: Text(s.approveAndReceive,
                        style: const TextStyle(fontSize: 12)),
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
                  final result = await _showRefundDialog(context, order);
                  if (result == null) return;
                  await ref.read(orderProvider.notifier).processRefund(
                        order.id,
                        refundMethod: result.method,
                        refundTransactionId: result.transactionId,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(s.tr('refundProcessed')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const ThinIcon(tabler.Exchange.new, size: 16),
                label: Text(
                    '${s.processRefund} (${CurrencyFormatter.format(order.refundAmount)})',
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
                  const ThinIcon(tabler.CircleCheck.new,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${s.tr("refunded")} ${CurrencyFormatter.format(order.refundAmount)}',
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ThinIcon(tabler.CircleX.new, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    s.tr('returnRejected'),
                    style: const TextStyle(
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

  List<String> _steps(BuildContext context) {
    final s = AppStrings.of(context);
    return [s.tr('requested'), s.tr('received'), s.tr('refunded')];
  }

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
    final steps = _steps(context);

    return Row(
      children: List.generate(steps.length, (i) {
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
                          ? const ThinIcon(tabler.Check.new, size: 12, color: Colors.white)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.withValues(alpha: 0.5))),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i],
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
