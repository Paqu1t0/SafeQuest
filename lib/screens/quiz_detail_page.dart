import 'package:flutter/material.dart';
import 'package:projeto_safequest/screens/assistent_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ DETAIL PAGE
// Mostra o detalhe de um quiz realizado: perguntas certas, erradas e botão IA
// ─────────────────────────────────────────────────────────────────────────────

class QuizDetailPage extends StatelessWidget {
  final Map<String, dynamic> quizResult;

  const QuizDetailPage({super.key, required this.quizResult});

  // ── cores ──────────────────────────────────────────────────────────────────
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _green       = Color(0xFF16A34A);
  static const _red         = Color(0xFFDC2626);
  static const _amber       = Color(0xFFD97706);
  static const _bgColor     = Color(0xFFF8FAFC);

  // ── helpers ────────────────────────────────────────────────────────────────

  Color get _scoreColor {
    final p = (quizResult['percent'] ?? 0) as num;
    if (p >= 70) return _green;
    if (p >= 40) return _amber;
    return _red;
  }

  IconData get _scoreIcon {
    final p = (quizResult['percent'] ?? 0) as num;
    if (p >= 70) return Icons.check_circle_rounded;
    if (p >= 40) return Icons.warning_amber_rounded;
    return Icons.cancel_rounded;
  }

  String get _scoreLabel {
    final p = (quizResult['percent'] ?? 0) as num;
    if (p >= 70) return 'Bom';
    if (p >= 40) return 'Fraco';
    return 'Mau';
  }

  List<Map<String, dynamic>> get _questions {
    final raw = quizResult['questions'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  List<Map<String, dynamic>> get _wrongQuestions =>
      _questions.where((q) => q['isCorrect'] != true).toList();

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme       = quizResult['theme'] ?? 'Quiz';
    final percent     = quizResult['percent'] ?? 0;
    final points      = quizResult['points'] ?? 0;
    final time        = quizResult['time'] ?? '—';
    final dateStr     = quizResult['dateStr'] ?? '';
    final dificuldade = quizResult['dificuldade'] ?? '';
    final questions   = _questions;
    final wrongCount  = _wrongQuestions.length;
    final correct     = (quizResult['correct'] ?? 0) as int;
    final total       = (quizResult['total'] ?? questions.length) as int;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _primaryDeep, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              theme,
              style: const TextStyle(
                color: _primaryDeep,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            if (dificuldade.isNotEmpty)
              Text(
                dificuldade,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cartão de resumo ──────────────────────────────────────────
            _buildSummaryCard(
                percent, points, time, dateStr, correct, total),

            const SizedBox(height: 28),

            // ── Botão perguntar ao assistente (só se houver erros) ────────
            if (wrongCount > 0) _buildAskAIButton(context),

            if (wrongCount > 0) const SizedBox(height: 28),

            // ── Lista de perguntas ────────────────────────────────────────
            if (questions.isEmpty)
              _buildNoDetailCard()
            else ...[
              Row(
                children: [
                  const Text(
                    'Revisão das Perguntas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryDeep,
                    ),
                  ),
                  const Spacer(),
                  _pill('$correct corretas', _green),
                  const SizedBox(width: 8),
                  if (wrongCount > 0) _pill('$wrongCount erradas', _red),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(
                questions.length,
                (i) => _buildQuestionCard(context, i, questions[i]),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── SUMMARY CARD ───────────────────────────────────────────────────────────

  Widget _buildSummaryCard(
      int percent, int points, String time, String dateStr, int correct, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, const Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Score central
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _scoreLabel,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _summaryItem(Icons.check_circle_outline, '$correct/$total', 'Acertos'),
              _summaryItem(Icons.star_rounded, '+$points', 'Pontos'),
              _summaryItem(Icons.timer_outlined, time, 'Tempo'),
            ],
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  // ── BOTÃO PERGUNTAR AO ASSISTENTE ─────────────────────────────────────────

  Widget _buildAskAIButton(BuildContext context) {
    final wrongQs = _wrongQuestions;

    // Monta o prompt com as perguntas erradas
    final buffer = StringBuffer();
    buffer.writeln(
        'Olá! Acabei de fazer um quiz sobre "${quizResult['theme']}" e errei as seguintes perguntas. Podes explicar-me cada uma?');
    buffer.writeln();
    for (int i = 0; i < wrongQs.length; i++) {
      final q           = wrongQs[i];
      final options     = List<String>.from(q['options'] ?? []);
      final correctIdx  = (q['correctIndex'] ?? 0) as int;
      final userIdx     = q['userAnswer'] as int?;
      final correctAns  = correctIdx < options.length ? options[correctIdx] : '—';
      final userAns     =
          userIdx != null && userIdx < options.length ? options[userIdx] : '—';

      buffer.writeln('Pergunta ${i + 1}: ${q['question']}');
      buffer.writeln('  • A minha resposta: $userAns');
      buffer.writeln('  • Resposta correta: $correctAns');
      buffer.writeln();
    }

    final prompt = buffer.toString();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AssistantPage(initialPrompt: prompt),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perguntar ao Assistente IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Explica-me as ${_wrongQuestions.length} pergunta(s) que errei',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ── QUESTION CARD ─────────────────────────────────────────────────────────

  Widget _buildQuestionCard(
      BuildContext context, int index, Map<String, dynamic> q) {
    final isCorrect  = q['isCorrect'] == true;
    final options    = List<String>.from(q['options'] ?? []);
    final correctIdx = (q['correctIndex'] ?? 0) as int;
    final userIdx    = q['userAnswer'] as int?;

    final cardBorder = isCorrect
        ? _green.withOpacity(0.3)
        : _red.withOpacity(0.3);
    final cardBg     = isCorrect
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFFF1F1);
    final iconData   = isCorrect
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;
    final iconColor  = isCorrect ? _green : _red;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da pergunta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconData, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pergunta ${index + 1}: ${q['question'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _primaryDeep,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Opções
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: List.generate(options.length, (i) {
                final isCorrectOption = i == correctIdx;
                final isUserAnswer    = i == userIdx;
                final isWrongUserPick = isUserAnswer && !isCorrectOption;

                Color bg     = Colors.transparent;
                Color border = const Color(0xFFE5E7EB);
                Color text   = const Color(0xFF374151);
                Widget? trailing;

                if (isCorrectOption) {
                  bg     = const Color(0xFFF0FDF4);
                  border = _green;
                  text   = _green;
                  trailing = const Icon(Icons.check_rounded,
                      color: Color(0xFF16A34A), size: 18);
                } else if (isWrongUserPick) {
                  bg     = const Color(0xFFFEF2F2);
                  border = _red;
                  text   = _red;
                  trailing = const Icon(Icons.close_rounded,
                      color: Color(0xFFDC2626), size: 18);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          options[i],
                          style: TextStyle(
                            fontSize: 13,
                            color: text,
                            fontWeight: (isCorrectOption || isWrongUserPick)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing,
                    ],
                  ),
                );
              }),
            ),
          ),

          // Botão individual "Perguntar ao IA" (só para perguntas erradas)
          if (!isCorrect)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _buildAskAISmallButton(context, q, options, correctIdx, userIdx),
            ),
        ],
      ),
    );
  }

  // ── BOTÃO PEQUENO INDIVIDUAL ──────────────────────────────────────────────

  Widget _buildAskAISmallButton(
    BuildContext context,
    Map<String, dynamic> q,
    List<String> options,
    int correctIdx,
    int? userIdx,
  ) {
    final correctAns = correctIdx < options.length ? options[correctIdx] : '—';
    final userAns    = userIdx != null && userIdx < options.length
        ? options[userIdx]
        : '—';

    final prompt =
        'Olá! Errei esta pergunta de um quiz sobre "${quizResult['theme']}".\n\n'
        'Pergunta: ${q['question']}\n'
        'A minha resposta: $userAns\n'
        'Resposta correta: $correctAns\n\n'
        'Podes explicar-me porquê a resposta correta é "$correctAns" e ajudar-me a entender melhor este conceito?';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AssistantPage(initialPrompt: prompt),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.psychology_rounded, color: Color(0xFF7C3AED), size: 16),
            SizedBox(width: 7),
            Text(
              'Explicar esta pergunta com IA',
              style: TextStyle(
                color: Color(0xFF7C3AED),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SEM DETALHE (quizzes antigos sem o campo questions) ───────────────────

  Widget _buildNoDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'O detalhe das perguntas não está disponível para quizzes realizados antes desta atualização.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── PILL ──────────────────────────────────────────────────────────────────

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}