import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../main.dart' show appApi, billingService;
import '../models/recipe.dart';
import 'paywall_screen.dart';

// =============================================================================
// HANDS FREE SCREEN — Cozinha Guiada por Voz
// =============================================================================
// Permite navegar pelos passos de uma receita com comandos de voz:
//   "Seguinte" / "Próximo"  → avança um passo
//   "Repete"  / "De novo"   → relê o passo atual
//   "Anterior" / "Volta"    → recua um passo
//
// Regra Premium:
//   - Utilizadores Free     → voz activa até ao passo 3 inclusive.
//     Ao tentar avançar para o passo 4, surge o BottomSheet de paywall.
//   - Utilizadores Premium  → fluxo completo sem interrupções.
//
// Ciclo de áudio (após "Ativar Modo Voz"):
//   speak(passo) → onCompletion → startListening → onResult → handleCommand
// =============================================================================

/// Free users may navigate with voice up to (and including) this step index.
const int _kFreeVoiceLimit = 2; // índice 0-based → passos 1-3

class HandsFreeScreen extends StatefulWidget {
  final Recipe recipe;

  const HandsFreeScreen({super.key, required this.recipe});

  @override
  State<HandsFreeScreen> createState() => _HandsFreeScreenState();
}

class _HandsFreeScreenState extends State<HandsFreeScreen>
    with SingleTickerProviderStateMixin {
  // ── Engines (lazy — created only when user taps "Ativar Modo Voz") ───────
  FlutterTts? _tts;
  SpeechToText? _speech;

  // ── Navigation ───────────────────────────────────────────────────────────
  int _currentStep = 0;

  // ── Plan ─────────────────────────────────────────────────────────────────
  bool _isPremium = false;
  bool _planLoaded = false;

  // ── Voice mode ───────────────────────────────────────────────────────────
  bool _voiceActive = false;
  bool _voiceInitializing = false;
  bool _speechAvailable = false;

  // ── UI state ─────────────────────────────────────────────────────────────
  bool _isSpeaking = false;
  bool _isListening = false;
  String _statusText = 'A carregar...';
  String _recognizedText = '';

  // ── Mic pulse animation ───────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  List<String> get _steps => widget.recipe.steps;

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _loadPlan();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tts?.stop();
    _speech?.stop();
    super.dispose();
  }

  // ============================================================================
  // PLAN (no voice plugins — safe on screen open)
  // ============================================================================

  Future<void> _loadPlan() async {
    try {
      final status = await appApi.getUserStatus();
      if (mounted) {
        setState(() {
          _isPremium =
              status['is_premium'] == true || status['plan'] == 'premium';
          _planLoaded = true;
          _statusText =
              'Toca em "Ativar Modo Voz" para começar a cozinhar com as mãos livres.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _planLoaded = true;
          _statusText =
              'Toca em "Ativar Modo Voz" para começar a cozinhar com as mãos livres.';
        });
      }
    }
  }

  // ============================================================================
  // VOICE ACTIVATION (explicit user action — TTS + STT init here only)
  // ============================================================================

  Future<void> _activateVoiceMode() async {
    if (_voiceActive || _voiceInitializing) return;

    setState(() {
      _voiceInitializing = true;
      _statusText = 'A activar modo voz...';
    });

    _tts = FlutterTts();
    _speech = SpeechToText();

    await _tts!.setLanguage('pt-PT');
    await _tts!.setSpeechRate(0.45);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.05);

    _tts!.setCompletionHandler(() {
      if (mounted && _voiceActive && !_isListening) _startListening();
    });

    _tts!.setErrorHandler((msg) {
      debugPrint('[HandsFree] TTS error: $msg');
    });

    _speechAvailable = await _speech!.initialize(
      onStatus: _onSpeechStatus,
      onError: (err) {
        debugPrint('[HandsFree] STT error: $err');
        if (mounted) {
          _pulseCtrl.stop();
          setState(() {
            _isListening = false;
            _statusText = 'Erro no microfone. Usa os botões abaixo.';
          });
        }
      },
    );

    if (!mounted) return;

    if (!_speechAvailable) {
      setState(() {
        _voiceInitializing = false;
        _tts = null;
        _speech = null;
        _statusText = 'Microfone indisponível. Usa os botões abaixo.';
      });
      return;
    }

    setState(() {
      _voiceActive = true;
      _voiceInitializing = false;
      _statusText = 'Pronto! Diz "Seguinte", "Repete" ou "Anterior".';
    });

    await _speakCurrentStep();
  }

  // ============================================================================
  // STT STATUS
  // ============================================================================

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening') {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      setState(() => _isListening = false);
    }
  }

  // ============================================================================
  // SPEAK
  // ============================================================================

  Future<void> _speakCurrentStep() async {
    if (!mounted || !_voiceActive || _tts == null) return;

    await _tts!.stop();
    await _speech?.stop();

    setState(() {
      _isSpeaking = true;
      _isListening = false;
      _recognizedText = '';
      _statusText = 'A ler passo ${_currentStep + 1}…';
    });
    _pulseCtrl.stop();

    final text = 'Passo ${_currentStep + 1}. ${_steps[_currentStep]}';
    await _tts!.speak(text);

    if (mounted) setState(() => _isSpeaking = false);
  }

  // ============================================================================
  // LISTEN
  // ============================================================================

  Future<void> _startListening() async {
    if (!_voiceActive || !_speechAvailable || _speech == null || !mounted) {
      return;
    }
    await _speech!.stop();

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _statusText = 'A ouvir… Diz "Seguinte", "Repete" ou "Anterior"';
    });
    _pulseCtrl.repeat(reverse: true);

    await _speech!.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      localeId: 'pt_PT',
      cancelOnError: false,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _recognizedText = result.recognizedWords);

    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      _handleCommand(result.recognizedWords);
    }
  }

  // ============================================================================
  // COMMAND HANDLER
  // ============================================================================

  void _handleCommand(String words) {
    final w = words.toLowerCase();

    if (_containsAny(w, ['seguinte', 'proximo', 'próximo', 'avança', 'avanca'])) {
      _nextStep();
    } else if (_containsAny(w, ['repete', 'repetir', 'de novo', 'outra vez', 'outra'])) {
      _repeatStep();
    } else if (_containsAny(w, ['anterior', 'volta', 'voltar', 'atras', 'atrás'])) {
      _previousStep();
    } else {
      setState(() => _statusText = 'Não entendi "${words}". Tenta novamente.');
      _startListening();
    }
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any(text.contains);

  // ============================================================================
  // NAVIGATION
  // ============================================================================

  void _nextStep() {
    if (!_isPremium && _currentStep >= _kFreeVoiceLimit) {
      _tts?.stop();
      _speech?.stop();
      _pulseCtrl.stop();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
        _statusText = 'Limites do plano Free atingidos.';
      });
      _showPremiumGate();
      return;
    }

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      if (_voiceActive) {
        _speakCurrentStep();
      }
    } else if (_voiceActive && _tts != null) {
      _tts!.speak('Parabéns! Chegaste ao fim da receita. Bom apetite!');
      setState(() => _statusText = '🎉 Receita concluída!');
    } else {
      setState(() => _statusText = '🎉 Receita concluída!');
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      if (_voiceActive) {
        _speakCurrentStep();
      }
    } else if (_voiceActive && _tts != null) {
      _tts!.speak('Já estás no primeiro passo.');
      setState(() => _statusText = 'Já estás no passo 1.');
      Future.delayed(const Duration(seconds: 2), _startListening);
    }
  }

  void _repeatStep() {
    if (_voiceActive) {
      _speakCurrentStep();
    }
  }

  // ============================================================================
  // PREMIUM GATE
  // ============================================================================

  Future<void> _refreshPremiumStatus() async {
    try {
      final status = await appApi.getUserStatus();
      if (!mounted) return;
      setState(() {
        _isPremium =
            status['is_premium'] == true || status['plan'] == 'premium';
      });
    } catch (_) {
      // Keep local optimistic state if refresh fails.
    }
  }

  void _showPremiumGate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PremiumGateSheet(
        onUpgrade: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaywallScreen(
                billingService: billingService,
                onPurchaseSuccess: _refreshPremiumStatus,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    if (!_planLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF7043)),
        ),
      );
    }

    final isLastStep = _currentStep == _steps.length - 1;
    final isAtLimit = !_isPremium && _currentStep >= _kFreeVoiceLimit;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.mic, color: Color(0xFFFF7043), size: 20),
            SizedBox(width: 8),
            Text('Modo Mãos Livres',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (!_isPremium)
            TextButton(
              onPressed: _showPremiumGate,
              child: const Text('Premium ⭐',
                  style: TextStyle(color: Color(0xFFFF7043))),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              // ── Step counter ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Passo ${_currentStep + 1}',
                    style: const TextStyle(
                      color: Color(0xFFFF7043),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    ' de ${_steps.length}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 14),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Progress bar ───────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _steps.length,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFFF7043),
                  minHeight: 5,
                ),
              ),

              // ── Free plan limit hint ───────────────────────────────────────
              if (!_isPremium) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (i) {
                    final isFree = i <= _kFreeVoiceLimit;
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFree
                            ? const Color(0xFFFF7043)
                            : Colors.white24,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPremium ? '' : 'Voz gratuita: passos 1-${_kFreeVoiceLimit + 1}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],

              const SizedBox(height: 24),

              // ── Step text card ─────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _steps[_currentStep],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Microphone / speaker indicator ────────────────────────────
              SizedBox(
                height: 72,
                child: Center(
                  child: _isListening
                      ? ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF7043).withOpacity(0.15),
                              border: Border.all(
                                  color: const Color(0xFFFF7043), width: 2),
                            ),
                            child: const Icon(Icons.mic,
                                color: Color(0xFFFF7043), size: 30),
                          ),
                        )
                      : _isSpeaking
                          ? const Icon(Icons.volume_up,
                              color: Colors.white54, size: 36)
                          : const Icon(Icons.mic_none,
                              color: Colors.white24, size: 36),
                ),
              ),

              const SizedBox(height: 10),

              // ── Status / recognised text ───────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _recognizedText.isNotEmpty
                      ? '"$_recognizedText"'
                      : _statusText,
                  key: ValueKey(_recognizedText + _statusText),
                  style: TextStyle(
                    color: _recognizedText.isNotEmpty
                        ? const Color(0xFFFF7043)
                        : Colors.white54,
                    fontSize: 13,
                    fontStyle: _recognizedText.isNotEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Premium limit CTA ──────────────────────────────────────────
              if (isAtLimit && !isLastStep) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _showPremiumGate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7043).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFF7043).withOpacity(0.35)),
                    ),
                    child: const Text(
                      '⭐ Continua com voz além do passo 3 — Adere ao Premium',
                      style:
                          TextStyle(color: Color(0xFFFF7043), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],

              // ── Activate voice mode (lazy plugin init) ─────────────────────
              if (!_voiceActive) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _voiceInitializing ? null : _activateVoiceMode,
                    icon: _voiceInitializing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.mic, color: Colors.white),
                    label: Text(
                      _voiceInitializing
                          ? 'A activar...'
                          : 'Ativar Modo Voz',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Touch navigation (fallback) ────────────────────────────────
              Row(
                children: [
                  _NavButton(
                    icon: Icons.skip_previous_rounded,
                    label: 'Anterior',
                    enabled: _currentStep > 0,
                    onTap: _previousStep,
                  ),
                  const SizedBox(width: 8),
                  _NavButton(
                    icon: Icons.replay_rounded,
                    label: 'Repete',
                    enabled: true,
                    onTap: _repeatStep,
                    accent: false,
                  ),
                  const SizedBox(width: 8),
                  _NavButton(
                    icon: isLastStep
                        ? Icons.check_circle_rounded
                        : Icons.skip_next_rounded,
                    label: isLastStep ? 'Fim ✓' : 'Seguinte',
                    enabled: !isLastStep,
                    onTap: isLastStep ? null : _nextStep,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// NAV BUTTON (touch fallback)
// =============================================================================

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final bool accent;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
    this.accent = true,
  });

  @override
  Widget build(BuildContext context) {
    final col =
        accent ? const Color(0xFFFF7043) : Colors.white70;

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.28,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: enabled ? col.withOpacity(0.35) : Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: enabled ? col : Colors.white24, size: 26),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: enabled ? col : Colors.white24,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PREMIUM GATE BOTTOM SHEET
// =============================================================================

class _PremiumGateSheet extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _PremiumGateSheet({required this.onUpgrade});

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
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          const Text('🎙️', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          const Text(
            'Queres cozinhar com as\nmãos livres até ao fim?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'No plano Free, o controlo por voz está disponível até ao 3.º passo. '
            'Com o Premium, navega por toda a receita sem tocar no ecrã.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: onUpgrade,
            child: const Text(
              'Adere ao Premium — Mãos Livres Total ⭐',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continuar com os botões por agora',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
