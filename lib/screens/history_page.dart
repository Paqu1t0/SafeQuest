import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:projeto_safequest/screens/quiz_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  late TabController _tabCtrl;
  String? _aiAnalysis;
  bool    _aiLoading = false;

  static IconData _classIcon(double p) {
    if (p >= 0.70) return Icons.check_circle_rounded;
    if (p >= 0.40) return Icons.warning_amber_rounded;
    return Icons.cancel_rounded;
  }

  static Color _classColor(double p) {
    if (p >= 0.70) return const Color(0xFF16A34A);
    if (p >= 0.40) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  static String _classLabel(double p) {
    if (p >= 0.70) return "Bom";
    if (p >= 0.40) return "Fraco";
    return "Mau";
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text("Histórico", style: TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold, fontSize: 20)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(border: Border(bottom: BorderSide(color: _primary, width: 3))),
          labelColor: _primary,
          unselectedLabelColor: Colors.grey,
          dividerColor: const Color(0xFFE5E7EB),
          tabs: const [Tab(text: 'Atividade'), Tab(text: '🤖 Análise IA')],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(user?.uid).collection('quiz_results')
            .orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          List<Map<String, dynamic>> displayData = [];
          int    totalQuizzes = 0;
          double media        = 0;
          int    somaPontos   = 0;

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final results = snapshot.data!.docs;
            totalQuizzes  = results.length;
            double somaPercent = 0;
            for (var doc in results) {
              var d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
              somaPercent += (d['percent'] ?? 0).toDouble();
              somaPontos  += ((d['points'] ?? 0) as num).toInt();
              DateTime date = d['date'] != null ? (d['date'] as Timestamp).toDate() : DateTime.now();
              d['dateStr'] = DateFormat('dd MMM yyyy').format(date);
              displayData.add(d);
            }
            media = totalQuizzes > 0 ? somaPercent / totalQuizzes : 0;
          }

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _buildActivityTab(displayData, totalQuizzes, media, somaPontos),
              _buildAITab(displayData),
            ],
          );
        },
      ),
    );
  }


  // ── ABA ATIVIDADE ──────────────────────────────────────────────────────────
  Widget _buildActivityTab(List<Map<String, dynamic>> displayData, int total, double media, int pontos) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _statCard("$total",                          "Quizzes", Icons.calendar_today_outlined),
            _statCard("${media.toStringAsFixed(0)}%",   "Média",   Icons.trending_up),
            _statCard(NumberFormat.decimalPattern().format(pontos), "Pontos", Icons.emoji_events_outlined),
          ]),
          const SizedBox(height: 35),
          const Text("Atividade Recente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDeep)),
          const SizedBox(height: 15),
          if (displayData.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(children: [
                Text('📋', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('Nenhum quiz realizado ainda.', style: TextStyle(color: Colors.grey)),
              ]),
            ))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayData.length,
              itemBuilder: (context, i) => _activityItem(context, displayData[i]),
            ),
        ],
      ),
    );
  }

  // ── ABA ANÁLISE IA ─────────────────────────────────────────────────────────
  Widget _buildAITab(List<Map<String, dynamic>> data) {
    // Largura real do ecrã — acesso direto ao context do State
    final screenW = MediaQuery.of(context).size.width;
    final textW   = screenW - 80; // scrollview 20+20, card 20+20

    if (data.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🤖', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text('Faz alguns quizzes primeiro!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDeep)),
          SizedBox(height: 8),
          Text('A IA precisa de dados para te dar recomendações.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Card do Mentor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Text('🤖', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Análise do Mentor SafeQuest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('IA personalizada para o teu desempenho', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _aiLoading ? null : () => _fetchAIAnalysis(data),
                    child: _aiLoading
                        ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
                            SizedBox(width: 10),
                            Text('A analisar...', style: TextStyle(fontWeight: FontWeight.bold)),
                          ])
                        : const Text('Analisar o meu desempenho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),

          // 2. Resposta da IA
          if (_aiAnalysis != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Recomendações do Mentor',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _primaryDeep)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _renderAIText(_aiAnalysis!, textW),
                ],
              ),
            ),
          ],

          const SizedBox(height: 25),
          _buildThemeBreakdown(data),
        ],
      ),
    );
}

  // ── Renderizador com largura explícita (LayoutBuilder) ────────────────────
  Widget _renderAIText(String text, double maxW) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final t = line.trim();

      if (t.isEmpty) { widgets.add(const SizedBox(height: 6)); continue; }

      if (t == '---') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: Colors.grey.shade200, thickness: 1),
        ));
        continue;
      }

      if (t.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: SizedBox(width: maxW, child: Text(
            t.substring(2).trim(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), height: 1.4),
            softWrap: true,
          )),
        ));
        continue;
      }

      if (t.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: SizedBox(width: maxW, child: Text(
            t.substring(3).trim(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), height: 1.4),
            softWrap: true,
          )),
        ));
        continue;
      }

      if (t.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: SizedBox(width: maxW, child: Text(
            t.substring(4).trim(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151), height: 1.4),
            softWrap: true,
          )),
        ));
        continue;
      }

      // Bullet point
      if ((t.startsWith('• ') || t.startsWith('- ') || t.startsWith('* ')) && !t.startsWith('**')) {
        final content = t.replaceFirst(RegExp(r'^[•\-\*]\s+'), '');
        final bulletW = maxW - 18.0;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('• ', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              SizedBox(width: bulletW, child: _inlineText(content, bulletW)),
            ],
          ),
        ));
        continue;
      }

      // Parágrafo normal
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(width: maxW, child: _inlineText(t, maxW)),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  // Texto inline com **bold** — largura explícita
  Widget _inlineText(String text, double maxW) {
    final regex = RegExp(r'\*\*(.+?)\*\*');
    final matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
      return SizedBox(
        width: maxW,
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151)),
          softWrap: true,
          overflow: TextOverflow.clip,
        ),
      );
    }

    final spans = <TextSpan>[];
    int last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, m.start),
          style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151)),
        ));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151)),
      ));
    }

    return SizedBox(
      width: maxW,
      child: RichText(
        text: TextSpan(children: spans),
        softWrap: true,
        overflow: TextOverflow.clip,
      ),
    );
  }

  Widget _buildThemeBreakdown(List<Map<String, dynamic>> data) {
    final temas = ['Phishing', 'Palavras-passe', 'Redes Sociais', 'Segurança Web'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Desempenho por Tema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _primaryDeep)),
          const SizedBox(height: 16),
          ...temas.map((tema) {
            final themed = data.where((d) => d['theme'] == tema).toList();
            if (themed.isEmpty) return const SizedBox.shrink();
            final avg = themed.fold<double>(0, (s, d) => s + (d['percent'] ?? 0).toDouble()) / themed.length;
            final color = _classColor(avg / 100);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(tema, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _primaryDeep)),
                  Text('${avg.toInt()}% · ${themed.length} quiz${themed.length == 1 ? '' : 'zes'}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: avg / 100),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: val, minHeight: 8, backgroundColor: const Color(0xFFF1F5F9), color: color),
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
Future<void> _fetchAIAnalysis(List<Map<String, dynamic>> data) async {
  setState(() { _aiLoading = true; _aiAnalysis = null; });

  try {
    String docSafeQuest = '';
    try {
      docSafeQuest = await rootBundle.loadString('assets/conhecimento_safequest.txt');
    } catch (_) {
      docSafeQuest = 'Conhecimento base: Foca-te em Phishing, Passwords, Redes Sociais e Segurança Web.';
    }

    final temas = ['Phishing', 'Palavras-passe', 'Redes Sociais', 'Segurança Web'];
    final buffer = StringBuffer();

    // Calcula estatísticas por tema
    final temaStats = <String, Map<String, dynamic>>{};
    for (final tema in temas) {
      final themed = data.where((d) => d['theme'] == tema).toList();
      if (themed.isEmpty) continue;
      final avg = themed.fold<double>(0, (s, d) => s + (d['percent'] ?? 0).toDouble()) / themed.length;
      temaStats[tema] = {'count': themed.length, 'avg': avg.toInt()};
    }

    // Identifica tema mais fraco
    String? temaFraco;
    int avgFraco = 101;
    for (final entry in temaStats.entries) {
      final avg = entry.value['avg'] as int;
      if (avg < avgFraco) { avgFraco = avg; temaFraco = entry.key; }
    }

    // Recolhe perguntas erradas dos últimos 10 quizzes
    final ultimosQuizzes = data.take(10).toList();
    final perguntasErradas = <String>[];
    for (final quiz in ultimosQuizzes) {
      final questions = quiz['questions'] as List? ?? [];
      for (final q in questions) {
        final qMap = q as Map<String, dynamic>;
        if (qMap['isCorrect'] == false) {
          perguntasErradas.add('• [${quiz['theme']}] ${qMap['question']}');
        }
      }
    }

    buffer.writeln('És o Mentor SafeQuest. Analisa o desempenho deste aluno em cibersegurança.');
    buffer.writeln('Contexto: $docSafeQuest');
    buffer.writeln('---');
    buffer.writeln('DESEMPENHO:');

    for (final entry in temaStats.entries) {
      final avg = entry.value['avg'] as int;
      final count = entry.value['count'] as int;
      buffer.writeln('• ${entry.key}: $avg% de média ($count quizzes)');
    }

    if (perguntasErradas.isNotEmpty) {
      buffer.writeln('\nErros recentes:');
      for (final p in perguntasErradas.take(5)) {
        buffer.writeln(p);
      }
    }

    buffer.writeln('''

INSTRUÇÃO: Responde em Português de Portugal, de forma MUITO CURTA e direta (máximo 8-10 linhas).
Usa EXATAMENTE este formato:

## ⚠️ Quiz Recomendado
[Diz qual o tema onde está a falhar mais e porquê, em 1-2 frases. Recomenda fazer esse quiz.]

## ✅ Onde te sais bem
[Lista os temas com boa média, em 1 linha apenas.]

## 🎯 Próximo Passo
[1 frase com ação concreta para melhorar.]
''');

    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'role': 'user', 'parts': [{'text': buffer.toString()}]}],
        'generationConfig': {'maxOutputTokens': 500, 'temperature': 0.7},
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates'][0]['content']['parts'][0]['text'] as String;
      setState(() { _aiAnalysis = text; _aiLoading = false; });
    } else {
      setState(() { _aiAnalysis = 'Erro ao contactar o Mentor. Tenta novamente.'; _aiLoading = false; });
    }
  } catch (e) {
    setState(() { _aiAnalysis = 'Erro de ligação: $e'; _aiLoading = false; });
  }
}

  // ── STAT CARD ──────────────────────────────────────────────────────────────
  Widget _statCard(String value, String label, IconData icon) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Icon(icon, color: const Color(0xFF3B82F6), size: 26),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDeep)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  // ── ACTIVITY ITEM ──────────────────────────────────────────────────────────
  Widget _activityItem(BuildContext context, Map<String, dynamic> data) {
    final title    = data['theme']   ?? "Quiz Geral";
    final date     = data['dateStr'] ?? "";
    final time     = data['time']    ?? "0s";
    final percent  = data['percent'] ?? 0;
    final pts      = data['points']  ?? 0;
    final progress = (percent as num) / 100;
    final tipoQuiz = data['tipoQuiz'] ?? 'normal';

    final iconData  = _classIcon(progress);
    final iconColor = _classColor(progress);

    // Badge do tipo de quiz
    final typeBadge = tipoQuiz == 'tempo' ? '⏱️' : tipoQuiz == 'vf' ? '✅' : '📚';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizDetailPage(quizResult: data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDeep)),
                  const SizedBox(width: 6),
                  Text(typeBadge, style: const TextStyle(fontSize: 14)),
                ]),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  Text('$percent%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDeep)),
                  const SizedBox(width: 6),
                  Tooltip(message: _classLabel(progress), child: Icon(iconData, color: iconColor, size: 20)),
                ]),
                const SizedBox(height: 4),
                Text("+$pts pts", style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Text("Tempo: $time", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Spacer(),
            const Text('Ver detalhe', style: TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded, color: _primary, size: 12),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, backgroundColor: const Color(0xFFEFF6FF), color: _primary, minHeight: 8),
          ),
        ]),
      ),
    );
  }
}