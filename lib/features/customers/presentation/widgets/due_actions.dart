import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/customer.dart';
import '../../../../data/models/order.dart';
import '../../../../data/models/payment.dart';
import '../../../../data/services/dues_service.dart';
import '../../../../data/services/isar_service.dart';
import '../../../../data/services/statement_service.dart';
import '../../../../shared/widgets/bottom_sheet_handle.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/payment_method_chips.dart';
import '../../../cash_register/providers/cash_register_provider.dart';
import '../../../orders/providers/order_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';

// ─── Reminder ────────────────────────────────────────────────────────────

String buildDueReminderText(
  BuildContext context,
  Customer customer,
  List<OrderDue> orderDues,
  double total, {
  required String shopName,
  String shopPhone = '',
}) {
  final s = AppStrings.of(context);
  final sb = StringBuffer()
    ..writeln(s.reminderGreeting(customer.name))
    ..writeln()
    ..writeln(s.reminderBody(shopName, CurrencyFormatter.format(total)))
    ..writeln();
  for (final d in orderDues) {
    sb.writeln('• ${d.order.orderNumber} (${DateFormatter.format(d.order.createdAt)})'
        ' — ${CurrencyFormatter.format(d.due)}');
  }
  sb
    ..writeln()
    ..writeln(s.reminderClosing);
  if (shopPhone.isNotEmpty) sb.writeln(s.reminderContact(shopPhone));
  return sb.toString().trimRight();
}

/// wa.me needs an international number without '+'. We only strip
/// formatting — except for the main user base: a Bangladeshi local mobile
/// (`01XXXXXXXXX`, 11 digits) with the ৳ currency gets the 88 country code,
/// since sellers there save numbers in local form. Anything else is passed
/// through as typed; users elsewhere should save numbers with country code.
String? whatsAppNumber(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 11 &&
      digits.startsWith('01') &&
      CurrencyFormatter.symbol == '৳') {
    digits = '88$digits';
  }
  return digits;
}

/// [shareOrigin] is the tapped control's rect (`shareOriginOf`): on an iPad
/// the share sheet, used when WhatsApp doesn't open, points at it.
Future<void> sendDueReminder(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
  List<OrderDue> orderDues,
  double total, {
  Rect? shareOrigin,
}) async {
  final s = AppStrings.of(context);
  final settings = ref.read(settingsProvider.notifier);
  final text = buildDueReminderText(context, customer, orderDues, total,
      shopName: settings.shopName, shopPhone: settings.shopPhone);

  final number = whatsAppNumber(customer.phone);
  if (number != null) {
    final uri = Uri.parse(
        'https://wa.me/$number?text=${Uri.encodeComponent(text)}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Fall through to the share sheet.
    }
  } else if (context.mounted) {
    context.showSnackBar(s.noPhoneShareInstead);
  }
  await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: shareOrigin));
}

// ─── Statement ───────────────────────────────────────────────────────────

/// [shareOrigin] is the tapped control's rect (`shareOriginOf`), for an
/// iPad's share sheet to point at.
Future<void> shareCustomerStatement(
  BuildContext context,
  WidgetRef ref,
  Customer customer, {
  Rect? shareOrigin,
}) async {
  final s = AppStrings.of(context);
  final settings = ref.read(settingsProvider.notifier);
  final direction = Directionality.of(context);
  final labels = StatementLabels(
    title: s.customerStatement,
    date: s.date,
    reference: s.reference,
    debit: s.debit,
    credit: s.credit,
    balance: s.runningBalance,
    closingBalance: s.closingBalance,
    payment: s.payment,
    refund: s.refund,
    generatedOn: s.generatedOn,
    pageOf: s.pageOf,
  );

  try {
    // Spinner up (and repeat taps blocked) while the statement renders; it
    // comes down before the share sheet opens.
    final file = await runWithProgress(context, () async {
      final isar = await ref.read(isarProvider.future);
      // Index lookups don't return equal keys in id order. Sort by id — the
      // order the old filter() query gave — so the running balance is
      // computed over the rows in exactly the same order as before.
      final orders = (await isar.orders
          .where()
          .customerIdEqualTo(customer.id)
          .findAll())
        ..sort((a, b) => a.id.compareTo(b.id));
      final payments = (await isar.payments
          .where()
          .customerIdEqualTo(customer.id)
          .findAll())
        ..sort((a, b) => a.id.compareTo(b.id));

      final service = StatementService();
      final rows = service.buildRows(orders, payments, labels: labels);
      final bytes = await service.generateStatementPdf(
        customer: customer,
        rows: rows,
        labels: labels,
        shopName: settings.shopName,
        shopPhone: settings.shopPhone,
        currencySymbol: settings.currencySymbol,
        textDirection: direction,
      );
      final dir = await getTemporaryDirectory();
      final safeName = customer.name.replaceAll(RegExp(r'[^\w]+'), '_');
      final file = File('${dir.path}/statement_$safeName.pdf');
      await file.writeAsBytes(bytes);
      return file;
    });
    await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)], sharePositionOrigin: shareOrigin));
  } catch (e) {
    if (context.mounted) context.showErrorSnackBar(s.error);
  }
}

// ─── Collect ─────────────────────────────────────────────────────────────

Future<void> showCollectPaymentSheet(
  BuildContext context,
  Customer customer,
  List<OrderDue> orderDues,
  double totalDue,
) {
  return AppBottomSheet.show(
    context,
    title: '${AppStrings.of(context).collectPayment} · ${customer.name}',
    child: _CollectPaymentForm(
        customer: customer, orderDues: orderDues, totalDue: totalDue),
  );
}

class _CollectPaymentForm extends ConsumerStatefulWidget {
  const _CollectPaymentForm({
    required this.customer,
    required this.orderDues,
    required this.totalDue,
  });

  final Customer customer;
  final List<OrderDue> orderDues;

  /// Net of credits; the cap for this collection.
  final double totalDue;

  @override
  ConsumerState<_CollectPaymentForm> createState() =>
      _CollectPaymentFormState();
}

class _CollectPaymentFormState extends ConsumerState<_CollectPaymentForm> {
  final _amountCtrl = TextEditingController();
  final _txnCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _addToRegister = true;
  bool _saving = false;

  double get _totalDue => widget.totalDue;
  double get _amount => double.tryParse(_amountCtrl.text) ?? 0;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _txnCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(int? registerId) async {
    final s = AppStrings.of(context);
    final amount = _amount;
    if (amount <= 0 || amount > _totalDue + kDueEpsilon) return;
    setState(() => _saving = true);
    try {
      final applied = await ref.read(orderProvider.notifier).collectFromCustomer(
            widget.customer.id,
            amount,
            method: _method,
            transactionId: _txnCtrl.text.trim(),
            registerId: _addToRegister && _method == PaymentMethod.cash
                ? registerId
                : null,
          );
      ref.invalidate(openRegisterProvider);
      if (!mounted) return;
      Navigator.pop(context);
      context.showSuccessSnackBar(
          s.paymentCollected(CurrencyFormatter.format(applied)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showErrorSnackBar(s.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final amount = _amount;
    final tooMuch = amount > _totalDue + kDueEpsilon;
    final register = ref.watch(openRegisterProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${s.balanceDue}: ${CurrencyFormatter.format(_totalDue)}',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
          controller: _amountCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: s.paymentAmount,
            prefixText: '${CurrencyFormatter.symbol} ',
            errorText: tooMuch
                ? s.amountExceedsDue(CurrencyFormatter.format(_totalDue))
                : null,
            // Wraps rather than cutting off the amount it names.
            errorMaxLines: 3,
            suffixIcon: TextButton(
              onPressed: () => setState(() =>
                  _amountCtrl.text = _totalDue.toStringAsFixed(2)),
              child: Text(s.fullDue),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PaymentMethodChips(
          selected: _method,
          onChanged: (m) => setState(() => _method = m),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _txnCtrl,
          decoration: InputDecoration(
            labelText: s.transactionId,
            hintText: s.transactionIdHint,
          ),
        ),
        if (register != null && _method == PaymentMethod.cash)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _addToRegister,
            onChanged: (v) => setState(() => _addToRegister = v ?? false),
            title: Text(s.addToCashRegister),
          ),
        if (amount > 0 && !tooMuch) ...[
          const SizedBox(height: 12),
          Text(s.willSettle,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ..._preview(context, amount),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving || amount <= 0 || tooMuch
              ? null
              : () => _submit(register?.id),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.collectPayment),
        ),
      ],
    );
  }

  /// Mirrors OrderNotifier.collectFromCustomer's oldest-first allocation.
  List<Widget> _preview(BuildContext context, double amount) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    var remaining = amount; // already validated ≤ net total
    final rows = <Widget>[];
    for (final d in widget.orderDues) {
      if (remaining <= kDueEpsilon) break;
      final part = remaining < d.due ? remaining : d.due;
      remaining -= part;
      final left = d.due - part;
      final settled = left <= kDueEpsilon;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            ThinIcon(
              settled ? tabler.CircleCheck.new : tabler.Progress.new,
              size: 18,
              color: settled ? AppColors.paymentPaid : AppColors.paymentPartial,
            ),
            const SizedBox(width: 8),
            // The order number at the start and the amounts at the end, as
            // a Row with a spacer; the amounts wrap under the order number
            // (and "left" under the amount) when they don't fit beside it.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(d.order.orderNumber),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(CurrencyFormatter.format(part),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        settled
                            ? s.paidInFull
                            : s.amountLeft(CurrencyFormatter.format(left)),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }
    return rows;
  }
}

// ─── Payment history tile ────────────────────────────────────────────────

class PaymentHistoryTile extends StatelessWidget {
  const PaymentHistoryTile({super.key, required this.payment, this.onTap});

  final Payment payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final color =
        payment.isRefund ? AppColors.paymentUnpaid : AppColors.paymentPaid;
    final subtitle = [
      DateFormatter.formatWithTime(payment.paidAt),
      paymentMethodLabel(context, payment.method),
      if (payment.transactionId.isNotEmpty) payment.transactionId,
    ].join(' · ');

    // ListTile gives the trailing amount all the width it asks for and the
    // title what's left: a big amount at a large text size squeezed the
    // title into a sliver that broke "Payment" mid-word. The amount gets at
    // most 40% of the row and shrinks beyond that; the title ends in an
    // ellipsis rather than breaking.
    return LayoutBuilder(
      builder: (context, constraints) => ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: ThinIcon(
            payment.isRefund ? tabler.ArrowBackUp.new : tabler.Cash.new,
            color: color,
            size: 20,
          ),
        ),
        title: Text(payment.isRefund ? s.refund : s.payment,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${payment.isRefund ? '−' : '+'}'
              '${CurrencyFormatter.format(payment.amount.abs())}',
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
