import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// TOKEN STORAGE
/// ----------------------------------------------------------------------------
/// Responsible ONLY for:
/// - Persisting tokens
/// - Retrieving tokens
/// - Clearing session
///
/// This decouples storage from business logic (best practice).
/// ============================================================================

class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  // ============================================================================
  // SAVE TOKENS
  // ============================================================================

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  // ============================================================================
  // LOAD TOKENS
  // ============================================================================

  Future<Map<String, String?>> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      "access": prefs.getString(_accessKey),
      "refresh": prefs.getString(_refreshKey),
    };
  }

  // ============================================================================
  // CLEAR TOKENS (LOGOUT)
  // ============================================================================

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}
