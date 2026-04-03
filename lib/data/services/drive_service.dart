import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/stock_movement.dart';
import '../../core/utils/date_formatter.dart';

class DriveBackupInfo {
  final String fileId;
  final String name;
  final DateTime createdTime;

  DriveBackupInfo({
    required this.fileId,
    required this.name,
    required this.createdTime,
  });
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client;

  _AuthClient(this._headers, this._client);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}

class DriveService {
  static const _scopes = [drive.DriveApi.driveAppdataScope];
  static const _maxBackups = 5;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final account = await _googleSignIn.signInSilently() ??
          await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final client = _AuthClient(
        {'Authorization': 'Bearer ${auth.accessToken}'},
        http.Client(),
      );
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('Drive auth error: $e');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('Sign in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  }

  Future<void> backupToDrive(Isar isar) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('Not authenticated. Please sign in first.');

    final jsonStr = await _createLocalBackup(isar);
    final fileName =
        'sellerbook_backup_${DateFormatter.formatForBackup(DateTime.now())}.json';
    final bytes = utf8.encode(jsonStr);

    final file = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    await driveApi.files.create(
      file,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );

    // Cleanup old backups (don't let cleanup failure break the backup)
    try {
      await _cleanupOldBackups(driveApi);
    } catch (e) {
      debugPrint('Old backup cleanup failed (non-critical): $e');
    }
  }

  Future<void> _cleanupOldBackups(drive.DriveApi driveApi) async {
    final list = await driveApi.files.list(
      spaces: 'appDataFolder',
      orderBy: 'createdTime',
      q: "name contains 'sellerbook_backup'",
    );

    final files = list.files ?? [];
    if (files.length > _maxBackups) {
      final toDelete = files.sublist(0, files.length - _maxBackups);
      for (final f in toDelete) {
        if (f.id != null) {
          await driveApi.files.delete(f.id!);
        }
      }
    }
  }

  Future<List<DriveBackupInfo>> listBackups() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return [];

    final list = await driveApi.files.list(
      spaces: 'appDataFolder',
      orderBy: 'createdTime desc',
      q: "name contains 'sellerbook_backup'",
      $fields: 'files(id,name,createdTime)',
    );

    return (list.files ?? [])
        .where((f) => f.id != null && f.name != null)
        .map((f) => DriveBackupInfo(
              fileId: f.id!,
              name: f.name!,
              createdTime: f.createdTime ?? DateTime.now(),
            ))
        .toList();
  }

  /// Creates a local safety backup of all data, returns the JSON string.
  Future<String> _createLocalBackup(Isar isar) async {
    final products = await isar.products.where().findAll();
    final orders = await isar.orders.where().findAll();
    final customers = await isar.customers.where().findAll();
    final expenses = await isar.expenses.where().findAll();
    final movements = await isar.stockMovements.where().findAll();

    return jsonEncode({
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'products': products.map((p) => p.toJson()).toList(),
      'orders': orders.map((o) => o.toJson()).toList(),
      'customers': customers.map((c) => c.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'stockMovements': movements.map((m) => m.toJson()).toList(),
    });
  }

  /// Restores data from a JSON map into the database.
  Future<void> _importData(Isar isar, Map<String, dynamic> data) async {
    await isar.writeTxn(() async {
      await isar.products.clear();
      await isar.orders.clear();
      await isar.customers.clear();
      await isar.expenses.clear();
      await isar.stockMovements.clear();

      if (data['products'] != null) {
        final products = (data['products'] as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        await isar.products.putAll(products);
      }

      if (data['orders'] != null) {
        final orders = (data['orders'] as List)
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
        await isar.orders.putAll(orders);
      }

      if (data['customers'] != null) {
        final customers = (data['customers'] as List)
            .map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .toList();
        await isar.customers.putAll(customers);
      }

      if (data['expenses'] != null) {
        final expenses = (data['expenses'] as List)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList();
        await isar.expenses.putAll(expenses);
      }

      if (data['stockMovements'] != null) {
        final movements = (data['stockMovements'] as List)
            .map((e) => StockMovement.fromJson(e as Map<String, dynamic>))
            .toList();
        await isar.stockMovements.putAll(movements);
      }
    });
  }

  Future<void> restoreFromDrive(Isar isar, String fileId) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) throw Exception('Not authenticated. Please sign in first.');

    // Download and validate backup data before touching local DB
    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <int>[];
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
    }

    final jsonStr = utf8.decode(chunks);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    // Validate backup structure
    if (!data.containsKey('version') || !data.containsKey('timestamp')) {
      throw Exception('Invalid backup file: missing required fields.');
    }

    // Create local safety backup before clearing
    final safetyBackup = await _createLocalBackup(isar);

    try {
      await _importData(isar, data);
    } catch (e) {
      // Restore from safety backup if import fails
      debugPrint('Restore failed, rolling back: $e');
      try {
        final safetyData =
            jsonDecode(safetyBackup) as Map<String, dynamic>;
        await _importData(isar, safetyData);
      } catch (rollbackError) {
        debugPrint('Rollback also failed: $rollbackError');
      }
      throw Exception('Restore failed. Your previous data has been preserved.');
    }
  }
}
