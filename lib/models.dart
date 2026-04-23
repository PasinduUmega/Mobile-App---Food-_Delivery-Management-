import 'dart:convert';
import 'dart:math' as Math;

enum PaymentMethod { paypal, cashOnDelivery, onlineBanking }

enum UserRole { customer, admin, storeOwner, deliveryDriver }

extension UserRoleApi on UserRole {
  static UserRole fromApi(String? raw) {
    switch ((raw ?? 'CUSTOMER').toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'STORE_OWNER':
        return UserRole.storeOwner;
      case 'DELIVERY_DRIVER':
        return UserRole.deliveryDriver;
      default:
        return UserRole.customer;
    }
  }

  String get apiValue => switch (this) {
    UserRole.admin => 'ADMIN',
    UserRole.storeOwner => 'STORE_OWNER',
    UserRole.deliveryDriver => 'DELIVERY_DRIVER',
    UserRole.customer => 'CUSTOMER',
  };
}

extension UserRoleDisplay on UserRole {
  String get displayLabel => switch (this) {
    UserRole.customer => 'Customer',
    UserRole.admin => 'Administrator',
    UserRole.storeOwner => 'Restaurant owner',
    UserRole.deliveryDriver => 'Delivery driver',
  };
}

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

  /// Combo / special instructions — copied to order for drivers & kitchen.
  final String? lineNote;

  const CartItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.lineNote,
  });

  Map<String, Object?> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
    if (lineNote != null && lineNote!.trim().isNotEmpty) 'lineNote': lineNote,
  };
}

class MenuItem {
  final int id;
  final int storeId;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;

  /// Calendar date (local) when this item is featured as the “daily special”.
  final DateTime? specialForDate;

  /// Bundle / meal deal — show components to customers and drivers.
  final bool isCombo;
  final List<String> comboComponents;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MenuItem({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.specialForDate,
    this.isCombo = false,
    this.comboComponents = const [],
    this.createdAt,
    this.updatedAt,
  });

  static List<String> _parseComboComponents(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return const [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((x) => x.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static bool _parseBoolCombo(dynamic v) {
    if (v == true || v == 1 || v == '1') return true;
    return false;
  }

  static MenuItem fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;
    DateTime? parseDateOnly(dynamic v) {
      final d = parseDt(v);
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day);
    }

    final combo = _parseComboComponents(json['combo_components']);
    final isCombo = _parseBoolCombo(json['is_combo']) || combo.isNotEmpty;

    return MenuItem(
      id: int.tryParse('${json['id']}') ?? 0,
      storeId: int.tryParse('${json['store_id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: double.tryParse('${json['price']}') ?? 0.0,
      imageUrl: json['image_url']?.toString(),
      specialForDate: parseDateOnly(json['special_for_date']),
      isCombo: isCombo,
      comboComponents: combo,
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }
}

extension MenuItemCartNote on MenuItem {
  /// Text stored on cart/order lines so drivers see combo contents.
  String? get cartLineNote {
    if (!isCombo || comboComponents.isEmpty) return null;
    return 'Includes: ${comboComponents.join(', ')}';
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
  final String? lineNote;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.lineNote,
  });

  static OrderItem fromJson(Map<String, dynamic> json) {
    final n = json['line_note']?.toString().trim();
    return OrderItem(
      id: int.tryParse('${json['id']}') ?? 0,
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      productId: int.tryParse('${json['product_id']}'),
      name: json['name']?.toString() ?? '',
      qty: int.tryParse('${json['qty']}') ?? 0,
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0.0,
      lineTotal: double.tryParse('${json['line_total']}') ?? 0.0,
      lineNote: n != null && n.isNotEmpty ? n : null,
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
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    this.address,
    this.role = UserRole.customer,
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
      role: UserRoleApi.fromApi(
        json['role']?.toString() ??
            json['user_role']?.toString() ??
            json['userRole']?.toString(),
      ),
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
  final int? ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Store({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.ownerUserId,
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
      ownerUserId: int.tryParse(json['owner_user_id']?.toString() ?? ''),
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
  final String? lineNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DatabaseCartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.lineNote,
    required this.createdAt,
    required this.updatedAt,
  });

  static DatabaseCartItem fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) => DateTime.tryParse(v?.toString() ?? '');
    final ln = json['line_note']?.toString().trim();
    return DatabaseCartItem(
      id: int.tryParse('${json['id']}') ?? 0,
      cartId: int.tryParse('${json['cart_id']}') ?? 0,
      productId: int.tryParse('${json['product_id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      qty: int.tryParse('${json['qty']}') ?? 0,
      unitPrice: double.tryParse('${json['unit_price']}') ?? 0.0,
      lineNote: ln != null && ln.isNotEmpty ? ln : null,
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'qty': qty,
    'unit_price': unitPrice,
    if (lineNote != null && lineNote!.trim().isNotEmpty) 'line_note': lineNote,
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
    DateTime? parseDt(dynamic v) => DateTime.tryParse(v?.toString() ?? '');
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

/// Enhanced driver profile for delivery management
class DriverProfile {
  final int id;
  final int userId;
  final String name;
  final String? phone;
  final String? email;
  final String? vehicleType;
  final String? vehicleNumber;
  final String? licenseNumber;
  final String status; // ACTIVE, INACTIVE, ON_DELIVERY, PENDING_VERIFICATION
  final double? ratingsAverage;
  final int ratingsCount;
  final bool verified;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.phone,
    this.email,
    this.vehicleType,
    this.vehicleNumber,
    this.licenseNumber,
    this.status = 'PENDING_VERIFICATION',
    this.ratingsAverage,
    this.ratingsCount = 0,
    this.verified = false,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static DriverProfile fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;
    return DriverProfile(
      id: int.tryParse('${json['id']}') ?? 0,
      userId: int.tryParse('${json['user_id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      vehicleNumber: json['vehicle_number']?.toString(),
      licenseNumber: json['license_number']?.toString(),
      status: json['status']?.toString() ?? 'PENDING_VERIFICATION',
      ratingsAverage: double.tryParse('${json['ratings_average']}'),
      ratingsCount: int.tryParse('${json['ratings_count']}') ?? 0,
      verified: json['verified'] == true || json['verified'] == 1,
      verifiedAt: parseDt(json['verified_at']),
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'phone': phone,
    'email': email,
    'vehicle_type': vehicleType,
    'vehicle_number': vehicleNumber,
    'license_number': licenseNumber,
    'status': status,
    'verified': verified,
  };
}

/// Driver rating and feedback model
class DriverRating {
  final int id;
  final int driverId;
  final int orderId;
  final int? customerId;
  final String? customerName;
  final int rating; // 1-5 stars
  final String? feedback;
  final String?
  category; // delivery_speed, politeness, vehicle_condition, accuracy
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverRating({
    required this.id,
    required this.driverId,
    required this.orderId,
    this.customerId,
    this.customerName,
    required this.rating,
    this.feedback,
    this.category,
    this.isAnonymous = false,
    required this.createdAt,
    required this.updatedAt,
  });

  static DriverRating fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;
    return DriverRating(
      id: int.tryParse('${json['id']}') ?? 0,
      driverId: int.tryParse('${json['driver_id']}') ?? 0,
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      customerId: int.tryParse('${json['customer_id']}'),
      customerName: json['customer_name']?.toString(),
      rating: int.tryParse('${json['rating']}') ?? 3,
      feedback: json['feedback']?.toString(),
      category: json['category']?.toString(),
      isAnonymous: json['is_anonymous'] == true || json['is_anonymous'] == 1,
      createdAt: parseDt(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'driver_id': driverId,
    'order_id': orderId,
    'customer_id': customerId,
    'rating': rating,
    'feedback': feedback,
    'category': category,
    'is_anonymous': isAnonymous,
  };
}

/// Driver performance metrics
class DriverMetrics {
  final int driverId;
  final String driverName;
  final int totalDeliveries;
  final int completedDeliveries;
  final double averageRating;
  final int ratingCount;
  final double? averageDeliveryTime; // in minutes
  final DateTime? lastDelivery;
  final List<int>
  ratingDistribution; // [1-star, 2-star, 3-star, 4-star, 5-star]

  const DriverMetrics({
    required this.driverId,
    required this.driverName,
    required this.totalDeliveries,
    required this.completedDeliveries,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.averageDeliveryTime,
    this.lastDelivery,
    this.ratingDistribution = const [0, 0, 0, 0, 0],
  });

  static DriverMetrics fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) =>
        v != null ? DateTime.tryParse(v.toString()) : null;
    List<int> parseDistribution(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => int.tryParse('$e') ?? 0).toList();
      }
      return [0, 0, 0, 0, 0];
    }

    return DriverMetrics(
      driverId: int.tryParse('${json['driver_id']}') ?? 0,
      driverName: json['driver_name']?.toString() ?? '',
      totalDeliveries: int.tryParse('${json['total_deliveries']}') ?? 0,
      completedDeliveries: int.tryParse('${json['completed_deliveries']}') ?? 0,
      averageRating: double.tryParse('${json['average_rating']}') ?? 0.0,
      ratingCount: int.tryParse('${json['rating_count']}') ?? 0,
      averageDeliveryTime: double.tryParse('${json['average_delivery_time']}'),
      lastDelivery: parseDt(json['last_delivery']),
      ratingDistribution: parseDistribution(json['rating_distribution']),
    );
  }
}

/// Location tracking for delivery drivers
class DeliveryLocation {
  final int id;
  final int deliveryId;
  final double latitude;
  final double longitude;
  final double? accuracy; // meters
  final String? address;
  final DateTime timestamp;
  final DateTime createdAt;

  const DeliveryLocation({
    required this.id,
    required this.deliveryId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
    required this.timestamp,
    required this.createdAt,
  });

  static DeliveryLocation fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return DeliveryLocation(
      id: int.tryParse('${json['id']}') ?? 0,
      deliveryId: int.tryParse('${json['delivery_id']}') ?? 0,
      latitude: double.tryParse('${json['latitude']}') ?? 0.0,
      longitude: double.tryParse('${json['longitude']}') ?? 0.0,
      accuracy: double.tryParse('${json['accuracy']}'),
      address: json['address']?.toString(),
      timestamp: parseDt(json['timestamp']),
      createdAt: parseDt(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'delivery_id': deliveryId,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'address': address,
    'timestamp': timestamp.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  /// Calculate distance between two locations (in meters)
  double distanceTo(DeliveryLocation other) {
    const earthRadiusKm = 6371;
    final lat1 = latitude * 3.14159265359 / 180;
    final lat2 = other.latitude * 3.14159265359 / 180;
    final deltaLat = (other.latitude - latitude) * 3.14159265359 / 180;
    final deltaLon = (other.longitude - longitude) * 3.14159265359 / 180;

    final a =
        (Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2)) +
        (Math.cos(lat1) *
            Math.cos(lat2) *
            Math.sin(deltaLon / 2) *
            Math.sin(deltaLon / 2));
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c * 1000; // Convert to meters
  }
}

/// Complete delivery information with driver assignment
class Delivery {
  final int id;
  final int orderId;
  final int? driverId;
  final String status; // pending, assigned, in_transit, delivered, cancelled
  final String? driverName;
  final String? driverPhone;
  final String? driverVehicle;
  final String? estimatedDeliveryTime; // ISO 8601 format or relative time
  final double? totalDistance; // in km
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DeliveryLocation> locationHistory;

  const Delivery({
    required this.id,
    required this.orderId,
    this.driverId,
    required this.status,
    this.driverName,
    this.driverPhone,
    this.driverVehicle,
    this.estimatedDeliveryTime,
    this.totalDistance,
    required this.assignedAt,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.locationHistory = const [],
  });

  static Delivery fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    List<DeliveryLocation> parseLocations(dynamic raw) {
      if (raw is List) {
        return raw
            .map(
              (item) => DeliveryLocation.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    }

    return Delivery(
      id: int.tryParse('${json['id']}') ?? 0,
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      driverId: int.tryParse('${json['driver_id']}'),
      status: json['status']?.toString() ?? 'pending',
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      driverVehicle: json['driver_vehicle']?.toString(),
      estimatedDeliveryTime: json['estimated_delivery_time']?.toString(),
      totalDistance: double.tryParse('${json['total_distance']}'),
      assignedAt: parseDt(json['assigned_at']),
      startedAt: parseDt(json['started_at']),
      completedAt: parseDt(json['completed_at']),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
      locationHistory: parseLocations(json['location_history']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'driver_id': driverId,
    'status': status,
    'driver_name': driverName,
    'driver_phone': driverPhone,
    'driver_vehicle': driverVehicle,
    'estimated_delivery_time': estimatedDeliveryTime,
    'total_distance': totalDistance,
    'assigned_at': assignedAt.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'location_history': locationHistory.map((loc) => loc.toJson()).toList(),
  };

  /// Check if delivery is in progress
  bool get isInProgress => status == 'in_transit' || status == 'assigned';

  /// Check if delivery is completed
  bool get isCompleted => status == 'delivered';

  /// Get last known location
  DeliveryLocation? get lastLocation =>
      locationHistory.isEmpty ? null : locationHistory.last;

  /// Get distance traveled so far
  double get distanceTraveled {
    if (locationHistory.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < locationHistory.length - 1; i++) {
      total += locationHistory[i].distanceTo(locationHistory[i + 1]);
    }
    return total / 1000; // Convert to km
  }
}
