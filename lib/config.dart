import 'package:flutter/foundation.dart';
import 'dart:io';

class AppConfig {
  static String get apiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (Platform.isAndroid) {
      return 'http://10.245.37.182:8080'; // Your current WiFi IP
    }
    if (Platform.isIOS) {
      return 'http://localhost:8080';
    }
    return 'http://localhost:8080';
  }
}
