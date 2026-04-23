class AppConfig {
  // For Android emulator, use: http://10.0.2.2:8080
  // For iOS simulator, use: http://localhost:8080
  // For real device, use your PC LAN IP: http://192.168.x.x:8080
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}

