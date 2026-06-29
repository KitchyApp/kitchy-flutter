import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/app_api.dart';
import 'models/recipe.dart';
import 'services/ads_service.dart';
import 'widgets/recipe_card_premium.dart';
import 'premium_screen.dart';
import 'screens/login_screen.dart';

import 'core/api_client.dart';
import 'features/auth/auth_service.dart';
import 'services/billing_service.dart';
import 'screens/favorites_screen.dart';

const String baseUrl = "http://10.0.2.2:8000";

// ============================================================================
// GLOBAL SERVICES (SINGLETON STYLE)
// ============================================================================
final ApiClient apiClient = ApiClient(baseUrl: baseUrl);
final BillingService billingService = BillingService(apiClient);
final AuthService authService = AuthService(apiClient);
final AppApi appApi = AppApi(apiClient);

// ============================================================================
// MAIN
// ============================================================================
void main() async {
  // Must be the very first line — required by FlutterSecureStorage and any
  // plugin that accesses platform channels during initialisation.
  WidgetsFlutterBinding.ensureInitialized();

  // Decide the start screen here, inside try-catch, so any SecureStorage /
  // Keystore failure is caught before runApp() is called.
  // Routing must NOT happen inside MyApp.build() — at that point there is no
  // try-catch context and an uncaught exception silently kills the process.
  Widget startScreen = const LoginScreen();

  try {
    // Single point of session restoration.
    // authService.loadSession() reads both tokens from FlutterSecureStorage
    // and sets them in apiClient via apiClient.setTokens() — so apiClient.init()
    // is not needed and has been removed to avoid a redundant double-read.
    await authService.loadSession();

    startScreen =
        apiClient.hasToken ? const HomePage() : const LoginScreen();
  } catch (e, stack) {
    // FlutterSecureStorage throws PlatformException on Android when the
    // Keystore has data from a previous install that the new install cannot
    // decrypt (common during development / reinstalls).
    // We catch it, wipe the corrupt tokens, and fall back to LoginScreen
    // instead of crashing with "Lost connection to device".
    debugPrint('[INIT] Falha ao restaurar sessão: $e');
    debugPrint('[INIT] $stack');

    try {
      await apiClient.clearTokens();
    } catch (clearError) {
      // clearTokens() itself can fail if the Keystore is fully inaccessible.
      // Ignore — we are already going to LoginScreen.
      debugPrint('[INIT] Não foi possível limpar tokens: $clearError');
    }

    startScreen = const LoginScreen();
  }

  // Ads init (uncomment when AdMob unit IDs are production-ready)
  // MobileAds.instance.initialize();

  runApp(MyApp(home: startScreen));
}

// ============================================================================
// APP ROOT
// ============================================================================
class MyApp extends StatelessWidget {
  // The start screen is resolved in main() inside a try-catch before runApp()
  // is called, so routing failures are caught and handled gracefully.
  final Widget home;

  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFF8F3),

        primaryColor: const Color(0xFFFF7043),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7043),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF7043),
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7043),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),

      home: home,
    );
  }
}

// ============================================================================
// HOME PAGE
// ============================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String responseText = "";

  // isPremiumUser is always loaded from GET /auth/user/status on startup.
  // It is NEVER read from local storage — the backend is the single source
  // of truth for the user's plan.
  bool isPremiumUser = false;

  List<Recipe> recipes = [];

  final ImagePicker picker = ImagePicker();
  String ingredientsDetected = "";
  final TextEditingController ingredientsController = TextEditingController();

  bool isLoading = false;
  String loadingMessage = "A analisar ingredientes...";

  // ============================================================================
  // INIT / DISPOSE
  // ============================================================================
  @override
  void initState() {
    super.initState();
    loadUserStatus();
  }

  @override
  void dispose() {
    ingredientsController.dispose();
    super.dispose();
  }

  // ============================================================================
  // USER STATUS  →  GET /auth/user/status
  // ============================================================================
  // Fetches the real plan from the database on every app start and after any
  // operation that may change it (e.g. purchase verification).
  // Never reads isPremiumUser from local storage.
  // SAFETY RULES:
  //  - Never use "as bool" hard cast — use == true to survive null fields
  //  - Always check mounted before setState (called from initState fire-and-forget)
  //  - Catch (e, stack) to log the full trace — never let status failures crash
  Future<void> loadUserStatus() async {
    try {
      final response = await appApi.getUserStatus();

      // mounted must be checked after every await before any setState
      if (!mounted) return;

      // Defensive read: "== true" survives null, int, String, or any
      // unexpected type that a "as bool" hard cast would crash on in AOT.
      final bool premium = response['is_premium'] == true;

      setState(() => isPremiumUser = premium);
    } catch (e, stack) {
      // Never crash the app if status fetch fails.
      // Default stays false (free tier) which is the safe fallback.
      debugPrint('[UserStatus] Erro ao obter status: $e');
      debugPrint('[UserStatus] Stack: $stack');
    }
  }

  // ============================================================================
  // LOADING ANIMATION
  // ============================================================================
  // IMPORTANT: always call without await (fire-and-forget) but MUST check
  // mounted before every setState — otherwise crashes in release mode when
  // the widget is disposed while the delay is still running.
  Future<void> _startLoadingAnimation() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => loadingMessage = "A gerar receitas...");
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => loadingMessage = "Quase pronto...");
  }

  // ============================================================================
  // API CALLS
  // ============================================================================
  Future<void> generateFromText() async {
    // ── Validation ──────────────────────────────────────────────────────────
    final ingredients = ingredientsController.text.trim();

    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Escreve os ingredientes antes de gerar."),
          backgroundColor: Color(0xFFFF7043),
        ),
      );
      return;
    }

    // ── Start loading ────────────────────────────────────────────────────────
    if (!mounted) return;
    setState(() {
      isLoading = true;
      loadingMessage = "A gerar receitas com IA...";
      responseText = "";
      recipes = [];
    });

    // Fire-and-forget animation — mounted checks are inside _startLoadingAnimation
    _startLoadingAnimation();

    // ── API call ─────────────────────────────────────────────────────────────
    try {
      final data = await appApi.generateRecipesFromText(ingredients);

      // Always check mounted after any await before calling setState
      if (!mounted) return;

      final rawIngredients = data["ingredients_detected"];
      final detected = rawIngredients is List
          ? (rawIngredients as List).join(", ")
          : rawIngredients.toString();

      final List<Recipe> parsed = [];
      for (final r in data["recipes"] as List) {
        parsed.add(Recipe.fromJson(r as Map<String, dynamic>));
      }

      setState(() {
        isLoading = false;
        ingredientsDetected = detected;
        recipes = parsed;
      });

      await loadUserStatus();

      if (!mounted) return;
      if (!isPremiumUser) AdsService.showInterstitial();

    } on DailyLimitExceededException {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showLimitDialog();

    } catch (e, stack) {
      debugPrint('[generateFromText] Erro: $e');
      debugPrint('[generateFromText] Stack: $stack');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        responseText = "Erro ao gerar receitas. Tenta novamente.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro: $e"),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> takePhoto() async {
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (photo != null) {
      await uploadImage(photo.path);
    }
  }

  Future<void> uploadImage(String path) async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      loadingMessage = "A analisar ingredientes...";
      responseText = "";
    });

    // Fire-and-forget animation — mounted checks are inside _startLoadingAnimation
    _startLoadingAnimation();

    try {
      final data = await appApi.uploadImage(path);

      if (!mounted) return;

      final List<Recipe> parsed = [];
      for (final r in data["recipes"] as List) {
        parsed.add(Recipe.fromJson(r as Map<String, dynamic>));
      }

      setState(() {
        isLoading = false;
        ingredientsDetected = data["ingredients_detected"].toString();
        recipes = parsed;
      });

      await loadUserStatus();

      if (!mounted) return;
      if (!isPremiumUser) AdsService.showInterstitial();

    } on DailyLimitExceededException {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showLimitDialog();

    } catch (e, stack) {
      debugPrint('[uploadImage] Erro: $e');
      debugPrint('[uploadImage] Stack: $stack');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        responseText = "Erro ao enviar imagem. Tenta novamente.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro: $e"),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Limite atingido"),
        content: Text(
          isPremiumUser
              ? "Atingiste o limite de análises de hoje (4). Volta amanhã!"
              : "Já usaste a tua análise gratuita de hoje.\nFaz upgrade para Premium e analisa até 4 vezes por dia!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          if (!isPremiumUser)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PremiumScreen()),
                );
                if (result == true) await loadUserStatus();
              },
              child: const Text("Ir para Premium"),
            ),
        ],
      ),
    );
  }

  // Daily limit is enforced exclusively by the backend (/analyze-image/).
  // The backend returns 403 when the limit is reached, which uploadImage()
  // catches and converts to a _showLimitDialog() call.
  // There is no local counter — the server's analyses_today is the
  // single source of truth.

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset: true is the Flutter default, but we set it
      // explicitly. When the soft keyboard opens, the Scaffold shrinks the body
      // height. Without this, a Column+Expanded layout collapses to negative
      // height → RenderFlex fatal error → "Lost connection" in release mode.
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        title: const Text("Kitchy"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FavoritesScreen(),
                ),
              );
            },
            icon: const Icon(Icons.favorite),
          ),
          IconButton(
            onPressed: () async {
              await authService.logout();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: Stack(
        children: [
          // ── Main scrollable content ──────────────────────────────────────
          // SingleChildScrollView + Column replaces the old Column+Expanded
          // pattern. When the keyboard opens the Scaffold shrinks the body;
          // SingleChildScrollView absorbs that resize gracefully instead of
          // crashing with a RenderFlex negative-height error.
          IgnorePointer(
            ignoring: isLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Transforma ingredientes em receitas incríveis",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TextField — hardened against emulator keyboard crashes:
                  //  - autofocus: false  → never forces the keyboard open on
                  //    build; Impeller/Skia only render the keyboard on explicit
                  //    tap, avoiding a re-render race on screen load.
                  //  - keyboardType: TextInputType.text (explicit, not inferred)
                  //  - enableSuggestions / autocorrect: false  → disables the
                  //    InlineSuggestionsRequest path that triggers a secondary
                  //    InputConnection callback known to crash x86_64 Impeller.
                  //  - onSubmitted unfocuses cleanly to dismiss the keyboard
                  //    without triggering another viewport resize event.
                  TextField(
                    controller: ingredientsController,
                    autofocus: false,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    enableSuggestions: false,
                    autocorrect: false,
                    // maxLines: null would grow unbounded; 4 is a safe fixed height.
                    maxLines: 4,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),

                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "Ex: ovos, tomate, queijo",
                      labelText: "Que ingredientes tens em casa?",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF7043),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                      prefixIcon: const Icon(Icons.restaurant_menu),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: isLoading ? null : generateFromText,
                    child: const Text("Gerar receitas com IA"),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: isLoading ? null : takePhoto,
                    child: const Text("Fotografar ingredientes"),
                  ),

                  const SizedBox(height: 20),

                  if (responseText.isNotEmpty)
                    Text(responseText, textAlign: TextAlign.center),

                  if (ingredientsDetected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      "Ingredientes detectados:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(ingredientsDetected),
                  ],

                  const SizedBox(height: 20),

                  // ── Recipe / skeleton list ───────────────────────────────
                  // shrinkWrap: true + NeverScrollableScrollPhysics lets the
                  // inner ListView measure itself and hand scrolling to the
                  // outer SingleChildScrollView — no Expanded needed, no
                  // height constraint errors when keyboard is open.
                  if (isLoading)
                    Column(
                      children: List.generate(
                        3,
                        (_) => Container(
                          height: 100,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    )
                  else if (recipes.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = recipes[index];
                        return RecipeCardPremium(
                          recipe: recipe,
                          isUnlocked: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailScreen(recipe: recipe),
                            ),
                          ),
                        );
                      },
                    ),

                  // Bottom padding so content is never hidden behind the
                  // keyboard when the user scrolls all the way down.
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Full-screen loading overlay ──────────────────────────────────
          // Rendered on top of the Stack; safe to use here because it doesn't
          // participate in the Column layout — no height constraint conflict.
          if (isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFFF7043)),
                    const SizedBox(height: 20),
                    Text(
                      loadingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// RECIPE DETAIL
// ============================================================================
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
  });

  Widget nutritionCard(
      String label,
      String value,
      IconData icon,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFF7043),
            ),

            const SizedBox(height: 8),

            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vitamins = recipe.vitamins ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),

        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
          ),

          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // =====================================================
            // TITLE
            // =====================================================

            Text(
              recipe.title,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.timer,
                  color: Color(0xFFFF7043),
                ),

                const SizedBox(width: 8),

                Text(
                  "${recipe.timeMinutes} min",
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // =====================================================
            // MACROS
            // =====================================================

            sectionTitle("Nutrição"),

            Row(
              children: [
                nutritionCard(
                  "Kcal",
                  "${recipe.calories}",
                  Icons.local_fire_department,
                ),

                nutritionCard(
                  "Proteína",
                  "${recipe.protein}g",
                  Icons.fitness_center,
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                nutritionCard(
                  "Carbs",
                  "${recipe.carbs}g",
                  Icons.rice_bowl,
                ),

                nutritionCard(
                  "Gordura",
                  "${recipe.fat}g",
                  Icons.opacity,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // =====================================================
            // STEPS
            // =====================================================

            sectionTitle("Passos"),

            ...List.generate(
              recipe.steps.length,
                  (index) {
                final step = recipe.steps[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),

                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Container(
                        width: 34,
                        height: 34,

                        decoration: const BoxDecoration(
                          color: Color(0xFFFF7043),
                          shape: BoxShape.circle,
                        ),

                        child: Center(
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // =====================================================
            // OPTIONAL INGREDIENTS
            // =====================================================

            if (recipe.optionalIngredients.isNotEmpty) ...[
              sectionTitle("Ingredientes em falta"),

              Wrap(
                spacing: 10,
                runSpacing: 10,

                children: recipe.optionalIngredients.map((ingredient) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),

                    child: Text(ingredient),
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),
            ],

            // =====================================================
            // VITAMINS
            // =====================================================

            if (vitamins.isNotEmpty) ...[
              sectionTitle("Vitaminas"),

              Container(
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),

                child: Column(
                  children: vitamins.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),

                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,

                        children: [
                          Text(entry.key),

                          Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}