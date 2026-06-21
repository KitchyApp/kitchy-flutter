import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import 'api_client.dart';

/// ============================================================================
/// APP API SERVICE
/// ----------------------------------------------------------------------------
/// High-level API abstraction for app features.
///
/// Responsibilities:
/// - Calls backend endpoints
/// - Parses responses
/// - Keeps UI clean
///
/// IMPORTANT:
/// - Uses ApiClient (NOT raw http)
/// - Ready for interceptor (auth, retry, refresh)
/// ============================================================================

class AppApi {
  final ApiClient client;

  AppApi(this.client);

  // ============================================================================
  // GET USER STATUS
  // ============================================================================
  Future<Map<String, dynamic>> getUserStatus() async {
    final response = await client.get('/auth/user/status');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to fetch user status');
  }

  // ============================================================================
  // GET RECIPES (TEST)
  // ============================================================================
  Future<List<Recipe>> getRecipes() async {
    final response = await client.get('/recipes');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final recipes = data['recipes'];

      return List<Recipe>.from(
        recipes.map((r) => Recipe.fromJson(r)),
      );
    }

    throw Exception('Failed to fetch recipes');
  }

  // ============================================================================
  // UPLOAD IMAGE
  // ============================================================================
  Future<Map<String, dynamic>> uploadImage(String path) async {
    final response = await client.multipart(
      '/upload',
      path,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Image upload failed');
  }
}