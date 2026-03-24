import 'dart:math';
import 'package:flutter/material.dart';
import 'package:projeto_safequest/screens/assistent_page.dart';

class QuizResultDialog extends StatefulWidget {
  final int percent;
  final int points;
  final int correct;
  final int total;
  final String timeStr;
  final String tema;
  final String? newBadge;
  final List<Map<String, dynamic>> wrongQuestions;
  final int moedasGanhas; // ← novo

  const QuizResultDialog({
    super.key,
    required this.percent,
    required this.points,
    required this.correct,
    required this.total,
    required this.timeStr,
    required this.tema,
    this.newBadge,
    required this.wrongQuestions,
    this.moedasGanhas = 50, // ← default
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
  late AnimationController _coinsCtrl; // ← novo

  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _circleProgress;
  late Animation<double> _badgeScale;
  late Animation<double> _starsOpacity;
  late Animation<double> _coinsScale;   // ← novo
  late Animation<double> _coinsOpacity; // ← novo

  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  // Partículas de moedas flutuantes
  late List<_CoinParticle> _particles;

  @override
  void initState() {
    super.initState();

    _particles = List.generate(8, (i) => _CoinParticle(i));

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 60, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _circleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _circleProgress = Tween<double>(begin: 0, end: widget.percent / 100)
        .animate(CurvedAnimation(parent: _circleCtrl, curve: Curves.easeInOut));

    _starsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _starsOpacity =
        CurvedAnimation(parent: _starsCtrl, curve: Curves.easeIn);

    _badgeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _badgeCtrl, curve: Curves.elasticOut));

    // Animação das moedas — aparece depois do círculo
    _coinsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _coinsScale   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _coinsCtrl, curve: Curves.elasticOut));
    _coinsOpacity = CurvedAnimation(parent: _coinsCtrl, curve: Curves.easeIn);

    // Sequência
    _entryCtrl.forward().then((_) {
      _starsCtrl.forward();
      _circleCtrl.forward().then((_) {
        // Moedas aparecem após o círculo
        Future.delayed(const Duration(milliseconds: 200),
            () { if (mounted) _coinsCtrl.forward(); });
        if (widget.newBadge != null) {
          Future.delayed(const Duration(milliseconds: 600),
              () { if (mounted) _badgeCtrl.forward(); });
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
      child: AnimatedBuilder(
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
                      // ── Animação de moedas ganhas ─────────────────────
                      _buildCoinsAnimation(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Banner de novo emblema ────────────────────────────────
                if (widget.newBadge != null) _buildBadgeBanner(),
                if (widget.newBadge != null) const SizedBox(height: 12),

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
    );
  }

  // ── HEADER COM GRADIENTE ───────────────────────────────────────────────────

  Widget _buildGradientHeader() {
    // Cor do gradiente muda consoante o resultado
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
            // ── Círculos decorativos de fundo ──────────────────────────
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),

            // ── Estrelas animadas ──────────────────────────────────────
            // topo esquerda
            Positioned(
              left: 28,
              top: 22,
              child: Opacity(
                opacity: _starsOpacity.value,
                child: Transform.rotate(
                  angle: -0.4,
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFFDE68A), size: 22),
                ),
              ),
            ),
            // topo direita
            Positioned(
              right: 28,
              top: 18,
              child: Opacity(
                opacity: _starsOpacity.value,
                child: Transform.rotate(
                  angle: 0.4,
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFFDE68A), size: 26),
                ),
              ),
            ),
            // meio esquerda (pequena)
            Positioned(
              left: 55,
              top: 55,
              child: Opacity(
                opacity: _starsOpacity.value * 0.7,
                child: const Icon(Icons.star_rounded,
                    color: Color(0xFFFDE68A), size: 14),
              ),
            ),
            // meio direita (pequena)
            Positioned(
              right: 55,
              top: 60,
              child: Opacity(
                opacity: _starsOpacity.value * 0.7,
                child: const Icon(Icons.star_rounded,
                    color: Color(0xFFFDE68A), size: 14),
              ),
            ),

            // ── Conteúdo central ──────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  // Troféu com halo
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo exterior
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      // Círculo interior
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Título
                  Text(
                    _titulo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Subtítulo
                  Text(
                    _subtitulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TROFÉU + ESTRELAS (mantido por compatibilidade, já não usado) ──────────

  Widget _buildTrofeuComEstrelas() => const SizedBox.shrink();

  // ── CÍRCULO DE PERCENTAGEM ─────────────────────────────────────────────────

  Widget _buildCirclePercent() {
    return AnimatedBuilder(
      animation: _circleProgress,
      builder: (_, __) {
        final pct = (_circleProgress.value * 100).round();
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Círculo de fundo
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFE2E8F0)),
              ),
              // Círculo de progresso
              CircularProgressIndicator(
                value: _circleProgress.value,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation<Color>(_circleColor),
              ),
              // Texto central
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: _primaryDeep,
                      ),
                    ),
                    const Text(
                      'Pontuação',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── STATS ROW ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _statBox('Corretas', '${widget.correct}/${widget.total}', false)),
          const SizedBox(width: 12),
          Expanded(child: _statBox('Pontos Ganhos', '+${widget.points}', true)),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? _primary.withOpacity(0.2)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: highlight ? _primary : _primaryDeep,
            ),
          ),
        ],
      ),
    );
  }

  // ── BANNER EMBLEMA ─────────────────────────────────────────────────────────

  Widget _buildBadgeBanner() {
    return ScaleTransition(
      scale: _badgeScale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.military_tech_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Novo Emblema Conquistado!',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.newBadge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // Faísca animada
            _SparkleIcon(),
          ],
        ),
      ),
    );
  }

  // ── BOTÃO REVER COM IA ─────────────────────────────────────────────────────

  Widget _buildReviewButton(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln(
        'Olá! Acabei de fazer um quiz sobre "${widget.tema}" e errei as seguintes perguntas. Podes explicar-me cada uma?');
    buffer.writeln();
    for (int i = 0; i < widget.wrongQuestions.length; i++) {
      final q          = widget.wrongQuestions[i];
      final options    = List<String>.from(q['options'] ?? []);
      final correctIdx = (q['correctIndex'] ?? 0) as int;
      final userIdx    = q['userAnswer'] as int?;
      buffer.writeln('Pergunta ${i + 1}: ${q['question']}');
      buffer.writeln(
          '  • A minha resposta: ${userIdx != null && userIdx < options.length ? options[userIdx] : "—"}');
      buffer.writeln(
          '  • Resposta correta: ${correctIdx < options.length ? options[correctIdx] : "—"}');
      buffer.writeln();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        icon: const Icon(Icons.psychology_rounded, size: 20),
        label: const Text(
          'Rever com Assistente IA  →',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.of(context).pop(); // fecha dialog
          Navigator.of(context).pop(); // volta ao dashboard
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AssistantPage(initialPrompt: buffer.toString()),
            ),
          );
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
        label: const Text(
          'Voltar ao Início',
          style: TextStyle(
            color: Color(0xFF1A56DB),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── ANIMAÇÃO DE MOEDAS GANHAS ──────────────────────────────────────────────

  Widget _buildCoinsAnimation() {
    return AnimatedBuilder(
      animation: _coinsCtrl,
      builder: (_, __) => Opacity(
        opacity: _coinsOpacity.value,
        child: Transform.scale(
          scale: _coinsScale.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withOpacity(0.4)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 40,
                  child: Stack(
                    children: _particles.map((p) {
                      return Positioned(
                        left: p.x,
                        top: p.y * (1 - _coinsCtrl.value),
                        child: Opacity(
                          opacity:
                              (_coinsCtrl.value * p.opacity).clamp(0.0, 1.0),
                          child: Text(
                            '🪙',
                            style: TextStyle(fontSize: p.size),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+${widget.moedasGanhas} Moedas',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          widget.moedasGanhas >= 100
                              ? 'Bónus por ≥ 70%! 🎯'
                              : 'Completa com ≥ 70% para bónus!',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                const Color(0xFF92400E).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2))
      ..repeat();
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
        child: const Icon(Icons.auto_awesome_rounded,
            color: Color(0xFFFBBF24), size: 26),
      ),
    );
  }
}