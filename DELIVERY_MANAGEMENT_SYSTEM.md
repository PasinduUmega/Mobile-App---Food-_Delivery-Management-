# Delivery Management & Driver Rating System Documentation

## Overview

A comprehensive delivery management system for your food delivery app that includes:
- ✅ Full CRUD driver profile management
- ✅ Driver rating and feedback system (1-5 star ratings)
- ✅ Customer feedback collection
- ✅ Driver performance metrics and leaderboard
- ✅ Admin dashboard for delivery operations
- ✅ User management integration

---

## Architecture

### Data Models

#### 1. **DriverProfile** (`models.dart`)
Represents a delivery driver's complete profile.

```dart
class DriverProfile {
  final int id;
  final int userId;
  final String name;
  final String? phone;
  final String? email;
  final String? vehicleType;        // e.g., "Motorcycle", "Car"
  final String? vehicleNumber;
  final String? licenseNumber;
  final String status;              // ACTIVE, INACTIVE, ON_DELIVERY, PENDING_VERIFICATION
  final double? ratingsAverage;
  final int ratingsCount;
  final bool verified;              // Admin verification flag
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Status Values:**
- `ACTIVE` - Driver is available for deliveries
- `INACTIVE` - Driver temporarily unavailable
- `ON_DELIVERY` - Currently delivering an order
- `PENDING_VERIFICATION` - Awaiting admin verification

#### 2. **DriverRating** (`models.dart`)
Stores customer feedback for drivers.

```dart
class DriverRating {
  final int id;
  final int driverId;
  final int orderId;
  final int? customerId;
  final String? customerName;
  final int rating;                 // 1-5 stars
  final String? feedback;           // Optional text feedback
  final String? category;           // delivery_speed, politeness, etc.
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Rating Categories:**
- `delivery_speed` - How quickly the driver delivered
- `politeness` - Driver's professionalism and courtesy
- `vehicle_condition` - Cleanliness and condition of vehicle
- `accuracy` - Correct order and delivery location

#### 3. **DriverMetrics** (`models.dart`)
Performance statistics for drivers.

```dart
class DriverMetrics {
  final int driverId;
  final String driverName;
  final int totalDeliveries;
  final int completedDeliveries;
  final double averageRating;
  final int ratingCount;
  final double? averageDeliveryTime;  // in minutes
  final DateTime? lastDelivery;
  final List<int> ratingDistribution; // [1-star, 2-star, 3-star, 4-star, 5-star]
}
```

---

## API Endpoints

All endpoints are implemented in `ApiClient` class (`services/api.dart`):

### Driver Management

#### List all drivers
```dart
Future<List<DriverProfile>> listDrivers({
  String? status,           // Filter by status
  bool? verified,           // Show only verified
  int limit = 50,
  int offset = 0,
})
```

#### Get specific driver
```dart
Future<DriverProfile> getDriver({required int id})
```

#### Create driver
```dart
Future<DriverProfile> createDriver({
  required int userId,
  required String name,
  String? phone,
  String? email,
  String? vehicleType,
  String? vehicleNumber,
  String? licenseNumber,
})
```

#### Update driver
```dart
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
})
```

#### Delete driver
```dart
Future<bool> deleteDriver({required int id})
```

### Rating & Feedback

#### List driver ratings
```dart
Future<List<DriverRating>> listDriverRatings({
  int? driverId,            // Filter by driver
  int? orderId,
  int limit = 50,
  int offset = 0,
})
```

#### Submit rating
```dart
Future<DriverRating> createDriverRating({
  required int driverId,
  required int orderId,
  required int rating,      // 1-5
  String? feedback,
  String? category,
  int? customerId,
  bool isAnonymous = false,
})
```

#### Update rating
```dart
Future<DriverRating> updateDriverRating({
  required int id,
  int? rating,
  String? feedback,
  String? category,
})
```

### Performance Metrics

#### Get driver metrics
```dart
Future<DriverMetrics> getDriverMetrics({required int driverId})
```

#### Get leaderboard
```dart
Future<List<DriverMetrics>> getDriverLeaderboard({
  int limit = 20,
  int offset = 0,
})
```

---

## UI Screens

### 1. Driver Management Dashboard
**File:** `ui/driver_management_dashboard.dart`

Admin interface for managing driver profiles with full CRUD operations.

**Features:**
- ✅ Add new drivers
- ✅ Edit existing driver profiles
- ✅ Delete drivers
- ✅ Search drivers by name, phone, email
- ✅ Filter by status (ACTIVE, INACTIVE, ON_DELIVERY, PENDING_VERIFICATION)
- ✅ Filter by verification status
- ✅ View driver performance metrics

**Usage:**
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const DriverManagementDashboard(),
));
```

### 2. Driver Rating Dashboard
**File:** `ui/driver_ratings_dashboard.dart`

View and analyze driver ratings and performance leaderboard.

**Features:**
- ✅ View all driver ratings and feedback
- ✅ Performance leaderboard with rankings
- ✅ Average ratings and review counts
- ✅ Delivery statistics
- ✅ Top performers ranking

**Two Views:**
1. **Ratings Tab** - Individual customer reviews
2. **Leaderboard Tab** - Performance rankings

**Usage:**
```dart
// All ratings
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const DriverRatingDashboard(),
));

// Ratings for specific driver
Navigator.push(context, MaterialPageRoute(
  builder: (_) => DriverRatingDashboard(driverId: 123),
));
```

### 3. Driver Feedback Screen
**File:** `ui/driver_feedback_screen.dart`

Customer-facing screens for rating drivers after delivery.

**Two Components:**

#### a) Full Screen Version
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => DriverFeedbackScreen(
    delivery: deliveryInfo,
    customerId: userId,
  ),
));
```

#### b) Dialog Version
```dart
showDialog(
  context: context,
  builder: (_) => DriverFeedbackDialog(
    delivery: deliveryInfo,
    customerId: userId,
    onSuccess: () {
      // Handle successful rating
    },
  ),
);
```

**Features:**
- ✅ 5-star rating interface
- ✅ Category selection (Speed, Politeness, Vehicle, Accuracy)
- ✅ Optional feedback text
- ✅ Anonymous submission option
- ✅ Driver info display

### 4. Admin Delivery Hub
**File:** `ui/admin_delivery_hub_screen.dart`

Comprehensive admin dashboard combining all delivery management features.

**Features:**
- ✅ Dashboard statistics (Total drivers, Active drivers, Average rating, Total reviews)
- ✅ Tab-based navigation:
  - **Drivers Tab** - Driver management interface
  - **Ratings Tab** - Ratings and leaderboard
  - **Deliveries Tab** - Active deliveries (expandable)
- ✅ Quick-view recent ratings
- ✅ Top verified drivers display
- ✅ Refresh statistics button

**Usage:**
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const AdminDeliveryHubScreen(),
));
```

---

## Integration Guide

### Step 1: Update Your App Shell / Navigation

Add the new screens to your app navigation:

```dart
// In your app_shell.dart or main navigation file
import 'ui/admin_delivery_hub_screen.dart';
import 'ui/driver_management_dashboard.dart';
import 'ui/driver_ratings_dashboard.dart';
import 'ui/driver_feedback_screen.dart';

// Add to admin role navigation
if (userRole == UserRole.admin) {
  ListTile(
    leading: const Icon(Icons.local_shipping),
    title: const Text('Delivery Management'),
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const AdminDeliveryHubScreen(),
    )),
  ),
}

// Add to driver role navigation
if (userRole == UserRole.deliveryDriver) {
  ListTile(
    leading: const Icon(Icons.person),
    title: const Text('My Profile'),
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const DriverManagementDashboard(),
    )),
  ),
}
```

### Step 2: Integrate Customer Feedback

After order completion, show feedback dialog:

```dart
// In your order completion screen
if (delivery != null) {
  final rated = await showDialog<bool>(
    context: context,
    builder: (_) => DriverFeedbackDialog(
      delivery: delivery,
      customerId: userId,
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      },
    ),
  );
}
```

### Step 3: Backend Integration

You'll need to create these backend endpoints:

```
GET  /api/drivers                 - List drivers
GET  /api/drivers/:id             - Get driver
POST /api/drivers                 - Create driver
PUT  /api/drivers/:id             - Update driver
DELETE /api/drivers/:id           - Delete driver

GET  /api/driver-ratings          - List ratings
POST /api/driver-ratings          - Create rating
PUT  /api/driver-ratings/:id      - Update rating

GET  /api/drivers/:id/metrics     - Get driver metrics
GET  /api/drivers/metrics/leaderboard - Leaderboard
```

### Step 4: Update User Management

The user management dashboard works alongside driver profiles:

```dart
// Create user as delivery driver
await api.createUser(
  name: 'John Doe',
  email: 'john@example.com',
  mobile: '+1234567890',
  role: UserRole.deliveryDriver,
);

// Then create driver profile
await api.createDriver(
  userId: userId,
  name: 'John Doe',
  phone: '+1234567890',
  vehicleType: 'Motorcycle',
  vehicleNumber: 'ABC-123',
  licenseNumber: 'DL-2024-12345',
);
```

---

## Usage Examples

### Admin: Create and Verify a Driver

```dart
// 1. Create user account
final user = await api.createUser(
  name: 'Alice Driver',
  email: 'alice@drivers.com',
  mobile: '555-1234',
  role: UserRole.deliveryDriver,
);

// 2. Create driver profile
final driver = await api.createDriver(
  userId: user.id,
  name: 'Alice Driver',
  phone: '555-1234',
  email: 'alice@drivers.com',
  vehicleType: 'Motorcycle',
  vehicleNumber: 'DV-001',
  licenseNumber: 'LIC-2024-001',
);

// 3. Verify driver after document check
await api.updateDriver(
  id: driver.id,
  verified: true,
  status: 'ACTIVE',
);
```

### Customer: Rate Driver After Delivery

```dart
// Show feedback dialog after delivery
final rated = await showDialog<bool>(
  context: context,
  builder: (_) => DriverFeedbackDialog(
    delivery: deliveryInfo,  // DeliveryInfo from API
    customerId: currentUserId,
    onSuccess: () {
      print('Rating submitted successfully!');
    },
  ),
);

// Or navigate to full feedback screen
Navigator.push(context, MaterialPageRoute(
  builder: (_) => DriverFeedbackScreen(
    delivery: deliveryInfo,
    customerId: currentUserId,
  ),
));
```

### Admin: View Driver Performance

```dart
// Get driver metrics
final metrics = await api.getDriverMetrics(driverId: 123);
print('Avg Rating: ${metrics.averageRating}');
print('Deliveries: ${metrics.completedDeliveries}/${metrics.totalDeliveries}');
print('Avg Time: ${metrics.averageDeliveryTime} minutes');

// Get leaderboard
final leaderboard = await api.getDriverLeaderboard(limit: 10);
for (var i = 0; i < leaderboard.length; i++) {
  print('#${i + 1}: ${leaderboard[i].driverName} - ${leaderboard[i].averageRating}★');
}
```

### Admin: Filter and Search Drivers

```dart
// Get only active, verified drivers
final activeDrivers = await api.listDrivers(
  verified: true,
  status: 'ACTIVE',
);

// Get all pending verification drivers
final pending = await api.listDrivers(
  status: 'PENDING_VERIFICATION',
);

// Get paged results for large datasets
final page1 = await api.listDrivers(limit: 20, offset: 0);
final page2 = await api.listDrivers(limit: 20, offset: 20);
```

---

## Database Schema (Reference)

### drivers table
```sql
CREATE TABLE drivers (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(255),
  vehicle_type VARCHAR(100),
  vehicle_number VARCHAR(50),
  license_number VARCHAR(50),
  status VARCHAR(50) DEFAULT 'PENDING_VERIFICATION',
  verified BOOLEAN DEFAULT FALSE,
  verified_at TIMESTAMP,
  ratings_average DECIMAL(3,2),
  ratings_count INTEGER DEFAULT 0,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE driver_ratings (
  id INTEGER PRIMARY KEY,
  driver_id INTEGER NOT NULL,
  order_id INTEGER NOT NULL,
  customer_id INTEGER,
  customer_name VARCHAR(255),
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  feedback TEXT,
  category VARCHAR(100),
  is_anonymous BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  FOREIGN KEY (driver_id) REFERENCES drivers(id),
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (customer_id) REFERENCES users(id)
);
```

---

## Security & Permissions

### Role-Based Access

```dart
// Admin: Full access to all features
if (ApiClient.sessionUserId != null && userRole == UserRole.admin) {
  // Can view all drivers, manage all drivers
  // Can view all ratings
  // Can verify/unverify drivers
}

// Delivery Driver: Limited access
if (userRole == UserRole.deliveryDriver) {
  // Can view only their own profile
  // Can see their ratings
  // Cannot modify other drivers
}

// Customer: Feedback only
if (userRole == UserRole.customer) {
  // Can submit ratings for drivers they've used
  // Can view ratings of drivers
  // Cannot access driver management
}
```

### API Headers
The API automatically includes admin session:
```dart
// In api.dart
Map<String, String> _jsonHeadersWithSession() {
  final h = <String, String>{'Content-Type': 'application/json'};
  final id = ApiClient.sessionUserId;
  if (id != null) h['X-User-Id'] = id.toString();
  return h;
}
```

---

## Performance Considerations

### Caching Recommendations
```dart
// For dashboards, implement pagination
List<DriverProfile> drivers = await api.listDrivers(
  limit: 20,   // Only load 20 at a time
  offset: 0,
);

// For leaderboard, use limits
List<DriverMetrics> top10 = await api.getDriverLeaderboard(limit: 10);
```

### Optimization Tips
1. Use `listDrivers()` with pagination for large datasets
2. Load driver metrics only when needed (on-demand)
3. Cache leaderboard data and refresh periodically
4. Use SearchDelegate for efficient filtering
5. Implement infinite scroll for ratings list

---

## Troubleshooting

### Issue: Drivers not showing in list
**Solution:** Ensure driver has been verified by admin
```dart
// Check if verified
final driver = await api.getDriver(id: driverId);
if (!driver.verified) {
  await api.updateDriver(id: driverId, verified: true);
}
```

### Issue: Ratings not submitted
**Solution:** Ensure customerId is set correctly
```dart
// Verify customer is logged in
if (ApiClient.sessionUserId == null) {
  // Show login prompt
  return;
}

// Submit with current user
await api.createDriverRating(
  driverId: deliveryInfo.id,
  orderId: deliveryInfo.orderId,
  customerId: ApiClient.sessionUserId,  // Use session user
  rating: 5,
);
```

### Issue: Metrics showing zero
**Solution:** Ensure deliveries and ratings have been created
```dart
// Query should return completed deliveries and ratings
final metrics = await api.getDriverMetrics(driverId: driverId);
// If zero, check that orders/deliveries exist in backend
```

---

## Future Enhancements

1. **Real-time Location Tracking** - Live GPS tracking during delivery
2. **Driver Scheduling** - Timeline for driver availability
3. **Performance Bonuses** - Automated incentives for top performers
4. **Customer Complaint Handling** - Escalation workflow
5. **Driver Analytics** - Dashboard with charts and trends
6. **Push Notifications** - Driver assignment alerts
7. **Integration with Payment** - Commission calculations

---

## Files Changed/Created

### Modified
- `lib/models.dart` - Added DriverProfile, DriverRating, DriverMetrics
- `lib/services/api.dart` - Added all driver management endpoints
- `lib/ui/driver_management_dashboard.dart` - Enhanced with full CRUD

### Created
- `lib/ui/driver_management_dashboard.dart` - Driver CRUD management
- `lib/ui/driver_ratings_dashboard.dart` - Ratings and leaderboard
- `lib/ui/driver_feedback_screen.dart` - Customer feedback forms
- `lib/ui/admin_delivery_hub_screen.dart` - Admin hub dashboard
- `DELIVERY_MANAGEMENT_SYSTEM.md` - This documentation

---

## Support & Questions

For implementation questions or issues:
1. Check the example usage above
2. Review the inline code comments
3. Verify API endpoints are implemented in your backend
4. Check user roles and permissions
5. Ensure database schema matches the reference

---

**Last Updated:** April 22, 2026  
**Version:** 1.0
