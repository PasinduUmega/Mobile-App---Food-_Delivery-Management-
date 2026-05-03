import { Platform } from 'react-native';

/**
 * Same as Flutter `lib/config.dart` / `AppConfig.apiBaseUrl`.
 * Android emulator: 10.0.2.2 → host. iOS sim: localhost.
 * Physical device: change to http://YOUR_LAN_IP:8080
 */
export const API_BASE_URL = Platform.select({
  android: 'http://10.0.2.2:8080',
  ios: 'http://127.0.0.1:8080',
  default: 'http://127.0.0.1:8080',
}).replace(/\/+$/, '');
