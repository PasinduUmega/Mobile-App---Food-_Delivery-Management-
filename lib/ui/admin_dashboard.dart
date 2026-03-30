import 'package:flutter/material.dart';

import 'delivery_management_dashboard.dart';
import 'inventory_management_dashboard.dart';
import 'menu_management_dashboard.dart';
import 'order_management_dashboard.dart';
import 'payment_management_dashboard.dart';
import 'restaurant_management_dashboard.dart';
import 'user_management_dashboard.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'ADMIN SUITE',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 150,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Summary Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Total Orders',
                      '1,284',
                      Icons.shopping_cart_checkout,
                      const Color(0xFFFF6A00),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Revenue',
                      'LKR 142K',
                      Icons.payments_outlined,
                      const Color(0xFF11A36A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Management Sections Header
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'MANAGEMENT MODULES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),

          // Module Grid/List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildModuleCard(
                  context,
                  'Restaurant Management',
                  'Full Profile & Status CRUD',
                  Icons.storefront_outlined,
                  const Color(0xFFFF6A00),
                  const RestaurantManagementDashboard(),
                ),
                _buildModuleCard(
                  context,
                  'Order & Cart Management',
                  'Live Tracking & Item CRUD',
                  Icons.shopping_bag_outlined,
                  const Color(0xFF4A90E2),
                  const OrderManagementDashboard(),
                ),
                _buildModuleCard(
                  context,
                  'Delivery & Logistics',
                  'Driver Assignment & Status',
                  Icons.delivery_dining_outlined,
                  const Color(0xFF11A36A),
                  const DeliveryManagementDashboard(),
                ),
                _buildModuleCard(
                  context,
                  'Menu & Catalog',
                  'Item & Category Management',
                  Icons.restaurant_menu,
                  const Color(0xFF9B51E0),
                  const MenuManagementDashboard(),
                ),
                _buildModuleCard(
                  context,
                  'User Administration',
                  'Role & Profile Controls',
                  Icons.people_outline,
                  const Color(0xFFF2994A),
                  const UserManagementDashboard(),
                ),
                _buildModuleCard(
                  context,
                  'Fleet & Inventory',
                  'Stock Tracking & Alerts',
                  Icons.inventory_2_outlined,
                  const Color(0xFFEB5757),
                  const InventoryManagementDashboard(),
                ),
                _buildModuleCard(
                  context,
                  'Finance & Payments',
                  'Transaction Logs & Refunds',
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF27AE60),
                  const PaymentManagementDashboard(),
                ),
              ]),
            ),
          ),

          // Feature Status Table (From Screenshots)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'SYSTEM ROADMAP STATUS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _buildStatusRow('Admin Dashboard', 'Completed', true),
                      _buildStatusRow('User Management', 'Completed', true),
                      _buildStatusRow('Order Management', 'Completed', true),
                      _buildStatusRow('Driver Assignment', 'Completed', true),
                      _buildStatusRow('Analytics Reports', 'In Progress', false),
                      _buildStatusRow('Auto Stock Deduction', 'Completed', true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget screen,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String feature, String status, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: completed ? const Color(0xFFE9FFF3) : const Color(0xFFFFF4EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  completed ? Icons.check_box : Icons.sync,
                  size: 14,
                  color: completed ? const Color(0xFF11A36A) : const Color(0xFFFF6A00),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: completed ? const Color(0xFF11A36A) : const Color(0xFFFF6A00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
