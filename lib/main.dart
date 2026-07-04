import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';

import 'core/app_api.dart';
import 'models/recipe.dart';
import 'services/ads_service.dart';
import 'widgets/recipe_card_premium.dart';
import 'premium_screen.dart';
import 'screens/login_screen.dart';

import 'core/api_client.dart';
import 'core/network_info.dart';
import 'features/auth/auth_service.dart';
import 'services/billing_service.dart';
import 'services/notification_service.dart';
import 'screens/favorites_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_settings_screen.dart';

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

  // Initialize local notifications plugin + timezone database.
  // Must run after ensureInitialized() and before runApp() so the plugin's
  // platform channel is ready before any widget tree is built.
  await NotificationService().init();

  // ── Start-screen resolution (inside try-catch — see comment below) ──────────
  // Routing must NOT happen inside MyApp.build(): at that point there is no
  // try-catch context and an uncaught exception silently kills the process.
  Widget startScreen = const LoginScreen();

  try {
    // ── Step 1: Onboarding gate ─────────────────────────────────────────────
    // The flag is written by OnboardingScreen on completion and lives in the
    // same FlutterSecureStorage instance used by ApiClient for tokens.
    // We read it BEFORE restoring the session so first-time users always see
    // the onboarding regardless of any stale token state.
    final seenOnboarding = await ApiClient.storage.read(
      key: 'has_seen_onboarding',
    );

    if (seenOnboarding != 'true') {
      // First launch (or reinstall that wiped the Keystore).
      // Skip session restoration entirely — user must onboard first.
      startScreen = const OnboardingScreen();
    } else {
      // ── Step 2: Session restoration (returning users) ───────────────────
      // authService.loadSession() reads both tokens from FlutterSecureStorage
      // and sets them in apiClient via apiClient.setTokens().
      await authService.loadSession();

      startScreen =
          apiClient.hasToken ? const HomePage() : const LoginScreen();
    }
  } catch (e, stack) {
    // FlutterSecureStorage throws PlatformException on Android when the
    // Keystore has data from a previous install that the new install cannot
    // decrypt (common during development / reinstalls).
    // We catch it, wipe the corrupt tokens, and fall back to LoginScreen.
    debugPrint('[INIT] Falha ao restaurar sessão: $e');
    debugPrint('[INIT] $stack');

    try {
      await apiClient.clearTokens();
    } catch (clearError) {
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
    _initHomeState();
    // Rebuild whenever connectivity changes so buttons enable/disable reactively.
    isOnlineNotifier.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    if (mounted) setState(() {});
  }

  // Chains loadUserStatus → manageAppNotifications in the correct order.
  // Both are awaited so notifications are always configured with the real
  // plan value — never with the default isPremiumUser=false before the
  // server responds.
  Future<void> _initHomeState() async {
    final status = await loadUserStatus();

    // mounted must be checked after every await — the user may have navigated
    // away while the HTTP request was in flight.
    if (!mounted) return;

    final bool premium = status?['is_premium'] == true;

    // Apply notification policy immediately after plan is confirmed:
    //   premium → cancel all reminders (never bother paying customers)
    //   free    → schedule 3-day retention reminder at 19:00
    //
    // Fire-and-forget: notification scheduling is a background operation and
    // must never block the UI. Errors are swallowed inside manageAppNotifications.
    NotificationService().manageAppNotifications(premium);
  }

  @override
  void dispose() {
    isOnlineNotifier.removeListener(_onConnectivityChange);
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
  // Returns the raw status map on success, null on any error.
  // Callers that don't need the map (initState, generateFromText, uploadImage)
  // simply ignore the return value — no call-site changes required.
  Future<Map<String, dynamic>?> loadUserStatus() async {
    try {
      final response = await appApi.getUserStatus();

      // mounted must be checked after every await before any setState
      if (!mounted) return null;

      // Defensive read: "== true" survives null, int, String, or any
      // unexpected type that a "as bool" hard cast would crash on in AOT.
      final bool premium = response['is_premium'] == true;

      setState(() => isPremiumUser = premium);
      return response;
    } catch (e, stack) {
      // Never crash the app if status fetch fails.
      // Default stays false (free tier) which is the safe fallback.
      debugPrint('[UserStatus] Erro ao obter status: $e');
      debugPrint('[UserStatus] Stack: $stack');
      return null;
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
  // OPEN PAYWALL
  // ============================================================================
  // Single entry-point for showing the upgrade screen.
  //
  //  fromLimit = true  → triggered by a 403 quota block
  //  fromLimit = false → triggered manually ("Ver Planos" button)
  //
  // For premium users who already hit their 4-per-day limit, there is nothing
  // to upgrade — show a plain SnackBar instead of the paywall.
  Future<void> _openPaywall({bool fromLimit = false}) async {
    if (!mounted) return;

    if (isPremiumUser && fromLimit) {
      // Already on premium plan — just inform the user about the daily limit.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Limite diário de 4 receitas atingido. Volta amanhã! 🍽️"),
          backgroundColor: Color(0xFFFF7043),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Log analytics before opening the screen (fire-and-forget).
    appApi.logEvent(
      'paywall_displayed',
      metadata: {
        'plan': isPremiumUser ? 'premium' : 'free',
        'trigger': fromLimit ? 'limit_403' : 'manual',
      },
    );

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          billingService: billingService,
          // After a successful purchase the PaywallScreen calls this callback
          // before popping, so the HomePage state is updated the moment the
          // user returns — no extra refresh step needed.
          onPurchaseSuccess: () async {
            final status = await loadUserStatus();
            if (!mounted) return;
            setState(() {
              isPremiumUser = status?['is_premium'] == true;
            });

            // Cancel all scheduled notifications the instant premium is
            // confirmed — before the UI even finishes updating.
            // We pass true directly rather than reading isPremiumUser from
            // state because setState above may not have flushed yet.
            NotificationService().manageAppNotifications(true);
          },
        ),
      ),
    );
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

    // ── Phase 1: Ad slot (before the API call) ───────────────────────────────
    // Free users see "A carregar anúncio..." for 3 s while the interstitial
    // plays (or is simulated). Premium users see the normal message instantly.
    if (!mounted) return;
    setState(() {
      isLoading = true;
      loadingMessage =
          isPremiumUser ? "A gerar receitas com IA..." : "A carregar anúncio...";
      responseText = "";
      recipes = [];
    });

    // Await the ad — premium returns in < 1 ms, free waits 3 s.
    await AdsService.showInterstitialAdIfNeeded(isPremiumUser);

    // ── Phase 2: API call ────────────────────────────────────────────────────
    // Update the message now that the ad slot is over, then fire the animation
    // and the HTTP request in parallel.
    if (!mounted) return;
    setState(() => loadingMessage = "A gerar receitas com IA...");

    // Fire-and-forget animation — mounted checks are inside _startLoadingAnimation
    _startLoadingAnimation();

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

      // Refresh plan status after generation (quota counter may have changed).
      await loadUserStatus();

    } on DailyLimitExceededException {
      if (!mounted) return;
      setState(() => isLoading = false);
      _openPaywall(fromLimit: true);

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
    // ── Phase 1: Ad slot (before the API call) ───────────────────────────────
    // Same pattern as generateFromText: Free users wait 3 s on the ad overlay,
    // Premium users skip straight to the camera analysis message.
    if (!mounted) return;
    setState(() {
      isLoading = true;
      loadingMessage =
          isPremiumUser ? "A analisar ingredientes..." : "A carregar anúncio...";
      responseText = "";
    });

    // Await the ad — premium returns in < 1 ms, free waits 3 s.
    await AdsService.showInterstitialAdIfNeeded(isPremiumUser);

    // ── Phase 2: API call ────────────────────────────────────────────────────
    if (!mounted) return;
    setState(() => loadingMessage = "A analisar ingredientes...");

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

      // Refresh plan status after generation (quota counter may have changed).
      await loadUserStatus();

    } on DailyLimitExceededException {
      if (!mounted) return;
      setState(() => isLoading = false);
      _openPaywall(fromLimit: true);

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

  // Daily limit is enforced exclusively by the backend (/generate-recipes/ and /analyze-image/).
  // The backend returns 403 when the limit is reached, which both endpoints
  // catch as DailyLimitExceededException and forward to _openPaywall().
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
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.person),
            tooltip: 'Perfil',
          ),
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

      body: Column(
        children: [
          // ── Offline banner — shown reactively without full rebuild ────────
          ValueListenableBuilder<bool>(
            valueListenable: isOnlineNotifier,
            builder: (_, isOnline, __) => isOnline
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estás em modo offline. A mostrar dados guardados.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          Expanded(
            child: Stack(
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
                    onPressed: (isLoading || !isOnlineNotifier.value)
                        ? null
                        : generateFromText,
                    child: const Text("Gerar receitas com IA"),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: (isLoading || !isOnlineNotifier.value)
                        ? null
                        : takePhoto,
                    child: const Text("Fotografar ingredientes"),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _openPaywall,
                    icon: const Icon(Icons.workspace_premium),
                    label: const Text("Ver Planos Premium"),
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
            ),   // Stack
          ),     // Expanded
        ],
      ),         // Column (body)
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
            onPressed: () {
              // Log intent before opening the share sheet.
              // Fire-and-forget — never awaited so the sheet opens instantly.
              appApi.logEvent(
                'share_triggered',
                metadata: {
                  'source': 'recipe_detail',
                  'recipe_title': recipe.title,
                },
              );
              SharePlus.instance.share(
                ShareParams(text: recipe.toShareText()),
              );
            },
            icon: const Icon(Icons.share),
            tooltip: "Partilhar receita",
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