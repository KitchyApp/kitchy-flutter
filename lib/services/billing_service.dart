import 'package:in_app_purchase/in_app_purchase.dart';
import '../core/api_client.dart';

/// ============================================================================
/// BILLING SERVICE (PRODUCTION READY)
/// ----------------------------------------------------------------------------
/// Handles:
/// - In-app purchases (Google Play)
/// - Purchase validation with backend
///
/// Flow:
/// 1. User buys product
/// 2. Google returns purchase token
/// 3. Token sent to backend
/// 4. Backend validates with Google API
/// 5. Premium activated securely
///
/// SECURITY:
/// - NEVER trust client purchase
/// - ALWAYS validate server-side
/// ============================================================================

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final ApiClient apiClient;

  BillingService(this.apiClient);

  // ============================================================================
  // INIT LISTENER
  // ============================================================================
  Future<void> init() async {
    final available = await _iap.isAvailable();

    if (!available) return;

    _iap.purchaseStream.listen(_listenToPurchases);
  }

  // ============================================================================
  // PURCHASE LISTENER
  // ============================================================================
  void _listenToPurchases(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {

        final token = purchase.verificationData.serverVerificationData;
        final productId = purchase.productID;

        // 🔥 CALL BACKEND (NEW SYSTEM)
        final success = await verifyPurchase(
          purchaseToken: token,
          productId: productId,
        );

        if (success) {
          print("✅ Premium activated");
        } else {
          print("❌ Validation failed");
        }

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  // ============================================================================
  // VERIFY PURCHASE WITH BACKEND
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

    return response.statusCode == 200;
  }

  // ============================================================================
  // START PURCHASE FLOW
  // ============================================================================
  Future<void> buy(String productId) async {
    final productDetails = await _getProducts(productId);

    final purchaseParam = PurchaseParam(productDetails: productDetails);

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // ============================================================================
  // FETCH PRODUCT FROM STORE
  // ============================================================================
  Future<ProductDetails> _getProducts(String productId) async {
    final response = await _iap.queryProductDetails({productId});

    if (response.productDetails.isEmpty) {
      throw Exception("Product not found");
    }

    return response.productDetails.first;
  }
}
