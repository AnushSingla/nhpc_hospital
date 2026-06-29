import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  // Mock login function
  static Future<String?> login(String username, String password) async {
    // Simulate a network delay
    await Future.delayed(Duration(seconds: 1));

    // Fake login check
    if (username == 'admin' && password == '12345') {
      const fakeToken = 'mock-jwt-token-1234567890';
      await _storage.write(key: 'jwt_token', value: fakeToken);
      return fakeToken;
    } else {
      return null;
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
}
