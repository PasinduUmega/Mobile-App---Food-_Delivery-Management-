import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';
import './permissions.dart';

/// Complete API Integration Guide with Permission Checks
/// 
/// This guide demonstrates:
/// 1. Client-side permission validation before API calls
/// 2. API methods with role-based parameters
/// 3. Error handling for permission denials
/// 4. Backend permission validation strategy

class PermissionAwareApiClient {
  static const String baseUrl = 'http://localhost:8000/api';
  static String? _userId;
  static UserRole? _userRole;

  /// Initialize API client with user context
  static void initialize({
    required String userId,
    required UserRole userRole,
  }) {
    _userId = userId;
    _userRole = userRole;
  }

  /// Helper to build headers with user context
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'X-User-Id': _userId ?? '',
      'X-User-Role': _userRole?.toString().split('.').last ?? '',
    };
  }

  // ============================================
  // CUSTOMER OPERATIONS
  // ============================================

  /// ✅ Create Order - Customer only
  /// Check permission before calling
static Future<OrderSummary?> createOrder({
    required String restaurantId,
    required List<Map<String, dynamic>> items,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canCreate(ComponentPermissions.orders)) {
      throw PermissionException(
        'You do not have permission to create orders',
        _userRole!,
        ComponentPermissions.orders,
        PermissionLevel.create,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: _getHeaders(),
        body: jsonEncode({
          'restaurantId': restaurantId,
          'items': items,
          // Backend validates:
          // 1. X-User-Id matches order.customerId
          // 2. X-User-Role == 'customer'
          // 3. Return 403 if not allowed
        }),
      );

      // Handle permission denied from backend
      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied order creation',
          _userRole!,
          ComponentPermissions.orders,
          PermissionLevel.create,
        );
      }

      if (response.statusCode == 201) {
        return OrderSummary.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Read Orders - Customer sees own orders only
  static Future<List<OrderSummary>> getMyOrders({
    int limit = 10,
    int offset = 0,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canRead(ComponentPermissions.orders)) {
      throw PermissionException(
        'You do not have permission to view orders',
        _userRole!,
        ComponentPermissions.orders,
        PermissionLevel.read,
      );
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/me?limit=$limit&offset=$offset'),
        headers: _getHeaders(),
        // Backend validates:
        // 1. X-User-Role == 'customer'
        // 2. Only return orders where customerId == X-User-Id
        // 3. Return 403 if user doesn't have read permission
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied access to orders',
          _userRole!,
          ComponentPermissions.orders,
          PermissionLevel.read,
        );
      }

      if (response.statusCode == 200) {
        final List items = jsonDecode(response.body);
        return items.map((item) => OrderSummary.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Update Order - Customer can only update pending orders
  static Future<OrderSummary?> updateOrder({
    required String orderId,
    required Map<String, dynamic> updates,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canUpdate(ComponentPermissions.orders)) {
      throw PermissionException(
        'You do not have permission to update orders',
        _userRole!,
        ComponentPermissions.orders,
        PermissionLevel.update,
      );
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: _getHeaders(),
        body: jsonEncode(updates),
        // Backend validates:
        // 1. X-User-Id is the order creator
        // 2. Order status is 'pending'
        // 3. Only certain fields can be updated
        // 4. Return 403 if not allowed
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied order update',
          _userRole!,
          ComponentPermissions.orders,
          PermissionLevel.update,
        );
      }

      if (response.statusCode == 200) {
        return OrderSummary.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// ❌ Delete Order - Customer NOT allowed
  /// This method should not be called for customers
  static Future<bool> deleteOrder({required String orderId}) async {
    // CLIENT-SIDE PERMISSION CHECK - DENY
    if (!_userRole!.canDelete(ComponentPermissions.orders)) {
      throw PermissionException(
        'You do not have permission to delete orders',
        _userRole!,
        ComponentPermissions.orders,
        PermissionLevel.delete,
      );
    }
    // This will never execute for customer
    return false;
  }

  /// ✅ Create Payment - Customer can create, not update/delete
  static Future<Payment?> createPayment({
    required String orderId,
    required double amount,
    required String method,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canCreate(ComponentPermissions.payments)) {
      throw PermissionException(
        'You do not have permission to create payments',
        _userRole!,
        ComponentPermissions.payments,
        PermissionLevel.create,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments'),
        headers: _getHeaders(),
        body: jsonEncode({
          'orderId': orderId,
          'amount': amount,
          'method': method,
          // Backend validates:
          // 1. User owns the order
          // 2. Amount matches order total
          // 3. X-User-Role == 'customer'
        }),
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied payment creation',
          _userRole!,
          ComponentPermissions.payments,
          PermissionLevel.create,
        );
      }

      if (response.statusCode == 201) {
        return Payment.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // RESTAURANT OWNER OPERATIONS
  // ============================================

  /// ✅ Create Menu Item - Restaurant only
  static Future<MenuItem?> createMenuItem({
    required String restaurantId,
    required String name,
    required double price,
    required String description,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canCreate(ComponentPermissions.menu)) {
      throw PermissionException(
        'You do not have permission to create menu items',
        _userRole!,
        ComponentPermissions.menu,
        PermissionLevel.create,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/restaurants/$restaurantId/menu'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'price': price,
          'description': description,
          // Backend validates:
          // 1. X-User-Id owns this restaurant
          // 2. X-User-Role == 'storeOwner'
          // 3. Return 403 if not owner
        }),
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied menu item creation',
          _userRole!,
          ComponentPermissions.menu,
          PermissionLevel.create,
        );
      }

      if (response.statusCode == 201) {
        return MenuItem.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Update Inventory - Restaurant only for their own inventory
  static Future<bool> updateInventory({
    required String restaurantId,
    required String itemId,
    required int newQuantity,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canUpdate(ComponentPermissions.inventory)) {
      throw PermissionException(
        'You do not have permission to update inventory',
        _userRole!,
        ComponentPermissions.inventory,
        PermissionLevel.update,
      );
    }

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/restaurants/$restaurantId/inventory/$itemId'),
        headers: _getHeaders(),
        body: jsonEncode({'quantity': newQuantity}),
        // Backend validates:
        // 1. X-User-Id owns this restaurant
        // 2. Item belongs to this restaurant
        // 3. X-User-Role == 'storeOwner'
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied inventory update',
          _userRole!,
          ComponentPermissions.inventory,
          PermissionLevel.update,
        );
      }

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ View Orders - Restaurant can read but only update status
  static Future<List<OrderSummary>> getRestaurantOrders({
    required String restaurantId,
    int limit = 10,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canRead(ComponentPermissions.orders)) {
      throw PermissionException(
        'You do not have permission to view orders',
        _userRole!,
        ComponentPermissions.orders,
        PermissionLevel.read,
      );
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/restaurants/$restaurantId/orders?limit=$limit',
        ),
        headers: _getHeaders(),
        // Backend validates:
        // 1. X-User-Id owns this restaurant
        // 2. Only return orders for this restaurant
        // 3. Restaurant can read orders
      );

      if (response.statusCode == 200) {
        final List items = jsonDecode(response.body);
        return items.map((item) => OrderSummary.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // DELIVERY DRIVER OPERATIONS
  // ============================================

  /// ✅ Accept Delivery - Driver only
  static Future<bool> acceptDelivery({
    required String deliveryId,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canUpdate(ComponentPermissions.delivery)) {
      throw PermissionException(
        'You do not have permission to accept deliveries',
        _userRole!,
        ComponentPermissions.delivery,
        PermissionLevel.update,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/$deliveryId/accept'),
        headers: _getHeaders(),
        body: jsonEncode({}),
        // Backend validates:
        // 1. X-User-Role == 'deliveryDriver'
        // 2. Delivery status is 'pending'
        // 3. Update delivery.driverId = X-User-Id
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied accepting delivery',
          _userRole!,
          ComponentPermissions.delivery,
          PermissionLevel.update,
        );
      }

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Update Location - Driver only
  static Future<bool> updateDeliveryLocation({
    required String deliveryId,
    required double latitude,
    required double longitude,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canUpdate(ComponentPermissions.location)) {
      throw PermissionException(
        'You do not have permission to update location',
        _userRole!,
        ComponentPermissions.location,
        PermissionLevel.update,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/$deliveryId/location'),
        headers: _getHeaders(),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().toIso8601String(),
          // Backend validates:
          // 1. X-User-Id is the assigned driver
          // 2. Delivery status is 'in_transit' or 'assigned'
          // 3. Location is valid coordinates
        }),
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied location update',
          _userRole!,
          ComponentPermissions.location,
          PermissionLevel.update,
        );
      }

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // ADMIN OPERATIONS (Full CRUD all)
  // ============================================

  /// ✅ Admin: Create User with any role
  static Future<User?> adminCreateUser({
    required String email,
    required String name,
    required UserRole role,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canCreate(ComponentPermissions.users)) {
      throw PermissionException(
        'You do not have permission to create users',
        _userRole!,
        ComponentPermissions.users,
        PermissionLevel.create,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'name': name,
          'role': role.toString().split('.').last,
          // Backend validates:
          // 1. X-User-Role == 'admin'
          // 2. Permission to create users
        }),
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied user creation',
          _userRole!,
          ComponentPermissions.users,
          PermissionLevel.create,
        );
      }

      if (response.statusCode == 201) {
        return User.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ Admin: Delete any delivery (full CRUD)
  static Future<bool> adminDeleteDelivery({
    required String deliveryId,
  }) async {
    // CLIENT-SIDE PERMISSION CHECK
    if (!_userRole!.canDelete(ComponentPermissions.delivery)) {
      throw PermissionException(
        'You do not have permission to delete deliveries',
        _userRole!,
        ComponentPermissions.delivery,
        PermissionLevel.delete,
      );
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/deliveries/$deliveryId'),
        headers: _getHeaders(),
        // Backend validates:
        // 1. X-User-Role == 'admin'
        // 2. Permission to delete deliveries
      );

      if (response.statusCode == 403) {
        throw PermissionException(
          'Server denied delivery deletion',
          _userRole!,
          ComponentPermissions.delivery,
          PermissionLevel.delete,
        );
      }

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }
}

// ============================================
// CUSTOM EXCEPTION FOR PERMISSION ERRORS
// ============================================

class PermissionException implements Exception {
  final String message;
  final UserRole userRole;
  final String component;
  final PermissionLevel level;

  PermissionException(
    this.message,
    this.userRole,
    this.component,
    this.level,
  );

  @override
  String toString() {
    return 'PermissionException: $message\n'
        'Role: ${userRole.toString().split('.').last}\n'
        'Component: $component\n'
        'Level: ${level.toString().split('.').last}';
  }
}

// ============================================
// BACKEND API VALIDATION CHECKLIST
// ============================================

/// Every API endpoint MUST validate permissions on the backend:
///
/// 1. AUTHENTICATION LAYER
///    - Verify X-User-Id header exists
///    - Verify X-User-Role header matches user's actual role
///    - Return 401 Unauthorized if missing
///
/// 2. AUTHORIZATION LAYER
///    - Check permission matrix for requested operation
///    - Verify role can perform operation on component
///    - Return 403 Forbidden if denied
///    - Log all permission denials for audit
///
/// 3. DATA ISOLATION LAYER
///    - For non-admin users: Filter data by ownership
///    - Customers see only their own orders
///    - Restaurant owners see only their own inventory
///    - Drivers see only assigned deliveries
///    - Admins see all data
///
/// 4. FIELD-LEVEL ACCESS
///    - Some roles can update certain fields only
///    - E.g., Restaurant can update order status but not customer
///    - Validate each field change
///
/// 5. STATE TRANSITION VALIDATION
///    - Order: pending → confirmed → preparing → ready → completed
///    - Delivery: pending → assigned → in_transit → delivered
///    - Only allow valid transitions per role
///
/// EXAMPLE Node.js Permission Check:
/// ```javascript
/// app.post('/api/orders', async (req, res) => {
///   const userId = req.headers['x-user-id'];
///   const userRole = req.headers['x-user-role'];
///
///   // Validation
///   if (!userId || !userRole) {
///     return res.status(401).json({ error: 'Missing authentication' });
///   }
///
///   // Permission check
///   if (userRole !== 'customer') {
///     logger.warn(`Unauthorized order creation: ${userRole}`);
///     return res.status(403).json({ error: 'Permission denied' });
///   }
///
///   // Data isolation
///   try {
///     const order = await Order.create({
///       customerId: userId,
///       items: req.body.items,
///     });
///     res.status(201).json(order);
///   } catch (error) {
///     res.status(500).json({ error: error.message });
///   }
/// });
/// ```
///
/// EXAMPLE Node.js for Restaurant Orders:
/// ```javascript
/// app.put('/api/orders/:id', async (req, res) => {
///   const userId = req.headers['x-user-id'];
///   const userRole = req.headers['x-user-role'];
///   const { id } = req.params;
///
///   // Permission: Only restaurant can update order status
///   if (userRole !== 'storeOwner') {
///     return res.status(403).json({ error: 'Only restaurants can update orders' });
///   }
///
///   const order = await Order.findById(id);
///
///   // Data isolation: Restaurant can only update their own orders
///   if (order.restaurantId !== userId) {
///     logger.warn(`Unauthorized order access: ${userId}`);
///     return res.status(403).json({ error: 'Not your order' });
///   }
///
///   // Field validation: Only status can be updated by restaurant
///   if (req.body.status) {
///     order.status = req.body.status;
///   } else {
///     return res.status(400).json({ error: 'Can only update status' });
///   }
///
///   await order.save();
///   res.json(order);
/// });
/// ```
