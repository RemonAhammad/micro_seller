/// What a product is counted in. Prices are per one of these (৳600 per kg),
/// and stock and order quantities are in them.
///
/// Stored by name (`@Enumerated(EnumType.name)`), so reordering is safe and a
/// name this version doesn't know reads as [piece].
enum QuantityUnit {
  piece,
  kg,
  g,
  litre,
  ml,
  metre,
  cm,
  dozen,
  pack;

  /// Weighed or measured goods: a quantity may have decimals (1.25 kg).
  /// The small units (g, ml, cm) and counted ones stay whole.
  bool get allowsDecimal =>
      this == QuantityUnit.kg ||
      this == QuantityUnit.litre ||
      this == QuantityUnit.metre;

  /// Counted goods: the order form's + / − steps, no quantity sheet.
  bool get isCounted => !allowsDecimal;

  /// The English sign, for documents whose labels are English (the invoice,
  /// the WhatsApp text, the POS slip). None for pieces. Screens use the
  /// translated one (`AppStrings.unitSymbol`).
  String get documentSymbol => switch (this) {
        QuantityUnit.piece => '',
        QuantityUnit.kg => 'kg',
        QuantityUnit.g => 'g',
        QuantityUnit.litre => 'L',
        QuantityUnit.ml => 'ml',
        QuantityUnit.metre => 'm',
        QuantityUnit.cm => 'cm',
        QuantityUnit.dozen => 'dozen',
        QuantityUnit.pack => 'pack',
      };
}
