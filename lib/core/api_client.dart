import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ============================================================================
/// API CLIENT (PRODUCTION READY)
/// ----------------------------------------------------------------------------
/// Handles:
/// - HTTP requests
/// - Auth headers
/// - Token storage
/// - Interceptor logic (refresh + retry)
///
/// Security:
/// - Access token in memory
/// - Refresh token persisted
/// - Auto-rotation supported
/// ============================================================================

class ApiClient {
  final String baseUrl;

  static const storage = FlutterSecureStorage();

  String? accessToken;
  String? refreshToken;

  // Both tokens must be present — access token alone is insufficient because
  // a missing refresh token means the 401 interceptor cannot recover the session.
  bool get hasToken =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      refreshToken != null &&
      refreshToken!.isNotEmpty;

  ApiClient({required this.baseUrl});

  // ============================================================================
  // INIT
  // ============================================================================
  Future<void> init() async {
    accessToken = await storage.read(
      key: 'access_token',
    );

    refreshToken = await storage.read(
      key: 'refresh_token',
    );

  }

  // ============================================================================
  // SET TOKENS
  // ============================================================================
  Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    accessToken = access;
    refreshToken = refresh;

    await storage.write(
      key: 'access_token',
      value: access,
    );

    await storage.write(
      key: 'refresh_token',
      value:refresh,
    );
  }

  // ============================================================================
  // CLEAR TOKENS
  // ============================================================================
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;

    await storage.delete(
      key: 'access_token',
    );

    await storage.delete(
      key: 'refresh_token',
    );
  }

  // ============================================================================
  // BASE REQUEST (WITH INTERCEPTOR)
  // ============================================================================
  Future<http.Response> _request(
      String method,
      String endpoint, {
        Map<String, String>? headers,
        Object? body,
        bool retry = true,
      }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final requestHeaders = {
      'Content-Type': 'application/json',
      if (accessToken != null && accessToken!.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
      ...?headers,
    };

    http.Response response;

    if (method == 'GET') {
      response = await http.get(uri, headers: requestHeaders);
    } else if (method == 'POST') {
      response = await http.post(
        uri,
        headers: requestHeaders,
        body: jsonEncode(body),
      );
    }
    else if (method == 'DELETE') {
      response = await http.delete(
        uri,
        headers: requestHeaders,
      );
    }
    else {
      throw Exception('Unsupported HTTP method');
    }

    // ==========================================================================
    // INTERCEPTOR: HANDLE 401 (TOKEN EXPIRED)
    // ==========================================================================
    if (response.statusCode == 401 && retry && refreshToken != null) {
      final refreshed = await _refreshToken();

      if (refreshed) {
        // 🔁 RETRY ORIGINAL REQUEST
        return _request(
          method,
          endpoint,
          headers: headers,
          body: body,
          retry: false,
        );
      } else {
        // 🔐 FORCE LOGOUT
        await clearTokens();
        throw Exception('Session expired. Please login again.');
      }
    }

    return response;
  }

  // ============================================================================
  // REFRESH TOKEN
  // ============================================================================
  Future<bool> _refreshToken() async {
    final uri = Uri.parse('$baseUrl/auth/refresh');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      await setTokens(
        access: data['access_token'],
        refresh: data['refresh_token'],
      );

      return true;
    }

    return false;
  }

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  Future<http.Response> get(String endpoint) {
    return _request('GET', endpoint);
  }

  Future<http.Response> post(String endpoint, Object body) {
    return _request('POST', endpoint, body: body);
  }

  Future<http.Response> delete(String endpoint) {
    return _request('DELETE', endpoint);
  }

  // ============================================================================
  // MULTIPART (UPLOAD)
  // ============================================================================
  Future<http.Response> multipart(String endpoint, String filePath) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final request = http.MultipartRequest('POST', uri);

    if (accessToken != null && accessToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send();
    return await http.Response.fromStream(streamed);
  }
}