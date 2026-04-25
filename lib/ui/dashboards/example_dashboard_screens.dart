/// Example Dashboard Implementations with Permission Integration
///
/// This file shows best practices for implementing role-based dashboards
/// using the RBAC permission system
library;

import 'package:flutter/material.dart';
import '../../models.dart';
import '../../models/permissions.dart';
import '../../services/permission_service.dart';

// ============================================================================
// EXAMPLE 1: Customer Dashboard with Conditional Features
// ============================================================================

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          if (permissions.canRead(DashboardModule.paymentAndIntegrations))
            IconButton(
              icon: const Icon(Icons.payment),
              onPressed: () {
                // Navigate to payment history
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          // Orders section - Always available for customers
          CustomerOrdersSection(permissions: permissions),

          // Shopping cart - Only if can create orders
          if (permissions.canCreate(DashboardModule.ordersAndCarts))
            CustomerCartSection(permissions: permissions),

          // Payments - Only if can access payment module
          PermissionGate(
            module: DashboardModule.paymentAndIntegrations,
            operation: OperationType.read,
            child: const PaymentHistorySection(),
          ),

          // Ratings - Only if can create ratings
          if (permissions.canCreate(DashboardModule.ratingAndFeedback))
            const RatingsSection(),

          // View restaurants
          const RestaurantsSection(),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 2: Store Owner Dashboard with Full CRUD Options
// ============================================================================

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> {
  late PermissionService _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = PermissionService();
    _verifyStoreOwnerAccess();
  }

  void _verifyStoreOwnerAccess() {
    if (PermissionService().currentUserRole != UserRole.storeOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This dashboard is for restaurant owners only.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Management')),
      body: ListView(
        children: [
          // Orders - View only
          OrdersMonitorSection(permissions: _permissions),

          // Restaurant Info - Full CRUD
          if (_permissions.hasFullCrud(DashboardModule.restaurantManagement))
            RestaurantInfoManagementSection(permissions: _permissions),

          // Menu - Full CRUD
          if (_permissions.hasFullCrud(DashboardModule.menuManagement))
            MenuManagementSection(permissions: _permissions),

          // Inventory - Full CRUD
          if (_permissions.hasFullCrud(DashboardModule.inventoryManagement))
            InventoryManagementSection(permissions: _permissions),

          // Payment view - Read only
          if (_permissions.canRead(DashboardModule.paymentAndIntegrations))
            const PaymentMonitoringSection(),

          // Delivery view - Read only
          if (_permissions.canRead(DashboardModule.deliveryManagement))
            const DeliveryMonitoringSection(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
      floatingActionButton: FloatingActionButton(
        onPressed:
            _permissions.hasFullCrud(DashboardModule.restaurantManagement)
            ? () {
                // Add new restaurant
              }
            : null,
        tooltip: 'Add Restaurant',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 3: Admin Dashboard with Full System Control
// ============================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedTab = 'overview';

  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: _buildAdminDrawer(context, permissions),
      body: _buildAdminContent(permissions),
    );
  }

  Widget _buildAdminDrawer(
    BuildContext context,
    PermissionService permissions,
  ) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Admin Menu')),
          // System Overview
          if (permissions.canRead(DashboardModule.adminDashboard))
            ListTile(
              title: const Text('System Overview'),
              onTap: () => setState(() => _selectedTab = 'overview'),
            ),

          // User Management - Only if admin has permission
          if (permissions.hasFullCrud(DashboardModule.userManagement))
            ListTile(
              title: const Text('User Management'),
              onTap: () => setState(() => _selectedTab = 'users'),
            ),

          // Delivery Management
          if (permissions.canManage(DashboardModule.deliveryManagement))
            ListTile(
              title: const Text('Delivery Management'),
              onTap: () => setState(() => _selectedTab = 'delivery'),
            ),

          // Ratings & Feedback
          if (permissions.canManage(DashboardModule.ratingAndFeedback))
            ListTile(
              title: const Text('Ratings & Feedback'),
              onTap: () => setState(() => _selectedTab = 'feedback'),
            ),

          // View-only sections
          const Divider(),
          ListTile(
            title: const Text('Orders (View)'),
            enabled: permissions.canRead(DashboardModule.ordersAndCarts),
            onTap: permissions.canRead(DashboardModule.ordersAndCarts)
                ? () => setState(() => _selectedTab = 'orders')
                : null,
          ),
          ListTile(
            title: const Text('Restaurants (View)'),
            enabled: permissions.canRead(DashboardModule.restaurantManagement),
            onTap: permissions.canRead(DashboardModule.restaurantManagement)
                ? () => setState(() => _selectedTab = 'restaurants')
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminContent(PermissionService permissions) {
    switch (_selectedTab) {
      case 'overview':
        return const AdminOverviewTab();
      case 'users':
        return permissions.hasFullCrud(DashboardModule.userManagement)
            ? const UserManagementTab()
            : const Center(child: Text('No access'));
      case 'delivery':
        return permissions.canManage(DashboardModule.deliveryManagement)
            ? const DeliveryManagementTab()
            : const Center(child: Text('No access'));
      case 'feedback':
        return permissions.canManage(DashboardModule.ratingAndFeedback)
            ? const FeedbackModerationTab()
            : const Center(child: Text('No access'));
      case 'orders':
        return permissions.canRead(DashboardModule.ordersAndCarts)
            ? const OrdersViewTab()
            : const Center(child: Text('No access'));
      case 'restaurants':
        return permissions.canRead(DashboardModule.restaurantManagement)
            ? const RestaurantsViewTab()
            : const Center(child: Text('No access'));
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }
}

// ============================================================================
// EXAMPLE 4: Delivery Driver Dashboard
// ============================================================================

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  late PermissionService _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = PermissionService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Deliveries')),
      body: ListView(
        children: [
          // Active Deliveries - Full management
          if (_permissions.canManage(DashboardModule.deliveryManagement))
            ActiveDeliveriesSection(permissions: _permissions),

          // Orders - View only
          if (_permissions.canRead(DashboardModule.ordersAndCarts))
            const OrderDetailsSection(),

          // Customer Info - View only
          if (_permissions.canRead(DashboardModule.customerDashboard))
            const CustomerContactSection(),

          // My Ratings - View only
          if (_permissions.canRead(DashboardModule.ratingAndFeedback))
            const DriverRatingsSection(),

          // Daily Stats
          const DailyStatsSection(),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 5: Reusable Permission-Based Components
// ============================================================================

/// Text field with permission check
class EditableTextField extends StatelessWidget {
  final String initialValue;
  final DashboardModule module;
  final ValueChanged<String> onChanged;
  final String label;

  const EditableTextField({
    required this.initialValue,
    required this.module,
    required this.onChanged,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = context.canUpdate(module);

    return TextField(
      controller: TextEditingController(text: initialValue),
      enabled: canEdit,
      onChanged: canEdit ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: canEdit ? 'Edit me' : 'Read only',
        suffixIcon: Icon(
          canEdit ? Icons.edit : Icons.lock,
          color: canEdit ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}

/// Button that works only with permission
class ActionButton extends StatelessWidget {
  final String label;
  final DashboardModule module;
  final OperationType operation;
  final VoidCallback onPressed;
  final IconData? icon;

  const ActionButton({
    required this.label,
    required this.module,
    required this.operation,
    required this.onPressed,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasPermission = PermissionMatrix.canPerform(
      PermissionService().currentUserRole ?? UserRole.customer,
      module,
      operation,
    );

    return ElevatedButton.icon(
      onPressed: hasPermission ? onPressed : null,
      icon: Icon(icon ?? Icons.check),
      label: Text(label),
    );
  }
}

/// List of items with conditional delete/edit buttons
class PermissionAwareList<T> extends StatelessWidget {
  final List<T> items;
  final DashboardModule module;
  final Widget Function(BuildContext, T) itemBuilder;
  final Function(T item)? onEdit;
  final Function(T item)? onDelete;

  const PermissionAwareList({
    required this.items,
    required this.module,
    required this.itemBuilder,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = context.canUpdate(module);
    final canDelete = context.canDelete(module);

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          title: itemBuilder(context, item),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => onEdit?.call(item),
                ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => onDelete?.call(item),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// PLACEHOLDER SECTIONS (Implement based on your needs)
// ============================================================================

class CustomerOrdersSection extends StatelessWidget {
  final PermissionService permissions;

  const CustomerOrdersSection({required this.permissions, super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Customer Orders Section'),
      ),
    );
  }
}

class CustomerCartSection extends StatelessWidget {
  final PermissionService permissions;

  const CustomerCartSection({required this.permissions, super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Shopping Cart Section'),
      ),
    );
  }
}

class PaymentHistorySection extends StatelessWidget {
  const PaymentHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Payment History'),
      ),
    );
  }
}

class RatingsSection extends StatelessWidget {
  const RatingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('My Ratings & Feedback'),
      ),
    );
  }
}

class RestaurantsSection extends StatelessWidget {
  const RestaurantsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Browse Restaurants'),
      ),
    );
  }
}

class OrdersMonitorSection extends StatelessWidget {
  final PermissionService permissions;

  const OrdersMonitorSection({required this.permissions, super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Orders Monitor (View Only)'),
      ),
    );
  }
}

class RestaurantInfoManagementSection extends StatelessWidget {
  final PermissionService permissions;

  const RestaurantInfoManagementSection({required this.permissions, super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Restaurant Info Management (Full CRUD)'),
      ),
    );
  }
}

class MenuManagementSection extends StatelessWidget {
  final PermissionService permissions;

  const MenuManagementSection({required this.permissions, super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Menu Management (Full CRUD)'),
      ),
    );
  }
}

class InventoryManagementSection extends StatelessWidget {
  final PermissionService permissions;

  const InventoryManagementSection({required this.permissions, super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Inventory Management (Full CRUD)'),
      ),
    );
  }
}

class PaymentMonitoringSection extends StatelessWidget {
  const PaymentMonitoringSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Payment Monitoring (View Only)'),
      ),
    );
  }
}

class DeliveryMonitoringSection extends StatelessWidget {
  const DeliveryMonitoringSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Delivery Monitoring (View Only)'),
      ),
    );
  }
}

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Admin Overview'));
  }
}

class UserManagementTab extends StatelessWidget {
  const UserManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('User Management'));
  }
}

class DeliveryManagementTab extends StatelessWidget {
  const DeliveryManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Delivery Management'));
  }
}

class FeedbackModerationTab extends StatelessWidget {
  const FeedbackModerationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Feedback Moderation'));
  }
}

class OrdersViewTab extends StatelessWidget {
  const OrdersViewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Orders View'));
  }
}

class RestaurantsViewTab extends StatelessWidget {
  const RestaurantsViewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Restaurants View'));
  }
}

class ActiveDeliveriesSection extends StatelessWidget {
  final PermissionService permissions;

  const ActiveDeliveriesSection({required this.permissions, super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Active Deliveries'),
      ),
    );
  }
}

class OrderDetailsSection extends StatelessWidget {
  const OrderDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Order Details'),
      ),
    );
  }
}

class CustomerContactSection extends StatelessWidget {
  const CustomerContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Customer Contact'),
      ),
    );
  }
}

class DriverRatingsSection extends StatelessWidget {
  const DriverRatingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(padding: EdgeInsets.all(16.0), child: Text('My Ratings')),
    );
  }
}

class DailyStatsSection extends StatelessWidget {
  const DailyStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Daily Statistics'),
      ),
    );
  }
}
