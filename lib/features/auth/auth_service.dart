import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';

/// ============================================================================
/// AUTH SERVICE
/// ----------------------------------------------------------------------------
/// Centralizes all authentication logic.
///
/// Responsibilities:
/// - Login (API call)
/// - Token persistence
/// - Session restoration (auto-login)
/// - Logout
///
/// Architecture:
/// - Keeps UI clean (no business logic in widgets)
/// - Delegates HTTP to ApiClient
/// - Uses SharedPreferences for local persistence
///
/// Security:
/// - Tokens are stored locally (for now)
/// - Ready for future secure storage upgrade (FlutterSecureStorage)
/// ============================================================================

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  // ============================================================================
  // LOGIN
  // ============================================================================
  /// Authenticates user against backend.
  ///
  /// Flow:
  /// 1. Sends credentials to API
  /// 2. Receives access + refresh tokens
  /// 3. Persists tokens locally
  /// 4. Updates ApiClient state
  ///
  /// Returns:
  /// - true if login successful
  /// - false otherwise
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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      await apiClient.setTokens(
        access: data['access_token'],
        refresh: data['refresh_token'],
      );

      return true;
    }

    return false;
  }

  // ============================================================================
  // LOAD SESSION (AUTO LOGIN)
  // ============================================================================
  /// Restores user session from local storage.
  ///
  /// Use case:
  /// - App startup
  /// - Avoid forcing user to login again
  ///
  /// Flow:
  /// 1. Reads tokens from SharedPreferences
  /// 2. If present → inject into ApiClient
  ///
  /// IMPORTANT:
  /// - Does NOT validate token with backend
  /// - Interceptor will handle expiration automatically
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    final access = prefs.getString('access_token');
    final refresh = prefs.getString('refresh_token');

    if (access != null && refresh != null) {
      apiClient.setTokens(
        access: access,
        refresh: refresh,
      );
    }
  }

  // ============================================================================
  // LOGOUT
  // ============================================================================
  /// Clears user session completely.
  ///
  /// Flow:
  /// 1. Remove tokens from local storage
  /// 2. Reset ApiClient state
  ///
  /// Result:
  /// - User is fully logged out
  /// - Requires new login
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    apiClient.setTokens(
      access: '',
      refresh: '',
    );
  }
}
