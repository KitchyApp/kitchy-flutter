import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart' show appApi;

// =============================================================================
// PROFILE SCREEN
// =============================================================================
// Unified user profile: shows identity (email / plan) and lets the user
// manage their dietary preferences and preferred cuisine style.
//
// Data flow
// ---------
// initState calls a single endpoint:
//   GET /auth/user/status  → email + plan badge + dietary switches + cuisine
// On save (button press or 600 ms after any toggle / dropdown change):
//   PUT /update-preferences → persists all preference fields
// =============================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Identity ──────────────────────────────────────────────────────────────
  String _email = '';
  bool _isPremium = false;

  // ── Preferences ───────────────────────────────────────────────────────────
  bool _glutenFree = false;
  bool _vegetarian = false;
  bool _vegan = false;
  String _preferredCuisine = 'international';

  // ── Badges ────────────────────────────────────────────────────────────────
  List<String> _earnedBadges = [];

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isSaving = false;

  // Debounce timer: rapid consecutive toggles collapse into a single PUT.
  Timer? _saveDebounce;

  static const List<Map<String, String>> _cuisineOptions = [
    {'value': 'international', 'label': 'Internacional'},
    {'value': 'italian',       'label': 'Italiana'},
    {'value': 'mediterranean', 'label': 'Mediterrânica'},
    {'value': 'portuguese',    'label': 'Portuguesa'},
    {'value': 'asian',         'label': 'Asiática'},
    {'value': 'mexican',       'label': 'Mexicana'},
    {'value': 'french',        'label': 'Francesa'},
    {'value': 'american',      'label': 'Americana'},
    {'value': 'indian',        'label': 'Indiana'},
    {'value': 'japanese',      'label': 'Japonesa'},
  ];

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ============================================================================
  // DATA — load status + preferences in parallel
  // ============================================================================

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Single request: GET /auth/user/status now returns identity AND
      // dietary preferences, so no second call to GET /preferences is needed.
      final status = await appApi.getUserStatus();

      if (!mounted) return;

      // Cuisine guard: fall back to 'international' for unknown backend values.
      final rawCuisine =
          (status['preferred_cuisine'] as String?) ?? 'international';
      final safeCuisine = _cuisineOptions.any((o) => o['value'] == rawCuisine)
          ? rawCuisine
          : 'international';

      setState(() {
        // Identity
        _email     = (status['email'] as String?) ?? '';
        _isPremium = status['is_premium'] == true;

        // Dietary preferences (now included in the status response)
        _glutenFree       = status['dietary_gluten_free'] == true;
        _vegetarian       = status['dietary_vegetarian']  == true;
        _vegan            = status['dietary_vegan']       == true;
        _preferredCuisine = safeCuisine;

        // Earned badges — list of badge_code strings from completed challenges
        final raw = status['earned_badges'];
        _earnedBadges = raw is List
            ? List<String>.from(raw.whereType<String>())
            : [];

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ProfileScreen] Erro ao carregar perfil: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Não foi possível carregar o perfil.', error: true);
    }
  }

  // ============================================================================
  // SAVE
  // ============================================================================

  // Called from every onChanged handler. Cancels any pending timer and starts
  // a fresh 600 ms countdown so that rapid consecutive toggles collapse into
  // a single PUT — the one that reflects the final settled state.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Vegan logically implies vegetarian — enforce before sending.
    final effectiveVegetarian = _vegan ? true : _vegetarian;

    try {
      await appApi.updatePreferences(
        glutenFree:      _glutenFree,
        vegetarian:      effectiveVegetarian,
        vegan:           _vegan,
        preferredCuisine: _preferredCuisine,
      );

      if (!mounted) return;
      setState(() {
        _isSaving   = false;
        _vegetarian = effectiveVegetarian;
      });
      _showSnack('Preferências guardadas com sucesso! ✅');
    } catch (e) {
      debugPrint('[ProfileScreen] Erro ao guardar preferências: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Erro ao guardar. Tenta novamente.', error: true);
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[700] : const Color(0xFFFF7043),
      duration: const Duration(seconds: 3),
    ));
  }

  // Avatar initials: first letter of the email local-part, upper-cased.
  String get _initials {
    if (_email.isEmpty) return '?';
    return _email[0].toUpperCase();
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7043)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Identity header ──────────────────────────────────────
                  _IdentityHeader(
                    initials:  _initials,
                    email:     _email,
                    isPremium: _isPremium,
                  ),

                  const SizedBox(height: 28),

                  // ── Section: Dietary restrictions ────────────────────────
                  _SectionLabel('Restrições Alimentares'),
                  const SizedBox(height: 8),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        // Gluten-Free
                        SwitchListTile(
                          secondary: Icon(
                            Icons.no_food,
                            color: _glutenFree
                                ? const Color(0xFFFF7043)
                                : Colors.grey,
                          ),
                          title: const Text(
                            'Glúten-Free',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Sem trigo, cevada, centeio ou farinha normal',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _glutenFree,
                          activeColor: const Color(0xFFFF7043),
                          onChanged: (v) {
                            setState(() => _glutenFree = v);
                            _scheduleSave();
                          },
                        ),

                        const Divider(height: 1, indent: 16, endIndent: 16),

                        // Vegetarian — locked when vegan is active
                        Opacity(
                          opacity: _vegan ? 0.45 : 1.0,
                          child: SwitchListTile(
                            secondary: Icon(
                              Icons.eco,
                              color: _vegetarian
                                  ? const Color(0xFFFF7043)
                                  : Colors.grey,
                            ),
                            title: const Text(
                              'Vegetariano',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Sem carne, aves, peixe ou marisco',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _vegetarian,
                            activeColor: const Color(0xFFFF7043),
                            onChanged: _vegan
                                ? null
                                : (v) {
                                    setState(() => _vegetarian = v);
                                    _scheduleSave();
                                  },
                          ),
                        ),

                        const Divider(height: 1, indent: 16, endIndent: 16),

                        // Vegan
                        SwitchListTile(
                          secondary: Icon(
                            Icons.spa,
                            color: _vegan
                                ? const Color(0xFFFF7043)
                                : Colors.grey,
                          ),
                          title: const Text(
                            'Vegan',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Sem qualquer produto animal (inclui ovos e laticínios)',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _vegan,
                          activeColor: const Color(0xFFFF7043),
                          onChanged: (v) {
                            setState(() {
                              _vegan = v;
                              if (v) _vegetarian = true;
                            });
                            _scheduleSave();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Vegan auto-includes vegetarian hint
                  if (_vegan) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 13,
                          color: Color(0xFFFF7043),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'O modo Vegan inclui automaticamente a restrição Vegetariana.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Section: Cuisine style ───────────────────────────────
                  _SectionLabel('Estilo de Cozinha Preferido'),
                  const SizedBox(height: 8),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _preferredCuisine,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.restaurant_menu,
                            color: Color(0xFFFF7043),
                          ),
                        ),
                        items: _cuisineOptions
                            .map(
                              (o) => DropdownMenuItem(
                                value: o['value'],
                                child: Text(o['label']!),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _preferredCuisine = v);
                            _scheduleSave();
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'A IA adapta sabores, temperos e estilo de apresentação '
                    'ao tipo de cozinha selecionado.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),

                  // ── Section: Earned badges ───────────────────────────────
                  _SectionLabel('Medalhas do Chef 🏅'),
                  const SizedBox(height: 12),
                  _BadgesSection(earnedBadges: _earnedBadges),

                  const SizedBox(height: 36),

                  // ── Save button ──────────────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isSaving ? 'A guardar...' : 'Guardar Preferências',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// =============================================================================
// PRIVATE WIDGETS
// =============================================================================

class _IdentityHeader extends StatelessWidget {
  final String initials;
  final String email;
  final bool isPremium;

  const _IdentityHeader({
    required this.initials,
    required this.email,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7043), Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7043).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar circle
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Email
          Text(
            email.isEmpty ? 'Utilizador' : email,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // Plan badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium
                      ? Icons.workspace_premium
                      : Icons.person_outline,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isPremium ? 'Plano Premium ⭐' : 'Plano Free',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

// =============================================================================
// BADGE DATA
// =============================================================================

class _BadgeInfo {
  final String emoji;
  final String name;
  final Color color;
  const _BadgeInfo(this.emoji, this.name, this.color);
}

const Map<String, _BadgeInfo> _kBadgeMap = {
  'badge_tomato':        _BadgeInfo('🍅', 'Rei do Tomate',           Color(0xFFFFCDD2)),
  'badge_chickpea':      _BadgeInfo('🫘', 'Mestre das Leguminosas',  Color(0xFFFFF9C4)),
  'badge_tuna':          _BadgeInfo('🐟', 'Caçador de Atum',         Color(0xFFB3E5FC)),
  'badge_lentil':        _BadgeInfo('🟤', 'Herói das Lentilhas',     Color(0xFFD7CCC8)),
  'badge_egg':           _BadgeInfo('🥚', 'Rei dos Ovos',            Color(0xFFFFF8E1)),
  'badge_protein':       _BadgeInfo('🍗', 'Monstro do Ginásio',      Color(0xFFFFE0B2)),
  'badge_gourmet':       _BadgeInfo('🥑', 'Chef de Elite',           Color(0xFFC8E6C9)),
  'badge_rosemary':      _BadgeInfo('🌿', 'Lombo & Alecrim',         Color(0xFFDCEDC8)),
  'badge_mediterranean': _BadgeInfo('🐠', 'Rei do Mediterrâneo',     Color(0xFFB2EBF2)),
  'badge_mushroom':      _BadgeInfo('🍄', 'O Cogumelo Místico',      Color(0xFFE1BEE7)),
};

// =============================================================================
// BADGES SECTION WIDGET
// =============================================================================

class _BadgesSection extends StatelessWidget {
  final List<String> earnedBadges;
  const _BadgesSection({required this.earnedBadges});

  @override
  Widget build(BuildContext context) {
    if (earnedBadges.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              '🍳',
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ainda não tens medalhas.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D4037),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Aceita um Desafio do Chef para começares\na tua coleção!',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: earnedBadges.map((code) => _BadgeTile(badgeCode: code)).toList(),
    );
  }
}

// =============================================================================
// SINGLE BADGE TILE
// =============================================================================

class _BadgeTile extends StatelessWidget {
  final String badgeCode;
  const _BadgeTile({required this.badgeCode});

  @override
  Widget build(BuildContext context) {
    final info = _kBadgeMap[badgeCode] ??
        const _BadgeInfo('🏅', 'Conquista', Color(0xFFF5F5F5));

    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: info.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: info.color.withValues(alpha: 0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                info.emoji,
                style: const TextStyle(fontSize: 34),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            info.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4E342E),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
