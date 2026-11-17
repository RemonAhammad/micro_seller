import '../../data/models/order_item.dart';
import 'date_formatter.dart';

/// The lines printed under an order line on the receipt, the WhatsApp text
/// and the POS slip, in English like the rest of those documents:
/// "S/N: 3521…, 3521…" and "Warranty: 12 months (until 17 Nov 2027)". The
/// warranty counts from [saleDate] (the order's date); without one, only
/// its length.
List<String> documentItemNotes(OrderItem item, DateTime? saleDate) {
  final end = saleDate == null ? null : item.warrantyEndsFrom(saleDate);
  return [
    if (item.serials.isNotEmpty) 'S/N: ${item.serials.join(', ')}',
    if (item.warrantyMonths > 0)
      'Warranty: ${item.warrantyMonths} ${item.warrantyMonths == 1 ? 'month' : 'months'}'
          '${end == null ? '' : ' (until ${DateFormatter.format(end)})'}',
  ];
}
