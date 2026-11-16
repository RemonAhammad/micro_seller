import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/quantity.dart';
import '../models/product.dart';
import '../models/quantity_unit.dart';

/// A CSV "Unit" cell: the unit's name ("kg", "litre") or a common spelling
/// ("kilogram", "l", "meter", "pcs"); anything else is a piece.
QuantityUnit _unitFrom(String raw) {
  final v = raw.trim().toLowerCase();
  for (final u in QuantityUnit.values) {
    if (u.name == v) return u;
  }
  return switch (v) {
    'kilogram' || 'kilograms' || 'kgs' => QuantityUnit.kg,
    'gram' || 'grams' || 'gm' => QuantityUnit.g,
    'l' || 'liter' || 'liters' || 'litres' || 'ltr' => QuantityUnit.litre,
    'millilitre' || 'milliliter' => QuantityUnit.ml,
    'm' || 'meter' || 'meters' || 'metres' => QuantityUnit.metre,
    'centimetre' || 'centimeter' => QuantityUnit.cm,
    'dz' || 'doz' => QuantityUnit.dozen,
    'packs' || 'pkt' || 'packet' => QuantityUnit.pack,
    _ => QuantityUnit.piece,
  };
}

class CsvImportResult {
  final List<Product> products;
  final List<String> errors;
  CsvImportResult({required this.products, required this.errors});
}

class CsvImportService {

  Future<CsvImportResult?> importProducts() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked == null) return null;

    final csvString = utf8.decode(await picked.readAsBytes());
    final rows = csv.decode(csvString);

    if (rows.isEmpty) {
      return CsvImportResult(products: [], errors: ['CSV file is empty']);
    }

    final dataRows = rows.length > 1 ? rows.sublist(1) : rows;
    final products = <Product>[];
    final errors = <String>[];

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      try {
        if (row.length < 4) {
          errors.add('Row ${i + 2}: Not enough columns (need at least 4)');
          continue;
        }

        final name = row[0].toString().trim();
        if (name.isEmpty) {
          errors.add('Row ${i + 2}: Name is empty');
          continue;
        }

        final sku = row.length > 1 ? row[1].toString().trim() : '';
        final category = row.length > 2 ? row[2].toString().trim() : '';
        final sellingPrice =
            double.tryParse(row[3].toString().trim()) ?? 0;
        final costPrice = row.length > 4
            ? (double.tryParse(row[4].toString().trim()) ?? 0)
            : 0.0;
        final unit = row.length > 7 ? _unitFrom(row[7].toString()) : QuantityUnit.piece;
        // A unit that counts whole things keeps whole numbers (2.5 pieces
        // would be refused by the product form).
        double qtyOf(double v) => roundQty(unit.allowsDecimal ? v : v.roundToDouble());
        final stockQty = row.length > 5
            ? qtyOf(double.tryParse(row[5].toString().trim()) ?? 0)
            : 0.0;
        final threshold = row.length > 6
            ? qtyOf(double.tryParse(row[6].toString().trim()) ?? 10)
            : 10.0;

        products.add(Product(
          name: name,
          sku: sku,
          category: category,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          stockQty: stockQty,
          lowStockThreshold: threshold,
          unit: unit,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      } catch (e) {
        errors.add('Row ${i + 2}: $e');
      }
    }

    return CsvImportResult(products: products, errors: errors);
  }
}
