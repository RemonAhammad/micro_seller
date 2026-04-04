const translationsBn = <String, String>{
  // Navigation
  'dashboard': 'ড্যাশবোর্ড',
  'products': 'পণ্য',
  'orders': 'অর্ডার',
  'customers': 'গ্রাহক',
  'inventory': 'ইনভেন্টরি',
  'expenses': 'খরচ',
  'categories': 'ক্যাটাগরি',
  'settings': 'সেটিংস',
  'reports': 'রিপোর্ট',

  // Dashboard
  'todayRevenue': 'আজকের আয়',
  'monthRevenue': 'মাসের আয়',
  'monthProfit': 'মাসের লাভ',
  'totalOrders': 'মোট অর্ডার',
  'pendingOrders': 'পেন্ডিং অর্ডার',
  'unpaidAmount': 'বকেয়া পরিমাণ',
  'lowStockItems': 'কম স্টক পণ্য',
  'weeklySales': 'সাপ্তাহিক বিক্রয়',
  'goodMorning': 'সুপ্রভাত',
  'goodAfternoon': 'শুভ অপরাহ্ণ',
  'goodEvening': 'শুভ সন্ধ্যা',

  // Products
  'addProduct': 'পণ্য যোগ করুন',
  'editProduct': 'পণ্য সম্পাদনা',
  'productName': 'পণ্যের নাম',
  'sku': 'SKU',
  'description': 'বিবরণ',
  'sellingPrice': 'বিক্রয় মূল্য',
  'costPrice': 'ক্রয় মূল্য',
  'stockQuantity': 'স্টক পরিমাণ',
  'lowStockThreshold': 'কম স্টক সীমা',
  'category': 'ক্যাটাগরি',
  'profitMargin': 'লাভের হার',
  'inStock': 'স্টকে আছে',
  'lowStock': 'কম স্টক',
  'outOfStock': 'স্টক শেষ',

  // Orders
  'addOrder': 'নতুন অর্ডার',
  'editOrder': 'অর্ডার সম্পাদনা',
  'orderNumber': 'অর্ডার #',
  'customer': 'গ্রাহক',
  'orderItems': 'অর্ডার আইটেম',
  'subtotal': 'সাবটোটাল',
  'discount': 'ছাড়',
  'deliveryFee': 'ডেলিভারি চার্জ',
  'tax': 'ট্যাক্স',
  'total': 'মোট',
  'amountPaid': 'পরিশোধিত',
  'notes': 'নোট',
  'paymentMethod': 'পেমেন্ট পদ্ধতি',
  'deliveryAddress': 'ডেলিভারি ঠিকানা',
  'estimatedDelivery': 'আনুমানিক ডেলিভারি',
  'returnOrder': 'রিটার্ন অর্ডার',

  // Order status
  'pending': 'পেন্ডিং',
  'confirmed': 'কনফার্মড',
  'shipped': 'শিপড',
  'completed': 'সম্পন্ন',
  'cancelled': 'বাতিল',

  // Payment status
  'unpaid': 'অপরিশোধিত',
  'partial': 'আংশিক',
  'paid': 'পরিশোধিত',

  // Payment methods
  'cash': 'নগদ',
  'card': 'কার্ড',
  'mfs': 'এমএফএস',
  'bank': 'ব্যাংক',
  'other': 'অন্যান্য',

  // Customers
  'addCustomer': 'গ্রাহক যোগ করুন',
  'editCustomer': 'গ্রাহক সম্পাদনা',
  'customerName': 'নাম',
  'phone': 'ফোন',
  'address': 'ঠিকানা',
  'totalSpent': 'মোট খরচ',
  'outstandingBalance': 'বকেয়া ব্যালেন্স',
  'purchaseHistory': 'ক্রয়ের ইতিহাস (৬ মাস)',

  // Inventory
  'stockAdjustment': 'স্টক সমন্বয়',
  'stockMovements': 'স্টক মুভমেন্ট',
  'adjustQty': 'পরিমাণ সমন্বয়',
  'reason': 'কারণ',

  // Expenses
  'addExpense': 'খরচ যোগ করুন',
  'expenseTitle': 'খরচের শিরোনাম',
  'amount': 'পরিমাণ',
  'expenseCategory': 'ক্যাটাগরি',
  'date': 'তারিখ',

  // Settings
  'shopName': 'দোকানের নাম',
  'currencySymbol': 'মুদ্রা চিহ্ন',
  'googleAccount': 'গুগল অ্যাকাউন্ট',
  'backupToDrive': 'ড্রাইভে ব্যাকআপ',
  'restoreFromDrive': 'ড্রাইভ থেকে রিস্টোর',
  'lastBackup': 'শেষ ব্যাকআপ',
  'appVersion': 'অ্যাপ ভার্সন',
  'defaultLowStockThreshold': 'ডিফল্ট কম স্টক সীমা',
  'clearAllData': 'সব ডাটা মুছুন',
  'signIn': 'সাইন ইন',
  'signOut': 'সাইন আউট',
  'taxRate': 'ট্যাক্স হার (%)',
  'theme': 'থিম',
  'light': 'লাইট',
  'dark': 'ডার্ক',
  'system': 'সিস্টেম',
  'language': 'ভাষা',

  // Actions
  'save': 'সেভ',
  'cancel': 'বাতিল',
  'delete': 'মুছুন',
  'edit': 'সম্পাদনা',
  'confirm': 'নিশ্চিত',
  'yes': 'হ্যাঁ',
  'no': 'না',
  'add': 'যোগ',
  'search': 'খুঁজুন',
  'filter': 'ফিল্টার',
  'share': 'শেয়ার',
  'print': 'প্রিন্ট',
  'markAsPaid': 'পরিশোধিত হিসেবে চিহ্নিত',
  'exportCsv': 'CSV এক্সপোর্ট',
  'importCsv': 'CSV ইমপোর্ট',

  // Messages
  'deleteConfirmation': 'আপনি কি এটি মুছতে চান?',
  'clearDataConfirmation':
      'এটি আপনার সমস্ত ডাটা স্থায়ীভাবে মুছে ফেলবে। এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না। আপনি কি নিশ্চিত?',
  'savedSuccessfully': 'সফলভাবে সেভ হয়েছে',
  'deletedSuccessfully': 'সফলভাবে মুছে ফেলা হয়েছে',
  'errorOccurred': 'একটি ত্রুটি ঘটেছে। অনুগ্রহ করে আবার চেষ্টা করুন।',
  'backupSuccess': 'ব্যাকআপ সফলভাবে সম্পন্ন হয়েছে',
  'restoreSuccess': 'ডাটা সফলভাবে রিস্টোর হয়েছে',
  'noDataFound': 'কোনো ডাটা পাওয়া যায়নি',
  'addFirstProduct': 'শুরু করতে আপনার প্রথম পণ্য যোগ করুন',
  'addFirstOrder': 'এখনো কোনো অর্ডার নেই। আপনার প্রথম অর্ডার তৈরি করুন!',
  'addFirstCustomer': 'অর্ডার ট্র্যাক করতে গ্রাহক যোগ করুন',
  'noExpenses': 'এখনো কোনো খরচ রেকর্ড করা হয়নি',
  'noStockMovements': 'কোনো স্টক মুভমেন্ট রেকর্ড করা হয়নি',

  // Reports
  'totalRevenue': 'মোট আয়',
  'totalProfit': 'মোট লাভ',
  'totalExpenses': 'মোট খরচ',
  'avgOrderValue': 'গড় অর্ডার মূল্য',
  'topProducts': 'শীর্ষ পণ্য (আয় অনুসারে)',
  'topProductsByQty': 'শীর্ষ পণ্য (পরিমাণ অনুসারে)',
  'topCustomers': 'শীর্ষ গ্রাহক',
  'salesByCategory': 'ক্যাটাগরি অনুসারে বিক্রয়',

  // Recurring
  'recurringOrder': 'পুনরাবৃত্ত অর্ডার',
  'repeatEvery': 'প্রতি',
  'days': 'দিন পরপর',

  // Delivery
  'delivery': 'ডেলিভারি',
  'markDelivered': 'ডেলিভারি সম্পন্ন',
  'delivered': 'ডেলিভারি হয়েছে',

  // Variants
  'variants': 'ভ্যারিয়েন্ট',
  'addVariant': 'ভ্যারিয়েন্ট যোগ',
  'variantName': 'অ্যাট্রিবিউট (যেমন সাইজ)',
  'variantValue': 'মান (যেমন বড়)',
  'priceAdjustment': 'মূল্য +/-',
};
