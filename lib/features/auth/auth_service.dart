import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  static const storage = FlutterSecureStorage();

  // ============================================================================
  // REGISTER
  // ============================================================================

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/register',
      {
        'email': email,
        'password': password,
      },
    );

    return response.statusCode == 200;
  }

  // ============================================================================
  // LOGIN
  // ============================================================================

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      '/auth/login',
      {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    await saveTokens(
      access: data['access_token'],
      refresh: data['refresh_token'],
    );

    return true;
  }

  // ============================================================================
  // SAVE TOKENS
  // ============================================================================

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await storage.write(
      key: 'access_token',
      value: access,
    );

    await storage.write(
      key: 'refresh_token',
      value: refresh,
    );

    await apiClient.setTokens(
      access: access,
      refresh: refresh,
    );
  }

  // ============================================================================
  // AUTO LOGIN
  // ============================================================================

  Future<void> loadSession() async {
    final access = await storage.read(
      key: 'access_token',
    );

    final refresh = await storage.read(
      key: 'refresh_token',
    );

    if (access != null && refresh != null) {
      await apiClient.setTokens(
        access: access,
        refresh: refresh,
      );
    }
  }

  // ============================================================================
  // REFRESH TOKEN
  // ============================================================================

  Future<bool> refreshToken() async {
    final refresh =
    await storage.read(key: 'refresh_token');

    if (refresh == null) {
      return false;
    }

    final response = await apiClient.post(
      '/auth/refresh',
      {
        'refresh_token': refresh,
      },
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    await saveTokens(
      access: data['access_token'],
      refresh: data['refresh_token'],
    );

    return true;
  }

  // ============================================================================
  // LOGOUT
  // ============================================================================

  Future<void> logout() async {
    await storage.deleteAll();

    await apiClient.setTokens(
      access: '',
      refresh: '',
    );
  }

  // ============================================================================
  // CHECK LOGIN
  // ============================================================================

  Future<bool> isLoggedIn() async {
    final token = await storage.read(
      key: 'access_token',
    );

    return token != null;
  }
}
