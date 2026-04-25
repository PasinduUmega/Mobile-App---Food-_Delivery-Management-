# Role-Based Access Control (RBAC) System
## Food Delivery App - Dashboard & Operations Permissions

### Overview
This document defines the complete role-based access control system for the food delivery application. Each user role has specific permissions for dashboard modules and operations.

---

## User Roles

### 1. **CUSTOMER**
- **Access Level**: User-focused ordering and account management
- **Primary Dashboard**: Customer Dashboard

### 2. **STORE_OWNER** / Restaurant Owner
- **Access Level**: Restaurant management and order tracking
- **Primary Dashboard**: Restaurant Dashboard

### 3. **ADMIN**
- **Access Level**: System-wide management and oversight
- **Primary Dashboard**: Admin Dashboard

### 4. **DELIVERY_DRIVER**
- **Access Level**: Delivery-focused operations
- **Primary Dashboard**: Delivery Management Dashboard

---

## Dashboard Modules & Permissions Matrix

### Module: **Orders and Carts Management**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **Full CRUD** | Create, Read, Update, Delete | Full control over personal orders and cart |
| **STORE_OWNER** | **View Only** | Read | View orders for their restaurant |
| **ADMIN** | **View Only** | Read | Monitoring purpose only |
| **DELIVERY_DRIVER** | **View Only** | Read | View assigned orders |

**Use Cases**:
- Customer: Add to cart, modify quantities, checkout, view order history
- Store Owner: View incoming orders, track order status
- Admin: Monitor system activity, troubleshoot orders
- Driver: View pickup and delivery orders

---

### Module: **Customer Dashboard**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **Full CRUD** | Create, Read, Update, Delete | Full control of dashboard |
| **STORE_OWNER** | **View Only** | Read | Analytics view of their customers |
| **ADMIN** | **View Only** | Read | System monitoring |
| **DELIVERY_DRIVER** | **View Only** | Read | Customer information for deliveries |

**Use Cases**:
- Customer: Edit profile, manage addresses, view transaction history
- Store Owner: View customer data for their restaurant
- Admin: Access customer information for support/compliance
- Driver: View customer info and delivery addresses

---

### Module: **Payment & Integrations**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **Create & View Only** | Create, Read | Process payments and view transaction history |
| **STORE_OWNER** | **View Only** | Read | Monitor payment receipts |
| **ADMIN** | **View Only** | Read | Payment system monitoring |
| **DELIVERY_DRIVER** | **No Access** | — | — |

**Payment Methods Supported**:
- PayPal
- Cash on Delivery
- Online Banking

**Use Cases**:
- Customer: Initiate PayPal/Online banking payments, view payment history
- Store Owner: View revenue and payment breakdowns
- Admin: Monitor payment transactions and reconciliation
- Driver: N/A (no payment access)

---

### Module: **User Management** (Admin Panel)

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **View Only** | Read | Limited profile viewing |
| **STORE_OWNER** | **View Only** | Read | Team member management read-only |
| **ADMIN** | **Full Management** | Create, Read, Update, Delete, Manage | Complete user administration |
| **DELIVERY_DRIVER** | **No Access** | — | — |

**Admin Capabilities**:
- ✅ Create/delete user accounts
- ✅ Assign/modify user roles
- ✅ Manage user permissions
- ✅ View user activity logs
- ✅ Suspend/activate accounts
- ✅ Review and manage ratings & feedback

**Use Cases**:
- Admin: User onboarding, role assignment, access control management

---

### Module: **Rating & Feedback System**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **Create & View** | Create, Read | Post ratings and view feedback |
| **STORE_OWNER** | **View Only** | Read | View feedback on their restaurants |
| **ADMIN** | **Create, Read, Manage** | Create, Read, Manage | Moderate and manage all feedback |
| **DELIVERY_DRIVER** | **View Only** | Read | View their ratings only |

**Use Cases**:
- Customer: Rate restaurants and delivery, provide feedback
- Store Owner: Monitor customer satisfaction and reviews
- Admin: Moderate inappropriate feedback, manage ratings
- Driver: View their own performance ratings

---

### Module: **Restaurant Management**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **View Only** | Read | Browse restaurants |
| **STORE_OWNER** | **Full CRUD** | Create, Read, Update, Delete | Manage restaurant details |
| **ADMIN** | **View Only** | Read | Oversee all restaurants |
| **DELIVERY_DRIVER** | **View Only** | Read | Restaurant info for pickups |

**Store Owner Operations**:
- ✅ Create restaurant profile
- ✅ Update restaurant info, hours, location
- ✅ Enable/disable restaurant
- ✅ View restaurant analytics
- ✅ Delete/archive restaurant

**Use Cases**:
- Store Owner: Setup and maintain restaurant profile
- Customer: Browse and discover restaurants
- Admin: Verify restaurant compliance
- Driver: Get pickup location details

---

### Module: **Menu Management**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **View Only** | Read | View menu items and prices |
| **STORE_OWNER** | **Full CRUD** | Create, Read, Update, Delete | Manage all menu items |
| **ADMIN** | **View Only** | Read | Menu oversight |
| **DELIVERY_DRIVER** | **View Only** | Read | View item descriptions |

**Store Owner Menu Operations**:
- ✅ Add new menu items
- ✅ Update item prices and descriptions
- ✅ Add/update item images
- ✅ Set item availability
- ✅ Organize items by category
- ✅ Delete items
- ✅ Promotional pricing
- ✅ Special instructions/customizations

**Use Cases**:
- Store Owner: Daily menu updates, inventory adjustments
- Customer: Browse menu, select items
- Admin: Menu quality control

---

### Module: **Inventory Management**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **View Only** | Read | See item availability |
| **STORE_OWNER** | **Full CRUD** | Create, Read, Update, Delete | Manage stock levels |
| **ADMIN** | **View Only** | Read | Inventory monitoring |
| **DELIVERY_DRIVER** | **No Access** | — | — |

**Store Owner Inventory Operations**:
- ✅ Update stock quantities
- ✅ Set minimum/maximum thresholds
- ✅ Mark items as out of stock
- ✅ Reorder alerts
- ✅ Track inventory history
- ✅ Set expiration dates (if applicable)
- ✅ View inventory reports

**Use Cases**:
- Store Owner: Real-time stock management, prevent overselling
- Customer: See available items only
- Admin: Detect stockouts, suggest optimization

---

### Module: **Delivery Management**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **View Only** | Read | Track delivery status |
| **STORE_OWNER** | **View Only** | Read | Monitor order deliveries |
| **ADMIN** | **Full Management** | Create, Read, Update, Delete, Manage | Complete delivery system control |
| **DELIVERY_DRIVER** | **Full Management** | Create, Read, Update, Delete, Manage | Manage personal deliveries |

**Admin Delivery Operations**:
- ✅ Assign delivery drivers
- ✅ Create delivery zones
- ✅ Set delivery fees and estimates
- ✅ Monitor all active deliveries
- ✅ Handle delivery disputes
- ✅ Manage driver schedules
- ✅ View delivery analytics
- ✅ Cancel/reassign deliveries

**Driver Delivery Operations**:
- ✅ Accept/decline delivery jobs
- ✅ Update delivery status (Picked up, In transit, Delivered)
- ✅ View route and customer details
- ✅ Record delivery completion
- ✅ Handle delivery notes
- ✅ View their earnings and statistics

**Use Cases**:
- Admin: Optimize delivery network, manage operations
- Driver: Handle daily deliveries, update status
- Customer: Track real-time delivery
- Store Owner: Monitor fulfillment

---

### Module: **Admin Dashboard**

| Role | Access Level | Operations | Description |
|------|-------------|-----------|-------------|
| **CUSTOMER** | **No Access** | — | — |
| **STORE_OWNER** | **No Access** | — | — |
| **ADMIN** | **Full Access** | Create, Read, Update, Delete, Manage | Complete system access |
| **DELIVERY_DRIVER** | **No Access** | — | — |

**Admin Dashboard Features**:
- ✅ System metrics and KPIs
- ✅ User management panel
- ✅ Payment reconciliation
- ✅ Delivery operations
- ✅ Revenue analytics
- ✅ Compliance monitoring
- ✅ System settings
- ✅ Support tickets

---

## Permission Summary by Role

### CUSTOMER Permissions Table
```
Module                          | Access  | CRUD Operations
================================|=========|=================
Orders & Carts                  | FULL    | C✓ R✓ U✓ D✓
Customer Dashboard              | FULL    | C✓ R✓ U✓ D✓
Payment & Integrations          | LIMITED | C✓ R✓ U✗ D✗ (CV Only)
Rating & Feedback               | LIMITED | C✓ R✓ U✗ D✗
Restaurant Management           | VIEW    | C✗ R✓ U✗ D✗
Menu Management                 | VIEW    | C✗ R✓ U✗ D✗
Inventory Management            | VIEW    | C✗ R✓ U✗ D✗
Delivery Management             | VIEW    | C✗ R✓ U✗ D✗
User Management                 | VIEW    | C✗ R✓ U✗ D✗
Admin Dashboard                 | NONE    | ✗✗✗✗
```

### STORE_OWNER Permissions Table
```
Module                          | Access  | CRUD Operations
================================|=========|=================
Orders & Carts                  | VIEW    | C✗ R✓ U✗ D✗
Restaurant Management           | FULL    | C✓ R✓ U✓ D✓
Menu Management                 | FULL    | C✓ R✓ U✓ D✓
Inventory Management            | FULL    | C✓ R✓ U✓ D✓
Payment & Integrations          | VIEW    | C✗ R✓ U✗ D✗
Delivery Management             | VIEW    | C✗ R✓ U✗ D✗
Customer Dashboard              | VIEW    | C✗ R✓ U✗ D✗
User Management                 | VIEW    | C✗ R✓ U✗ D✗
Rating & Feedback               | VIEW    | C✗ R✓ U✗ D✗
Admin Dashboard                 | NONE    | ✗✗✗✗
```

### ADMIN Permissions Table
```
Module                          | Access  | CRUD Operations
================================|=========|=================
User Management                 | FULL    | C✓ R✓ U✓ D✓
Delivery Management             | FULL    | C✓ R✓ U✓ D✓
Admin Dashboard                 | FULL    | C✓ R✓ U✓ D✓
Orders & Carts                  | VIEW    | C✗ R✓ U✗ D✗
Customer Dashboard              | VIEW    | C✗ R✓ U✗ D✗
Restaurant Management           | VIEW    | C✗ R✓ U✗ D✗
Menu Management                 | VIEW    | C✗ R✓ U✗ D✗
Inventory Management            | VIEW    | C✗ R✓ U✗ D✗
Payment & Integrations          | VIEW    | C✗ R✓ U✗ D✗
Rating & Feedback               | MANAGE  | C✗ R✓ U✓ D✗ (Moderate)
```

### DELIVERY_DRIVER Permissions Table
```
Module                          | Access  | CRUD Operations
================================|=========|=================
Delivery Management             | FULL    | C✓ R✓ U✓ D✓
Orders & Carts                  | VIEW    | C✗ R✓ U✗ D✗
Customer Dashboard              | VIEW    | C✗ R✓ U✗ D✗
Restaurant Management           | VIEW    | C✗ R✓ U✗ D✗
Menu Management                 | VIEW    | C✗ R✓ U✗ D✗
Rating & Feedback               | VIEW    | C✗ R✓ U✗ D✗
Payment & Integrations          | NONE    | ✗✗✗✗
Inventory Management            | NONE    | ✗✗✗✗
User Management                 | NONE    | ✗✗✗✗
Admin Dashboard                 | NONE    | ✗✗✗✗
```

---

## Implementation Guide

### 1. Initialize Permissions on App Startup

```dart
void main() async {
  // ... other initialization
  
  // Get current user role (from authentication service)
  final userRole = UserRole.customer; // Example
  
  // Initialize permission service
  PermissionService().initialize(userRole);
  
  runApp(const MyApp());
}
```

### 2. Check Permissions in Widgets

```dart
// Method 1: Using PermissionService directly
if (PermissionService().canCreate(DashboardModule.ordersAndCarts)) {
  // Show create order button
}

// Method 2: Using BuildContext extension
if (context.canUpdate(DashboardModule.menuManagement)) {
  // Show edit button
}

// Method 3: Using PermissionGate wrapper
PermissionGate(
  module: DashboardModule.restaurantManagement,
  operation: OperationType.create,
  child: ElevatedButton(
    onPressed: () { /* Create restaurant */ },
    child: const Text('Add Restaurant'),
  ),
  fallback: const SizedBox.shrink(),
)

// Method 4: Using PermissionButton
PermissionButton(
  module: DashboardModule.menuManagement,
  operation: OperationType.create,
  label: 'Add Menu Item',
  icon: Icons.add,
  onPressed: () { /* Add item */ },
)
```

### 3. API Integration with Permission Verification

```dart
// In your API service or repository
Future<Order> createOrder(Order order) async {
  // Verify permission before making API call
  PermissionService().verifyPermission(
    DashboardModule.ordersAndCarts,
    OperationType.create,
  );
  
  // Make API call
  return await apiClient.post('/orders', order);
}
```

### 4. Dashboard Navigation Based on Role

```dart
List<DashboardModule> accessibleModules = 
  PermissionService().getAccessibleModules();

// Build navigation menu
ListView.builder(
  itemCount: accessibleModules.length,
  itemBuilder: (context, index) {
    final module = accessibleModules[index];
    return ListTile(
      title: Text(module.name),
      onTap: () { /* Navigate to module */ },
    );
  },
)
```

### 5. Handle Permission Denial

```dart
try {
  PermissionService().verifyPermission(
    DashboardModule.adminDashboard,
    OperationType.read,
  );
  // Show admin dashboard
} on PermissionDeniedException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message)),
  );
}
```

---

## Best Practices

### ✅ DO:
- Always check permissions before showing UI elements
- Verify permissions server-side before processing requests
- Use meaningful error messages for denied permissions
- Log permission violations for security auditing
- Display role-specific dashboards/menus
- Hide sensitive actions from unauthorized users

### ❌ DON'T:
- Rely only on client-side permission checks
- Hide buttons but allow API access
- Display "Permission Denied" UI frequently
- Log sensitive data in permission errors
- Hard-code permissions in UI
- Allow users to request elevated permissions

---

## Session Management

### Permission Session Lifecycle

1. **Login**: User authenticates, role determined
2. **Initialize**: `PermissionService().initialize(role)` called
3. **Active**: Permissions checked on each action
4. **Logout**: Clean permission cache
5. **Role Change**: Re-initialize with new role

```dart
// On user logout
void handleLogout() {
  PermissionService._instance = PermissionService._internal();
  navigateToLoginScreen();
}
```

---

## Testing Permissions

```dart
// Test permission matrix
void testPermissions() {
  // Test customer permissions
  assert(PermissionMatrix.canPerform(
    UserRole.customer,
    DashboardModule.ordersAndCarts,
    OperationType.create,
  ) == true);

  // Test store owner permissions
  assert(PermissionMatrix.canPerform(
    UserRole.storeOwner,
    DashboardModule.ordersAndCarts,
    OperationType.create,
  ) == false);

  // Test admin permissions
  assert(PermissionMatrix.canPerform(
    UserRole.admin,
    DashboardModule.userManagement,
    OperationType.delete,
  ) == true);
}
```

---

## API Route Protection (Backend)

Each backend endpoint should verify user permissions:

```javascript
// Example Node.js/Express middleware
async function checkPermission(req, res, next) {
  const userRole = req.user.role;
  const requiredModule = req.requiredModule;
  const requiredOperation = req.requiredOperation;

  const hasPermission = PermissionMatrix.canPerform(
    userRole,
    requiredModule,
    requiredOperation
  );

  if (!hasPermission) {
    return res.status(403).json({ 
      error: 'Permission Denied',
      message: `${userRole} cannot ${requiredOperation} on ${requiredModule}`
    });
  }

  next();
}

// Usage
app.post('/api/orders', 
  checkPermission,
  (req, res) => {
    // Create order
  }
);
```

---

## Future Enhancements

- [ ] Time-based permissions (e.g., only 9-5 access)
- [ ] Conditional permissions (e.g., manage only own orders)
- [ ] Permission expiration and renewal
- [ ] Custom role creation
- [ ] Permission analytics dashboard
- [ ] Audit log with permission changes
- [ ] Two-factor verification for sensitive ops
- [ ] Data-level permission filtering

---

## Support & Questions

For permission-related issues, contact:
- **Backend**: Permission matrix sync between frontend/backend
- **Security**: Permission verification and token validation
- **UI**: Permission-aware component rendering

---

**Last Updated**: April 2026
**Version**: 1.0.0
