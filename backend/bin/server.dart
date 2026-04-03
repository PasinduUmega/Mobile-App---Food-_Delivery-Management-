import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final List<WebSocketChannel> clients = [];

Future<void> main() async {
  final db = await MySqlConnection.connect(
    ConnectionSettings(
      host: 'localhost',
      port: 3306,
      user: 'root',
      password: 'root',
      db: 'food_rush',
    ),
  );

  final router = Router()
    ..get('/menu-items', (Request request) => _getMenuItems(db))
    ..post('/menu-items', (Request request) => _createMenuItem(db, request))
    ..put('/menu-items/<id|[0-9]+>', (Request request, String id) {
      return _updateMenuItem(db, request, int.parse(id));
    })
    ..delete('/menu-items/<id|[0-9]+>', (Request request, String id) {
      return _deleteMenuItem(db, int.parse(id));
    })
    ..get('/ws', webSocketHandler(_handleSocket));

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}

Future<Response> _getMenuItems(MySqlConnection db) async {
  final results = await db.query(
    'SELECT id, name, category, price, available FROM menu_items ORDER BY id DESC',
  );

  final items = results
      .map(
        (row) => {
          'id': row['id'],
          'name': row['name'],
          'category': row['category'],
          'price': row['price'],
          'available': row['available'] == 1,
        },
      )
      .toList();

  return Response.ok(
    jsonEncode(items),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> _createMenuItem(MySqlConnection db, Request request) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  await db.query(
    'INSERT INTO menu_items (name, category, price, available) VALUES (?, ?, ?, ?)',
    [
      body['name'],
      body['category'],
      body['price'],
      (body['available'] as bool) ? 1 : 0,
    ],
  );

  _broadcastMenuUpdated();
  return Response(201, body: jsonEncode({'message': 'Created'}));
}

Future<Response> _updateMenuItem(
  MySqlConnection db,
  Request request,
  int id,
) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  await db.query(
    'UPDATE menu_items SET name = ?, category = ?, price = ?, available = ? WHERE id = ?',
    [
      body['name'],
      body['category'],
      body['price'],
      (body['available'] as bool) ? 1 : 0,
      id,
    ],
  );

  _broadcastMenuUpdated();
  return Response.ok(jsonEncode({'message': 'Updated'}));
}

Future<Response> _deleteMenuItem(MySqlConnection db, int id) async {
  await db.query('DELETE FROM menu_items WHERE id = ?', [id]);
  _broadcastMenuUpdated();
  return Response.ok(jsonEncode({'message': 'Deleted'}));
}

void _handleSocket(WebSocketChannel socket) {
  clients.add(socket);
  socket.stream.listen(
    (_) {},
    onDone: () {
      clients.remove(socket);
    },
    onError: (_) {
      clients.remove(socket);
    },
  );
}

void _broadcastMenuUpdated() {
  for (final client in clients) {
    client.sink.add(jsonEncode({'type': 'menu-updated'}));
  }
}
