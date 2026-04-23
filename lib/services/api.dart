import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';

class _TimeoutClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(const Duration(seconds: 10));
  }
}

class ApiClient {
  /// Set when the user signs in so the server can authorize admin-only actions (e.g. role changes).
  static int? sessionUserId;

  final String baseUrl;
  final http.Client _http;

  ApiClient({http.Client? httpClient, String? baseUrl})
    : baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
        RegExp(r'\/+$'),
        '',
      ),
      _http = httpClient ?? _TimeoutClient();

  Map<String, String> _jsonHeadersWithSession() {
    final h = <String, String>{'Content-Type': 'application/json'};
    final id = sessionUserId;
    if (id != null) h['X-User-Id'] = id.toString();
    return h;
  }

  Future<CreatedOrder> createOrder({
    required List<CartItem> items,
    double deliveryFee = 2.50,
    String currency = 'LKR',
    int? userId,
    int? storeId,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final uri = Uri.parse('$baseUrl/api/orders');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'storeId': storeId,
        'currency': currency,
        'deliveryFee': deliveryFee,
        'deliveryLatitude': deliveryLatitude,
        'deliveryLongitude': deliveryLongitude,
        'items': items.map((e) => e.toJson()).toList(),
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to create order');
    }
    return CreatedOrder(
      orderId: int.tryParse('${body['orderId']}') ?? 0,
      currency: body['currency']?.toString() ?? currency,
      subtotal: double.tryParse('${body['subtotal']}') ?? 0.0,
      deliveryFee: double.tryParse('${body['deliveryFee']}') ?? 0.0,
      total: double.tryParse('${body['total']}') ?? 0.0,
    );
  }

  Future<PayPalCreateResult> createPayPalPayment({required int orderId}) async {
    final uri = Uri.parse('$baseUrl/api/payments/paypal/create');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'orderId': orderId}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to start PayPal');
    }
    return PayPalCreateResult(
      paymentId: int.tryParse('${body['paymentId']}') ?? 0,
      paypalOrderId: body['paypalOrderId']?.toString() ?? '',

      approvalUrl: body['approvalUrl']?.toString() ?? '',
    );
  }

  Future<void> capturePayPal({required int orderId}) async {
    final uri = Uri.parse('$baseUrl/api/payments/paypal/capture');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'orderId': orderId}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to capture PayPal',
      );
    }
  }

  Future<void> confirmCod({required int orderId}) async {
    final uri = Uri.parse('$baseUrl/api/payments/cod/confirm');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'orderId': orderId}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to confirm COD');
    }
  }

  Future<void> confirmOnlineBanking({
    required int orderId,
    String? reference,
  }) async {
    final uri = Uri.parse('$baseUrl/api/payments/online-banking/confirm');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'orderId': orderId, 'reference': reference}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to confirm online banking',
      );
    }
  }

  Future<ReceiptResponse> getReceipt({required int orderId}) async {
    final uri = Uri.parse('$baseUrl/api/receipts/$orderId');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch receipt',
      );
    }
    final receiptMap = body['receipt'];
    Receipt? receipt;
    if (receiptMap is Map<String, dynamic>) {
      receipt = Receipt(
        receiptNo: receiptMap['receiptNo']?.toString() ?? '',
        issuedAt:
            DateTime.tryParse(receiptMap['issuedAt']?.toString() ?? '') ??
            DateTime.now(),
        paidAmount: double.tryParse('${receiptMap['paidAmount']}') ?? 0.0,
        currency: receiptMap['currency']?.toString() ?? '',
        paymentMethod: receiptMap['paymentMethod']?.toString() ?? '',
        paymentStatus: receiptMap['paymentStatus']?.toString() ?? '',
      );
    }

    return ReceiptResponse(
      orderId: int.tryParse('${body['orderId']}') ?? 0,
      orderStatus: body['orderStatus']?.toString() ?? '',
      total: double.tryParse('${body['total']}') ?? 0.0,
      currency: body['currency']?.toString() ?? '',
      receipt: receipt,
    );
  }

  Future<List<OrderSummary>> listOrders({
    int? userId,
    int? storeId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (userId != null) 'userId': '$userId',
      if (storeId != null) 'storeId': '$storeId',
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };
    final uri = Uri.parse('$baseUrl/api/orders').replace(queryParameters: qp);
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to list orders');
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => OrderSummary.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<OrderSummary> getOrderDetails({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/orders/$id');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch order details',
      );
    }
    return OrderSummary.fromJson(body);
  }

  Future<void> updateOrder({
    required int id,
    String? status,
    List<Map<String, dynamic>>? items,
  }) async {
    final uri = Uri.parse('$baseUrl/api/orders/$id');
    final data = <String, dynamic>{
      if (status != null) 'status': status,
      if (items != null) 'items': items,
    };
    final resp = await _http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to update order');
    }
  }

  Future<bool> deleteOrder({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/orders/$id');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to delete order');
    }
    return body['deleted'] == true;
  }

  Future<List<User>> listUsers() async {
    final uri = Uri.parse('$baseUrl/api/users');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to list users');
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => User.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<User> getUser({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/users/$id');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to fetch user');
    }
    return User.fromJson(body);
  }

  Future<User> createUser({
    required String name,
    required String email,
    String? mobile,
  }) async {
    final uri = Uri.parse('$baseUrl/api/users');
    final body = {'name': name, 'email': email};
    if (mobile != null && mobile.isNotEmpty) {
      body['mobile'] = mobile;
    }
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final respBody = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        respBody['error']?.toString() ?? 'Failed to create user',
      );
    }
    return User.fromJson(respBody);
  }

  Future<User> updateUser({
    required int id,
    required String name,
    required String email,
    String? mobile,
    UserRole? role,
  }) async {
    final uri = Uri.parse('$baseUrl/api/users/$id');
    final body = <String, dynamic>{'name': name, 'email': email};
    if (mobile != null && mobile.isNotEmpty) {
      body['mobile'] = mobile;
    }
    if (role != null) {
      body['role'] = role.apiValue;
    }
    final resp = await _http.put(
      uri,
      headers: _jsonHeadersWithSession(),
      body: jsonEncode(body),
    );
    final respBody = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        respBody['error']?.toString() ?? 'Failed to update user',
      );
    }
    return User.fromJson(respBody);
  }

  Future<bool> deleteUser({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/users/$id');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to delete user');
    }
    return body['deleted'] == true;
  }

  Future<User> signUp({
    required String name,
    required String email,
    required String password,
    String? mobile,
    String? address,
    UserRole accountRole = UserRole.customer,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/signup');
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      // Server expects uppercase role token (ADMIN, CUSTOMER, …)
      'role': accountRole.apiValue,
    };
    if (mobile != null && mobile.trim().isNotEmpty) {
      payload['mobile'] = mobile.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      payload['address'] = address.trim();
    }
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to signup');
    }
    return User.fromJson(body);
  }

  Future<User> signIn({required String email, required String password}) async {
    final uri = Uri.parse('$baseUrl/api/auth/signin');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to signin');
    }
    return User.fromJson(body);
  }

  Future<List<MenuItem>> getStoreMenu({required int storeId}) async {
    final uri = Uri.parse('$baseUrl/api/stores/$storeId/menu');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch store menu',
      );
    }
    final items = body['items'];
    if (items is List) {
      final List<MenuItem> result = [];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          result.add(MenuItem.fromJson(item));
        }
      }
      return result;
    }
    return const [];
  }

  Future<MenuItem> createMenuItem({
    required int storeId,
    required String name,
    required double price,
    String? description,
    String? imageUrl,
    String? specialForDate,
    bool isCombo = false,
    List<String>? comboComponents,
  }) async {
    final uri = Uri.parse('$baseUrl/api/menu_items');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'storeId': storeId,
        'name': name,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
        if (specialForDate != null) 'specialForDate': specialForDate,
        'isCombo': isCombo,
        if (comboComponents != null && comboComponents.isNotEmpty)
          'comboComponents': comboComponents,
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to create menu item',
      );
    }
    return MenuItem.fromJson(body);
  }

  Future<MenuItem> updateMenuItem({
    required int id,
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    String? specialForDate,
    bool setSpecialForDate = false,
    bool? isCombo,
    List<String>? comboComponents,
    bool setComboFields = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/menu_items/$id');
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (setSpecialForDate) 'specialForDate': specialForDate,
      if (setComboFields) ...{
        'isCombo': isCombo ?? false,
        'comboComponents': comboComponents ?? <String>[],
      },
    };
    final resp = await _http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to update menu item',
      );
    }
    return MenuItem.fromJson(body);
  }

  Future<bool> deleteMenuItem({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/menu_items/$id');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to delete menu item',
      );
    }
    return body['deleted'] == true;
  }

  Future<List<InventoryItem>> listInventory() async {
    final uri = Uri.parse('$baseUrl/api/inventory');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to list inventory',
      );
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => InventoryItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<void> updateInventory({required int id, required int quantity}) async {
    final uri = Uri.parse('$baseUrl/api/inventory/$id');
    final resp = await _http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'quantity': quantity}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to update inventory',
      );
    }
  }

  Future<void> createInventory({
    required int menuItemId,
    int quantity = 0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/inventory');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'menuItemId': menuItemId, 'quantity': quantity}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to create inventory record',
      );
    }
  }

  Future<bool> deleteInventory({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/inventory/$id');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to delete inventory record',
      );
    }
    return body['deleted'] == true;
  }

  Future<List<DeliveryInfo>> listDeliveries() async {
    final uri = Uri.parse('$baseUrl/api/deliveries');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to list deliveries',
      );
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => DeliveryInfo.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<DeliveryInfo?> getDeliveryByOrderId({required int orderId}) async {
    final uri = Uri.parse(
      '$baseUrl/api/deliveries',
    ).replace(queryParameters: {'orderId': '$orderId'});
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch delivery',
      );
    }
    final items = body['items'];
    if (items is List && items.isNotEmpty) {
      return DeliveryInfo.fromJson(items.first.cast<String, dynamic>());
    }
    return null;
  }

  Future<DeliveryInfo> createDelivery({
    required int orderId,
    String? driverName,
    String? driverPhone,
  }) async {
    final uri = Uri.parse('$baseUrl/api/deliveries');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orderId': orderId,
        'driverName': driverName,
        'driverPhone': driverPhone,
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to create delivery',
      );
    }
    return DeliveryInfo.fromJson(body);
  }

  Future<void> updateDelivery({
    required int id,
    String? status,
    String? driverName,
    String? driverPhone,
    String? pickupTime,
    String? deliveryTime,
    double? currentLatitude,
    double? currentLongitude,
  }) async {
    final uri = Uri.parse('$baseUrl/api/deliveries/$id');
    final data = <String, dynamic>{
      if (status != null) 'status': status,
      if (driverName != null) 'driverName': driverName,
      if (driverPhone != null) 'driverPhone': driverPhone,
      if (pickupTime != null) 'pickupTime': pickupTime,
      if (deliveryTime != null) 'deliveryTime': deliveryTime,
      if (currentLatitude != null) 'currentLatitude': currentLatitude,
      if (currentLongitude != null) 'currentLongitude': currentLongitude,
    };
    final resp = await _http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to update delivery',
      );
    }
  }

  Future<bool> deleteDelivery({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/deliveries/$id');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to delete delivery',
      );
    }
    return body['deleted'] == true;
  }

  Future<List<Store>> listStores({int? ownerUserId}) async {
    final uri = Uri.parse('$baseUrl/api/stores').replace(
      queryParameters: {if (ownerUserId != null) 'ownerUserId': '$ownerUserId'},
    );
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to list stores');
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Store.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<Store> getStore({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/stores/$id');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to fetch store');
    }
    return Store.fromJson(body);
  }

  Future<Store> createStore({
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int? ownerUserId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/stores');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (ownerUserId != null) 'ownerUserId': ownerUserId,
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to create store');
    }
    return Store.fromJson(body);
  }

  Future<Store> updateStore({
    required int id,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int? ownerUserId,
    bool patchOwnerUserId = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/stores/$id');
    final body = <String, dynamic>{
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (patchOwnerUserId) {
      body['ownerUserId'] = ownerUserId;
    }
    final resp = await _http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final _ = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to update store');
    }
    return Store.fromJson(body);
  }

  Future<bool> deleteStore({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/stores/$id');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to delete store');
    }
    return body['deleted'] == true;
  }

  Future<String> uploadStoreImage({
    required int storeId,
    required List<int> imageBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/api/stores/$storeId/image');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: fileName),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to upload image');
    }
    return body['imageUrl']?.toString() ?? '';
  }

  Future<List<Payment>> listPayments({
    int? orderId,
    String? method,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (orderId != null) 'orderId': '$orderId',
      if (method != null && method.trim().isNotEmpty) 'method': method.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };
    final uri = Uri.parse('$baseUrl/api/payments').replace(queryParameters: qp);
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to list payments',
      );
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Payment.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<Payment> getPayment({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/payments/$id');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch payment',
      );
    }
    return Payment.fromJson(body);
  }

  Future<int> createPayment({
    required int orderId,
    required String method,
    required double amount,
    required String currency,
    String status = 'CREATED',
    String? provider,
    String? providerOrderId,
    String? providerCaptureId,
    String? approvalUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/api/payments');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orderId': orderId,
        'method': method,
        'status': status,
        'provider': provider,
        'providerOrderId': providerOrderId,
        'providerCaptureId': providerCaptureId,
        'approvalUrl': approvalUrl,
        'amount': amount,
        'currency': currency,
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to create payment',
      );
    }
    return int.tryParse('${body['id']}') ?? 0;
  }

  Future<void> updatePayment({
    required int id,
    String? status,
    String? provider,
    String? providerOrderId,
    String? providerCaptureId,
    String? approvalUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/api/payments/$id');
    final data = <String, dynamic>{
      if (status != null) 'status': status,
      if (provider != null) 'provider': provider,
      if (providerOrderId != null) 'providerOrderId': providerOrderId,
      if (providerCaptureId != null) 'providerCaptureId': providerCaptureId,
      if (approvalUrl != null) 'approvalUrl': approvalUrl,
    };
    final resp = await _http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to update payment',
      );
    }
  }

  Future<bool> deletePayment({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/payments/$id');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to delete payment',
      );
    }
    return body['deleted'] == true;
  }

  // Cart Management Methods
  Future<ShoppingCart?> getActiveCart({required int userId}) async {
    final uri = Uri.parse('$baseUrl/api/carts/user/$userId');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to fetch cart');
    }
    if (body.isEmpty) return null;
    return ShoppingCart.fromJson(body);
  }

  Future<ShoppingCart> createCart({required int userId, int? storeId}) async {
    final uri = Uri.parse('$baseUrl/api/carts');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'storeId': storeId}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to create cart');
    }
    return ShoppingCart.fromJson(body);
  }

  Future<List<DatabaseCartItem>> addToCart({
    required int cartId,
    required int productId,
    required String name,
    required int qty,
    required double unitPrice,
    String? lineNote,
  }) async {
    final uri = Uri.parse('$baseUrl/api/carts/$cartId/items');
    final resp = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'productId': productId,
        'name': name,
        'qty': qty,
        'unitPrice': unitPrice,
        if (lineNote != null && lineNote.trim().isNotEmpty)
          'lineNote': lineNote,
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to add to cart');
    }
    final items = body['items'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((e) => DatabaseCartItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<DatabaseCartItem>> updateCartItem({
    required int cartId,
    required int itemId,
    required int qty,
  }) async {
    final uri = Uri.parse('$baseUrl/api/carts/$cartId/items/$itemId');
    final resp = await _http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'qty': qty}),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to update cart item',
      );
    }
    final items = body['items'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((e) => DatabaseCartItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<DatabaseCartItem>> removeFromCart({
    required int cartId,
    required int itemId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/carts/$cartId/items/$itemId');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to remove from cart',
      );
    }
    final items = body['items'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((e) => DatabaseCartItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> clearCart({required int cartId}) async {
    final uri = Uri.parse('$baseUrl/api/carts/$cartId');
    final resp = await _http.delete(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to clear cart');
    }
  }

  Future<void> checkoutCart({required int cartId}) async {
    final uri = Uri.parse('$baseUrl/api/carts/$cartId/checkout');
    final resp = await _http.post(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to checkout cart',
      );
    }
  }

  // Driver Management Methods
  /// List all drivers with optional filtering
  Future<List<DriverProfile>> listDrivers({
    String? status,
    bool? verified,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (verified != null) 'verified': verified ? '1' : '0',
    };
    final uri = Uri.parse('$baseUrl/api/drivers').replace(queryParameters: qp);
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(body['error']?.toString() ?? 'Failed to list drivers');
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => DriverProfile.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// Get a specific driver profile
  Future<DriverProfile> getDriver({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/drivers/$id');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch driver profile',
      );
    }
    return DriverProfile.fromJson(body);
  }

  /// Create a new driver profile
  Future<DriverProfile> createDriver({
    required int userId,
    required String name,
    String? phone,
    String? email,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
  }) async {
    final uri = Uri.parse('$baseUrl/api/drivers');
    final resp = await _http.post(
      uri,
      headers: _jsonHeadersWithSession(),
      body: jsonEncode({
        'userId': userId,
        'name': name,
        'phone': phone,
        'email': email,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
        'licenseNumber': licenseNumber,
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to create driver profile',
      );
    }
    return DriverProfile.fromJson(body);
  }

  /// Update driver profile
  Future<DriverProfile> updateDriver({
    required int id,
    String? name,
    String? phone,
    String? email,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    String? status,
    bool? verified,
  }) async {
    final uri = Uri.parse('$baseUrl/api/drivers/$id');
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (status != null) 'status': status,
      if (verified != null) 'verified': verified,
    };
    final resp = await _http.put(
      uri,
      headers: _jsonHeadersWithSession(),
      body: jsonEncode(data),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to update driver profile',
      );
    }
    return DriverProfile.fromJson(body);
  }

  /// Delete driver profile
  Future<bool> deleteDriver({required int id}) async {
    final uri = Uri.parse('$baseUrl/api/drivers/$id');
    final resp = await _http.delete(uri, headers: _jsonHeadersWithSession());
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to delete driver profile',
      );
    }
    return body['deleted'] == true;
  }

  // Driver Rating and Feedback Methods
  /// List driver ratings with optional filtering
  Future<List<DriverRating>> listDriverRatings({
    int? driverId,
    int? orderId,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (driverId != null) 'driverId': '$driverId',
      if (orderId != null) 'orderId': '$orderId',
    };
    final uri = Uri.parse(
      '$baseUrl/api/driver-ratings',
    ).replace(queryParameters: qp);
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to list driver ratings',
      );
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => DriverRating.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// Submit a rating/feedback for a driver
  Future<DriverRating> createDriverRating({
    required int driverId,
    required int orderId,
    required int rating,
    String? feedback,
    String? category,
    int? customerId,
    bool isAnonymous = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/driver-ratings');
    final resp = await _http.post(
      uri,
      headers: _jsonHeadersWithSession(),
      body: jsonEncode({
        'driverId': driverId,
        'orderId': orderId,
        'customerId': customerId,
        'rating': rating,
        'feedback': feedback,
        'category': category,
        'isAnonymous': isAnonymous,
      }),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to submit driver rating',
      );
    }
    return DriverRating.fromJson(body);
  }

  /// Update an existing driver rating
  Future<DriverRating> updateDriverRating({
    required int id,
    int? rating,
    String? feedback,
    String? category,
  }) async {
    final uri = Uri.parse('$baseUrl/api/driver-ratings/$id');
    final data = <String, dynamic>{
      if (rating != null) 'rating': rating,
      if (feedback != null) 'feedback': feedback,
      if (category != null) 'category': category,
    };
    final resp = await _http.put(
      uri,
      headers: _jsonHeadersWithSession(),
      body: jsonEncode(data),
    );
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to update driver rating',
      );
    }
    return DriverRating.fromJson(body);
  }

  /// Get driver metrics and performance statistics
  Future<DriverMetrics> getDriverMetrics({required int driverId}) async {
    final uri = Uri.parse('$baseUrl/api/drivers/$driverId/metrics');
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch driver metrics',
      );
    }
    return DriverMetrics.fromJson(body);
  }

  /// Get overall driver performance leaderboard
  Future<List<DriverMetrics>> getDriverLeaderboard({
    int limit = 20,
    int offset = 0,
  }) async {
    final qp = <String, String>{'limit': '$limit', 'offset': '$offset'};
    final uri = Uri.parse(
      '$baseUrl/api/drivers/metrics/leaderboard',
    ).replace(queryParameters: qp);
    final resp = await _http.get(uri);
    final body = _decode(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        body['error']?.toString() ?? 'Failed to fetch driver leaderboard',
      );
    }
    final items = body['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => DriverMetrics.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
