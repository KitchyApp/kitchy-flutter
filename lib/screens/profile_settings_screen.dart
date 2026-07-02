import 'package:flutter/material.dart';

import '../core/app_api.dart';
import '../main.dart' show appApi;

// ============================================================================
// PROFILE SETTINGS SCREEN
// ============================================================================
// Allows the authenticated user to configure dietary restrictions and their
// preferred cuisine style. Preferences are persisted on the backend and
// applied to every subsequent AI recipe generation in real-time.
// ============================================================================

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isSaving = false;

  bool _glutenFree = false;
  bool _vegetarian = false;
  bool _vegan = false;
  String _preferredCuisine = 'international';

  // ── Supported cuisine options ────────────────────────────────────────────
  static const List<Map<String, String>> _cuisineOptions = [
    {'value': 'international', 'label': 'Internacional'},
    {'value': 'italian', 'label': 'Italiana'},
    {'value': 'mediterranean', 'label': 'Mediterrânica'},
    {'value': 'portuguese', 'label': 'Portuguesa'},
    {'value': 'asian', 'label': 'Asiática'},
    {'value': 'mexican', 'label': 'Mexicana'},
    {'value': 'french', 'label': 'Francesa'},
    {'value': 'american', 'label': 'Americana'},
    {'value': 'indian', 'label': 'Indiana'},
    {'value': 'japanese', 'label': 'Japonesa'},
  ];

  // ============================================================================
  // LIFECYCLE
  // ============================================================================
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // ============================================================================
  // LOAD PREFERENCES FROM BACKEND
  // ============================================================================
  Future<void> _loadPreferences() async {
    try {
      final prefs = await appApi.getPreferences();

      if (!mounted) return;

      setState(() {
        _glutenFree = prefs['dietary_gluten_free'] == true;
        _vegetarian = prefs['dietary_vegetarian'] == true;
        _vegan = prefs['dietary_vegan'] == true;

        final cuisine = (prefs['preferred_cuisine'] as String?) ?? 'international';
        // Guard against unknown values coming from the backend
        _preferredCuisine = _cuisineOptions.any((o) => o['value'] == cuisine)
            ? cuisine
            : 'international';

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ProfileSettings] Erro ao carregar preferências: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Não foi possível carregar as preferências.', error: true);
    }
  }

  // ============================================================================
  // SAVE PREFERENCES TO BACKEND
  // ============================================================================
  Future<void> _savePreferences() async {
    if (_isSaving) return;

    // Enforce logical consistency: vegan implies vegetarian
    final effectiveVegetarian = _vegan ? true : _vegetarian;

    setState(() => _isSaving = true);

    try {
      await appApi.updatePreferences(
        glutenFree: _glutenFree,
        vegetarian: effectiveVegetarian,
        vegan: _vegan,
        preferredCuisine: _preferredCuisine,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      _showSnack('Preferências guardadas com sucesso!');
    } catch (e) {
      debugPrint('[ProfileSettings] Erro ao guardar preferências: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Erro ao guardar. Tenta novamente.', error: true);
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================
  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red[700] : const Color(0xFFFF7043),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // UI
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Definições de Perfil'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7043)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ────────────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.tune,
                    title: 'As tuas preferências afetam diretamente as receitas geradas pela IA.',
                  ),

                  const SizedBox(height: 28),

                  // ── Dietary Restrictions ──────────────────────────────────
                  _SectionLabel(label: 'Restrições Alimentares'),
                  const SizedBox(height: 8),

                  _PreferenceCard(
                    children: [
                      _DietaryCheckbox(
                        value: _glutenFree,
                        label: 'Glúten-Free',
                        subtitle: 'Sem trigo, cevada, centeio ou farinha normal',
                        icon: Icons.no_food,
                        onChanged: (v) => setState(() => _glutenFree = v ?? false),
                      ),
                      const Divider(height: 1),
                      _DietaryCheckbox(
                        value: _vegetarian,
                        label: 'Vegetariano',
                        subtitle: 'Sem carne, aves, peixe ou marisco',
                        icon: Icons.eco,
                        onChanged: _vegan
                            ? null // locked when vegan is active
                            : (v) => setState(() => _vegetarian = v ?? false),
                      ),
                      const Divider(height: 1),
                      _DietaryCheckbox(
                        value: _vegan,
                        label: 'Vegan',
                        subtitle: 'Sem qualquer produto animal (inclui ovos e laticínios)',
                        icon: Icons.spa,
                        onChanged: (v) {
                          final active = v ?? false;
                          setState(() {
                            _vegan = active;
                            // Vegan auto-activates vegetarian
                            if (active) _vegetarian = true;
                          });
                        },
                      ),
                    ],
                  ),

                  // ── Info chip when vegan forces vegetarian ─────────────────
                  if (_vegan)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: Color(0xFFFF7043)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'O modo Vegan já inclui a restrição Vegetariana.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── Cuisine Style ─────────────────────────────────────────
                  _SectionLabel(label: 'Estilo de Cozinha Preferido'),
                  const SizedBox(height: 8),

                  _PreferenceCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _preferredCuisine,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.restaurant,
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
                            if (v != null) setState(() => _preferredCuisine = v);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'A IA adapta o sabor, os temperos e o estilo de apresentação '
                    'ao tipo de cozinha que selecionares.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),

                  // ── Save button ───────────────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _savePreferences,
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
                    label: Text(_isSaving ? 'A guardar...' : 'Guardar Preferências'),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// PRIVATE HELPER WIDGETS
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7043).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF7043).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF7043), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  final List<Widget> children;

  const _PreferenceCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _DietaryCheckbox extends StatelessWidget {
  final bool value;
  final String label;
  final String subtitle;
  final IconData icon;
  final ValueChanged<bool?>? onChanged;

  const _DietaryCheckbox({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFFF7043),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        secondary: Icon(
          icon,
          color: value ? const Color(0xFFFF7043) : Colors.grey,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value ? const Color(0xFFFF7043) : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
