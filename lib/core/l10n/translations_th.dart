const translationsTh = <String, String>{
  // Navigation
  'dashboard': 'แดชบอร์ด',
  'products': 'สินค้า',
  'orders': 'คำสั่งซื้อ',
  'customers': 'ลูกค้า',
  'inventory': 'คลังสินค้า',
  'expenses': 'ค่าใช้จ่าย',
  'categories': 'หมวดหมู่',
  'settings': 'การตั้งค่า',
  'reports': 'รายงาน',

  // Dashboard
  'todayRevenue': 'รายได้วันนี้',
  'monthRevenue': 'รายได้เดือนนี้',
  'monthProfit': 'กำไรเดือนนี้',
  'totalOrders': 'คำสั่งซื้อทั้งหมด',
  'pendingOrders': 'คำสั่งซื้อที่รอดำเนินการ',
  'unpaidAmount': 'ยอดค้างชำระ',
  'lowStockItems': 'สินค้าใกล้หมด',
  'weeklySales': 'ยอดขายรายสัปดาห์',
  'goodMorning': 'สวัสดีตอนเช้า',
  'goodAfternoon': 'สวัสดีตอนบ่าย',
  'goodEvening': 'สวัสดีตอนเย็น',

  // Products
  'addProduct': 'เพิ่มสินค้า',
  'editProduct': 'แก้ไขสินค้า',
  'productName': 'ชื่อสินค้า',
  'sku': 'SKU',
  'description': 'รายละเอียด',
  'sellingPrice': 'ราคาขาย',
  'costPrice': 'ราคาทุน',
  'stockQuantity': 'จำนวนสต็อก',
  'lowStockThreshold': 'เกณฑ์สต็อกต่ำ',
  'category': 'หมวดหมู่',
  'profitMargin': 'อัตรากำไร',
  'inStock': 'มีสินค้า',
  'lowStock': 'สต็อกต่ำ',
  'outOfStock': 'สินค้าหมด',

  // Orders
  'addOrder': 'คำสั่งซื้อใหม่',
  'editOrder': 'แก้ไขคำสั่งซื้อ',
  'orderNumber': 'คำสั่งซื้อ #',
  'customer': 'ลูกค้า',
  'orderItems': 'รายการสั่งซื้อ',
  'subtotal': 'ยอดรวมย่อย',
  'discount': 'ส่วนลด',
  'deliveryFee': 'ค่าจัดส่ง',
  'tax': 'ภาษี',
  'total': 'รวมทั้งหมด',
  'amountPaid': 'ยอดชำระ',
  'notes': 'บันทึก',
  'paymentMethod': 'วิธีการชำระเงิน',
  'deliveryAddress': 'ที่อยู่จัดส่ง',
  'estimatedDelivery': 'กำหนดส่ง',
  'returnOrder': 'คืนสินค้า',

  // Order status
  'pending': 'รอดำเนินการ',
  'confirmed': 'ยืนยันแล้ว',
  'shipped': 'จัดส่งแล้ว',
  'completed': 'เสร็จสิ้น',
  'cancelled': 'ยกเลิก',

  // Payment status
  'unpaid': 'ยังไม่ชำระ',
  'partial': 'ชำระบางส่วน',
  'paid': 'ชำระแล้ว',

  // Payment methods
  'cash': 'เงินสด',
  'card': 'บัตร',
  'mfs': 'MFS',
  'bank': 'ธนาคาร',
  'other': 'อื่นๆ',

  // Customers
  'addCustomer': 'เพิ่มลูกค้า',
  'editCustomer': 'แก้ไขลูกค้า',
  'customerName': 'ชื่อ',
  'phone': 'โทรศัพท์',
  'address': 'ที่อยู่',
  'totalSpent': 'ยอดซื้อทั้งหมด',
  'outstandingBalance': 'ยอดค้างชำระ',
  'purchaseHistory': 'ประวัติการซื้อ (6 เดือน)',

  // Inventory
  'stockAdjustment': 'ปรับปรุงสต็อก',
  'stockMovements': 'ความเคลื่อนไหวสต็อก',
  'adjustQty': 'ปรับจำนวน',
  'reason': 'เหตุผล',

  // Expenses
  'addExpense': 'เพิ่มค่าใช้จ่าย',
  'expenseTitle': 'ชื่อค่าใช้จ่าย',
  'amount': 'จำนวนเงิน',
  'expenseCategory': 'หมวดหมู่',
  'date': 'วันที่',

  // Settings
  'shopName': 'ชื่อร้านค้า',
  'currencySymbol': 'สัญลักษณ์สกุลเงิน',
  'googleAccount': 'บัญชี Google',
  'backupToDrive': 'สำรองข้อมูลไปยัง Drive',
  'restoreFromDrive': 'กู้คืนจาก Drive',
  'lastBackup': 'สำรองข้อมูลล่าสุด',
  'appVersion': 'เวอร์ชันแอป',
  'defaultLowStockThreshold': 'เกณฑ์สต็อกต่ำเริ่มต้น',
  'clearAllData': 'ล้างข้อมูลทั้งหมด',
  'signIn': 'เข้าสู่ระบบ',
  'signOut': 'ออกจากระบบ',
  'taxRate': 'อัตราภาษี (%)',
  'theme': 'ธีม',
  'light': 'สว่าง',
  'dark': 'มืด',
  'system': 'ระบบ',
  'language': 'ภาษา',

  // Actions
  'save': 'บันทึก',
  'cancel': 'ยกเลิก',
  'delete': 'ลบ',
  'edit': 'แก้ไข',
  'confirm': 'ยืนยัน',
  'yes': 'ใช่',
  'no': 'ไม่',
  'add': 'เพิ่ม',
  'search': 'ค้นหา',
  'filter': 'กรอง',
  'share': 'แชร์',
  'print': 'พิมพ์',
  'markAsPaid': 'ทำเครื่องหมายว่าชำระแล้ว',
  'exportCsv': 'ส่งออก CSV',
  'importCsv': 'นำเข้า CSV',

  // Messages
  'deleteConfirmation': 'คุณแน่ใจหรือไม่ว่าต้องการลบรายการนี้?',
  'clearDataConfirmation':
      'การดำเนินการนี้จะลบข้อมูลทั้งหมดของคุณอย่างถาวร ไม่สามารถยกเลิกได้ คุณแน่ใจหรือไม่?',
  'savedSuccessfully': 'บันทึกเรียบร้อยแล้ว',
  'deletedSuccessfully': 'ลบเรียบร้อยแล้ว',
  'errorOccurred': 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง',
  'backupSuccess': 'สำรองข้อมูลเรียบร้อยแล้ว',
  'restoreSuccess': 'กู้คืนข้อมูลเรียบร้อยแล้ว',
  'noDataFound': 'ไม่พบข้อมูล',
  'addFirstProduct': 'เพิ่มสินค้าชิ้นแรกของคุณเพื่อเริ่มต้น',
  'addFirstOrder': 'ยังไม่มีคำสั่งซื้อ สร้างคำสั่งซื้อแรกของคุณ!',
  'addFirstCustomer': 'เพิ่มลูกค้าเพื่อติดตามคำสั่งซื้อ',
  'noExpenses': 'ยังไม่มีค่าใช้จ่ายที่บันทึกไว้',
  'noStockMovements': 'ยังไม่มีความเคลื่อนไหวสต็อกที่บันทึกไว้',

  // Reports
  'totalRevenue': 'รายได้ทั้งหมด',
  'totalProfit': 'กำไรทั้งหมด',
  'totalExpenses': 'ค่าใช้จ่ายทั้งหมด',
  'avgOrderValue': 'มูลค่าเฉลี่ยต่อคำสั่งซื้อ',
  'topProducts': 'สินค้าขายดีตามรายได้',
  'topProductsByQty': 'สินค้าขายดีตามจำนวน',
  'topCustomers': 'ลูกค้าอันดับต้น',
  'salesByCategory': 'ยอดขายตามหมวดหมู่',

  // Recurring
  'recurringOrder': 'คำสั่งซื้อประจำ',
  'repeatEvery': 'ทำซ้ำทุก',
  'days': 'วัน',

  // Delivery
  'delivery': 'การจัดส่ง',
  'markDelivered': 'ทำเครื่องหมายว่าจัดส่งแล้ว',
  'delivered': 'จัดส่งแล้ว',

  // Variants
  'variants': 'ตัวเลือก',
  'addVariant': 'เพิ่มตัวเลือก',
  'variantName': 'คุณสมบัติ (เช่น ขนาด)',
  'variantValue': 'ค่า (เช่น ใหญ่)',
  'priceAdjustment': 'ราคา +/-',
};
