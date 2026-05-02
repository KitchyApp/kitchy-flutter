import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_api.dart';
import 'models/recipe.dart';
import 'services/ads_service.dart';
import 'widgets/recipe_card_premium.dart';
import 'premium_screen.dart';

import 'core/api_client.dart';
import 'features/auth/auth_service.dart';
import 'services/billing_service.dart';


const String baseUrl = "http://10.0.2.2:8000";

final ApiClient apiClient = ApiClient(baseUrl: baseUrl);
final BillingService billingService = BillingService(apiClient);
final AuthService authService = AuthService(apiClient);
final AppApi appApi = AppApi(apiClient);


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Load tokens from storage before app starts
  await apiClient.init();

  // Initialize ads
  MobileAds.instance.initialize();
  AdsService.loadInterstitial();

  await authService.loadSession();

  await billingService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String responseText = "Press the button to test the backend";

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

  @override
  void initState() {
    super.initState();
    loadData();
    loadUserStatus();
  }

  Future<void> startLoadingAnimation() async {
    await Future.delayed(const Duration(seconds: 2));
    setState(() => loadingMessage = "A gerar receitas...");
    await Future.delayed(const Duration(seconds: 2));
    setState(() => loadingMessage = "Quase pronto...");
  }

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
    if (photo != null) await uploadImage(photo.path);
  }

  Future<void> uploadImage(String path) async {
    try {
      setState(() {
        isLoading = true;
        loadingMessage = "A analisar ingredientes...";
      });

      startLoadingAnimation();

      final data = await appApi.uploadImage(path);

      setState(() {
        isLoading = false;
        ingredientsDetected = data["ingredients_detected"].toString();
        recipes = List<Recipe>.from(
          data["recipes"].map((r) => Recipe.fromJson(r)),
        );
      });

      AdsService.showInterstitial();
    } catch (e) {
      setState(() {
        isLoading = false;
        responseText = "Erro ao enviar imagem: $e";
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kitchy")),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: isLoading,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Welcome to Kitchy", style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),

                  TextField(
                    controller: ingredientsController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Ingredientes (ex: ovos, tomate, queijo)",
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: testBackend,
                    child: const Text("Gerar Receitas"),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: isLoading ? null : takePhoto,
                    child: const Text("Tirar Foto"),
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
                                              const PremiumScreen(),
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

          // OVERLAY
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
            ),
        ],
      ),
    );
  }
}

// DETALHE DA RECEITA
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Calories: ${recipe.calories} kcal"),
            Text("Protein: ${recipe.protein} g"),
            Text("Carbs: ${recipe.carbs} g"),
            Text("Fat: ${recipe.fat} g"),
            const SizedBox(height: 20),
            const Text("Detalhes da receita..."),
          ],
        ),
      ),
    );
  }
}