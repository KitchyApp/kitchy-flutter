import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_api.dart';
import 'models/recipe.dart';
import 'services/ads_service.dart';
import 'widgets/recipe_card_premium.dart';
import 'premium_screen.dart';
import 'login_screen.dart';

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
  WidgetsFlutterBinding.ensureInitialized();
  // Load tokens BEFORE app starts
  await apiClient.init();
  // Ads init
  // MobileAds.instance.initialize();
  // AdsService.loadInterstitial();

  // Restore session
  await authService.loadSession();
  runApp(const MyApp());
}

// ============================================================================
// APP ROOT
// ============================================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

      home: apiClient.hasToken
          ? const HomePage()
          : const LoginScreen(),
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

  bool isPremiumUser = false;
  int dailyLimitFree = 1;
  int dailyLimitPremium = 4;

  int recipesUsedToday = 0;
  DateTime? lastUsageDate;

  List<Recipe> recipes = [];

  final ImagePicker picker = ImagePicker();
  String ingredientsDetected = "";
  final TextEditingController ingredientsController = TextEditingController();

  bool isLoading = false;
  String loadingMessage = "A analisar ingredientes...";

  // ============================================================================
  // INIT ( CORRETO - BillingService aqui)
  // ============================================================================
  @override
  void initState() {
    super.initState();

    initApp();
  }
  Future<void> initApp() async {
    final stopwatch = Stopwatch()
      ..start();

    print(
      "INIT 1 START loadData",
    );

    await loadData();

    print(
      "INIT 2 START loadUserStatus",
    );

    await loadUserStatus();

    print(
      "INIT 2 END (${stopwatch.elapsedMilliseconds}ms)",
    );

    print(
      "INIT 3 END (${stopwatch.elapsedMilliseconds}ms)",
    );

    print(
      "INIT DONE (${stopwatch.elapsedMilliseconds}ms)",
    );
  }
  // ============================================================================
  // USER STATUS
  // ============================================================================
  Future<void> loadUserStatus() async {
    try {
      final response = await appApi.getUserStatus();

      setState(() {
        isPremiumUser = response["is_premium"];
      });

      await saveData();
    } catch (e) {
      print("Erro ao obter status: $e");
    }
  }

  // ============================================================================
  // LOCAL STORAGE
  // ============================================================================
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isPremiumUser', isPremiumUser);
    await prefs.setInt('recipesUsedToday', recipesUsedToday);
    await prefs.setString(
      'lastUsageDate',
      lastUsageDate?.toIso8601String() ?? '',
    );
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      recipesUsedToday = prefs.getInt('recipesUsedToday') ?? 0;

      final dateString = prefs.getString('lastUsageDate');

      if (dateString != null && dateString.isNotEmpty) {
        lastUsageDate = DateTime.parse(dateString);
      }
    });
  }

  // ============================================================================
  // LOADING ANIMATION
  // ============================================================================
  Future<void> startLoadingAnimation() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() => loadingMessage = "A gerar receitas...");
    await Future.delayed(const Duration(seconds: 2));
    setState(() => loadingMessage = "Quase pronto...");
  }

  // ============================================================================
  // API CALLS
  // ============================================================================
  Future<void> testBackend() async {
    try {
      final result = await appApi.getRecipes();

      setState(() {
        recipes = result;
        responseText = recipes.isEmpty ? "Sem receitas" : "Receitas carregadas!";
      });
    } catch (e) {
      setState(() => responseText = "Erro: $e");
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
    try {
      setState(() {
        isLoading = true;
        loadingMessage = "A analisar ingredientes...";
      });

      startLoadingAnimation();

      final data = await appApi.uploadImage(path);
      print("===============");
      print(data);
      print(data.runtimeType);

      print(data["recipes"]);
      print(data["recipes"].runtimeType);

      print("===============");

      setState(() {
        isLoading = false;
        ingredientsDetected = data["ingredients_detected"].toString();
        recipes = (data["recipes"] as List)
            .map((r) => Recipe.fromJson(r))
            .toList();
      });

      AdsService.showInterstitial();
    } catch (e) {
      setState(() {
        isLoading = false;
        responseText = "Erro ao enviar imagem: $e";
      });
    }
  }

  // ============================================================================
  // PREMIUM LOGIC
  // ============================================================================
  void checkDailyReset() {
    final now = DateTime.now();

    if (lastUsageDate == null ||
        now.day != lastUsageDate!.day ||
        now.month != lastUsageDate!.month ||
        now.year != lastUsageDate!.year) {
      recipesUsedToday = 0;
      lastUsageDate = now;
      saveData();
    }
  }

  bool canAccessRecipe() {
    checkDailyReset();

    int limit = isPremiumUser ? dailyLimitPremium : dailyLimitFree;

    return recipesUsedToday < limit;
  }

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          IgnorePointer(
            ignoring: isLoading,
            child: Padding(
              padding: const EdgeInsets.all(20),
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

                  TextField(
                    controller: ingredientsController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    maxLines: 4,

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
                        borderSide: BorderSide(
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
                    onPressed: testBackend,
                    child: const Text("Gerar receitas com IA"),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: isLoading ? null : takePhoto,
                    child: const Text("Fotografar ingredientes"),
                  ),

                  const SizedBox(height: 20),

                  Text(responseText, textAlign: TextAlign.center),

                  const SizedBox(height: 20),

                  const Text(
                    "Ingredientes detectados:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  Text(ingredientsDetected),

                  const SizedBox(height: 20),

                  Expanded(
                    child: isLoading
                        ? ListView.builder(
                      itemCount: 3,
                      itemBuilder: (_, __) => Container(
                        height: 100,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                        : recipes.isEmpty
                        ? Center(child: Text(responseText))
                        : ListView.builder(
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = recipes[index];

                        return RecipeCardPremium(
                          recipe: recipe,
                          isUnlocked: false,
                          onTap: () async {
                            if (canAccessRecipe()) {
                              setState(() {
                                recipesUsedToday++;
                              });

                              await saveData();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RecipeDetailScreen(recipe: recipe),
                                ),
                              );
                            } else {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Limite atingido 🚫"),
                                  content: Text(
                                    isPremiumUser
                                        ? "Já viste 4 receitas hoje."
                                        : "Já viste a tua receita gratuita de hoje.\nFaz upgrade para continuar 🔥",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text("OK"),
                                    ),
                                    if (!isPremiumUser)
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.pop(context);

                                          final result =
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PremiumScreen(),
                                            ),
                                          );

                                          if (result == true) {
                                            setState(() {
                                              isPremiumUser = true;
                                            });

                                            await saveData();
                                          }
                                        },
                                        child: const Text("Ir para Premium"),
                                      ),
                                  ],
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black //withOpacity(0.3),
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