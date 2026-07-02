import 'package:flutter/material.dart';
import '../models/recipe.dart';

// =============================================================================
// RECIPE CARD
// =============================================================================
// Compact card used in the Favorites list and anywhere a recipe preview is
// needed without navigating to the detail screen.
//
// Design decisions:
//  - No Image.network: external food-image APIs are unreliable and add latency.
//    We use a deterministic gradient header instead — visually distinct per
//    recipe with zero network requests.
//  - Gradient color is derived from the recipe title length so identical-length
//    titles in the same list still cycle through the full palette.
//  - Macro chips (P/C/G) give nutritional context at a glance.
//  - Uses Card.clipBehavior so the gradient header respects the rounded corners
//    without needing an extra ClipRRect wrapper.
// =============================================================================

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  // ── Deterministic gradient ─────────────────────────────────────────────────
  // Each preset pair is [primary, lighter-tint] for a soft gradient effect.
  // The palette cycles based on title.length so cards in the same list look
  // visually distinct even when several recipes have similar names.
  static const List<List<Color>> _palette = [
    [Color(0xFFFF7043), Color(0xFFFF8A65)], // deep-orange
    [Color(0xFF43A047), Color(0xFF66BB6A)], // green
    [Color(0xFF5C6BC0), Color(0xFF7986CB)], // indigo
    [Color(0xFFE91E63), Color(0xFFF06292)], // pink
    [Color(0xFF00ACC1), Color(0xFF26C6DA)], // cyan
    [Color(0xFF7E57C2), Color(0xFF9575CD)], // deep-purple
    [Color(0xFFFFA726), Color(0xFFFFB74D)], // amber
    [Color(0xFF26A69A), Color(0xFF4DB6AC)], // teal
  ];

  List<Color> get _gradientColors =>
      _palette[recipe.title.length % _palette.length];

  // ── Food emoji — varies by calorie density for a subtle visual cue ─────────
  String get _foodEmoji {
    if (recipe.calories < 250) return '🥗';
    if (recipe.calories < 450) return '🍳';
    if (recipe.calories < 650) return '🍝';
    return '🍖';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradientColors;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // clipBehavior required so the gradient header clips to the card corners
      // without a separate ClipRRect wrapper.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient header ──────────────────────────────────────────────
            _GradientHeader(
              colors: colors,
              emoji: _foodEmoji,
              timeMinutes: recipe.timeMinutes,
            ),

            // ── Content body ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Time chip (standalone — calories moved to the macro row below)
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: '${recipe.timeMinutes} min',
                    color: Colors.grey.shade600,
                  ),

                  const SizedBox(height: 10),

                  // ── Macro badges ─────────────────────────────────────────────
                  // Wrap instead of Row: badges reflow to a second line on
                  // narrow screens without overflow errors.
                  // Field safety: all int fields default to 0 in Recipe.fromJson
                  // via ?? 0, so interpolation never produces "null" strings.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MacroBadge(
                        emoji: '🥩',
                        label: 'P',
                        value: '${recipe.protein}g',
                        color: const Color(0xFF5C6BC0), // indigo
                      ),
                      _MacroBadge(
                        emoji: '🌾',
                        label: 'C',
                        value: '${recipe.carbs}g',
                        color: const Color(0xFFFFA726), // amber
                      ),
                      _MacroBadge(
                        emoji: '🥑',
                        label: 'G',
                        value: '${recipe.fat}g',
                        color: const Color(0xFF26A69A), // teal
                      ),
                      _MacroBadge(
                        emoji: '🔥',
                        label: '',
                        value: '${recipe.calories} kcal',
                        color: const Color(0xFFFF7043), // brand orange
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PRIVATE HELPER WIDGETS
// =============================================================================

class _GradientHeader extends StatelessWidget {
  final List<Color> colors;
  final String emoji;
  final int timeMinutes;

  const _GradientHeader({
    required this.colors,
    required this.emoji,
    required this.timeMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Large translucent emoji watermark (decorative)
          Positioned(
            right: -10,
            bottom: -12,
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 90),
            ),
          ),
          // Centred foreground emoji
          Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 52),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill chip with icon — used for time and calories.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nutritional macro badge — displays emoji + label + value.
///
/// Used for the 4 macro nutrients: protein (🥩 P), carbs (🌾 C),
/// fat (🥑 G), and calories (🔥 kcal).
///
/// Defensive against empty [label]: when label is empty (calories badge),
/// no space is inserted between emoji and value.
class _MacroBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;

  const _MacroBadge({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Build the display text defensively:
    //   label non-empty → "🥩 P: 25g"
    //   label empty     → "🔥 320 kcal"
    final text = label.isEmpty ? '$emoji $value' : '$emoji $label: $value';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}
