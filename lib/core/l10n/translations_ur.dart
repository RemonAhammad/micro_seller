const translationsUr = <String, String>{
  // Navigation
  'dashboard': 'ڈیش بورڈ',
  'products': 'مصنوعات',
  'orders': 'آرڈرز',
  'customers': 'گاہک',
  'inventory': 'انوینٹری',
  'expenses': 'اخراجات',
  'categories': 'زمرے',
  'settings': 'ترتیبات',
  'reports': 'رپورٹس',

  // Dashboard
  'todayRevenue': 'آج کی آمدنی',
  'monthRevenue': 'ماہانہ آمدنی',
  'monthProfit': 'ماہانہ منافع',
  'totalOrders': 'کل آرڈرز',
  'pendingOrders': 'زیر التوا آرڈرز',
  'unpaidAmount': 'غیر ادا شدہ رقم',
  'lowStockItems': 'کم اسٹاک اشیاء',
  'weeklySales': 'ہفتہ وار فروخت',
  'goodMorning': 'صبح بخیر',
  'goodAfternoon': 'دوپہر بخیر',
  'goodEvening': 'شام بخیر',

  // Products
  'addProduct': 'مصنوع شامل کریں',
  'editProduct': 'مصنوع میں ترمیم',
  'productName': 'مصنوع کا نام',
  'sku': 'SKU',
  'description': 'تفصیل',
  'sellingPrice': 'فروخت قیمت',
  'costPrice': 'لاگت قیمت',
  'stockQuantity': 'اسٹاک مقدار',
  'lowStockThreshold': 'کم اسٹاک کی حد',
  'category': 'زمرہ',
  'profitMargin': 'منافع کا مارجن',
  'inStock': 'دستیاب',
  'lowStock': 'کم اسٹاک',
  'outOfStock': 'اسٹاک ختم',

  // Orders
  'addOrder': 'نیا آرڈر',
  'editOrder': 'آرڈر میں ترمیم',
  'orderNumber': 'آرڈر نمبر',
  'customer': 'گاہک',
  'orderItems': 'آرڈر کی اشیاء',
  'subtotal': 'ذیلی کل',
  'discount': 'رعایت',
  'deliveryFee': 'ترسیل فیس',
  'tax': 'ٹیکس',
  'total': 'کل',
  'amountPaid': 'ادا شدہ رقم',
  'notes': 'نوٹس',
  'paymentMethod': 'ادائیگی کا طریقہ',
  'deliveryAddress': 'ترسیل کا پتہ',
  'estimatedDelivery': 'متوقع ترسیل',
  'returnOrder': 'واپسی آرڈر',

  // Order status
  'pending': 'زیر التوا',
  'confirmed': 'تصدیق شدہ',
  'shipped': 'بھیج دیا گیا',
  'completed': 'مکمل',
  'cancelled': 'منسوخ',

  // Payment status
  'unpaid': 'غیر ادا شدہ',
  'partial': 'جزوی',
  'paid': 'ادا شدہ',

  // Payment methods
  'cash': 'نقد',
  'card': 'کارڈ',
  'mfs': 'MFS',
  'bank': 'بینک',
  'other': 'دیگر',

  // Customers
  'addCustomer': 'گاہک شامل کریں',
  'editCustomer': 'گاہک میں ترمیم',
  'customerName': 'نام',
  'phone': 'فون',
  'address': 'پتہ',
  'totalSpent': 'کل خرچ',
  'outstandingBalance': 'واجب الادا بقایا',
  'purchaseHistory': 'خریداری کی تاریخ (6 ماہ)',

  // Inventory
  'stockAdjustment': 'اسٹاک ایڈجسٹمنٹ',
  'stockMovements': 'اسٹاک کی نقل و حرکت',
  'adjustQty': 'مقدار ایڈجسٹ کریں',
  'reason': 'وجہ',

  // Expenses
  'addExpense': 'خرچ شامل کریں',
  'expenseTitle': 'خرچ کا عنوان',
  'amount': 'رقم',
  'expenseCategory': 'زمرہ',
  'date': 'تاریخ',

  // Settings
  'shopName': 'دکان کا نام',
  'currencySymbol': 'کرنسی کی علامت',
  'googleAccount': 'Google اکاؤنٹ',
  'backupToDrive': 'Drive پر بیک اپ',
  'restoreFromDrive': 'Drive سے بحال کریں',
  'lastBackup': 'آخری بیک اپ',
  'appVersion': 'ایپ ورژن',
  'defaultLowStockThreshold': 'پہلے سے طے شدہ کم اسٹاک کی حد',
  'clearAllData': 'تمام ڈیٹا صاف کریں',
  'signIn': 'سائن ان',
  'signOut': 'سائن آؤٹ',
  'taxRate': 'ٹیکس کی شرح (%)',
  'theme': 'تھیم',
  'light': 'ہلکا',
  'dark': 'گہرا',
  'system': 'سسٹم',
  'language': 'زبان',

  // Actions
  'save': 'محفوظ کریں',
  'cancel': 'منسوخ کریں',
  'delete': 'حذف کریں',
  'edit': 'ترمیم',
  'confirm': 'تصدیق',
  'yes': 'ہاں',
  'no': 'نہیں',
  'add': 'شامل کریں',
  'search': 'تلاش',
  'filter': 'فلٹر',
  'share': 'شیئر کریں',
  'print': 'پرنٹ',
  'markAsPaid': 'ادا شدہ نشان زد کریں',
  'exportCsv': 'CSV برآمد کریں',
  'importCsv': 'CSV درآمد کریں',

  // Messages
  'deleteConfirmation': 'کیا آپ واقعی اسے حذف کرنا چاہتے ہیں؟',
  'clearDataConfirmation':
      'یہ آپ کا تمام ڈیٹا مستقل طور پر حذف کر دے گا۔ یہ عمل واپس نہیں ہو سکتا۔ کیا آپ کو یقین ہے؟',
  'savedSuccessfully': 'کامیابی سے محفوظ ہو گیا',
  'deletedSuccessfully': 'کامیابی سے حذف ہو گیا',
  'errorOccurred': 'ایک خرابی پیش آئی۔ براہ کرم دوبارہ کوشش کریں۔',
  'backupSuccess': 'بیک اپ کامیابی سے مکمل ہوا',
  'restoreSuccess': 'ڈیٹا کامیابی سے بحال ہو گیا',
  'noDataFound': 'کوئی ڈیٹا نہیں ملا',
  'addFirstProduct': 'شروع کرنے کے لیے اپنی پہلی مصنوع شامل کریں',
  'addFirstOrder': 'ابھی تک کوئی آرڈر نہیں۔ اپنا پہلا آرڈر بنائیں!',
  'addFirstCustomer': 'ان کے آرڈرز ٹریک کرنے کے لیے گاہک شامل کریں',
  'noExpenses': 'ابھی تک کوئی خرچ ریکارڈ نہیں ہوا',
  'noStockMovements': 'ابھی تک کوئی اسٹاک کی نقل و حرکت ریکارڈ نہیں ہوئی',

  // Reports
  'totalRevenue': 'کل آمدنی',
  'totalProfit': 'کل منافع',
  'totalExpenses': 'کل اخراجات',
  'avgOrderValue': 'اوسط آرڈر کی قیمت',
  'topProducts': 'آمدنی کے لحاظ سے بہترین مصنوعات',
  'topProductsByQty': 'مقدار کے لحاظ سے بہترین مصنوعات',
  'topCustomers': 'بہترین گاہک',
  'salesByCategory': 'زمرے کے لحاظ سے فروخت',

  // Recurring
  'recurringOrder': 'بار بار آنے والا آرڈر',
  'repeatEvery': 'ہر بار دہرائیں',
  'days': 'دن',

  // Delivery
  'delivery': 'ترسیل',
  'markDelivered': 'ترسیل شدہ نشان زد کریں',
  'delivered': 'ترسیل شدہ',

  // Variants
  'variants': 'ویریئنٹس',
  'addVariant': 'ویریئنٹ شامل کریں',
  'variantName': 'خصوصیت (مثلاً سائز)',
  'variantValue': 'قدر (مثلاً بڑا)',
  'priceAdjustment': 'قیمت +/-',
};
