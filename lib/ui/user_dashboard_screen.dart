import 'package:flutter/material.dart';

import '../models.dart';
import 'admin_dashboard.dart';
import 'crud_suite_screen.dart';
import 'delivery_management_dashboard.dart';
import 'inventory_management_dashboard.dart';
import 'menu_management_dashboard.dart';
import 'my_orders_screen.dart';
import 'order_management_dashboard.dart';
import 'payment_management_dashboard.dart';
import 'payments_crud_screen.dart';
import 'restaurant_dashboard.dart';
import 'restaurant_management_dashboard.dart';
import 'stores_crud_screen.dart';
import 'user_management_dashboard.dart';
import 'user_profile_screen.dart';
import 'users_crud_screen.dart';

/// **Administrator** hub: Uber-style shortcuts to test ordering + full CRUD tools.
/// Customers use the separate 3-tab app (`CustomerDashboard`).
class UserDashboardScreen extends StatelessWidget {
  final User user;
  final Function()? onSignOut;
  final ValueChanged<bool>? onThemeChanged;

  const UserDashboardScreen({
    super.key,
    required this.user,
    this.onSignOut,
    this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 128,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Admin · CRUD hub',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: cs.onPrimary,
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1F1F1F),
                      const Color(0xFF1F1F1F).withOpacity(0.88),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${user.name} · Administrator',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'QUICK ACCESS (like Uber Eats)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[600],
                  letterSpacing: 1.05,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ModuleTile(
                  title: 'Browse & order',
                  subtitle: 'Restaurants, menu & cart checkout',
                  icon: Icons.restaurant_menu_outlined,
                  color: const Color(0xFFFF6A00),
                  screen: RestaurantDashboard(user: user),
                ),
                _ModuleTile(
                  title: 'My orders',
                  subtitle: 'History & track deliveries',
                  icon: Icons.receipt_long_outlined,
                  color: const Color(0xFF4A90E2),
                  screen: MyOrdersScreen(user: user),
                ),
                _ModuleTile(
                  title: 'Account',
                  subtitle: 'Address, theme, notifications & sign out',
                  icon: Icons.person_outline,
                  color: const Color(0xFF9B51E0),
                  screen: UserProfileScreen(
                    user: user,
                    onSignOut: onSignOut,
                    onThemeChanged: onThemeChanged,
                  ),
                ),
              ]),
            ),
          ),
          if (user.role == UserRole.admin) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'FULL CRUD — ALL 7 MODULES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[600],
                    letterSpacing: 1.05,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ModuleTile(
                    title: 'Open 7-module CRUD suite',
                    subtitle:
                        'Tap each area for Create · Read · Update · Delete tools',
                    icon: Icons.grid_view_rounded,
                    color: const Color(0xFF1B4332),
                    screen: const CrudSuiteScreen(),
                  ),
                  _ModuleTile(
                    title: 'Admin overview',
                    subtitle: 'Suite summary, roadmap & quick stats',
                    icon: Icons.admin_panel_settings_outlined,
                    color: const Color(0xFF1A1A2E),
                    screen: const AdminDashboard(),
                  ),
                  _ModuleTile(
                    title: 'User management',
                    subtitle: 'Identity, access & member invites',
                    icon: Icons.people_outline,
                    color: const Color(0xFFF2994A),
                    screen: const UserManagementDashboard(),
                  ),
                  _ModuleTile(
                    title: 'Users (CRUD)',
                    subtitle: 'Direct user records API',
                    icon: Icons.badge_outlined,
                    color: const Color(0xFFE67E22),
                    screen: const UsersCrudScreen(),
                  ),
                  _ModuleTile(
                    title: 'Inventory management',
                    subtitle: 'Stock levels & alerts',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFFEB5757),
                    screen: const InventoryManagementDashboard(),
                  ),
                  _ModuleTile(
                    title: 'Delivery management',
                    subtitle: 'Drivers, routes & delivery status',
                    icon: Icons.delivery_dining_outlined,
                    color: const Color(0xFF11A36A),
                    screen: const DeliveryManagementDashboard(),
                  ),
                  _ModuleTile(
                    title: 'Menu management',
                    subtitle: 'Catalog, items, pricing & daily specials',
                    icon: Icons.restaurant_menu,
                    color: const Color(0xFF9B51E0),
                    screen: const MenuManagementDashboard(),
                  ),
                  _ModuleTile(
                    title: 'Order & cart management',
                    subtitle: 'Orders, carts & live status',
                    icon: Icons.shopping_bag_outlined,
                    color: const Color(0xFF4A90E2),
                    screen: const OrderManagementDashboard(),
                  ),
                  _ModuleTile(
                    title: 'Restaurant management',
                    subtitle: 'Stores, images & fleet',
                    icon: Icons.storefront_outlined,
                    color: const Color(0xFFFF6A00),
                    screen: const RestaurantManagementDashboard(),
                  ),
                  _ModuleTile(
                    title: 'Stores (CRUD)',
                    subtitle: 'Direct store records API',
                    icon: Icons.store_mall_directory_outlined,
                    color: const Color(0xFFD35400),
                    screen: const StoresCrudScreen(),
                  ),
                  _ModuleTile(
                    title: 'Finance & payments (CRUD)',
                    subtitle: 'Admin-only ledger & edits (owners see view-only)',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF27AE60),
                    screen: const PaymentManagementDashboard(),
                  ),
                  _ModuleTile(
                    title: 'Payments API (CRUD)',
                    subtitle: 'Direct payment records — gateway-style',
                    icon: Icons.integration_instructions_outlined,
                    color: const Color(0xFF2D9CDB),
                    screen: const PaymentsCrudScreen(),
                  ),
                ]),
              ),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey.withOpacity(0.12)),
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => screen),
          ),
        ),
      ),
    );
  }
}
