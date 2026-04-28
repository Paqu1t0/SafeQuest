import 'dart:math';
import 'package:flutter/material.dart';
import 'package:projeto_safequest/screens/assistent_page.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizResultDialog extends StatefulWidget {
  final int percent;
  final int points;
  final int correct;
  final int total;
  final String timeStr;
  final String tema;
  final String? newBadge;    // nome do emblema real desbloqueado
  final String? comboLabel;  // texto do combo (ex: "✨ ×1.2 Combo x3!")
  final List<Map<String, dynamic>> wrongQuestions;
  final int moedasGanhas;
  final bool leveledUp;      // se o utilizador subiu de nível
  final int newNivel;        // novo nível atingido

  const QuizResultDialog({
    super.key,
    required this.percent,
    required this.points,
    required this.correct,
    required this.total,
    required this.timeStr,
    required this.tema,
    this.newBadge,
    this.comboLabel,
    required this.wrongQuestions,
    this.moedasGanhas = 0,
    this.leveledUp = false,
    this.newNivel  = 1,
  });

  @override
  State<QuizResultDialog> createState() => _QuizResultDialogState();
}

class _QuizResultDialogState extends State<QuizResultDialog>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _circleCtrl;
  late AnimationController _badgeCtrl;
  late AnimationController _starsCtrl;
  late AnimationController _coinsCtrl;
  late AnimationController _levelUpCtrl;   // ← level up banner
  late ConfettiController _confettiCtrl;
  late ConfettiController _levelUpConfettiCtrl; // ← confetti extra level up

  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _circleProgress;
  late Animation<double> _badgeScale;
  late Animation<double> _starsOpacity;
  late Animation<double> _coinsScale;
  late Animation<double> _coinsOpacity;
  late Animation<double> _levelUpScale;
  late Animation<double> _levelUpOpacity;

  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  late List<_CoinParticle> _particles;

  @override
  void initState() {
    super.initState();

    _particles = List.generate(8, (i) => _CoinParticle(i));

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 60, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _circleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _circleProgress = Tween<double>(begin: 0, end: widget.percent / 100)
        .animate(CurvedAnimation(parent: _circleCtrl, curve: Curves.easeInOut));

    _starsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _starsOpacity = CurvedAnimation(parent: _starsCtrl, curve: Curves.easeIn);

    _badgeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _badgeCtrl, curve: Curves.elasticOut));

    _coinsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _coinsScale   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _coinsCtrl, curve: Curves.elasticOut));
    _coinsOpacity = CurvedAnimation(parent: _coinsCtrl, curve: Curves.easeIn);

    // Level Up banner
    _levelUpCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _levelUpScale   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _levelUpCtrl, curve: Curves.elasticOut));
    _levelUpOpacity = CurvedAnimation(parent: _levelUpCtrl, curve: Curves.easeIn);

    // Confetti principal — dispara quando a pontuação é boa
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    // Confetti extra para Level Up
    _levelUpConfettiCtrl = ConfettiController(duration: const Duration(seconds: 4));

    _entryCtrl.forward().then((_) {
      _starsCtrl.forward();
      _circleCtrl.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 200),
            () { if (mounted) _coinsCtrl.forward(); });
        if (widget.percent >= 70) {
          Future.delayed(const Duration(milliseconds: 300),
              () { if (mounted) _confettiCtrl.play(); });
        }
        if (widget.newBadge != null) {
          Future.delayed(const Duration(milliseconds: 600),
              () { if (mounted) _badgeCtrl.forward(); });
        }
        // Level Up — dispara após o badge (ou logo após os coins)
        if (widget.leveledUp) {
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) {
              _levelUpCtrl.forward();
              _levelUpConfettiCtrl.play();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _circleCtrl.dispose();
    _badgeCtrl.dispose();
    _starsCtrl.dispose();
    _coinsCtrl.dispose();
    _levelUpCtrl.dispose();
    _confettiCtrl.dispose();
    _levelUpConfettiCtrl.dispose();
    super.dispose();
  }

  String get _titulo {
    if (widget.percent == 100) return 'Perfeito! 🎯';
    if (widget.percent >= 70)  return 'Excelente Trabalho!';
    if (widget.percent >= 40)  return 'Bom Esforço!';
    return 'Continua a Treinar!';
  }

  String get _subtitulo => 'Completou o Quiz de ${widget.tema}';

  Color get _circleColor {
    if (widget.percent >= 70) return _primary;
    if (widget.percent >= 40) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _entryCtrl,
            builder: (_, child) => Opacity(
              opacity: _fadeIn.value,
              child: Transform.translate(
                offset: Offset(0, _slideUp.value),
                child: child,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Card principal ───────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          _buildGradientHeader(),
                          const SizedBox(height: 28),
                          _buildCirclePercent(),
                          const SizedBox(height: 24),
                          _buildStatsRow(),
                          const SizedBox(height: 16),
                          _buildCoinsAnimation(),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Banner de Level Up ────────────────────────────────────
                    if (widget.leveledUp) _buildLevelUpBanner(),
                    if (widget.leveledUp) const SizedBox(height: 12),

                    // ── Banner de novo emblema (badge real) ──────────────────
                    if (widget.newBadge != null) _buildBadgeBanner(),
                    if (widget.newBadge != null) const SizedBox(height: 12),

                    // ── Banner de combo (se houver) ────────────────────────────
                    if (widget.comboLabel != null) _buildComboLabel(),
                    if (widget.comboLabel != null) const SizedBox(height: 12),

                    // ── Botão: Partilhar no Clã ───────────────────────────────
                    _buildShareToClanButton(context),
                    const SizedBox(height: 10),

                    // ── Botão: Partilhar resultado ────────────────────────────
                    _buildShareButton(),
                    const SizedBox(height: 10),

                    // ── Botão: Rever com IA ───────────────────────────────────
                    if (widget.wrongQuestions.isNotEmpty) _buildReviewButton(context),
                    if (widget.wrongQuestions.isNotEmpty) const SizedBox(height: 10),

                    // ── Botão: Voltar ao início ───────────────────────────────
                    _buildBackButton(context),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          // ── Confetti principal ────────────────────────────────────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.08,
              numberOfParticles: 22,
              gravity: 0.2,
              colors: const [
                Color(0xFF1A56DB), Color(0xFFF59E0B), Color(0xFF16A34A),
                Color(0xFF7C3AED), Color(0xFFEA580C), Color(0xFFDB2777),
              ],
            ),
          ),
          // ── Confetti extra Level Up (dourado) ────────────────────────────
          if (widget.leveledUp)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _levelUpConfettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.03,
                emissionFrequency: 0.12,
                numberOfParticles: 35,
                gravity: 0.15,
                colors: const [
                  Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A),
                  Color(0xFFFFD700), Color(0xFFF97316), Color(0xFFFFFFFF),
                ],
              ),
            ),
        ],
      ),
    );
  }


  // ── HEADER COM GRADIENTE ───────────────────────────────────────────────────

  Widget _buildGradientHeader() {
    final List<Color> gradientColors;
    if (widget.percent >= 70) {
      gradientColors = [const Color(0xFF1A56DB), const Color(0xFF1E40AF)];
    } else if (widget.percent >= 40) {
      gradientColors = [const Color(0xFFD97706), const Color(0xFFB45309)];
    } else {
      gradientColors = [const Color(0xFFDC2626), const Color(0xFFB91C1C)];
    }

    return AnimatedBuilder(
      animation: _starsOpacity,
      builder: (_, __) => Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -30, right: -30,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)),
              ),
            ),
            Positioned(
              bottom: -20, left: -20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)),
              ),
            ),
            Positioned(
              left: 28, top: 22,
              child: Opacity(opacity: _starsOpacity.value, child: Transform.rotate(angle: -0.4, child: const Icon(Icons.star_rounded, color: Color(0xFFFDE68A), size: 22))),
            ),
            Positioned(
              right: 28, top: 18,
              child: Opacity(opacity: _starsOpacity.value, child: Transform.rotate(angle: 0.4, child: const Icon(Icons.star_rounded, color: Color(0xFFFDE68A), size: 26))),
            ),
            Positioned(
              left: 55, top: 55,
              child: Opacity(opacity: _starsOpacity.value * 0.7, child: const Icon(Icons.star_rounded, color: Color(0xFFFDE68A), size: 14)),
            ),
            Positioned(
              right: 55, top: 60,
              child: Opacity(opacity: _starsOpacity.value * 0.7, child: const Icon(Icons.star_rounded, color: Color(0xFFFDE68A), size: 14)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Stack(alignment: Alignment.center, children: [
                    Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15))),
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))]),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(_titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text(_subtitulo, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildCirclePercent() {
    return AnimatedBuilder(
      animation: _circleProgress,
      builder: (_, __) {
        final pct = (_circleProgress.value * 100).round();
        return SizedBox(
          width: 140, height: 140,
          child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(value: 1, strokeWidth: 10, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE2E8F0))),
            CircularProgressIndicator(value: _circleProgress.value, strokeWidth: 10, strokeCap: StrokeCap.round, valueColor: AlwaysStoppedAnimation<Color>(_circleColor)),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$pct%', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _primaryDeep)),
              const Text('Pontuação', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
          ]),
        );
      },
    );
  }

  // ── STATS ROW ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(child: _statBox('Corretas', '${widget.correct}/${widget.total}', false)),
        const SizedBox(width: 12),
        Expanded(child: _statBox('Tempo', widget.timeStr, false)),
      ]),
    );
  }

  Widget _statBox(String label, String value, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? _primary.withOpacity(0.2) : const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: highlight ? _primary : _primaryDeep)),
      ]),
    );
  }

  // ── BANNER LEVEL UP ──────────────────────────────────────────────────────────

  Widget _buildLevelUpBanner() {
    return ScaleTransition(
      scale: _levelUpScale,
      child: FadeTransition(
        opacity: _levelUpOpacity,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFFFD700)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ícone pulsante
              _PulseIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⬆️  SUBISTE DE NÍVEL!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bem-vindo ao Nível ${widget.newNivel}! 🏆',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Continua a fazer quizzes para subir ainda mais!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge do nível
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text('NÍV.', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    Text(
                      '${widget.newNivel}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BANNER EMBLEMA (badge real) ────────────────────────────────────────────

  Widget _buildBadgeBanner() {
    const badgeEmoji = <String, String>{
      'Primeira Vitória': '🏆', 'Aprendiz Rápido': '⚡', 'Perfeccionista': '🎯',
      'Guru da Segurança': '🎓', 'Estudante Dedicado': '📚', 'Velocista': '⏱️',
      'Detetive': '🔍', 'Invicto': '👑', 'Madrugador': '🌟',
      'Guerreiro do Clã': '⚔️', 'Iniciante em Phishing': '🛡️',
      'Especialista em Phishing': '🔒', 'Mestre Anti-Phishing': '🦅',
      'Caçador de Phishing': '🎯', 'Detetive Digital': '🔍',
      'Guardião de Senhas': '🔑', 'Mestre das Palavras-passe': '🔐',
      'Criador de Senhas Fortes': '💎', 'Vault Keeper': '🏦',
      'Velocista das Senhas': '⚡', 'Surfista Web': '🌐',
      'Navegador Seguro': '🛡️', 'Guardião da Web': '🦅',
      'Hacker Ético': '💻', 'HTTPS Hero': '🔒',
      'Navegador Social': '📱', 'Influencer Seguro': '⭐',
      'Protetor Digital': '🛡️', 'Social Master': '🌟', 'Privacidade Pro': '🔐',
    };
    final emoji = badgeEmoji[widget.newBadge] ?? '🏅';

    return ScaleTransition(
      scale: _badgeScale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF1A56DB)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🏅 Novo Emblema Desbloqueado!',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(widget.newBadge!,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
          ),
          _SparkleIcon(),
        ]),
      ),
    );
  }

  // ── BANNER COMBO ───────────────────────────────────────────────────────────

  Widget _buildComboLabel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFF59E0B)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔥', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(widget.comboLabel!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    );
  }

  // ── BOTÃO REVER COM IA ─────────────────────────────────────────────────────

  Widget _buildReviewButton(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('Olá! Acabei de fazer um quiz sobre "${widget.tema}" e errei as seguintes perguntas. Podes explicar-me cada uma?');
    buffer.writeln();
    for (int i = 0; i < widget.wrongQuestions.length; i++) {
      final q          = widget.wrongQuestions[i];
      final options    = List<String>.from(q['options'] ?? []);
      final correctIdx = (q['correctIndex'] ?? 0) as int;
      final userIdx    = q['userAnswer'] as int?;
      buffer.writeln('Pergunta ${i + 1}: ${q['question']}');
      final myAnswer = (userIdx == null || userIdx < 0)
          ? (userIdx == -1 ? '(Tempo esgotado)' : '—')
          : (userIdx < options.length ? options[userIdx] : '—');
      buffer.writeln('  • A minha resposta: $myAnswer');
      buffer.writeln('  • Resposta correta: ${correctIdx < options.length ? options[correctIdx] : "—"}');
      buffer.writeln();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        icon: const Icon(Icons.psychology_rounded, size: 20),
        label: const Text('Rever com Assistente IA  →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          Navigator.push(context, MaterialPageRoute(builder: (_) => AssistantPage(initialPrompt: buffer.toString())));
        },
      ),
    );
  }

  // ── BOTÃO PARTILHAR NO CLÃ ────────────────────────────────────────────────

  Widget _buildShareToClanButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF7C3AED),
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: const Icon(Icons.groups_rounded, color: Color(0xFF7C3AED), size: 20),
        label: const Text('Partilhar no Clã', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 15, fontWeight: FontWeight.bold)),
        onPressed: () async {
          // 1. Lê o clanId do utilizador
          final userDoc = await FirebaseFirestore.instance
              .collection('users').doc(user.uid).get();
          final userData   = userDoc.data() as Map<String, dynamic>? ?? {};
          final clanId     = userData['clanId'] as String?;
          final senderName = userData['nickname'] ?? userData['name'] ?? 'Jogador';

          if (clanId == null || clanId.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Não estás em nenhum clã! Junta-te a um clã primeiro.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // 2. Compila a mensagem formatada
          final medal = widget.percent == 100 ? '🥇' : widget.percent >= 70 ? '🥈' : '🥉';
          final text = '📊 $senderName partilhou um resultado:\n'
              '$medal Quiz de ${widget.tema}\n'
              '✅ ${widget.correct}/${widget.total} corretas (${widget.percent}%)\n'
              '⚡ +${widget.points} XP\n'
              '⏱️ ${widget.timeStr}';

          // 3. Publica no chat do clã
          await FirebaseFirestore.instance
              .collection('clans').doc(clanId).collection('messages').add({
            'text'      : text,
            'uid'       : user.uid,
            'senderName': senderName,
            'isSystem'  : false,
            'isResult'  : true,
            'timestamp' : FieldValue.serverTimestamp(),
          });

          if (context.mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Resultado partilhado no chat do clã!'),
                backgroundColor: Color(0xFF7C3AED),
              ),
            );
          }
        },
      ),
    );
  }

  // ── BOTÃO PARTILHAR ────────────────────────────────────────────────────────

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF16A34A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: const Icon(Icons.share_rounded, color: Color(0xFF16A34A), size: 20),
        label: const Text('Partilhar Resultado', style: TextStyle(color: Color(0xFF16A34A), fontSize: 15, fontWeight: FontWeight.bold)),
        onPressed: () {
          final medal = widget.percent == 100 ? '🥇' : widget.percent >= 70 ? '🥈' : '🥉';
          final msg = '$medal Completei o quiz de ${widget.tema} no SafeQuest!\n\n'
              '📊 Pontuação: ${widget.percent}%\n'
              '✅ Corretas: ${widget.correct}/${widget.total}\n'
              '⚡ XP ganho: +${widget.points}\n'
              '⏱️ Tempo: ${widget.timeStr}\n\n'
              '🛡️ Aprende cibersegurança comigo no SafeQuest! #SafeQuest #Cibersegurança';
          Share.share(msg, subject: 'O meu resultado no SafeQuest!');
        },
      ),
    );
  }

  // ── BOTÃO VOLTAR ───────────────────────────────────────────────────────────

  Widget _buildBackButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: const Icon(Icons.home_rounded, color: Color(0xFF1A56DB), size: 20),
        label: const Text('Voltar ao Início', style: TextStyle(color: Color(0xFF1A56DB), fontSize: 15, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── ANIMAÇÃO DE MOEDAS GANHAS + XP ────────────────────────────────────────

  Widget _buildCoinsAnimation() {
    final hasMoedas = widget.moedasGanhas > 0;
    return AnimatedBuilder(
      animation: _coinsCtrl,
      builder: (_, __) => Opacity(
        opacity: _coinsOpacity.value,
        child: Transform.scale(
          scale: _coinsScale.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // ── XP ganho ────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primary.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('⚡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('+${widget.points} XP', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
                    const SizedBox(width: 8),
                    const Text('ganhos', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                ),
                const SizedBox(height: 10),
                // ── Moedas ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: hasMoedas ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hasMoedas ? _gold.withOpacity(0.4) : const Color(0xFFE5E7EB)),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (hasMoedas)
                        SizedBox(
                          height: 40,
                          child: Stack(
                            children: _particles.map((p) => Positioned(
                              left: p.x,
                              top: p.y * (1 - _coinsCtrl.value),
                              child: Opacity(
                                opacity: (_coinsCtrl.value * p.opacity).clamp(0.0, 1.0),
                                child: Text('🪙', style: TextStyle(fontSize: p.size)),
                              ),
                            )).toList(),
                          ),
                        ),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(hasMoedas ? '🪙' : '😔', style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            hasMoedas ? '+${widget.moedasGanhas} Moedas' : 'Sem moedas',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasMoedas ? const Color(0xFF92400E) : Colors.grey),
                          ),
                          Text(
                            hasMoedas
                                ? (widget.percent >= 100 ? 'Pontuação perfeita! 🎯' : widget.percent >= 70 ? 'Excelente resultado! 🌟' : 'Chega a 70%+ para mais moedas!')
                                : 'Passa os 20% para ganhar moedas!',
                            style: TextStyle(fontSize: 11, color: hasMoedas ? const Color(0xFF92400E).withOpacity(0.7) : Colors.grey),
                          ),
                        ]),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // fim de _QuizResultDialogState

// ─────────────────────────────────────────────────────────────────────────────
// COIN PARTICLE
// ─────────────────────────────────────────────────────────────────────────────

class _CoinParticle {
  final double x;
  final double y;
  final double size;
  final double opacity;

  _CoinParticle(int seed)
      : x    = (seed * 37.0) % 200,
        y    = -(seed * 13.0 % 30) - 10,
        size = 8.0 + (seed % 3) * 4,
        opacity = 0.4 + (seed % 3) * 0.2;
}

// ─────────────────────────────────────────────────────────────────────────────
// SPARKLE ICON — ícone de faísca animado no banner do emblema
// ─────────────────────────────────────────────────────────────────────────────

class _SparkleIcon extends StatefulWidget {
  @override
  State<_SparkleIcon> createState() => _SparkleIconState();
}

class _SparkleIconState extends State<_SparkleIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _rotate = Tween<double>(begin: 0, end: 2 * pi).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotate,
      builder: (_, __) => Transform.rotate(
        angle: _rotate.value,
        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 26),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PULSE ICON — ícone de estrela pulsante para o banner de Level Up
// ─────────────────────────────────────────────────────────────────────────────

class _PulseIcon extends StatefulWidget {
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: const Center(
            child: Text('⭐', style: TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}