import 'package:flutter/material.dart';

import '../services/billing_service.dart';

// =============================================================================
// PAYWALL SCREEN
// =============================================================================
// Shows the two subscription plans (monthly / annual) and handles the mock
// purchase flow via BillingService.purchasePremiumMock(productId: ...).
//
// Usage:
//   await Navigator.push<bool>(
//     context,
//     MaterialPageRoute(
//       builder: (_) => PaywallScreen(
//         billingService: billingService,
//         onPurchaseSuccess: () async { await loadUserStatus(); },
//       ),
//     ),
//   );
// =============================================================================

enum _Plan { monthly, yearly }

class PaywallScreen extends StatefulWidget {
  final BillingService billingService;

  /// Awaited after a successful purchase so the parent state (isPremiumUser)
  /// is updated before this screen pops.
  final Future<void> Function()? onPurchaseSuccess;

  const PaywallScreen({
    super.key,
    required this.billingService,
    this.onPurchaseSuccess,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  _Plan _selectedPlan = _Plan.monthly;
  bool _isLoading = false;
  String? _errorMessage;

  static const _orange = Color(0xFFFF7043);
  static const _deepOrange = Color(0xFFE64A19);
  static const _green = Color(0xFF4CAF50);

  // ── Derived from selection ───────────────────────────────────────────────────

  String get _productId => _selectedPlan == _Plan.monthly
      ? 'kitchy_premium_monthly'
      : 'kitchy_premium_yearly';

  String get _ctaLabel => _selectedPlan == _Plan.monthly
      ? 'Subscrever Plano Mensal'
      : 'Subscrever Plano Anual';

  // ── Purchase handler ────────────────────────────────────────────────────────

  Future<void> _handlePurchase() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.billingService.purchasePremiumMock(
        productId: _productId,
      );

      if (!mounted) return;

      if (success) {
        // Update the parent state before popping — parent UI reflects the new
        // plan the moment this screen disappears.
        await widget.onPurchaseSuccess?.call();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parabéns! Kitchy Premium ativado com sucesso! ⚡'),
            backgroundColor: _green,
            duration: Duration(seconds: 4),
          ),
        );

        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage =
              'Não foi possível verificar a compra. Tenta novamente.';
        });
      }
    } catch (e) {
      debugPrint('[PaywallScreen] Erro: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro inesperado. Verifica a ligação e tenta de novo.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: _isLoading
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  _buildBenefits(),
                  _buildPriceCards(),
                  if (_errorMessage != null) _buildError(),
                  _buildCta(),
                  _buildDisclaimer(),
                ],
              ),
            ),

            // Full-screen overlay blocks interaction during purchase.
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: _orange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Section builders ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_orange, _deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            children: [
              // "PREMIUM" pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'PREMIUM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Icon(Icons.bolt, color: Colors.white, size: 60),

              const SizedBox(height: 12),

              const Text(
                'Kitchy Premium ⚡',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Desbloqueia tudo, sem limites.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefits() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O que inclui:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 18),
          const _BenefitRow(
            icon: Icons.block,
            title: 'Remover anúncios',
            subtitle: 'Experiência completamente limpa, sem qualquer interrupção',
          ),
          const _BenefitRow(
            icon: Icons.restaurant_menu,
            title: '4 receitas por análise',
            subtitle: 'Passa de 1 para 4 receitas por pedido à IA',
          ),
          const _BenefitRow(
            icon: Icons.tune,
            title: 'Filtros alimentares avançados',
            subtitle: 'Vegan, sem glúten, vegetariano e muito mais',
          ),
          const _BenefitRow(
            icon: Icons.bolt,
            title: 'Respostas mais rápidas da IA',
            subtitle: 'Prioridade no processamento das tuas receitas',
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _PriceCard(
              plan: _Plan.monthly,
              selectedPlan: _selectedPlan,
              title: 'Plano Mensal',
              price: '€3.59',
              period: 'por mês',
              onTap: () => setState(() => _selectedPlan = _Plan.monthly),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PriceCard(
              plan: _Plan.yearly,
              selectedPlan: _selectedPlan,
              title: 'Plano Anual',
              price: '€35.90',
              period: 'por ano',
              badge: 'Poupa 15%',
              onTap: () => setState(() => _selectedPlan = _Plan.yearly),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePurchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _orange.withValues(alpha: 0.6),
          minimumSize: const Size(double.infinity, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
          shadowColor: _orange.withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                _ctaLabel,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 48),
      child: Text(
        'Cancela a qualquer momento.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}

// =============================================================================
// _PRICE CARD
// =============================================================================

class _PriceCard extends StatelessWidget {
  final _Plan plan;
  final _Plan selectedPlan;
  final String title;
  final String price;
  final String period;
  final String? badge;
  final VoidCallback onTap;

  const _PriceCard({
    required this.plan,
    required this.selectedPlan,
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.onTap,
  });

  static const _orange = Color(0xFFFF7043);

  @override
  Widget build(BuildContext context) {
    final selected = plan == selectedPlan;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF3F0) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _orange : const Color(0xFFE0E0E0),
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _orange.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio + savings badge row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? _orange : Colors.grey,
                  size: 18,
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // Plan name
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF757575),
              ),
            ),

            const SizedBox(height: 6),

            // Price
            Text(
              price,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: selected ? _orange : const Color(0xFF616161),
              ),
            ),

            // Period
            Text(
              period,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _BENEFIT ROW
// =============================================================================

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7043).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFFFF7043), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4CAF50), size: 22),
        ],
      ),
    );
  }
}
