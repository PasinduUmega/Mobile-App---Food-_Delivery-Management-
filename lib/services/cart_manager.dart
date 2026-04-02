import 'package:flutter/foundation.dart';

import '../models.dart';
import 'api.dart';

/// Manages persistent shopping cart with backend synchronization
class CartManager extends ChangeNotifier {
  final ApiClient _api;

  ShoppingCart? _currentCart;
  bool _isLoading = false;
  String? _error;

  CartManager({required ApiClient api}) : _api = api;

  // Getters
  ShoppingCart? get cart => _currentCart;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCart => _currentCart != null;
  int get itemCount => _currentCart?.getItemCount() ?? 0;
  double get subtotal => _currentCart?.getSubtotal() ?? 0.0;

  /// Initialize cart for user
  Future<void> initializeCart(int userId, {int? storeId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to get existing active cart
      _currentCart = await _api.getActiveCart(userId: userId);

      // If no active cart, create one
      if (_currentCart == null) {
        _currentCart = await _api.createCart(userId: userId, storeId: storeId);
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Cart init error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add item to cart
  Future<void> addItem({
    required int productId,
    required String name,
    required int qty,
    required double unitPrice,
  }) async {
    if (_currentCart == null) {
      _error = 'Cart not initialized';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _api.addToCart(
        cartId: _currentCart!.id,
        productId: productId,
        name: name,
        qty: qty,
        unitPrice: unitPrice,
      );

      // Update local cart with new items
      _currentCart = ShoppingCart(
        id: _currentCart!.id,
        userId: _currentCart!.userId,
        storeId: _currentCart!.storeId,
        status: _currentCart!.status,
        createdAt: _currentCart!.createdAt,
        updatedAt: DateTime.now(),
        checkedOutAt: _currentCart!.checkedOutAt,
        items: items,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Add to cart error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update cart item quantity (0 = remove)
  Future<void> updateItem(int itemId, int newQty) async {
    if (_currentCart == null) {
      _error = 'Cart not initialized';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _api.updateCartItem(
        cartId: _currentCart!.id,
        itemId: itemId,
        qty: newQty,
      );

      _currentCart = ShoppingCart(
        id: _currentCart!.id,
        userId: _currentCart!.userId,
        storeId: _currentCart!.storeId,
        status: _currentCart!.status,
        createdAt: _currentCart!.createdAt,
        updatedAt: DateTime.now(),
        checkedOutAt: _currentCart!.checkedOutAt,
        items: items,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Update cart item error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove item from cart
  Future<void> removeItem(int itemId) async {
    if (_currentCart == null) {
      _error = 'Cart not initialized';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _api.removeFromCart(
        cartId: _currentCart!.id,
        itemId: itemId,
      );

      _currentCart = ShoppingCart(
        id: _currentCart!.id,
        userId: _currentCart!.userId,
        storeId: _currentCart!.storeId,
        status: _currentCart!.status,
        createdAt: _currentCart!.createdAt,
        updatedAt: DateTime.now(),
        checkedOutAt: _currentCart!.checkedOutAt,
        items: items,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Remove from cart error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all items from cart
  Future<void> clearCart() async {
    if (_currentCart == null) {
      _error = 'Cart not initialized';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.clearCart(cartId: _currentCart!.id);

      _currentCart = ShoppingCart(
        id: _currentCart!.id,
        userId: _currentCart!.userId,
        storeId: _currentCart!.storeId,
        status: 'ABANDONED',
        createdAt: _currentCart!.createdAt,
        updatedAt: DateTime.now(),
        checkedOutAt: _currentCart!.checkedOutAt,
        items: const [],
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Clear cart error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Checkout cart after payment
  Future<void> checkoutCart() async {
    if (_currentCart == null) {
      _error = 'Cart not initialized';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.checkoutCart(cartId: _currentCart!.id);

      _currentCart = ShoppingCart(
        id: _currentCart!.id,
        userId: _currentCart!.userId,
        storeId: _currentCart!.storeId,
        status: 'CHECKED_OUT',
        createdAt: _currentCart!.createdAt,
        updatedAt: DateTime.now(),
        checkedOutAt: DateTime.now(),
        items: _currentCart!.items,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Checkout cart error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh cart from server
  Future<void> refreshCart() async {
    if (_currentCart == null) {
      _error = 'Cart not initialized';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedCart = await _api.getActiveCart(
        userId: _currentCart!.userId,
      );
      if (updatedCart != null) {
        _currentCart = updatedCart;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Refresh cart error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset cart (clear local state)
  void reset() {
    _currentCart = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
