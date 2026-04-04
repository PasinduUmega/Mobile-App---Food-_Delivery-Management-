import 'package:flutter/material.dart';

import 'delivery_management_dashboard.dart';
import 'inventory_management_dashboard.dart';
import 'menu_management_dashboard.dart';
import 'order_management_dashboard.dart';
import 'payment_management_dashboard.dart';
import 'payments_crud_screen.dart';
import 'restaurant_management_dashboard.dart';
import 'stores_crud_screen.dart';
import 'user_management_dashboard.dart';
import 'users_crud_screen.dart';

/// Single entry for all seven operational CRUD areas (admin / manager).
class CrudSuiteScreen extends StatelessWidget {
  const CrudSuiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'CRUD · 7 modules',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: cs.onPrimary,
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withOpacity(0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Each block is a full CRUD area (create, read, update, delete). '
                'Open the dashboard row for screens with add/edit/delete, or the '
                'API row for direct table CRUD.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _CrudModule(
                  index: 1,
                  title: 'Users',
                  subtitle: 'Roles, profiles & direct user records',
                  color: const Color(0xFFF2994A),
                  icon: Icons.people_outline,
                  primaryLabel: 'User management (CRUD)',
                  primaryBuilder: (_) => const UserManagementDashboard(),
                  secondaryLabel: 'Users table · API CRUD',
                  secondaryBuilder: (_) => const UsersCrudScreen(),
                ),
                _CrudModule(
                  index: 2,
                  title: 'Restaurants & stores',
                  subtitle: 'Locations, images, owner assignment',
                  color: const Color(0xFFFF6A00),
                  icon: Icons.storefront_outlined,
                  primaryLabel: 'Restaurant management (CRUD)',
                  primaryBuilder: (_) => const RestaurantManagementDashboard(),
                  secondaryLabel: 'Stores table · API CRUD',
                  secondaryBuilder: (_) => const StoresCrudScreen(),
                ),
                _CrudModule(
                  index: 3,
                  title: 'Menu & catalog',
                  subtitle: 'Items, prices, specials',
                  color: const Color(0xFF9B51E0),
                  icon: Icons.restaurant_menu,
                  primaryLabel: 'Menu management (CRUD)',
                  primaryBuilder: (_) => const MenuManagementDashboard(),
                ),
                _CrudModule(
                  index: 4,
                  title: 'Inventory & stock',
                  subtitle: 'Quantities tied to menu items & stores',
                  color: const Color(0xFFEB5757),
                  icon: Icons.inventory_2_outlined,
                  primaryLabel: 'Inventory management (CRUD)',
                  primaryBuilder: (_) => const InventoryManagementDashboard(),
                ),
                _CrudModule(
                  index: 5,
                  title: 'Orders & carts',
                  subtitle: 'Order lines, status, cart-style edits',
                  color: const Color(0xFF4A90E2),
                  icon: Icons.shopping_bag_outlined,
                  primaryLabel: 'Orders & carts (CRUD)',
                  primaryBuilder: (_) => const OrderManagementDashboard(),
                ),
                _CrudModule(
                  index: 6,
                  title: 'Payments & receipts',
                  subtitle: 'Admin-only finance · owners view-only in their hub',
                  color: const Color(0xFF27AE60),
                  icon: Icons.account_balance_wallet_outlined,
                  primaryLabel: 'Finance & payments (CRUD)',
                  primaryBuilder: (_) => const PaymentManagementDashboard(),
                  secondaryLabel: 'Payments table · API CRUD',
                  secondaryBuilder: (_) => const PaymentsCrudScreen(),
                ),
                _CrudModule(
                  index: 7,
                  title: 'Delivery & drivers',
                  subtitle: 'Assignments, status, logistics',
                  color: const Color(0xFF11A36A),
                  icon: Icons.delivery_dining_outlined,
                  primaryLabel: 'Delivery management (CRUD)',
                  primaryBuilder: (_) => const DeliveryManagementDashboard(),
                ),
                const SizedBox(height: 28),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrudModule extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String primaryLabel;
  final Widget Function(BuildContext) primaryBuilder;
  final String? secondaryLabel;
  final Widget Function(BuildContext)? secondaryBuilder;

  const _CrudModule({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.primaryLabel,
    required this.primaryBuilder,
    this.secondaryLabel,
    this.secondaryBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 20, color: color),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Chip(
                              label: const Text(
                                'CRUD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              side: BorderSide(color: color.withOpacity(0.35)),
                              backgroundColor: color.withOpacity(0.12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(primaryLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: primaryBuilder,
                ),
              ),
            ),
            if (secondaryLabel != null && secondaryBuilder != null) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(secondaryLabel!),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: secondaryBuilder!,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
