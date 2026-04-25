# Role-Based Access Control (RBAC) System Documentation

## Overview
Complete permission matrix for food delivery app with 4 user roles and 7 main components.

---

## 📋 Permission Matrix

### Legend
- ✅ **Create** - Can create new items
- ✏️ **Read/View** - Can view/read items  
- 🔄 **Update** - Can edit items
- ❌ **Delete** - Can delete items
- 🔒 **View Only** - Can only view, no other operations

---

## 1. CUSTOMER DASHBOARD

| Component | Create | Read | Update | Delete | Notes |
|-----------|--------|------|--------|--------|-------|
| **Orders & Carts** | ✅ | ✅ | ✅ | ✅ | Full CRUD - manage own orders |
| **Payment & Integrations** | ✅ | ✅ | ❌ | ❌ | Create payment, view only (no edit/delete) |
| **Restaurants** | ❌ | ✅ | ❌ | ❌ | View only |
| **Menu Items** | ❌ | ✅ | ❌ | ❌ | View only |
| **Inventory** | ❌ | ✅ | ❌ | ❌ | View only (for availability) |
| **Delivery Tracking** | ❌ | ✅ | ❌ | ❌ | View only - track order delivery |
| **User Profile** | ❌ | ✅ | ✅ | ❌ | Edit own profile only |
| **Ratings & Feedback** | ✅ | ✅ | ✅ | ❌ | Rate restaurants/drivers only |

**Key Permissions:**
```dart
canManageOwnOrders: true,
canCreatePayments: true,
canViewRestaurants: true,
canRateRestaurants: true,
canRateDrivers: true,
```

---

## 2. RESTAURANT OWNER DASHBOARD

| Component | Create | Read | Update | Delete | Notes |
|-----------|--------|------|--------|--------|-------|
| **Restaurant Info** | ✅ | ✅ | ✅ | ❌ | Create/Edit own restaurant |
| **Menu Items** | ✅ | ✅ | ✅ | ✅ | Full CRUD for menu |
| **Inventory** | ✅ | ✅ | ✅ | ✅ | Full CRUD for inventory |
| **Orders & Carts** | ❌ | ✅ | ✅ | ❌ | View & process orders only |
| **Payment** | ❌ | ✅ | ❌ | ❌ | View payments only |
| **Delivery Management** | ❌ | ✅ | ❌ | ❌ | View delivery only |
| **User Management** | ❌ | ✅ | ❌ | ❌ | View customers only |
| **Ratings & Feedback** | ❌ | ✅ | ❌ | ❌ | View ratings only |

**Key Permissions:**
```dart
canManageRestaurant: true,
canManageMenu: true,
canManageInventory: true,
canViewOrders: true,
canProcessOrders: true,
canViewPayments: true,
```

---

## 3. DELIVERY DRIVER DASHBOARD

| Component | Create | Read | Update | Delete | Notes |
|-----------|--------|------|--------|--------|-------|
| **Delivery Management** | ✅ | ✅ | ✅ | ❌ | Accept/Update/Complete deliveries |
| **Assigned Orders & Carts** | ❌ | ✅ | ❌ | ❌ | View assigned order details only |
| **Real-Time Location** | ✅ | ✅ | ✅ | ❌ | Update location during delivery |
| **Restaurants** | ❌ | ✅ | ❌ | ❌ | View only - pickup location |
| **Menu Items** | ❌ | ✅ | ❌ | ❌ | View only - order details |
| **Inventory** | ❌ | ✅ | ❌ | ❌ | View only |
| **Payment** | ❌ | ✅ | ❌ | ❌ | View only - payment method |
| **Ratings & Feedback** | ❌ | ✅ | ✅ | ❌ | View & respond to ratings only |

**Key Permissions:**
```dart
canManageDeliveries: true,
canUpdateLocation: true,
canCompleteDelivery: true,
canViewAssignedOrders: true,
canViewRatings: true,
cannotDeleteAnything: true,
```

---

## 4. ADMIN DASHBOARD

| Component | Create | Read | Update | Delete | Notes |
|-----------|--------|------|--------|--------|-------|
| **User Management** | ✅ | ✅ | ✅ | ✅ | Full CRUD - all users |
| **Delivery Management** | ✅ | ✅ | ✅ | ✅ | Assign/manage all deliveries |
| **Orders & Carts** | ❌ | ✅ | ✅ | ✅ | Manage all orders (override) |
| **Restaurants** | ✅ | ✅ | ✅ | ✅ | Full CRUD - manage restaurants |
| **Menu Items** | ✅ | ✅ | ✅ | ✅ | Full CRUD - manage all menus |
| **Inventory** | ❌ | ✅ | ✅ | ❌ | Modify but not delete |
| **Payment** | ❌ | ✅ | ✅ | ❌ | View & manage transactions |
| **Ratings & Feedback** | ❌ | ✅ | ✅ | ✅ | Manage all ratings/feedback |

**Key Permissions:**
```dart
canManageAllUsers: true,
canManageAllDeliveries: true,
canManageAllOrders: true,
canManageRestaurants: true,
canManageMenus: true,
canManageRatings: true,
fullAccess: true,
```

---

## Component Access by Role

### Orders & Carts Component
```
Customer:   ✅ Full CRUD (own only)
Restaurant: ✅ Read, Update (process orders)
Driver:     ✅ Read (assigned orders)
Admin:      ✅ Full CRUD (all orders)
```

### Payment & Integrations Component
```
Customer:   ✅ Create, Read (no edit/delete)
Restaurant: ✅ Read (payments received)
Driver:     ✅ Read (payment method to receive)
Admin:      ✅ Full CRUD + Management
```

### Restaurants Component
```
Customer:   ✅ Read (view only)
Restaurant: ✅ Full CRUD (own restaurant)
Driver:     ✅ Read (pickup location)
Admin:      ✅ Full CRUD (all restaurants)
```

### Menu & Inventory Component
```
Customer:   ✅ Read (view menu/availability)
Restaurant: ✅ Full CRUD (own menu & inventory)
Driver:     ✅ Read (order item details)
Admin:      ✅ Full CRUD (all menus/inventory)
```

### Delivery Management Component
```
Customer:   ✅ Read (track delivery)
Restaurant: ✅ Read (delivery status)
Driver:     ✅ Full CRUD (manage own deliveries)
Admin:      ✅ Full CRUD (manage all deliveries)
```

### User Management Component
```
Customer:   ✅ Read Own (profile only)
Restaurant: ✅ Read Own (profile only)
Driver:     ✅ Read Own (profile only)
Admin:      ✅ Full CRUD (all users)
```

### Ratings & Feedback Component
```
Customer:   ✅ Create/Read/Update (restaurants & drivers)
Restaurant: ✅ Read (customer ratings)
Driver:     ✅ Read/Update (view & respond to ratings)
Admin:      ✅ Full CRUD (manage all ratings)
```

---

## Permission Implementation

### Base Permission Interface
```dart
abstract class Permission {
  bool get canCreate;
  bool get canRead;
  bool get canUpdate;
  bool get canDelete;
  
  bool get hasFullAccess => canCreate && canRead && canUpdate && canDelete;
  bool get isViewOnly => !canCreate && canRead && !canUpdate && !canDelete;
}
```

### Role-Based Permissions
```dart
class CustomerPermissions implements Permission {
  @override
  bool get canCreate => true;   // Orders, Payments, Ratings
  @override
  bool get canRead => true;
  @override
  bool get canUpdate => true;   // Orders, Ratings
  @override
  bool get canDelete => false;  // Cannot delete (system keeps history)
}

class RestaurantPermissions implements Permission {
  @override
  bool get canCreate => true;   // Menu, Inventory
  @override
  bool get canRead => true;
  @override
  bool get canUpdate => true;   // Menu, Inventory, Orders
  @override
  bool get canDelete => true;   // Menu, Inventory (but not orders)
}

class DriverPermissions implements Permission {
  @override
  bool get canCreate => true;   // Deliveries, Location updates
  @override
  bool get canRead => true;
  @override
  bool get canUpdate => true;   // Deliveries, Location
  @override
  bool get canDelete => false;  // Cannot delete anything
}

class AdminPermissions implements Permission {
  @override
  bool get canCreate => true;   // Everything
  @override
  bool get canRead => true;
  @override
  bool get canUpdate => true;
  @override
  bool get canDelete => true;
}
```

---

## Component-Specific Rules

### Orders & Carts
```
Customer:
  - Create own orders/carts
  - Read own orders/carts
  - Update own orders (before payment)
  - Delete own carts (not orders after creation)
  
Restaurant:
  - Read orders for their restaurant only
  - Update order status (pending → confirmed → preparing → ready)
  - Cannot create/delete orders
  
Driver:
  - Read only assigned orders
  - Cannot modify order details
  - Can mark delivery as completed
  
Admin:
  - Full access to all orders
  - Can override/cancel orders if needed
```

### Payment
```
Customer:
  - Create new payment
  - View own payment history
  - Cannot modify/delete payments
  
Restaurant:
  - View payments received
  - View settlement records
  - Cannot create/modify/delete
  
Driver:
  - View payment details (delivery fee, tips, etc)
  - Cannot modify
  
Admin:
  - Full access
  - Can adjust payments if needed
  - Can view all transactions
```

### Delivery
```
Customer:
  - View delivery status
  - Cannot modify delivery
  
Restaurant:
  - View delivery status for orders
  - Cannot modify
  
Driver:
  - Accept delivery assignments
  - Update delivery status (in_transit, delivered, etc)
  - Update location in real-time
  - Mark as completed
  
Admin:
  - Assign/reassign deliveries
  - Override delivery status if needed
  - Full management
```

### User Management
```
Customer:
  - Read own profile
  - Update own profile
  - Cannot view other users
  - Can add ratings/feedback about restaurants/drivers
  
Restaurant:
  - Read own profile
  - Update own profile
  - Cannot view other users
  
Driver:
  - Read own profile
  - Update own profile
  - Cannot view other users
  
Admin:
  - Full CRUD on all users
  - Can create new accounts
  - Can deactivate/delete accounts
  - Can manage user roles and permissions
  - Can view all user profiles
  - Can manage ratings and feedback for all users
```

---

## Enforcement Implementation

### API-Level Enforcement
```
Every API endpoint should check:
1. User is authenticated
2. User has required permission
3. User is accessing their own data (or is admin)
```

### Frontend-Level Enforcement
```
Every screen should:
1. Check user role
2. Show/hide CRUD buttons based on permissions
3. Disable operations not allowed for user role
4. Show appropriate messages for denied actions
```

### Database-Level Enforcement
```
Backend should:
1. Validate all permissions server-side
2. Never trust frontend permission checks
3. Return 403 Forbidden for unauthorized operations
4. Log all permission attempts (especially failures)
```

---

## Special Cases

### Ratings & Feedback
- **Customers** can rate: Restaurants, Menu items, Delivery service, Drivers
- **Drivers** can receive ratings but cannot rate others
- **Restaurants** can receive ratings but cannot rate others
- **Admin** can manage all ratings, remove inappropriate feedback

### Delivery Location
- **Drivers** can update their location in real-time
- **Admins** can view driver location for management
- **Customers** can view delivery location if delivery in progress
- **Restaurants** cannot see driver location

### Order Status
- **Customer** sees: Confirmed, Preparing, Ready, Picked Up, Delivered, Cancelled
- **Restaurant** manages: Pending → Confirmed → Preparing → Ready
- **Driver** manages: Picked Up → In Transit → Delivered
- **Admin** can override any status

---

## Error Handling

### Permission Denied Scenarios
```dart
// Insufficient Permission
throw PermissionDeniedException('You do not have permission to ${operation}');

// Not Authorized for This Resource
throw UnauthorizedException('This resource belongs to another user/restaurant');

// Operation Not Allowed in Current State
throw InvalidOperationException('Cannot ${operation} in current state');
```

---

## Testing Checklist

- [ ] Customer can only see/modify own orders
- [ ] Restaurant can only see orders for their restaurant
- [ ] Driver can only see assigned deliveries
- [ ] Admin can see everything
- [ ] Permissions are enforced on backend
- [ ] Appropriate UI elements hidden based on permissions
- [ ] Error messages shown for permission denials
- [ ] Audit log captures permission attempts

---

## Summary Table

| Role | Dashboards | Primary Operations |
|------|-----------|-------------------|
| **Customer** | Orders, Payment, Profile, Ratings | Place orders, Pay, Rate services |
| **Restaurant** | Restaurant, Menu, Inventory, Orders | Manage menu, Process orders |
| **Driver** | Deliveries, Tracking, Ratings | Accept deliveries, Track location |
| **Admin** | Users, Restaurants, Orders, Payments, Deliveries, Ratings | Full system management |

