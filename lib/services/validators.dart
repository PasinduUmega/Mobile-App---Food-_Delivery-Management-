import '../models.dart';

/// Centralized validation utilities for all input forms
class Validators {
  /// Validate required string field
  static String? requireString(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate string length
  static String? validateLength(
    String? value,
    String fieldName,
    int minLength, {
    int? maxLength,
  }) {
    if (value == null || value.isEmpty) return null;
    final length = value.trim().length;
    if (length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (maxLength != null && length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate mobile number (10 digits)
  static String? validateMobileNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return 'Mobile number must contain at least one digit';
    }
    if (digitsOnly.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }
    return null;
  }

  /// Validate phone number (10 digits)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return 'Phone number must contain at least one digit';
    }
    if (digitsOnly.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    return null;
  }

  /// Validate latitude (-90 to 90)
  static String? validateLatitude(String? value) {
    if (value == null || value.isEmpty) return null;
    final lat = double.tryParse(value);
    if (lat == null) {
      return 'Latitude must be a valid number';
    }
    if (lat < -90 || lat > 90) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  /// Validate longitude (-180 to 180)
  static String? validateLongitude(String? value) {
    if (value == null || value.isEmpty) return null;
    final lng = double.tryParse(value);
    if (lng == null) {
      return 'Longitude must be a valid number';
    }
    if (lng < -180 || lng > 180) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  /// Validate positive number
  static String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final num = double.tryParse(value);
    if (num == null) {
      return '$fieldName must be a valid number';
    }
    if (num <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }

  /// Validate non-negative integer
  static String? validateNonNegativeInt(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final num = int.tryParse(value);
    if (num == null) {
      return '$fieldName must be a valid integer';
    }
    if (num < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  /// Validate positive integer
  static String? validatePositiveInt(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final num = int.tryParse(value);
    if (num == null) {
      return '$fieldName must be a valid integer';
    }
    if (num <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }

  /// Validate currency code (3 uppercase letters)
  static String? validateCurrencyCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Currency code is required';
    }
    final code = value.trim().toUpperCase();
    if (code.length != 3) {
      return 'Currency must be 3 letters';
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
      return 'Currency must contain only letters';
    }
    return null;
  }

  /// Validate URL format
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      Uri.parse(value);
      if (!value.startsWith('http://') && !value.startsWith('https://')) {
        return 'URL must start with http:// or https://';
      }
      return null;
    } catch (_) {
      return 'Please enter a valid URL';
    }
  }

  /// Validate name (alphanumeric and spaces, 2-50 chars)
  static String? validateName(String? value) {
    final error = requireString(value, 'Name');
    if (error != null) return error;

    final name = value!.trim();
    if (name.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (name.length > 50) {
      return 'Name must not exceed 50 characters';
    }
    if (!RegExp(
      r"^[a-zA-Z0-9\s\-&']+(?: [a-zA-Z0-9\s\-&']+)*$",
    ).hasMatch(name)) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  /// Validate address
  static String? validateAddress(String? value) {
    if (value == null || value.isEmpty) return null;

    final address = value.trim();
    if (address.length < 5) {
      return 'Address must be at least 5 characters';
    }
    if (address.length > 200) {
      return 'Address must not exceed 200 characters';
    }
    return null;
  }

  /// Validate price/amount
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }
    final price = double.tryParse(value);
    if (price == null) {
      return 'Price must be a valid number';
    }
    if (price <= 0) {
      return 'Price must be greater than 0';
    }
    if (price > 999999.99) {
      return 'Price is too high';
    }
    return null;
  }

  /// Validate card number (Luhn algorithm)
  static String? validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Card number is required';
    }
    final number = value.replaceAll(RegExp(r'\D'), '');
    if (number.length < 13 || number.length > 19) {
      return 'Card number must be 13-19 digits';
    }

    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    if (sum % 10 != 0) {
      return 'Invalid card number';
    }
    return null;
  }

  /// Validate card expiry (MM/YY)
  static String? validateCardExpiry(String? value) {
    if (value == null || value.isEmpty) {
      return 'Expiry date is required';
    }
    final regex = RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$');
    if (!regex.hasMatch(value)) {
      return 'Expiry must be MM/YY';
    }

    final now = DateTime.now();
    final parts = value.split('/');
    final month = int.parse(parts[0]);
    final year = int.parse('20${parts[1]}');

    if (year < now.year || (year == now.year && month < now.month)) {
      return 'Card has expired';
    }
    return null;
  }

  /// Validate card CVV (3-4 digits)
  static String? validateCardCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'CVV is required';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 3 || digitsOnly.length > 4) {
      return 'CVV must be 3 or 4 digits';
    }
    return null;
  }

  /// Strict integer validation
  static String? validateInteger(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (int.tryParse(value) == null) {
      return '$fieldName must be a valid whole number';
    }
    return null;
  }

  static const int maxCartLineQty = 50;

  /// Quantity rules before add/update cart (matches server `MAX_CART_LINE_QTY`).
  static String? validateCartLineQty(int qty, {int? maxStock}) {
    if (qty <= 0) return 'Quantity must be at least 1';
    if (qty > maxCartLineQty) {
      return 'Maximum $maxCartLineQty per item in the cart';
    }
    if (maxStock != null && qty > maxStock) {
      return 'Only $maxStock available in stock';
    }
    return null;
  }

  /// Validates in-cart lines and computed subtotal (no negative qty/price/subtotal).
  static String? validateCartSubtotal(List<CartItem> items) {
    if (items.isEmpty) return null;
    double subtotal = 0;
    for (final c in items) {
      final qErr = validateCartLineQty(c.qty);
      if (qErr != null) return '${c.name}: $qErr';
      if (c.qty < 0) {
        return 'Quantity cannot be negative for "${c.name}".';
      }
      if (c.unitPrice < 0) {
        return 'Unit price cannot be negative for "${c.name}".';
      }
      if (c.qty > 0 && c.unitPrice <= 0) {
        return 'Each item in the cart needs a price greater than zero.';
      }
      subtotal += c.qty * c.unitPrice;
    }
    if (subtotal < 0) {
      return 'Cart subtotal cannot be negative. Remove or adjust items with invalid prices.';
    }
    return null;
  }
}
