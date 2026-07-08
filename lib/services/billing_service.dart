import 'dart:convert';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../core/api_client.dart';

/// ============================================================================
/// BILLING SERVICE (PRODUCTION READY)
/// ----------------------------------------------------------------------------
/// Handles:
/// - Google Play purchases
/// - Sends purchase token to backend
/// - Backend validates purchase securely
///
/// SECURITY:
/// - Never trust client-side purchase
/// - Always validate via backend
/// ============================================================================

class BillingService {
  final ApiClient apiClient;
  final InAppPurchase _iap = InAppPurchase.instance;

  /// Product IDs — must match Google Play / backend billing config.
  static const monthlyProductId = 'kitchy_premium_monthly';
  static const yearlyProductId = 'kitchy_premium_yearly';

  /// Sandbox token accepted by POST /billing/verify-purchase in dev/emulator.
  static const sandboxToken = 'SANDBOX_TEST_TOKEN_V1';

  BillingService(this.apiClient);

  // ============================================================================
  // INIT
  // ============================================================================
  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    _iap.purchaseStream.listen(_listenToPurchases);
  }

  // ============================================================================
  // LISTEN TO PURCHASES
  // ============================================================================
  void _listenToPurchases(List<PurchaseDetails> purchases) {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        _handlePurchase(purchase);
      }
    }
  }

  // ============================================================================
  // HANDLE PURCHASE
  // ============================================================================
  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    final productId = purchase.productID;

    final success = await verifyPurchase(
      purchaseToken: token,
      productId: productId,
    );

    if (success) {
      print("Premium ativado!");
    } else {
      print("Falha na validação da compra");
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  // ============================================================================
  // VERIFY WITH BACKEND
  // ============================================================================
  Future<bool> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final response = await apiClient.post(
      '/verify-purchase',
      {
        'purchase_token': purchaseToken,
        'product_id': productId,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'premium_activated';
    }

    return false;
  }

  // ============================================================================
  // MOCK PURCHASE (sandbox — bypasses Google Play plugin)
  // ============================================================================
  Future<bool> purchasePremiumMock({
    String productId = monthlyProductId,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      final response = await apiClient.post(
        '/billing/verify-purchase',
        {
          'purchase_token': sandboxToken,
          'product_id': productId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'premium_activated';
      }

      print('[BillingService] purchasePremiumMock: status ${response.statusCode} | product=$productId');
      return false;
    } catch (e) {
      print('[BillingService] purchasePremiumMock error: $e');
      return false;
    }
  }

  // ============================================================================
  // BUY PRODUCT
  // ============================================================================
  Future<void> buy(String productId) async {
    final response = await _iap.queryProductDetails({productId});
    final product = response.productDetails.first;

    final purchaseParam = PurchaseParam(productDetails: product);

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }
}
