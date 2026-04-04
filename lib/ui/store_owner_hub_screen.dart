import 'package:flutter/material.dart';

import '../models.dart';
import 'delivery_management_dashboard.dart';
import 'inventory_management_dashboard.dart';
import 'menu_management_dashboard.dart';
import 'payment_management_dashboard.dart';
import 'restaurant_management_dashboard.dart';

/// Store owner workspace: full CRUD on menu / restaurants / inventory;
/// **view** payments & deliveries for your stores (customer carts & paid vs unpaid).
class StoreOwnerHubScreen extends StatelessWidget {
  final User user;

  const StoreOwnerHubScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My store'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            user.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Restaurant owner · no customer browse here',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Orders (bottom tab) for every customer basket at your stores. '
            'Below: full CRUD for catalog and stock, then payment and delivery view.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'FULL CRUD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.grey[600],
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: Icons.storefront_outlined,
            color: const Color(0xFFFF6A00),
            title: 'Restaurants (CRUD)',
            subtitle: 'Create, read, update, delete your locations',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    RestaurantManagementDashboard(ownerUserId: user.id),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.restaurant_menu,
            color: const Color(0xFF9B51E0),
            title: 'Menus (CRUD)',
            subtitle: 'Items, prices, specials — what customers can pick',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MenuManagementDashboard(ownerUserId: user.id),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFFEB5757),
            title: 'Inventory (CRUD)',
            subtitle: 'Stock / availability per item & store',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    InventoryManagementDashboard(ownerUserId: user.id),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'VIEW ONLY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.grey[600],
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          _Tile(
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF27AE60),
            title: 'Customer payments',
            subtitle: 'Paid vs pending — admin does payment CRUD',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PaymentManagementDashboard(
                  ownerUserId: user.id,
                  readOnly: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFF11A36A),
            title: 'Deliveries',
            subtitle: 'Driver status · open row for cart & payment snapshot',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => DeliveryManagementDashboard(
                  ownerUserId: user.id,
                  readOnly: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}
