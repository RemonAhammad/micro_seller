const translationsTr = <String, String>{
  // Navigation
  'dashboard': 'Gösterge Paneli',
  'products': 'Ürünler',
  'orders': 'Siparişler',
  'customers': 'Müşteriler',
  'inventory': 'Envanter',
  'expenses': 'Giderler',
  'categories': 'Kategoriler',
  'settings': 'Ayarlar',
  'reports': 'Raporlar',

  // Dashboard
  'todayRevenue': 'Bugünün Geliri',
  'monthRevenue': 'Aylık Gelir',
  'monthProfit': 'Aylık Kâr',
  'totalOrders': 'Toplam Sipariş',
  'pendingOrders': 'Bekleyen Siparişler',
  'unpaidAmount': 'Ödenmemiş Tutar',
  'lowStockItems': 'Düşük Stoklu Ürünler',
  'weeklySales': 'Haftalık Satışlar',
  'goodMorning': 'Günaydın',
  'goodAfternoon': 'İyi öğlenler',
  'goodEvening': 'İyi akşamlar',

  // Products
  'addProduct': 'Ürün Ekle',
  'editProduct': 'Ürünü Düzenle',
  'productName': 'Ürün Adı',
  'sku': 'SKU',
  'description': 'Açıklama',
  'sellingPrice': 'Satış Fiyatı',
  'costPrice': 'Maliyet Fiyatı',
  'stockQuantity': 'Stok Miktarı',
  'lowStockThreshold': 'Düşük Stok Eşiği',
  'category': 'Kategori',
  'profitMargin': 'Kâr Marjı',
  'inStock': 'Stokta',
  'lowStock': 'Düşük Stok',
  'outOfStock': 'Stokta Yok',

  // Orders
  'addOrder': 'Yeni Sipariş',
  'editOrder': 'Siparişi Düzenle',
  'orderNumber': 'Sipariş No',
  'customer': 'Müşteri',
  'orderItems': 'Sipariş Kalemleri',
  'subtotal': 'Ara Toplam',
  'discount': 'İndirim',
  'deliveryFee': 'Teslimat Ücreti',
  'tax': 'Vergi',
  'total': 'Toplam',
  'amountPaid': 'Ödenen Tutar',
  'notes': 'Notlar',
  'paymentMethod': 'Ödeme Yöntemi',
  'deliveryAddress': 'Teslimat Adresi',
  'estimatedDelivery': 'Tahmini Teslimat',
  'returnOrder': 'Sipariş İadesi',

  // Order status
  'pending': 'Beklemede',
  'confirmed': 'Onaylandı',
  'shipped': 'Kargoya Verildi',
  'completed': 'Tamamlandı',
  'cancelled': 'İptal Edildi',

  // Payment status
  'unpaid': 'Ödenmedi',
  'partial': 'Kısmi',
  'paid': 'Ödendi',

  // Payment methods
  'cash': 'Nakit',
  'card': 'Kart',
  'mfs': 'MFS',
  'bank': 'Banka',
  'other': 'Diğer',

  // Customers
  'addCustomer': 'Müşteri Ekle',
  'editCustomer': 'Müşteriyi Düzenle',
  'customerName': 'Ad',
  'phone': 'Telefon',
  'address': 'Adres',
  'totalSpent': 'Toplam Harcama',
  'outstandingBalance': 'Ödenmemiş Bakiye',
  'purchaseHistory': 'Satın Alma Geçmişi (6 ay)',

  // Inventory
  'stockAdjustment': 'Stok Düzeltmesi',
  'stockMovements': 'Stok Hareketleri',
  'adjustQty': 'Miktarı Düzenle',
  'reason': 'Neden',

  // Expenses
  'addExpense': 'Gider Ekle',
  'expenseTitle': 'Gider Başlığı',
  'amount': 'Tutar',
  'expenseCategory': 'Kategori',
  'date': 'Tarih',

  // Settings
  'shopName': 'Mağaza Adı',
  'currencySymbol': 'Para Birimi Simgesi',
  'googleAccount': 'Google Hesabı',
  'backupToDrive': 'Drive\'a Yedekle',
  'restoreFromDrive': 'Drive\'dan Geri Yükle',
  'lastBackup': 'Son Yedekleme',
  'appVersion': 'Uygulama Sürümü',
  'defaultLowStockThreshold': 'Varsayılan Düşük Stok Eşiği',
  'clearAllData': 'Tüm Verileri Sil',
  'signIn': 'Giriş Yap',
  'signOut': 'Çıkış Yap',
  'taxRate': 'Vergi Oranı (%)',
  'theme': 'Tema',
  'light': 'Açık',
  'dark': 'Koyu',
  'system': 'Sistem',
  'language': 'Dil',

  // Actions
  'save': 'Kaydet',
  'cancel': 'İptal',
  'delete': 'Sil',
  'edit': 'Düzenle',
  'confirm': 'Onayla',
  'yes': 'Evet',
  'no': 'Hayır',
  'add': 'Ekle',
  'search': 'Ara',
  'filter': 'Filtrele',
  'share': 'Paylaş',
  'print': 'Yazdır',
  'markAsPaid': 'Ödendi olarak işaretle',
  'exportCsv': 'CSV Dışa Aktar',
  'importCsv': 'CSV İçe Aktar',

  // Messages
  'deleteConfirmation': 'Bunu silmek istediğinizden emin misiniz?',
  'clearDataConfirmation':
      'Bu işlem tüm verilerinizi kalıcı olarak silecektir. Bu eylem geri alınamaz. Emin misiniz?',
  'savedSuccessfully': 'Başarıyla kaydedildi',
  'deletedSuccessfully': 'Başarıyla silindi',
  'errorOccurred': 'Bir hata oluştu. Lütfen tekrar deneyin.',
  'backupSuccess': 'Yedekleme başarıyla tamamlandı',
  'restoreSuccess': 'Veriler başarıyla geri yüklendi',
  'noDataFound': 'Veri bulunamadı',
  'addFirstProduct': 'Başlamak için ilk ürününüzü ekleyin',
  'addFirstOrder': 'Henüz sipariş yok. İlk siparişinizi oluşturun!',
  'addFirstCustomer': 'Siparişlerini takip etmek için müşteri ekleyin',
  'noExpenses': 'Henüz gider kaydedilmedi',
  'noStockMovements': 'Henüz stok hareketi kaydedilmedi',

  // Reports
  'totalRevenue': 'Toplam Gelir',
  'totalProfit': 'Toplam Kâr',
  'totalExpenses': 'Toplam Gider',
  'avgOrderValue': 'Ortalama Sipariş Değeri',
  'topProducts': 'Gelire Göre En İyi Ürünler',
  'topProductsByQty': 'Miktara Göre En İyi Ürünler',
  'topCustomers': 'En İyi Müşteriler',
  'salesByCategory': 'Kategoriye Göre Satışlar',

  // Recurring
  'recurringOrder': 'Tekrarlayan Sipariş',
  'repeatEvery': 'Her tekrarla',
  'days': 'gün',

  // Delivery
  'delivery': 'Teslimat',
  'markDelivered': 'Teslim edildi olarak işaretle',
  'delivered': 'Teslim Edildi',

  // Variants
  'variants': 'Varyantlar',
  'addVariant': 'Varyant Ekle',
  'variantName': 'Özellik (ör. Beden)',
  'variantValue': 'Değer (ör. Büyük)',
  'priceAdjustment': 'Fiyat +/-',
};
