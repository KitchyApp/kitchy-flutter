import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static InterstitialAd? _interstitialAd;

  static void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // TEST ID
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  static void showInterstitial() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      loadInterstitial(); // reload
    }
  }
}