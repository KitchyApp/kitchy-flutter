import 'package:flutter/material.dart';

import '../main.dart' show appApi, billingService;
import 'paywall_screen.dart';

// =============================================================================
// CHALLENGE MODEL (local DTO — mirrors the /challenges API response)
// =============================================================================

class ChallengeModel {
  final int id;
  final String title;
  final String requiredIngredients;
  final bool isPremiumOnly;
  final bool isLocked;
  final String badgeCode;
  final bool isCompleted;
  final String? completedAt;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.requiredIngredients,
    required this.isPremiumOnly,
    required this.isLocked,
    required this.badgeCode,
    required this.isCompleted,
    this.completedAt,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json) => ChallengeModel(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        requiredIngredients: json['required_ingredients'] as String? ?? '',
        isPremiumOnly: json['is_premium_only'] as bool? ?? false,
        isLocked: json['is_locked'] as bool? ?? false,
        badgeCode: json['badge_code'] as String? ?? '🏅',
        isCompleted: json['is_completed'] as bool? ?? false,
        completedAt: json['completed_at'] as String?,
      );

  List<String> get ingredientList =>
      requiredIngredients.split(',').map((s) => s.trim()).toList();
}

// =============================================================================
// CHALLENGES SCREEN
// =============================================================================
// Shows all Chef Challenges fetched from GET /challenges.
//
// Cards:
//  ✅ Completed    — glowing badge emoji + green accent, trophy indicator.
//  🔒 Locked      — dark overlay + lock icon; tapping opens Premium paywall.
//  🟠 Available   — open challenge, shows required ingredient chips.
// =============================================================================

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<ChallengeModel> _challenges = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final raw = await appApi.getChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = raw.map(ChallengeModel.fromJson).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Stats helpers ───────────────────────────────────────────────────────────
  int get _completed => _challenges.where((c) => c.isCompleted).length;
  int get _total => _challenges.length;

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          billingService: billingService,
          onPurchaseSuccess: () async {
            await _load();
          },
        ),
      ),
    );
  }

  void _onChallengeTap(ChallengeModel c) {
    if (c.isLocked) {
      _showLockedSheet(c);
    }
    // Completed / available challenges are informational only — tapping a
    // completed card shows a congratulation sheet; available cards do nothing
    // (verification happens automatically in the recipe generation flow).
    else if (c.isCompleted) {
      _showCompletedSheet(c);
    } else {
      _showAvailableSheet(c);
    }
  }

  // ── Bottom Sheets ───────────────────────────────────────────────────────────

  void _showLockedSheet(ChallengeModel c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LockedSheet(
        challenge: c,
        onUpgrade: _openPaywall,
      ),
    );
  }

  void _showCompletedSheet(ChallengeModel c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompletedSheet(challenge: c),
    );
  }

  void _showAvailableSheet(ChallengeModel c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvailableSheet(challenge: c),
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🏆 Desafios do Chef'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7043)),
            )
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : _challenges.isEmpty
                  ? const _EmptyState()
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _ProgressHeader(
                            completed: _completed,
                            total: _total,
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 14),
                                child: _ChallengeCard(
                                  challenge: _challenges[i],
                                  onTap: () =>
                                      _onChallengeTap(_challenges[i]),
                                ),
                              ),
                              childCount: _challenges.length,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// =============================================================================
// PROGRESS HEADER
// =============================================================================

class _ProgressHeader extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressHeader({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : completed / total;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7043), Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7043).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progresso Geral',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completed de $total concluídos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (completed == total && total > 0)
                const Text('🎉', style: TextStyle(fontSize: 28)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white30,
              color: Colors.white,
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CHALLENGE CARD
// =============================================================================

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final VoidCallback onTap;

  const _ChallengeCard({required this.challenge, required this.onTap});

  Color get _accentColor {
    if (challenge.isCompleted) return const Color(0xFF43A047); // green
    if (challenge.isLocked) return Colors.grey;
    if (challenge.isPremiumOnly) return const Color(0xFFFFB300); // gold
    return const Color(0xFFFF7043); // orange (free)
  }

  @override
  Widget build(BuildContext context) {
    final locked = challenge.isLocked;
    final done = challenge.isCompleted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done
                ? const Color(0xFF43A047).withOpacity(0.6)
                : locked
                    ? Colors.grey.withOpacity(0.25)
                    : _accentColor.withOpacity(0.25),
            width: done ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withOpacity(done ? 0.18 : 0.08),
              blurRadius: done ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Card body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: badge + title + plan pill ───────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge emoji — glowing when completed
                      _BadgeIcon(
                        badge: challenge.badgeCode,
                        glowing: done,
                        locked: locked,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: locked
                                    ? Colors.grey[600]
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Plan pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                challenge.isPremiumOnly
                                    ? '⭐ Exclusivo Premium'
                                    : '🆓 Gratuito',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status icon (right side)
                      _StatusIcon(
                          isCompleted: done, isLocked: locked),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Ingredient chips ──────────────────────────────────────
                  if (!locked) ...[
                    Text(
                      'Ingredientes necessários:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: challenge.ingredientList.map((ing) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: done
                                ? const Color(0xFF43A047).withOpacity(0.1)
                                : const Color(0xFFFF7043).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: done
                                  ? const Color(0xFF43A047).withOpacity(0.3)
                                  : const Color(0xFFFF7043).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                done
                                    ? Icons.check_circle
                                    : Icons.local_dining,
                                size: 12,
                                color: done
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFFFF7043),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ing,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: done
                                      ? const Color(0xFF43A047)
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // ── Completed footer ──────────────────────────────────────
                  if (done && challenge.completedAt != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.verified,
                            size: 14, color: const Color(0xFF43A047)),
                        const SizedBox(width: 4),
                        Text(
                          'Concluído',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF43A047),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Lock overlay ───────────────────────────────────────────────
            if (locked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Premium',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Toca para desbloquear',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BADGE ICON (with optional glow when completed)
// =============================================================================

class _BadgeIcon extends StatelessWidget {
  final String badge;
  final bool glowing;
  final bool locked;

  const _BadgeIcon({
    required this.badge,
    required this.glowing,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = locked ? '🔒' : badge;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked
            ? Colors.grey.withOpacity(0.1)
            : glowing
                ? const Color(0xFF43A047).withOpacity(0.12)
                : const Color(0xFFFF7043).withOpacity(0.1),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: const Color(0xFF43A047).withOpacity(0.35),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: locked ? 22 : 26),
        ),
      ),
    );
  }
}

// =============================================================================
// STATUS ICON (top right of card)
// =============================================================================

class _StatusIcon extends StatelessWidget {
  final bool isCompleted;
  final bool isLocked;

  const _StatusIcon({required this.isCompleted, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return const Icon(Icons.lock_outline, color: Colors.grey, size: 20);
    }
    if (isCompleted) {
      return const Icon(
          Icons.emoji_events_rounded, color: Color(0xFFFFB300), size: 24);
    }
    return Icon(Icons.arrow_forward_ios_rounded,
        color: Colors.grey[400], size: 16);
  }
}

// =============================================================================
// BOTTOM SHEETS
// =============================================================================

class _LockedSheet extends StatelessWidget {
  final ChallengeModel challenge;
  final VoidCallback onUpgrade;

  const _LockedSheet({required this.challenge, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          const SizedBox(height: 24),
          const Text('🔒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            challenge.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Este desafio é exclusivo para utilizadores Premium. '
            'Adere ao Premium para desbloquear este e outros desafios!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              onUpgrade();
            },
            child: const Text(
              'Desbloquear com Premium ⭐',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _CompletedSheet extends StatelessWidget {
  final ChallengeModel challenge;

  const _CompletedSheet({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B5E20),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          const SizedBox(height: 24),
          Text(challenge.badgeCode, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          Text(
            challenge.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            '🎉 Desafio concluído! Badge conquistado!',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _AvailableSheet extends StatelessWidget {
  final ChallengeModel challenge;

  const _AvailableSheet({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Handle(),
          const SizedBox(height: 24),
          Text(challenge.badgeCode, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            challenge.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Usa os ingredientes abaixo numa receita gerada com IA para '
            'completar este desafio e ganhar o teu badge.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: challenge.ingredientList.map((ing) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7043).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFF7043).withOpacity(0.35)),
                ),
                child: Text(
                  ing,
                  style: const TextStyle(
                      color: Color(0xFFFF7043),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido!',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY / ERROR STATES
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🍳', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'Sem desafios por agora.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Volta mais tarde!',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar os desafios.',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
