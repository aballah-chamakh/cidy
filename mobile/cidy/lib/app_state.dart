import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppState {
  static int notificationCount = 0;
  static const _storage = FlutterSecureStorage();

  static Future<String?> getJwtToken() async {
    return await _storage.read(key: 'jwt_token');
  }
}
