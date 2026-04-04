import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';

class CsvImportResult {
  final List<Product> products;
  final List<String> errors;
  CsvImportResult({required this.products, required this.errors});
}

class CsvImportService {
  /// Pick a CSV file and parse products from it.
  /// Expected CSV columns: Name, SKU, Category, Selling Price, Cost Price, Stock, Low Stock Threshold
  Future<CsvImportResult?> importProducts() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.single.path!);
    final csvString = await file.readAsString();
    final rows = const CsvToListConverter().convert(csvString, eol: '\n');

    if (rows.isEmpty) {
      return CsvImportResult(products: [], errors: ['CSV file is empty']);
    }

    // Skip header row
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
        final stockQty = row.length > 5
            ? (int.tryParse(row[5].toString().trim()) ?? 0)
            : 0;
        final threshold = row.length > 6
            ? (int.tryParse(row[6].toString().trim()) ?? 10)
            : 10;

        products.add(Product(
          name: name,
          sku: sku,
          category: category,
          sellingPrice: sellingPrice,
          costPrice: costPrice,
          stockQty: stockQty,
          lowStockThreshold: threshold,
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
