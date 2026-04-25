const translationsMs = <String, String>{
  // Navigation
  'dashboard': 'Papan Pemuka',
  'products': 'Produk',
  'orders': 'Pesanan',
  'customers': 'Pelanggan',
  'inventory': 'Inventori',
  'expenses': 'Perbelanjaan',
  'categories': 'Kategori',
  'settings': 'Tetapan',
  'reports': 'Laporan',

  // Dashboard
  'todayRevenue': 'Hasil Hari Ini',
  'monthRevenue': 'Hasil Bulanan',
  'monthProfit': 'Keuntungan Bulanan',
  'totalOrders': 'Jumlah Pesanan',
  'pendingOrders': 'Pesanan Tertangguh',
  'unpaidAmount': 'Jumlah Belum Dibayar',
  'lowStockItems': 'Item Stok Rendah',
  'weeklySales': 'Jualan Mingguan',
  'goodMorning': 'Selamat pagi',
  'goodAfternoon': 'Selamat tengah hari',
  'goodEvening': 'Selamat petang',

  // Products
  'addProduct': 'Tambah Produk',
  'editProduct': 'Edit Produk',
  'productName': 'Nama Produk',
  'sku': 'SKU',
  'description': 'Penerangan',
  'sellingPrice': 'Harga Jualan',
  'costPrice': 'Harga Kos',
  'stockQuantity': 'Kuantiti Stok',
  'lowStockThreshold': 'Had Stok Rendah',
  'category': 'Kategori',
  'profitMargin': 'Margin Keuntungan',
  'inStock': 'Ada Stok',
  'lowStock': 'Stok Rendah',
  'outOfStock': 'Kehabisan Stok',

  // Orders
  'addOrder': 'Pesanan Baru',
  'editOrder': 'Edit Pesanan',
  'orderNumber': 'Pesanan #',
  'customer': 'Pelanggan',
  'orderItems': 'Item Pesanan',
  'subtotal': 'Jumlah Kecil',
  'discount': 'Diskaun',
  'deliveryFee': 'Yuran Penghantaran',
  'tax': 'Cukai',
  'total': 'Jumlah',
  'amountPaid': 'Jumlah Dibayar',
  'notes': 'Nota',
  'paymentMethod': 'Kaedah Pembayaran',
  'deliveryAddress': 'Alamat Penghantaran',
  'estimatedDelivery': 'Anggaran Penghantaran',
  'returnOrder': 'Pemulangan Pesanan',

  // Order status
  'pending': 'Tertangguh',
  'confirmed': 'Disahkan',
  'shipped': 'Dihantar',
  'completed': 'Selesai',
  'cancelled': 'Dibatalkan',

  // Payment status
  'unpaid': 'Belum Dibayar',
  'partial': 'Separa',
  'paid': 'Dibayar',

  // Payment methods
  'cash': 'Tunai',
  'card': 'Kad',
  'mfs': 'MFS',
  'bank': 'Bank',
  'other': 'Lain-lain',

  // Customers
  'addCustomer': 'Tambah Pelanggan',
  'editCustomer': 'Edit Pelanggan',
  'customerName': 'Nama',
  'phone': 'Telefon',
  'address': 'Alamat',
  'totalSpent': 'Jumlah Dibelanjakan',
  'outstandingBalance': 'Baki Tertunggak',
  'purchaseHistory': 'Sejarah Pembelian (6 bulan)',

  // Inventory
  'stockAdjustment': 'Pelarasan Stok',
  'stockMovements': 'Pergerakan Stok',
  'adjustQty': 'Laraskan Kuantiti',
  'reason': 'Sebab',

  // Expenses
  'addExpense': 'Tambah Perbelanjaan',
  'expenseTitle': 'Tajuk Perbelanjaan',
  'amount': 'Jumlah',
  'expenseCategory': 'Kategori',
  'date': 'Tarikh',

  // Settings
  'shopName': 'Nama Kedai',
  'currencySymbol': 'Simbol Mata Wang',
  'googleAccount': 'Akaun Google',
  'backupToDrive': 'Sandaran ke Drive',
  'restoreFromDrive': 'Pulihkan dari Drive',
  'lastBackup': 'Sandaran Terakhir',
  'appVersion': 'Versi Aplikasi',
  'defaultLowStockThreshold': 'Had Stok Rendah Lalai',
  'clearAllData': 'Padam Semua Data',
  'signIn': 'Log Masuk',
  'signOut': 'Log Keluar',
  'taxRate': 'Kadar Cukai (%)',
  'theme': 'Tema',
  'light': 'Cerah',
  'dark': 'Gelap',
  'system': 'Sistem',
  'language': 'Bahasa',

  // Actions
  'save': 'Simpan',
  'cancel': 'Batal',
  'delete': 'Padam',
  'edit': 'Edit',
  'confirm': 'Sahkan',
  'yes': 'Ya',
  'no': 'Tidak',
  'add': 'Tambah',
  'search': 'Cari',
  'filter': 'Tapis',
  'share': 'Kongsi',
  'print': 'Cetak',
  'markAsPaid': 'Tandakan Dibayar',
  'exportCsv': 'Eksport CSV',
  'importCsv': 'Import CSV',

  // Messages
  'deleteConfirmation': 'Adakah anda pasti mahu memadam ini?',
  'clearDataConfirmation':
      'Ini akan memadam semua data anda secara kekal. Tindakan ini tidak boleh dibuat asal. Adakah anda pasti?',
  'savedSuccessfully': 'Berjaya disimpan',
  'deletedSuccessfully': 'Berjaya dipadam',
  'errorOccurred': 'Ralat berlaku. Sila cuba lagi.',
  'backupSuccess': 'Sandaran berjaya diselesaikan',
  'restoreSuccess': 'Data berjaya dipulihkan',
  'noDataFound': 'Tiada data dijumpai',
  'addFirstProduct': 'Tambah produk pertama anda untuk bermula',
  'addFirstOrder': 'Belum ada pesanan. Cipta pesanan pertama anda!',
  'addFirstCustomer': 'Tambah pelanggan untuk menjejaki pesanan mereka',
  'noExpenses': 'Belum ada perbelanjaan direkodkan',
  'noStockMovements': 'Belum ada pergerakan stok direkodkan',

  // Reports
  'totalRevenue': 'Jumlah Hasil',
  'totalProfit': 'Jumlah Keuntungan',
  'totalExpenses': 'Jumlah Perbelanjaan',
  'avgOrderValue': 'Purata Nilai Pesanan',
  'topProducts': 'Produk Teratas mengikut Hasil',
  'topProductsByQty': 'Produk Teratas mengikut Kuantiti',
  'topCustomers': 'Pelanggan Teratas',
  'salesByCategory': 'Jualan mengikut Kategori',

  // Recurring
  'recurringOrder': 'Pesanan Berulang',
  'repeatEvery': 'Ulang setiap',
  'days': 'hari',

  // Delivery
  'delivery': 'Penghantaran',
  'markDelivered': 'Tandakan Dihantar',
  'delivered': 'Dihantar',

  // Variants
  'variants': 'Varian',
  'addVariant': 'Tambah Varian',
  'variantName': 'Atribut (cth. Saiz)',
  'variantValue': 'Nilai (cth. Besar)',
  'priceAdjustment': 'Harga +/-',
};
