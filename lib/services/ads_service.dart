import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// =============================================================================
// ADS SERVICE
// =============================================================================
// Manages interstitial ad lifecycle for the Free monetisation tier.
//
// Key design rules
// ----------------
// • Premium users NEVER see ads — showInterstitialAdIfNeeded() short-circuits
//   immediately on isPremium=true (zero delay, no SDK calls).
// • Free users see a real AdMob interstitial when one is pre-loaded.
//   If the cache is empty (first launch, load failed, network error) the slot
//   is simulated with a 3-second Future.delayed so the UX remains consistent.
// • loadInterstitial() is called eagerly at app start AND after each show so
//   the next slot is always warming up in the background.
// • All AdMob SDK calls are guarded — a failed ad never crashes the app.
// =============================================================================

class AdsService {
  static InterstitialAd? _interstitialAd;

  // ============================================================================
  // LOAD (pre-warm the next ad slot)
  // ============================================================================
  // Call once at app startup (MobileAds.instance.initialize must run first).
  // Called automatically after every show to keep the cache warm.
  static void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Google test ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('[AdsService] Anúncio intersticial carregado.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          debugPrint('[AdsService] Falha ao carregar anúncio: ${error.message}');
        },
      ),
    );
  }

  // ============================================================================
  // SHOW IF NEEDED  —  await before every recipe generation
  // ============================================================================
  // Premium path  → log bypass + return instantly (no delay, no SDK call).
  // Free path     → show real ad if pre-loaded, otherwise simulate a 3-second
  //                 interstitial slot. Either way pre-loads the next ad.
  //
  // Callers must await this method so the loading overlay stays visible during
  // the full ad (or simulation) duration before the OpenAI request is sent.
  //
  // Example:
  //   setState(() => loadingMessage = "A carregar anúncio...");
  //   await AdsService.showInterstitialAdIfNeeded(isPremiumUser);
  //   setState(() => loadingMessage = "A gerar receitas com IA...");
  static Future<void> showInterstitialAdIfNeeded(bool isPremium) async {
    if (isPremium) {
      debugPrint('[AdsService] User Premium: Bypass de anúncios ativado.');
      return; // ← instant return, zero wait
    }

    // ── Free user ────────────────────────────────────────────────────────────
    if (_interstitialAd != null) {
      // Real ad available — show it full-screen and release the reference.
      debugPrint('[AdsService] A exibir anúncio real para utilizador Free...');
      _interstitialAd!.show();
      _interstitialAd = null;

      // AdMob's show() call is fire-and-forget; we give the system 3 seconds
      // to render and the user to dismiss the overlay before continuing.
      await Future.delayed(const Duration(seconds: 3));
    } else {
      // No ad pre-loaded (first launch / network failure / quota).
      // Simulate the interstitial slot so the user experience is identical
      // regardless of whether a real ad was available.
      debugPrint('[AdsService] Sem anúncio em cache — a simular pausa de 3s...');
      await Future.delayed(const Duration(seconds: 3));
    }

    debugPrint('[AdsService] Anúncio exibido para utilizador Free.');

    // Pre-warm the next slot so it is ready for the following request.
    loadInterstitial();
  }

  // ============================================================================
  // LEGACY SHOW (kept for call-sites not yet migrated to showInterstitialAdIfNeeded)
  // ============================================================================
  static void showInterstitial() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      loadInterstitial();
    }
  }
}