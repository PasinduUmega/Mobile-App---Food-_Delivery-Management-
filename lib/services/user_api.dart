import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class UserApi {
  final http.Client _client = http.Client();

  UserApi();

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3005';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3005';
    return 'http://localhost:3005';
  }

  Future<Map<String, dynamic>> _requestJson(
    String method, {
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    try {
      late http.Response res;
      final headers = {'Content-Type': 'application/json; charset=utf-8'};

      if (method == 'GET') {
        res = await _client.get(uri, headers: headers);
      } else if (method == 'POST') {
        res = await _client.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      } else if (method == 'PUT') {
        res = await _client.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      } else if (method == 'DELETE') {
        res = await _client.delete(uri, headers: headers);
      } else {
        throw ArgumentError('Unsupported HTTP method: $method');
      }

      final decoded =
          res.body.isNotEmpty ? (jsonDecode(res.body) as Map<String, dynamic>) : <String, dynamic>{};

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = decoded["error"]?.toString() ?? decoded.toString();
        throw ApiException(statusCode: res.statusCode, message: message);
      }

      return decoded;
    } catch (e) {
      if (e is ApiException) rethrow;
      String message = e.toString();
      if (message.contains('SocketException') || message.contains('Connection timed out')) {
        message = 'Cannot connect to backend server at $_baseUrl. Please ensure the server is running and accessible.';
      }
      throw ApiException(statusCode: 0, message: 'Network error: $message');
    }
  }

  void dispose() {
    _client.close();
  }

  Future<({List<User> users, int total})> fetchUsers({int limit = 50, int offset = 0}) async {
    final json = await _requestJson('GET', path: '/api/users?limit=$limit&offset=$offset');
    final list = (json["data"] as List<dynamic>? ?? const []);
    final users = list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    final total = json["meta"]?["total"] as int? ?? users.length;
    return (users: users, total: total);
  }

  Future<User> fetchUser(int id) async {
    final json = await _requestJson('GET', path: '/api/users/$id');
    return User.fromJson(json["data"] as Map<String, dynamic>);
  }

  Future<User> createUser({
    required String name,
    required String email,
    required String mobile,
    required String address,
    required String password,
  }) async {
    final json = await _requestJson('POST', path: '/api/users', body: {
      "name": name,
      "email": email,
      "mobile": mobile,
      "address": address,
      "password": password,
    });
    return User.fromJson(json["data"] as Map<String, dynamic>);
  }

  Future<User> updateUser({
    required int id,
    String? name,
    String? email,
    String? mobile,
    String? address,
    bool? isVerified,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body["name"] = name;
    if (email != null) body["email"] = email;
    if (mobile != null) body["mobile"] = mobile;
    if (address != null) body["address"] = address;
    if (isVerified != null) body["isVerified"] = isVerified;
    if (password != null) body["password"] = password;

    final json = await _requestJson('PUT', path: '/api/users/$id', body: body);
    return User.fromJson(json["data"] as Map<String, dynamic>);
  }

  Future<void> deleteUser(int id) async {
    await _requestJson('DELETE', path: '/api/users/$id');
  }
}

