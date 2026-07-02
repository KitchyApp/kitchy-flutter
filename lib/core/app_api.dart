import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import 'api_client.dart';

/// Thrown when the backend returns HTTP 403 (daily analysis limit reached).
/// The caller decides how to present the upgrade dialog.
class DailyLimitExceededException implements Exception {
  const DailyLimitExceededException();
  @override
  String toString() => 'DailyLimitExceededException';
}

/// ============================================================================
/// APP API SERVICE
/// ----------------------------------------------------------------------------
/// High-level API abstraction for app features.
///
/// Responsibilities:
/// - Calls backend endpoints
/// - Parses responses into typed Dart objects
/// - Translates HTTP status codes into typed exceptions
///
/// IMPORTANT:
/// - Uses ApiClient (NOT raw http) — gets auth headers + refresh interceptor
/// ============================================================================

class AppApi {
  final ApiClient client;

  AppApi(this.client);

  // ============================================================================
  // GET USER STATUS  →  GET /auth/user/status
  // ============================================================================
  // Returns the real plan from the database: { is_premium, plan, plan_expiry }
  //
  // SAFETY: jsonDecode returns `dynamic`. The implicit cast to Map<String,dynamic>
  // is checked at runtime in AOT (release) mode and can throw _CastError if the
  // server returns an unexpected body (empty string, HTML error page, etc.).
  // We perform an explicit `is` check and fall back to a safe default map so
  // the caller never receives a non-Map value, regardless of server state.
  Future<Map<String, dynamic>> getUserStatus() async {
    final response = await client.get('/auth/user/status');

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      // Unexpected JSON shape — return safe defaults rather than crashing.
      debugPrint(
        '[getUserStatus] Resposta inesperada do servidor: ${response.body}',
      );
      return {'is_premium': false, 'plan': 'free', 'plan_expiry': null};
    }

    throw Exception(
      'Falha ao obter estado do utilizador: HTTP ${response.statusCode}',
    );
  }

  // ============================================================================
  // GET RECIPES (STATIC TEST DATA)  →  GET /recipes
  // ============================================================================
  Future<List<Recipe>> getRecipes() async {
    final response = await client.get('/recipes');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Recipe>.from(
        (data['recipes'] as List).map((r) => Recipe.fromJson(r)),
      );
    }

    throw Exception('Failed to fetch recipes: ${response.statusCode}');
  }

  // ============================================================================
  // GENERATE RECIPES FROM TEXT  →  POST /generate-recipes/
  // ============================================================================
  // Sends a comma-separated ingredient string typed by the user.
  // The backend splits, normalises and passes the list to OpenAI.
  //
  // Returns the same shape as uploadImage():
  //   { "ingredients_detected": [...], "recipes": [...] }
  //
  // Throws [DailyLimitExceededException] on HTTP 403.
  Future<Map<String, dynamic>> generateRecipesFromText(
    String ingredients,
  ) async {
    final response = await client.post(
      '/generate-recipes/',
      {'ingredients': ingredients},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 403) {
      throw const DailyLimitExceededException();
    }

    throw Exception(
      'Falha ao gerar receitas: ${response.statusCode} — ${response.body}',
    );
  }

  // ============================================================================
  // UPLOAD IMAGE  →  POST /analyze-image/
  // ============================================================================
  // The backend endpoint:
  // - Validates the JWT (get_current_user dependency)
  // - Checks & increments the daily analysis counter (analyses_today)
  // - Returns HTTP 403 when the daily limit is reached
  // - Calls OpenAI Vision to detect ingredients
  // - Calls OpenAI to generate 1 recipe (Free) or 4 recipes (Premium)
  //
  // Throws [DailyLimitExceededException] on 403 so the caller can show
  // the Premium upgrade dialog without inspecting raw status codes.
  Future<Map<String, dynamic>> uploadImage(String path) async {
    final response = await client.multipart('/analyze-image/', path);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 403) {
      throw const DailyLimitExceededException();
    }

    throw Exception('Image upload failed: ${response.statusCode}');
  }

  // ============================================================================
  // GET PREFERENCES  →  GET /preferences
  // ============================================================================
  // Returns the current dietary preferences of the logged-in user:
  //   { dietary_gluten_free, dietary_vegetarian, dietary_vegan, preferred_cuisine }
  Future<Map<String, dynamic>> getPreferences() async {
    final response = await client.get('/preferences');

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {
        'dietary_gluten_free': false,
        'dietary_vegetarian': false,
        'dietary_vegan': false,
        'preferred_cuisine': 'international',
      };
    }

    throw Exception(
      'Falha ao obter preferências: HTTP ${response.statusCode}',
    );
  }

  // ============================================================================
  // UPDATE PREFERENCES  →  PUT /update-preferences
  // ============================================================================
  // Sends the user's dietary preferences to the backend, which persists them
  // in the User table and applies them on every subsequent recipe generation.
  //
  // Returns the saved preferences map on success.
  // Throws on any non-200 response so the caller can show an error message.
  Future<Map<String, dynamic>> updatePreferences({
    required bool glutenFree,
    required bool vegetarian,
    required bool vegan,
    required String preferredCuisine,
  }) async {
    final response = await client.put(
      '/update-preferences',
      {
        'dietary_gluten_free': glutenFree,
        'dietary_vegetarian': vegetarian,
        'dietary_vegan': vegan,
        'preferred_cuisine': preferredCuisine,
      },
    );

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    }

    throw Exception(
      'Falha ao guardar preferências: HTTP ${response.statusCode} — ${response.body}',
    );
  }

  // ============================================================================
  // LOG ANALYTICS EVENT  →  POST /analytics/log
  // ============================================================================
  // Fire-and-forget: always returns void, NEVER throws.
  //
  // Design rules:
  //  - The entire body is wrapped in try-catch — a network failure, 404, or
  //    any other error is silently swallowed so analytics never interrupts
  //    the main user experience.
  //  - The caller must NOT await this method (use it as unawaited fire-and-
  //    forget). Awaiting would block the UI thread until the server responds.
  //  - metadata is optional; omit it for events with no extra context.
  //
  // Usage:
  //   appApi.logEvent('paywall_displayed', metadata: {'plan': 'free'});
  //   appApi.logEvent('share_triggered',   metadata: {'source': 'recipe_detail'});
  Future<void> logEvent(
    String eventName, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await client.post(
        '/analytics/log',
        {
          'event_name': eventName,
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
      );
    } catch (e) {
      // Intentionally silent: analytics errors must never surface to the user.
      debugPrint('[AppApi.logEvent] Falha ao registar "$eventName": $e');
    }
  }
}
