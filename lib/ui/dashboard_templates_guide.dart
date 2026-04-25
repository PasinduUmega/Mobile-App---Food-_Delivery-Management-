import 'package:flutter/material.dart';
import '../models.dart';
import '../services/permissions.dart';

/// Customer Dashboard - Manages Orders, Carts, Payments, Ratings
class CustomerDashboardGuide extends StatefulWidget {
  final User user;
  final UserRole userRole;

  const CustomerDashboardGuide({
    required this.user,
    required this.userRole,
    super.key,
  });

  @override
  State<CustomerDashboardGuide> createState() =>
      _CustomerDashboardGuideState();
}

class _CustomerDashboardGuideState extends State<CustomerDashboardGuide> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Dashboard')),
      body: Column(
        children: [
          // Tab Navigation
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('My Orders'),
                  icon: Icon(Icons.shopping_cart),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Payments'),
                  icon: Icon(Icons.payment),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Restaurants'),
                  icon: Icon(Icons.restaurant),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('Ratings'),
                  icon: Icon(Icons.star),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (s) =>
                  setState(() => _selectedTab = s.first),
            ),
          ),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    // Customer can ONLY perform these operations with permission checks
    switch (_selectedTab) {
      case 0:
        return _buildOrdersTab();
      case 1:
        return _buildPaymentsTab();
      case 2:
        return _buildRestaurantsTab();
      case 3:
        return _buildRatingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOrdersTab() {
    // PERMISSIONS: Customer can Create, Read, Update own orders
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: Create new order
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.orders,
          level: PermissionLevel.create,
          child: ElevatedButton.icon(
            onPressed: _createNewOrder,
            icon: const Icon(Icons.add),
            label: const Text('New Order'),
          ),
        ),
        const SizedBox(height: 16),

        // ✅ ALLOWED: View own orders
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.orders,
          level: PermissionLevel.read,
          child: const Text('My Orders List'),
        ),

        // ✅ ALLOWED: Edit pending orders
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.orders,
          level: PermissionLevel.update,
          child: Card(
            child: ListTile(
              title: const Text('Order #123'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Check permission before editing
                  if (widget.userRole.canUpdate(ComponentPermissions.orders)) {
                    _editOrder();
                  }
                },
              ),
            ),
          ),
        ),

        // ❌ NOT ALLOWED: Delete orders
        // Customers cannot delete orders (maintains audit trail)
      ],
    );
  }

  Widget _buildPaymentsTab() {
    // PERMISSIONS: Customer can Create & Read payments, but NOT Update/Delete
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: Create new payment
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.payments,
          level: PermissionLevel.create,
          child: ElevatedButton.icon(
            onPressed: _initiatePayment,
            icon: const Icon(Icons.add_card),
            label: const Text('Make Payment'),
          ),
        ),
        const SizedBox(height: 16),

        // ✅ ALLOWED: View payment history
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.payments,
          level: PermissionLevel.read,
          child: const Text('Payment History'),
        ),

        // ❌ NOT ALLOWED: Edit payments (customers cannot modify)
        // ❌ NOT ALLOWED: Delete payments (audit trail must be maintained)
      ],
    );
  }

  Widget _buildRestaurantsTab() {
    // PERMISSIONS: Customer can only Read restaurants
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: View restaurants
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.restaurants,
          level: PermissionLevel.read,
          child: const Text('Browse Restaurants'),
        ),

        // ❌ NOT ALLOWED: Create, Edit, Delete restaurants
        // Only restaurant owners can manage restaurants
      ],
    );
  }

  Widget _buildRatingsTab() {
    // PERMISSIONS: Customer can Create & Update ratings
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: Rate restaurant
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.ratings,
          level: PermissionLevel.create,
          child: ElevatedButton.icon(
            onPressed: _rateRestaurant,
            icon: const Icon(Icons.star),
            label: const Text('Rate Restaurant'),
          ),
        ),
        const SizedBox(height: 16),

        // ✅ ALLOWED: Update rating
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.ratings,
          level: PermissionLevel.update,
          child: const Text('Your Ratings'),
        ),

        // ❌ NOT ALLOWED: Delete ratings
      ],
    );
  }

  void _createNewOrder() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.orders,
      PermissionLevel.create,
    )) {
      return;
    }
    // Proceed with creating order
  }

  void _editOrder() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.orders,
      PermissionLevel.update,
    )) {
      return;
    }
    // Proceed with editing order
  }

  void _initiatePayment() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.payments,
      PermissionLevel.create,
    )) {
      return;
    }
    // Proceed with payment
  }

  void _rateRestaurant() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.ratings,
      PermissionLevel.create,
    )) {
      return;
    }
    // Proceed with rating
  }
}

/// Restaurant Owner Dashboard - Manages Menu, Inventory, Orders
class RestaurantDashboardGuide extends StatefulWidget {
  final User user;
  final UserRole userRole;

  const RestaurantDashboardGuide({
    required this.user,
    required this.userRole,
    super.key,
  });

  @override
  State<RestaurantDashboardGuide> createState() =>
      _RestaurantDashboardGuideState();
}

class _RestaurantDashboardGuideState extends State<RestaurantDashboardGuide> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Dashboard')),
      body: Column(
        children: [
          // Tab Navigation
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Restaurant'),
                  icon: Icon(Icons.restaurant_menu),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Menu'),
                  icon: Icon(Icons.menu_book),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Inventory'),
                  icon: Icon(Icons.inventory),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('Orders'),
                  icon: Icon(Icons.receipt),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (s) =>
                  setState(() => _selectedTab = s.first),
            ),
          ),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    // Restaurant can manage their own Restaurant, Menu, Inventory
    switch (_selectedTab) {
      case 0:
        return _buildRestaurantTab();
      case 1:
        return _buildMenuTab();
      case 2:
        return _buildInventoryTab();
      case 3:
        return _buildOrdersTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRestaurantTab() {
    // PERMISSIONS: Full CRUD for own restaurant
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: Edit restaurant info
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.restaurants,
          level: PermissionLevel.update,
          child: ElevatedButton.icon(
            onPressed: () => _editRestaurant(),
            icon: const Icon(Icons.edit),
            label: const Text('Edit Restaurant Info'),
          ),
        ),
        const SizedBox(height: 16),

        // ✅ ALLOWED: View restaurant details
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.restaurants,
          level: PermissionLevel.read,
          child: const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Restaurant Details Here'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTab() {
    // PERMISSIONS: Full CRUD for own menu
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: Add menu item
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.menu,
          level: PermissionLevel.create,
          child: ElevatedButton.icon(
            onPressed: () => _addMenuItem(),
            icon: const Icon(Icons.add),
            label: const Text('Add Menu Item'),
          ),
        ),
        const SizedBox(height: 16),

        // ✅ ALLOWED: Edit menu items
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.menu,
          level: PermissionLevel.update,
          child: ListTile(
            title: const Text('Menu Item 1'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editMenuItem(),
            ),
          ),
        ),

        // ✅ ALLOWED: Delete menu items
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.menu,
          level: PermissionLevel.delete,
          child: ListTile(
            title: const Text('Menu Item 2'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteMenuItem(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    // PERMISSIONS: Full CRUD for inventory
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: Update inventory levels
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.inventory,
          level: PermissionLevel.update,
          child: ElevatedButton.icon(
            onPressed: () => _updateInventory(),
            icon: const Icon(Icons.update),
            label: const Text('Update Inventory'),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    // PERMISSIONS: Read & Update orders (process them)
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ✅ ALLOWED: View incoming orders
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.orders,
          level: PermissionLevel.read,
          child: const Text('New Orders'),
        ),
        const SizedBox(height: 16),

        // ✅ ALLOWED: Update order status
        PermissionBuilder(
          userRole: widget.userRole,
          component: ComponentPermissions.orders,
          level: PermissionLevel.update,
          child: Card(
            child: ListTile(
              title: const Text('Order #123'),
              subtitle: const Text('Pending'),
              trailing: DropdownButton<String>(
                value: 'pending',
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                  DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                  DropdownMenuItem(value: 'ready', child: Text('Ready')),
                ],
                onChanged: (value) => _updateOrderStatus(value),
              ),
            ),
          ),
        ),

        // ❌ NOT ALLOWED: Create or Delete orders
      ],
    );
  }

  void _editRestaurant() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.restaurants,
      PermissionLevel.update,
    )) {
      return;
    }
    // Edit logic here
  }

  void _addMenuItem() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.menu,
      PermissionLevel.create,
    )) {
      return;
    }
    // Add menu logic here
  }

  void _editMenuItem() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.menu,
      PermissionLevel.update,
    )) {
      return;
    }
    // Edit menu logic here
  }

  void _deleteMenuItem() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.menu,
      PermissionLevel.delete,
    )) {
      return;
    }
    // Delete menu logic here
  }

  void _updateInventory() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.inventory,
      PermissionLevel.update,
    )) {
      return;
    }
    // Update logic here
  }

  void _updateOrderStatus(String? status) {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.orders,
      PermissionLevel.update,
    )) {
      return;
    }
    // Update order status logic here
  }
}

/// Delivery Driver Dashboard - Manages Deliveries & Location
class DeliveryDashboardGuide extends StatefulWidget {
  final User user;
  final UserRole userRole;

  const DeliveryDashboardGuide({
    required this.user,
    required this.userRole,
    super.key,
  });

  @override
  State<DeliveryDashboardGuide> createState() =>
      _DeliveryDashboardGuideState();
}

class _DeliveryDashboardGuideState extends State<DeliveryDashboardGuide> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ ALLOWED: View assigned orders
          PermissionBuilder(
            userRole: widget.userRole,
            component: ComponentPermissions.orders,
            level: PermissionLevel.read,
            child: const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Assigned Deliveries'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ ALLOWED: Accept delivery
          PermissionBuilder(
            userRole: widget.userRole,
            component: ComponentPermissions.delivery,
            level: PermissionLevel.update,
            child: ElevatedButton.icon(
              onPressed: _acceptDelivery,
              icon: const Icon(Icons.check),
              label: const Text('Accept Delivery'),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ ALLOWED: Update location
          PermissionBuilder(
            userRole: widget.userRole,
            component: ComponentPermissions.location,
            level: PermissionLevel.update,
            child: ElevatedButton.icon(
              onPressed: _updateLocation,
              icon: const Icon(Icons.location_on),
              label: const Text('Update Location'),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ ALLOWED: Mark delivered
          PermissionBuilder(
            userRole: widget.userRole,
            component: ComponentPermissions.delivery,
            level: PermissionLevel.update,
            child: ElevatedButton(
              onPressed: _markDelivered,
              child: const Text('Mark as Delivered'),
            ),
          ),
        ],
      ),
    );
  }

  void _acceptDelivery() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.delivery,
      PermissionLevel.update,
    )) {
      return;
    }
    // Accept logic here
  }

  void _updateLocation() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.location,
      PermissionLevel.update,
    )) {
      return;
    }
    // Update location logic here
  }

  void _markDelivered() {
    if (!PermissionHelper.guardOperation(
      context,
      widget.userRole,
      ComponentPermissions.delivery,
      PermissionLevel.update,
    )) {
      return;
    }
    // Mark delivered logic here
  }
}

/// Admin Dashboard - Full Access to All Components
class AdminDashboardGuide extends StatefulWidget {
  final User user;
  final UserRole userRole;

  const AdminDashboardGuide({
    required this.user,
    required this.userRole,
    super.key,
  });

  @override
  State<AdminDashboardGuide> createState() =>
      _AdminDashboardGuideState();
}

class _AdminDashboardGuideState extends State<AdminDashboardGuide> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Users'),
                  icon: Icon(Icons.people),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Restaurants'),
                  icon: Icon(Icons.restaurant),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Orders'),
                  icon: Icon(Icons.shopping_cart),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('Deliveries'),
                  icon: Icon(Icons.local_shipping),
                ),
                ButtonSegment(
                  value: 4,
                  label: Text('Payments'),
                  icon: Icon(Icons.payment),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (s) =>
                  setState(() => _selectedTab = s.first),
            ),
          ),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    // Admin has FULL CRUD access to all components
    switch (_selectedTab) {
      case 0:
        return _buildUsersTab();
      case 1:
        return _buildRestaurantsTab();
      case 2:
        return _buildOrdersTab();
      case 3:
        return _buildDeliveriesTab();
      case 4:
        return _buildPaymentsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUsersTab() {
    // ✅ Admin has Full CRUD access to all users
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () => _addUser(),
          icon: const Icon(Icons.add),
          label: const Text('Add User'),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('User 1'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editUser(),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteUser(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantsTab() {
    // ✅ Admin has Full CRUD access to all restaurants
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () => _addRestaurant(),
          icon: const Icon(Icons.add),
          label: const Text('Add Restaurant'),
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    // ✅ Admin has Full CRUD access to all orders
    return const Center(child: Text('All Orders Management'));
  }

  Widget _buildDeliveriesTab() {
    // ✅ Admin has Full CRUD access to all deliveries
    return const Center(child: Text('All Deliveries Management'));
  }

  Widget _buildPaymentsTab() {
    // ✅ Admin has Full CRUD access to all payments
    return const Center(child: Text('All Payments Management'));
  }

  void _addUser() {
    // Admin always has permission
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add User'),
        content: const Text('Add new user form'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editUser() {}
  void _deleteUser() {}
  void _addRestaurant() {}
}
