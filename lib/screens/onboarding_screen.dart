import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'login_screen.dart';

// =============================================================================
// ONBOARDING SCREEN
// =============================================================================
// Shown exactly once on first launch.
// On completion, writes `has_seen_onboarding = "true"` to FlutterSecureStorage
// and replaces itself with LoginScreen (no back-stack entry left behind).
//
// Design rules
// ------------
// • Each slide owns its accent colour so the bottom bar + button tint shift
//   smoothly as the user swipes — creating a sense of visual progress.
// • The PageView fills the screen; all chrome (dots, buttons) lives OUTSIDE
//   it to avoid re-layout on each swipe.
// • "Saltar" (skip) is always visible so power users aren't trapped.
// • "Próximo" animates to "Começar Agora" only on the last slide — a clear
//   call-to-action without cognitive overhead on earlier slides.
// =============================================================================

// ── Slide data model ──────────────────────────────────────────────────────────
class _SlideData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;

  const _SlideData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}

const List<_SlideData> _slides = [
  _SlideData(
    emoji: '🥑',
    title: 'Evita o Desperdício',
    subtitle:
        'Digita ou tira uma foto aos ingredientes que tens esquecidos no frigorífico.',
    accent: Color(0xFF43A047),
  ),
  _SlideData(
    emoji: '🍳',
    title: 'Chef de IA Pessoal',
    subtitle:
        'A nossa inteligência artificial cria receitas personalizadas e adaptadas à tua dieta.',
    accent: Color(0xFFFF7043),
  ),
  _SlideData(
    emoji: '⚡',
    title: 'Cozinha e Partilha',
    subtitle:
        'Guarda as tuas receitas favoritas, controla as tuas macros e partilha com amigos!',
    accent: Color(0xFF5C6BC0),
  ),
];

const String _onboardingKey = 'has_seen_onboarding';

// =============================================================================
// WIDGET
// =============================================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _storage = FlutterSecureStorage();

  final PageController _controller = PageController();
  int _currentPage = 0;

  bool get _isLastSlide => _currentPage == _slides.length - 1;

  // ── Complete onboarding ───────────────────────────────────────────────────
  // Persists the flag so subsequent launches skip straight to LoginScreen,
  // then replaces the route so there is no back-stack entry to the onboarding.
  Future<void> _complete() async {
    try {
      await _storage.write(key: _onboardingKey, value: 'true');
    } catch (e) {
      // Storage failure is non-fatal — the worst outcome is seeing onboarding
      // again on the next launch. Log and continue.
      debugPrint('[OnboardingScreen] Falha ao guardar flag: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Next page or complete ─────────────────────────────────────────────────
  void _next() {
    if (_isLastSlide) {
      _complete();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = _slides[_currentPage].accent;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _isLastSlide ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _isLastSlide ? null : _complete,
                  child: Text(
                    'Saltar',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // ── Slides ───────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, index) => _Slide(data: _slides[index]),
              ),
            ),

            // ── Dots ─────────────────────────────────────────────────────────
            _DotIndicator(
              count: _slides.length,
              current: _currentPage,
              accent: accent,
            ),

            const SizedBox(height: 24),

            // ── Primary action button ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _next,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _isLastSlide ? 'Começar Agora 🚀' : 'Próximo →',
                          key: ValueKey(_isLastSlide),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// =============================================================================
// SLIDE WIDGET
// =============================================================================

class _Slide extends StatelessWidget {
  final _SlideData data;

  const _Slide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Emoji badge ──────────────────────────────────────────────────────
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                data.emoji,
                style: const TextStyle(fontSize: 68),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // ── Title ────────────────────────────────────────────────────────────
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: data.accent,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // ── Subtitle ─────────────────────────────────────────────────────────
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: Colors.grey[700],
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DOT INDICATOR
// =============================================================================

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color accent;

  const _DotIndicator({
    required this.count,
    required this.current,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? accent : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
