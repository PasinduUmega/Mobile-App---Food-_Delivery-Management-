enum PaymentMethod { paypal, cashOnDelivery, onlineBanking }

class Payment {
  final int id;
  final int orderId;
  final String method; // PAYPAL | CASH_ON_DELIVERY | ONLINE_BANKING
  final String
  status; // CREATED | APPROVAL_PENDING | AUTHORIZED | CAPTURED | FAILED | CANCELLED
  final String? provider;
  final String? providerOrderId;
  final String? providerCaptureId;
  final String? approvalUrl;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.status,
    required this.provider,
    required this.providerOrderId,
    required this.providerCaptureId,
    required this.approvalUrl,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  static Payment fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return Payment(
      id: int.tryParse('${json['id']}') ?? 0,
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      method: json['method']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      provider: json['provider']?.toString(),
      providerOrderId: json['provider_order_id']?.toString(),
      providerCaptureId: json['provider_capture_id']?.toString(),
      approvalUrl: json['approval_url']?.toString(),
      amount: double.tryParse('${json['amount']}') ?? 0.0,
      currency: json['currency']?.toString() ?? '',
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class CartItem {
  final int? productId;
  final String name;
  final int qty;
  final double unitPrice;

  const CartItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
  });

  Map<String, Object?> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
  };
}

class MenuItem {
  final int id;
  final int storeId;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MenuItem({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  static MenuItem fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;
    return MenuItem(
      id: int.tryParse('${json['id']}') ?? 0,
      storeId: int.tryParse('${json['store_id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: double.tryParse('${json['price']}') ?? 0.0,
      imageUrl: json['image_url']?.toString(),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class InventoryItem {
  final int id;
  final int menuItemId;
  final String? menuItemName;
  final int? storeId;
  final String? storeName;
  final int quantity;
  final DateTime? updatedAt;

  const InventoryItem({
    required this.id,
    required this.menuItemId,
    this.menuItemName,
    this.storeId,
    this.storeName,
    required this.quantity,
    this.updatedAt,
  });

  static InventoryItem fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: int.tryParse('${json['id']}') ?? 0,
      menuItemId: int.tryParse('${json['menu_item_id']}') ?? 0,
      menuItemName: json['menu_item_name']?.toString(),
      storeId: json['store_id'] != null
          ? int.tryParse('${json['store_id']}')
          : null,
      storeName: json['store_name']?.toString(),
      quantity: int.tryParse('${json['quantity']}') ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class DeliveryInfo {
  final int id;
  final int orderId;
  final String? driverName;
  final String? driverPhone;
  final String status;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? pickupTime;
  final DateTime? deliveryTime;
  final DateTime createdAt;

  const DeliveryInfo({
    required this.id,
    required this.orderId,
    this.driverName,
    this.driverPhone,
    required this.status,
    this.currentLatitude,
    this.currentLongitude,
    this.pickupTime,
    this.deliveryTime,
    required this.createdAt,
  });

  static DeliveryInfo fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;
    return DeliveryInfo(
      id: int.tryParse('${json['id']}') ?? 0,
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      currentLatitude: double.tryParse('${json['current_latitude']}'),
      currentLongitude: double.tryParse('${json['current_longitude']}'),
      pickupTime: parseDt(json['pickup_time']),
      deliveryTime: parseDt(json['delivery_time']),
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
    );
  }
}

class CreatedOrder {
  final int orderId;
  final String currency;
  final double subtotal;
  final double deliveryFee;
  final double total;

  const CreatedOrder({
    required this.orderId,
    required this.currency,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  });
}

class OrderItem {
  final int id;
  final int orderId;
  final int? productId;
  final String name;
  final int qty;
  final double unitPrice;
  final double lineTotal;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  static OrderItem fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: int.tryParse('${json['id']}') ?? 0,
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      productId: int.tryParse('${json['product_id']}'),
      name: json['name']?.toString() ?? '',
      qty: int.tryParse('${json['qty']}') ?? 0,
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0.0,
      lineTotal: double.tryParse('${json['line_total']}') ?? 0.0,
    );
  }
}

class OrderSummary {
  final int orderId;
  final int? userId;
  final int? storeId;
  final String currency;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String status;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final List<OrderItem>? items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderSummary({
    required this.orderId,
    this.userId,
    this.storeId,
    required this.currency,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.status,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  static OrderSummary fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    List<OrderItem>? parsedItems;
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .whereType<Map>()
          .map((e) => OrderItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return OrderSummary(
      orderId: int.tryParse('${json['id']}') ?? 0,
      userId: json['user_id'] != null
          ? int.tryParse('${json['user_id']}')
          : null,
      storeId: json['store_id'] != null
          ? int.tryParse('${json['store_id']}')
          : null,
      currency: json['currency']?.toString() ?? '',
      subtotal: double.tryParse('${json['subtotal']}') ?? 0.0,
      deliveryFee: double.tryParse('${json['delivery_fee']}') ?? 0.0,
      total: double.tryParse('${json['total']}') ?? 0.0,
      status: json['status']?.toString() ?? '',
      deliveryLatitude: double.tryParse('${json['delivery_latitude']}'),
      deliveryLongitude: double.tryParse('${json['delivery_longitude']}'),
      items: parsedItems,
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class User {
  final int id;
  final String name;
  final String email;
  final String? mobile;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  static User fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return User(
      id: int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      address: json['address']?.toString(),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class Store {
  final int id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Store({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  static Store fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return Store(
      id: int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      latitude: double.tryParse('${json['latitude']}'),
      longitude: double.tryParse('${json['longitude']}'),
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

class PayPalCreateResult {
  final int paymentId;
  final String paypalOrderId;
  final String approvalUrl;

  const PayPalCreateResult({
    required this.paymentId,
    required this.paypalOrderId,
    required this.approvalUrl,
  });
}

class ReceiptResponse {
  final int orderId;
  final String orderStatus;
  final double total;
  final String currency;
  final Receipt? receipt;

  const ReceiptResponse({
    required this.orderId,
    required this.orderStatus,
    required this.total,
    required this.currency,
    required this.receipt,
  });
}

class Receipt {
  final String receiptNo;
  final DateTime issuedAt;
  final double paidAmount;
  final String currency;
  final String paymentMethod;
  final String paymentStatus;

  const Receipt({
    required this.receiptNo,
    required this.issuedAt,
    required this.paidAmount,
    required this.currency,
    required this.paymentMethod,
    required this.paymentStatus,
  });
}

/// Persistent cart item model (from database)
class DatabaseCartItem {
  final int id;
  final int cartId;
  final int productId;
  final String name;
  final int qty;
  final double unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DatabaseCartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  static DatabaseCartItem fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '');
    return DatabaseCartItem(
      id: int.tryParse('${json['id']}') ?? 0,
      cartId: int.tryParse('${json['cart_id']}') ?? 0,
      productId: int.tryParse('${json['product_id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      qty: int.tryParse('${json['qty']}') ?? 0,
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0.0,
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'qty': qty,
    'unit_price': unitPrice,
  };
}

/// Persistent shopping cart model (from database)
class ShoppingCart {
  final int id;
  final int userId;
  final int? storeId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? checkedOutAt;
  final List<DatabaseCartItem> items;

  const ShoppingCart({
    required this.id,
    required this.userId,
    this.storeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.checkedOutAt,
    this.items = const [],
  });

  static ShoppingCart fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '');
    final itemsList = json['items'] as List? ?? [];
    final items = itemsList
        .whereType<Map>()
        .map((e) => DatabaseCartItem.fromJson(e.cast<String, dynamic>()))
        .toList();

    return ShoppingCart(
      id: int.tryParse('${json['id']}') ?? 0,
      userId: int.tryParse('${json['user_id']}') ?? 0,
      storeId: int.tryParse('${json['store_id']}'),
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(json['updated_at']) ?? DateTime.now(),
      checkedOutAt: parseDt(json['checked_out_at']),
      items: items,
    );
  }

  /// Calculate cart subtotal
  double getSubtotal() {
    return items.fold(0.0, (sum, item) => sum + (item.qty * item.unitPrice));
  }

  /// Get number of items in cart
  int getItemCount() {
    return items.fold(0, (sum, item) => sum + item.qty);
  }
}
