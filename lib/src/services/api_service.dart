import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/menu_item.dart';

class ApiService {
  ApiService({
    this.baseUrl = 'http://10.0.2.2:8080',
    this.wsUrl = 'ws://10.0.2.2:8080/ws',
  });

  final String baseUrl;
  final String wsUrl;

  Future<List<MenuItemModel>> getMenuItems() async {
    final response = await http.get(Uri.parse('$baseUrl/menu-items'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch menu items');
    }

    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) => MenuItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createMenuItem({
    required String name,
    required String category,
    required double price,
    required bool available,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/menu-items'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'category': category,
        'price': price,
        'available': available,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create menu item');
    }
  }

  Future<void> updateMenuItem(MenuItemModel item) async {
    final response = await http.put(
      Uri.parse('$baseUrl/menu-items/${item.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(item.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update menu item');
    }
  }

  Future<void> deleteMenuItem(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/menu-items/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete menu item');
    }
  }

  WebSocketChannel connectRealtime() {
    return WebSocketChannel.connect(Uri.parse(wsUrl));
  }
}
