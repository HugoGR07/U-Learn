import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _tokenKey = 'ul_auth_token';
  static const _userKey = 'ul_auth_user';
  static const _installFlagKey = 'ul_app_installed';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<void> save(String token, Map<String, dynamic>? user) async {
    await saveToken(token);
    if (user != null) await saveUser(user);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user));
    } catch (_) {}
  }

  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  static Future<({String token, Map<String, dynamic>? user})?> load() async {
    try {
      await _limpiarSiEsReinstalacion();

      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return null;

      if (isTokenExpired(token)) {
        await clear();
        return null;
      }

      Map<String, dynamic>? user;
      final rawUser = await _storage.read(key: _userKey);
      if (rawUser != null) {
        user = Map<String, dynamic>.from(jsonDecode(rawUser) as Map);
      }
      return (token: token, user: user);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }

  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return false;
      final expiraEn = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiraEn.subtract(const Duration(seconds: 60)));
    } catch (_) {
      return true;
    }
  }

  static Future<void> _limpiarSiEsReinstalacion() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_installFlagKey) != true) {
      await _storage.deleteAll();
      await prefs.setBool(_installFlagKey, true);
    }
  }
}