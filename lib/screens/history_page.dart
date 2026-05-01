import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:projeto_safequest/env.dart';
import 'package:projeto_safequest/screens/quiz_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  late TabController _tabCtrl;
  String? _aiAnalysis;
  bool    _aiLoading = false;
  String  _searchQuery = '';
  String  _filterTema  = 'Todos';

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
  bool get wantKeepAlive => true;

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

  /// Processa os documentos Firestore e devolve (displayData, total, media%, somaPontos)
  (List<Map<String, dynamic>>, int, double, int) _processResults(
      List<QueryDocumentSnapshot> docs) {
    final List<Map<String, dynamic>> displayData = [];
    int totalQuizzes = 0;
    double somaPercent = 0;
    int somaPontos = 0;

    if (docs.isNotEmpty) {
      totalQuizzes = docs.length;
      // Ordena manualmente pelo campo 'date' (caso não haja índice)
      final sorted = List<QueryDocumentSnapshot>.from(docs)
        ..sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['date'] as Timestamp?;
          final bDate = (b.data() as Map<String, dynamic>)['date'] as Timestamp?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate); // descending
        });

      for (var doc in sorted) {
        final d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        somaPercent += (d['percent'] ?? 0).toDouble();
        somaPontos += ((d['points'] ?? 0) as num).toInt();
        final ts = d['date'] as Timestamp?;
        final date = ts != null ? ts.toDate() : DateTime.now();
        d['dateStr'] = DateFormat('dd MMM yyyy').format(date);
        displayData.add(d);
      }
    }

    final media = totalQuizzes > 0 ? somaPercent / totalQuizzes : 0.0;
    return (displayData, totalQuizzes, media, somaPontos);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // necessário para AutomaticKeepAliveClientMixin
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
          // Estado de carregamento
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A56DB)),
            );
          }

          // Erro (p.ex. índice em falta no Firestore — tenta sem ordenação)
          if (snapshot.hasError) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users').doc(user?.uid).collection('quiz_results')
                  .snapshots(),
              builder: (ctx2, snap2) {
                if (snap2.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
                }
                final data2 = _processResults(snap2.data?.docs ?? []);
                return AnimatedBuilder(
                  animation: _tabCtrl,
                  builder: (context, _) => IndexedStack(
                    index: _tabCtrl.index,
                    children: [
                      _buildActivityTab(data2.$1, data2.$2, data2.$3, data2.$4),
                      _buildAITab(data2.$1),
                    ],
                  ),
                );
              },
            );
          }

          final data = _processResults(snapshot.data?.docs ?? []);

          return AnimatedBuilder(
            animation: _tabCtrl,
            builder: (context, _) => IndexedStack(
              index: _tabCtrl.index,
              children: [
                _buildActivityTab(data.$1, data.$2, data.$3, data.$4),
                _buildAITab(data.$1),
              ],
            ),
          );
        },
      ),
    );
  }


  // ── ABA ATIVIDADE ──────────────────────────────────────────────────────────
  Widget _buildActivityTab(List<Map<String, dynamic>> displayData, int total, double media, int pontos) {
    // Aplica pesquisa + filtro por tema
    final filtered = displayData.where((d) {
      final tema = (d['theme'] ?? '').toString().toLowerCase();
      final matchesTema = _filterTema == 'Todos' || d['theme'] == _filterTema;
      final matchesSearch = _searchQuery.isEmpty ||
          tema.contains(_searchQuery.toLowerCase());
      return matchesTema && matchesSearch;
    }).toList();

    final temas = ['Todos', 'Phishing', 'Palavras-passe', 'Redes Sociais', 'Segurança Web'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _statCard("$total",                          "Quizzes", Icons.calendar_today_outlined),
            const SizedBox(width: 10),
            _statCard("${media.toStringAsFixed(0)}%",   "Média",   Icons.trending_up),
            const SizedBox(width: 10),
            _statCard(NumberFormat.decimalPattern().format(pontos), "Pontos", Icons.emoji_events_outlined),
          ]),
          const SizedBox(height: 20),

          // ── Barra de pesquisa ───────────────────────────────────
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Pesquisar quiz...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Filtros por tema ─────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: temas.map((t) {
                final isSelected = t == _filterTema;
                return GestureDetector(
                  onTap: () => setState(() => _filterTema = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? _primary : const Color(0xFFE5E7EB)),
                    ),
                    child: Text(t, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey,
                    )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Atividade ${_filterTema == 'Todos' ? 'Recente' : '— $_filterTema'}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDeep)),
            if (filtered.length != displayData.length)
              Text('${filtered.length} resultado${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Text('📋', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty || _filterTema != 'Todos'
                      ? 'Nenhum resultado encontrado.'
                      : 'Nenhum quiz realizado ainda.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ]),
            ))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _activityItem(context, filtered[i]),
            ),
        ],
      ),
    );
  }

  // ── ABA ANÁLISE IA ─────────────────────────────────────────────────────────
  Widget _buildAITab(List<Map<String, dynamic>> data) {

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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
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
                  MarkdownBody(
                    data: _aiAnalysis!,
                    selectable: true,
                    softLineBreak: true,
                    styleSheet: MarkdownStyleSheet(
                      h2: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), height: 1.5),
                      p: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151)),
                      strong: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                      listBullet: const TextStyle(fontSize: 14, color: Color(0xFF7C3AED)),
                      blockSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
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

  // ── Renderizador Markdown simples ────────────────────────────────────────
  Widget _renderAIText(String text) {
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
          child: Text(
            t.substring(2).trim(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), height: 1.4),
            softWrap: true,
          ),
        ));
        continue;
      }

      if (t.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            t.substring(3).trim(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), height: 1.4),
            softWrap: true,
          ),
        ));
        continue;
      }

      if (t.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            t.substring(4).trim(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151), height: 1.4),
            softWrap: true,
          ),
        ));
        continue;
      }

      // Bullet point
      if ((t.startsWith('\u2022 ') || t.startsWith('- ') || t.startsWith('* ')) && !t.startsWith('**')) {
        final content = t.replaceFirst(RegExp(r'^[\u2022\-\*]\s+'), '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('\u2022 ', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Expanded(child: _inlineText(content)),
            ],
          ),
        ));
        continue;
      }

      // Parágrafo normal
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _inlineText(t),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  // Texto inline com **bold** — sem largura fixa, texto cresce livremente
  Widget _inlineText(String text) {
    final regex = RegExp(r'\*\*(.+?)\*\*');
    final matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF374151)),
        softWrap: true,
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

    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
    );
  }

  Widget _buildThemeBreakdown(List<Map<String, dynamic>> data) {
    final temas = ['Phishing', 'Palavras-passe', 'Redes Sociais', 'Segurança Web'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
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
                  builder: (_, val, _) => ClipRRect(
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

    String docSafeQuest = '';
    try {
      docSafeQuest = await rootBundle.loadString('assets/conhecimento_safequest.txt');
    } catch (e) {
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

INSTRUÇÃO: Responde em Português de Portugal, de forma direta e concisa.
Usa EXATAMENTE este formato:

## ⚠️ Quiz Recomendado
[Diz qual o tema onde está a falhar mais e porquê, em 1-2 frases. Recomenda fazer esse quiz.]

## ✅ Onde te sais bem
[Lista os temas com boa média, em 1 linha apenas.]

## 🎯 Próximo Passo
[1 frase com ação concreta para melhorar.]
''');

    final apiKey = Env.geminiApiKey;

    if (apiKey.isEmpty) {
      setState(() {
        _aiAnalysis = '## ⚠️ Assistente Indisponível\n\nO Mentor SafeQuest não está disponível de momento. Tenta novamente mais tarde.';
        _aiLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'role': 'user', 'parts': [{'text': buffer.toString()}]}],
          'generationConfig': {'maxOutputTokens': 2048, 'temperature': 0.7},
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final candidates = json['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          setState(() {
            _aiAnalysis = '## ⚠️ Sem resposta\n\nO Mentor não gerou conteúdo. Tenta novamente.';
            _aiLoading = false;
          });
          return;
        }
        final parts = (candidates[0] as Map<String, dynamic>)['content']['parts'] as List;
        
        // Gemini 2.5-flash tem "thinking" parts com thought:true. Filtramos os thoughts e juntamos o texto que sobra!
        final responseParts = parts.where((p) {
          final pMap = p as Map<String, dynamic>;
          return pMap['thought'] != true && (pMap['text'] as String? ?? '').isNotEmpty;
        }).toList();
        
        final text = responseParts.map((p) => (p as Map<String, dynamic>)['text'] as String).join('');
        
        setState(() { _aiAnalysis = text.trim(); _aiLoading = false; });
      } else {
        // Log do erro real para diagnóstico
        debugPrint('🚨 Gemini API error ${response.statusCode}: ${response.body}');
        setState(() {
          _aiAnalysis = '## ⚠️ Assistente Indisponível\n\nNão foi possível contactar o Mentor. Verifica a tua ligação e tenta novamente.';
          _aiLoading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _aiAnalysis = '## ⏱️ Tempo esgotado\n\nA ligação demorou demasiado. Verifica a tua internet e tenta novamente.';
        _aiLoading = false;
      });
    } catch (e) {
      setState(() {
        _aiAnalysis = '## ⚠️ Erro de ligação\n\nNão foi possível contactar o Mentor. Verifica a tua internet.';
        _aiLoading = false;
      });
    }
  }

  // ── STAT CARD ──────────────────────────────────────────────────────────────
  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 26),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDeep), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
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