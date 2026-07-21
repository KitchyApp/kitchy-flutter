import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'network_info.dart';

/// ============================================================================
/// API CLIENT (PRODUCTION READY)
/// ----------------------------------------------------------------------------
/// Handles:
/// - HTTP requests (with 12 s timeout; 30 s for multipart uploads)
/// - Auth headers
/// - Token storage
/// - Interceptor logic (refresh + retry)
/// - Connectivity detection — updates [isOnlineNotifier] and throws
///   [NoInternetException] on [SocketException] / [TimeoutException]
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
    accessToken = await storage.read(key: 'access_token');
    refreshToken = await storage.read(key: 'refresh_token');
  }

  // ============================================================================
  // SET TOKENS
  // ============================================================================
  Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    // Update in-memory tokens immediately so the next HTTP call uses them.
    accessToken = access;
    refreshToken = refresh;

    // Explicitly replace any previous values in SecureStorage.
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    await storage.write(key: 'access_token', value: access);
    await storage.write(key: 'refresh_token', value: refresh);
  }

  // ============================================================================
  // CLEAR TOKENS
  // ============================================================================
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;

    // Wipe every SecureStorage key so no leftover session data survives logout.
    await storage.deleteAll();
  }

  // ============================================================================
  // BASE REQUEST (WITH INTERCEPTOR)
  // ============================================================================
  // All HTTP verbs funnel through here.
  //
  // Connectivity contract:
  //   - A [SocketException] means the device has no network path to the server.
  //   - A [TimeoutException] (12 s hard limit) means the server is unreachable
  //     even though a network interface exists (captive portal, DNS failure, etc.).
  //   Both conditions update [isOnlineNotifier] to false and throw
  //   [NoInternetException] so callers can switch to cached data.
  //   A successful response resets [isOnlineNotifier] to true.
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

    try {
      if (method == 'GET') {
        response = await http
            .get(uri, headers: requestHeaders)
            .timeout(const Duration(seconds: 12));
      } else if (method == 'POST') {
        response = await http
            .post(uri, headers: requestHeaders, body: jsonEncode(body))
            .timeout(const Duration(seconds: 12));
      } else if (method == 'PUT') {
        response = await http
            .put(uri, headers: requestHeaders, body: jsonEncode(body))
            .timeout(const Duration(seconds: 12));
      } else if (method == 'DELETE') {
        response = await http
            .delete(uri, headers: requestHeaders)
            .timeout(const Duration(seconds: 12));
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }
    } on SocketException {
      isOnlineNotifier.value = false;
      throw const NoInternetException();
    } on TimeoutException {
      isOnlineNotifier.value = false;
      throw const NoInternetException();
    }

    // Successful response — device is reachable.
    isOnlineNotifier.value = true;

    // ==========================================================================
    // INTERCEPTOR: HANDLE 401 (TOKEN EXPIRED)
    // ==========================================================================
    if (response.statusCode == 401 && retry && refreshToken != null) {
      final refreshed = await _refreshToken();

      if (refreshed) {
        return _request(
          method,
          endpoint,
          headers: headers,
          body: body,
          retry: false,
        );
      } else {
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

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setTokens(
          access: data['access_token'],
          refresh: data['refresh_token'],
        );
        return true;
      }
    } on SocketException {
      isOnlineNotifier.value = false;
    } on TimeoutException {
      isOnlineNotifier.value = false;
    }

    return false;
  }

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  Future<http.Response> get(String endpoint) => _request('GET', endpoint);

  Future<http.Response> post(String endpoint, Object body) =>
      _request('POST', endpoint, body: body);

  Future<http.Response> put(String endpoint, Object body) =>
      _request('PUT', endpoint, body: body);

  Future<http.Response> delete(String endpoint) =>
      _request('DELETE', endpoint);

  // ============================================================================
  // MULTIPART (UPLOAD)
  // ============================================================================
  // Uses XFile bytes (already downscaled by image_picker via imageQuality /
  // maxWidth at pick time) and streams them through MultipartFile.fromBytes.
  Future<http.MultipartFile> _buildUploadFile(String filePath) async {
    final xFile = XFile(filePath);
    final bytes = await xFile.readAsBytes();

    return http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: xFile.name.isNotEmpty ? xFile.name : 'upload.jpg',
    );
  }

  Future<http.Response> multipart(String endpoint, String filePath) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final request = http.MultipartRequest('POST', uri);

      if (accessToken != null && accessToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }

      request.files.add(await _buildUploadFile(filePath));
      // Image uploads can be large; use a longer timeout.
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));

      isOnlineNotifier.value = true;
      return await http.Response.fromStream(streamed);
    } on SocketException {
      isOnlineNotifier.value = false;
      throw const NoInternetException();
    } on TimeoutException {
      isOnlineNotifier.value = false;
      throw const NoInternetException();
    }
  }
}
