const translationsVi = <String, String>{
  // Navigation
  'dashboard': 'Bảng điều khiển',
  'products': 'Sản phẩm',
  'orders': 'Đơn hàng',
  'customers': 'Khách hàng',
  'inventory': 'Kho hàng',
  'expenses': 'Chi phí',
  'categories': 'Danh mục',
  'settings': 'Cài đặt',
  'reports': 'Báo cáo',

  // Dashboard
  'todayRevenue': 'Doanh thu hôm nay',
  'monthRevenue': 'Doanh thu tháng',
  'monthProfit': 'Lợi nhuận tháng',
  'totalOrders': 'Tổng đơn hàng',
  'pendingOrders': 'Đơn hàng chờ xử lý',
  'unpaidAmount': 'Số tiền chưa thanh toán',
  'lowStockItems': 'Sản phẩm sắp hết hàng',
  'weeklySales': 'Doanh số tuần',
  'goodMorning': 'Chào buổi sáng',
  'goodAfternoon': 'Chào buổi chiều',
  'goodEvening': 'Chào buổi tối',

  // Products
  'addProduct': 'Thêm sản phẩm',
  'editProduct': 'Sửa sản phẩm',
  'productName': 'Tên sản phẩm',
  'sku': 'SKU',
  'description': 'Mô tả',
  'sellingPrice': 'Giá bán',
  'costPrice': 'Giá vốn',
  'stockQuantity': 'Số lượng tồn kho',
  'lowStockThreshold': 'Ngưỡng tồn kho thấp',
  'category': 'Danh mục',
  'profitMargin': 'Biên lợi nhuận',
  'inStock': 'Còn hàng',
  'lowStock': 'Sắp hết hàng',
  'outOfStock': 'Hết hàng',

  // Orders
  'addOrder': 'Đơn hàng mới',
  'editOrder': 'Sửa đơn hàng',
  'orderNumber': 'Đơn hàng #',
  'customer': 'Khách hàng',
  'orderItems': 'Sản phẩm trong đơn',
  'subtotal': 'Tạm tính',
  'discount': 'Giảm giá',
  'deliveryFee': 'Phí giao hàng',
  'tax': 'Thuế',
  'total': 'Tổng cộng',
  'amountPaid': 'Số tiền đã trả',
  'notes': 'Ghi chú',
  'paymentMethod': 'Phương thức thanh toán',
  'deliveryAddress': 'Địa chỉ giao hàng',
  'estimatedDelivery': 'Giao hàng dự kiến',
  'returnOrder': 'Trả hàng',

  // Order status
  'pending': 'Chờ xử lý',
  'confirmed': 'Đã xác nhận',
  'shipped': 'Đã gửi hàng',
  'completed': 'Hoàn thành',
  'cancelled': 'Đã hủy',

  // Payment status
  'unpaid': 'Chưa thanh toán',
  'partial': 'Thanh toán một phần',
  'paid': 'Đã thanh toán',

  // Payment methods
  'cash': 'Tiền mặt',
  'card': 'Thẻ',
  'mfs': 'MFS',
  'bank': 'Ngân hàng',
  'other': 'Khác',

  // Customers
  'addCustomer': 'Thêm khách hàng',
  'editCustomer': 'Sửa khách hàng',
  'customerName': 'Tên',
  'phone': 'Điện thoại',
  'address': 'Địa chỉ',
  'totalSpent': 'Tổng chi tiêu',
  'outstandingBalance': 'Số dư còn nợ',
  'purchaseHistory': 'Lịch sử mua hàng (6 tháng)',

  // Inventory
  'stockAdjustment': 'Điều chỉnh kho',
  'stockMovements': 'Biến động kho',
  'adjustQty': 'Điều chỉnh số lượng',
  'reason': 'Lý do',

  // Expenses
  'addExpense': 'Thêm chi phí',
  'expenseTitle': 'Tiêu đề chi phí',
  'amount': 'Số tiền',
  'expenseCategory': 'Danh mục',
  'date': 'Ngày',

  // Settings
  'shopName': 'Tên cửa hàng',
  'currencySymbol': 'Ký hiệu tiền tệ',
  'googleAccount': 'Tài khoản Google',
  'backupToDrive': 'Sao lưu lên Drive',
  'restoreFromDrive': 'Khôi phục từ Drive',
  'lastBackup': 'Sao lưu lần cuối',
  'appVersion': 'Phiên bản ứng dụng',
  'defaultLowStockThreshold': 'Ngưỡng tồn kho thấp mặc định',
  'clearAllData': 'Xóa tất cả dữ liệu',
  'signIn': 'Đăng nhập',
  'signOut': 'Đăng xuất',
  'taxRate': 'Thuế suất (%)',
  'theme': 'Giao diện',
  'light': 'Sáng',
  'dark': 'Tối',
  'system': 'Hệ thống',
  'language': 'Ngôn ngữ',

  // Actions
  'save': 'Lưu',
  'cancel': 'Hủy',
  'delete': 'Xóa',
  'edit': 'Sửa',
  'confirm': 'Xác nhận',
  'yes': 'Có',
  'no': 'Không',
  'add': 'Thêm',
  'search': 'Tìm kiếm',
  'filter': 'Lọc',
  'share': 'Chia sẻ',
  'print': 'In',
  'markAsPaid': 'Đánh dấu đã thanh toán',
  'exportCsv': 'Xuất CSV',
  'importCsv': 'Nhập CSV',

  // Messages
  'deleteConfirmation': 'Bạn có chắc chắn muốn xóa mục này không?',
  'clearDataConfirmation':
      'Thao tác này sẽ xóa vĩnh viễn tất cả dữ liệu của bạn. Không thể hoàn tác. Bạn có chắc không?',
  'savedSuccessfully': 'Đã lưu thành công',
  'deletedSuccessfully': 'Đã xóa thành công',
  'errorOccurred': 'Đã xảy ra lỗi. Vui lòng thử lại.',
  'backupSuccess': 'Sao lưu thành công',
  'restoreSuccess': 'Khôi phục dữ liệu thành công',
  'noDataFound': 'Không tìm thấy dữ liệu',
  'addFirstProduct': 'Thêm sản phẩm đầu tiên để bắt đầu',
  'addFirstOrder': 'Chưa có đơn hàng. Tạo đơn hàng đầu tiên!',
  'addFirstCustomer': 'Thêm khách hàng để theo dõi đơn hàng của họ',
  'noExpenses': 'Chưa có chi phí nào được ghi nhận',
  'noStockMovements': 'Chưa có biến động kho nào được ghi nhận',

  // Reports
  'totalRevenue': 'Tổng doanh thu',
  'totalProfit': 'Tổng lợi nhuận',
  'totalExpenses': 'Tổng chi phí',
  'avgOrderValue': 'Giá trị đơn hàng trung bình',
  'topProducts': 'Sản phẩm hàng đầu theo doanh thu',
  'topProductsByQty': 'Sản phẩm hàng đầu theo số lượng',
  'topCustomers': 'Khách hàng hàng đầu',
  'salesByCategory': 'Doanh số theo danh mục',

  // Recurring
  'recurringOrder': 'Đơn hàng định kỳ',
  'repeatEvery': 'Lặp lại mỗi',
  'days': 'ngày',

  // Delivery
  'delivery': 'Giao hàng',
  'markDelivered': 'Đánh dấu đã giao',
  'delivered': 'Đã giao',

  // Variants
  'variants': 'Biến thể',
  'addVariant': 'Thêm biến thể',
  'variantName': 'Thuộc tính (vd. Kích cỡ)',
  'variantValue': 'Giá trị (vd. Lớn)',
  'priceAdjustment': 'Giá +/-',
};
