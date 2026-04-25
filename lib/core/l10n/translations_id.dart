const translationsId = <String, String>{
  // Navigation
  'dashboard': 'Dasbor',
  'products': 'Produk',
  'orders': 'Pesanan',
  'customers': 'Pelanggan',
  'inventory': 'Inventaris',
  'expenses': 'Pengeluaran',
  'categories': 'Kategori',
  'settings': 'Pengaturan',
  'reports': 'Laporan',

  // Dashboard
  'todayRevenue': 'Pendapatan Hari Ini',
  'monthRevenue': 'Pendapatan Bulan Ini',
  'monthProfit': 'Laba Bulan Ini',
  'totalOrders': 'Total Pesanan',
  'pendingOrders': 'Pesanan Tertunda',
  'unpaidAmount': 'Jumlah Belum Dibayar',
  'lowStockItems': 'Stok Menipis',
  'weeklySales': 'Penjualan Mingguan',
  'goodMorning': 'Selamat pagi',
  'goodAfternoon': 'Selamat siang',
  'goodEvening': 'Selamat malam',

  // Products
  'addProduct': 'Tambah Produk',
  'editProduct': 'Edit Produk',
  'productName': 'Nama Produk',
  'sku': 'SKU',
  'description': 'Deskripsi',
  'sellingPrice': 'Harga Jual',
  'costPrice': 'Harga Pokok',
  'stockQuantity': 'Jumlah Stok',
  'lowStockThreshold': 'Batas Stok Minimum',
  'category': 'Kategori',
  'profitMargin': 'Margin Keuntungan',
  'inStock': 'Tersedia',
  'lowStock': 'Stok Rendah',
  'outOfStock': 'Habis',

  // Orders
  'addOrder': 'Pesanan Baru',
  'editOrder': 'Edit Pesanan',
  'orderNumber': 'Pesanan #',
  'customer': 'Pelanggan',
  'orderItems': 'Item Pesanan',
  'subtotal': 'Subtotal',
  'discount': 'Diskon',
  'deliveryFee': 'Biaya Pengiriman',
  'tax': 'Pajak',
  'total': 'Total',
  'amountPaid': 'Jumlah Dibayar',
  'notes': 'Catatan',
  'paymentMethod': 'Metode Pembayaran',
  'deliveryAddress': 'Alamat Pengiriman',
  'estimatedDelivery': 'Estimasi Pengiriman',
  'returnOrder': 'Pengembalian Pesanan',

  // Order status
  'pending': 'Tertunda',
  'confirmed': 'Dikonfirmasi',
  'shipped': 'Dikirim',
  'completed': 'Selesai',
  'cancelled': 'Dibatalkan',

  // Payment status
  'unpaid': 'Belum Dibayar',
  'partial': 'Sebagian',
  'paid': 'Lunas',

  // Payment methods
  'cash': 'Tunai',
  'card': 'Kartu',
  'mfs': 'MFS',
  'bank': 'Bank',
  'other': 'Lainnya',

  // Customers
  'addCustomer': 'Tambah Pelanggan',
  'editCustomer': 'Edit Pelanggan',
  'customerName': 'Nama',
  'phone': 'Telepon',
  'address': 'Alamat',
  'totalSpent': 'Total Belanja',
  'outstandingBalance': 'Saldo Tertunggak',
  'purchaseHistory': 'Riwayat Pembelian (6 bulan)',

  // Inventory
  'stockAdjustment': 'Penyesuaian Stok',
  'stockMovements': 'Pergerakan Stok',
  'adjustQty': 'Sesuaikan Jumlah',
  'reason': 'Alasan',

  // Expenses
  'addExpense': 'Tambah Pengeluaran',
  'expenseTitle': 'Judul Pengeluaran',
  'amount': 'Jumlah',
  'expenseCategory': 'Kategori',
  'date': 'Tanggal',

  // Settings
  'shopName': 'Nama Toko',
  'currencySymbol': 'Simbol Mata Uang',
  'googleAccount': 'Akun Google',
  'backupToDrive': 'Cadangkan ke Drive',
  'restoreFromDrive': 'Pulihkan dari Drive',
  'lastBackup': 'Cadangan Terakhir',
  'appVersion': 'Versi Aplikasi',
  'defaultLowStockThreshold': 'Batas Stok Minimum Default',
  'clearAllData': 'Hapus Semua Data',
  'signIn': 'Masuk',
  'signOut': 'Keluar',
  'taxRate': 'Tarif Pajak (%)',
  'theme': 'Tema',
  'light': 'Terang',
  'dark': 'Gelap',
  'system': 'Sistem',
  'language': 'Bahasa',

  // Actions
  'save': 'Simpan',
  'cancel': 'Batal',
  'delete': 'Hapus',
  'edit': 'Edit',
  'confirm': 'Konfirmasi',
  'yes': 'Ya',
  'no': 'Tidak',
  'add': 'Tambah',
  'search': 'Cari',
  'filter': 'Filter',
  'share': 'Bagikan',
  'print': 'Cetak',
  'markAsPaid': 'Tandai Lunas',
  'exportCsv': 'Ekspor CSV',
  'importCsv': 'Impor CSV',

  // Messages
  'deleteConfirmation': 'Apakah Anda yakin ingin menghapus ini?',
  'clearDataConfirmation':
      'Ini akan menghapus semua data Anda secara permanen. Tindakan ini tidak dapat dibatalkan. Apakah Anda yakin?',
  'savedSuccessfully': 'Berhasil disimpan',
  'deletedSuccessfully': 'Berhasil dihapus',
  'errorOccurred': 'Terjadi kesalahan. Silakan coba lagi.',
  'backupSuccess': 'Pencadangan berhasil',
  'restoreSuccess': 'Data berhasil dipulihkan',
  'noDataFound': 'Data tidak ditemukan',
  'addFirstProduct': 'Tambahkan produk pertama Anda untuk memulai',
  'addFirstOrder': 'Belum ada pesanan. Buat pesanan pertama Anda!',
  'addFirstCustomer': 'Tambahkan pelanggan untuk melacak pesanan mereka',
  'noExpenses': 'Belum ada pengeluaran tercatat',
  'noStockMovements': 'Belum ada pergerakan stok tercatat',

  // Reports
  'totalRevenue': 'Total Pendapatan',
  'totalProfit': 'Total Laba',
  'totalExpenses': 'Total Pengeluaran',
  'avgOrderValue': 'Rata-rata Nilai Pesanan',
  'topProducts': 'Produk Teratas berdasarkan Pendapatan',
  'topProductsByQty': 'Produk Teratas berdasarkan Jumlah',
  'topCustomers': 'Pelanggan Teratas',
  'salesByCategory': 'Penjualan berdasarkan Kategori',

  // Recurring
  'recurringOrder': 'Pesanan Berulang',
  'repeatEvery': 'Ulangi setiap',
  'days': 'hari',

  // Delivery
  'delivery': 'Pengiriman',
  'markDelivered': 'Tandai Terkirim',
  'delivered': 'Terkirim',

  // Variants
  'variants': 'Varian',
  'addVariant': 'Tambah Varian',
  'variantName': 'Atribut (cth. Ukuran)',
  'variantValue': 'Nilai (cth. Besar)',
  'priceAdjustment': 'Harga +/-',
};
