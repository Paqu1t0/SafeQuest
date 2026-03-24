import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:projeto_safequest/screens/quiz_detail_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  static const primary     = Color(0xFF2563EB);
  static const primaryDeep = Color(0xFF1E3A8A);
  static const textDark    = Color(0xFF111827);

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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Histórico",
          style: TextStyle(
            color: primaryDeep,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('quiz_results')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primary));
          }

          bool isDummy = !snapshot.hasData || snapshot.data!.docs.isEmpty;
          List<Map<String, dynamic>> displayData = [];
          int totalQuizzes = 0;
          double media = 0;
          int somaPontos = 0;

          if (isDummy) {
            totalQuizzes = 5;
            media = 78;
            somaPontos = 2450;
            displayData = [
              {'theme': 'Phishing',       'dateStr': '19 Dez 2024', 'percent': 100, 'points': 250, 'time': '2m 15s', 'questions': []},
              {'theme': 'Palavras-passe', 'dateStr': '18 Dez 2024', 'percent': 85,  'points': 200, 'time': '3m 45s', 'questions': []},
              {'theme': 'Redes Sociais',  'dateStr': '17 Dez 2024', 'percent': 55,  'points': 130, 'time': '2m 50s', 'questions': []},
              {'theme': 'Phishing',       'dateStr': '16 Dez 2024', 'percent': 30,  'points': 80,  'time': '4m 10s', 'questions': []},
              {'theme': 'Segurança Web',  'dateStr': '15 Dez 2024', 'percent': 70,  'points': 170, 'time': '3m 20s', 'questions': []},
            ];
          } else {
            final results = snapshot.data!.docs;
            totalQuizzes = results.length;
            double somaPercent = 0;
            for (var doc in results) {
              var d = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
              somaPercent += (d['percent'] ?? 0).toDouble();
              somaPontos  += ((d['points'] ?? 0) as num).toInt();
              DateTime date = d['date'] != null
                  ? (d['date'] as Timestamp).toDate()
                  : DateTime.now();
              d['dateStr'] = DateFormat('dd MMM yyyy').format(date);
              displayData.add(d);
            }
            media = totalQuizzes > 0 ? somaPercent / totalQuizzes : 0;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Stat cards ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard("$totalQuizzes", "Quizzes", Icons.calendar_today_outlined),
                    _statCard("${media.toStringAsFixed(0)}%", "Média", Icons.trending_up),
                    _statCard(NumberFormat.decimalPattern().format(somaPontos), "Pontos", Icons.emoji_events_outlined),
                  ],
                ),
                const SizedBox(height: 35),

                const Text(
                  "Atividade Recente",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryDeep,
                  ),
                ),
                const SizedBox(height: 15),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayData.length,
                  itemBuilder: (context, index) {
                    var data = displayData[index];
                    return _activityItem(context, data);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── STAT CARD ─────────────────────────────────────────────────────────────
  Widget _statCard(String value, String label, IconData icon) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 26),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── ACTIVITY ITEM (agora com GestureDetector para abrir detalhe) ──────────
  Widget _activityItem(BuildContext context, Map<String, dynamic> data) {
    final title    = data['theme'] ?? "Quiz Geral";
    final date     = data['dateStr'] ?? "";
    final time     = data['time'] ?? "0s";
    final percent  = data['percent'] ?? 0;
    final pts      = data['points'] ?? 0;
    final progress = (percent as num) / 100;

    final iconData  = _classIcon(progress);
    final iconColor = _classColor(progress);
    final label     = _classLabel(progress);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizDetailPage(quizResult: data),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + data
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),

                // Percentagem + pontos + classificação
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryDeep,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: label,
                          child: Icon(iconData, color: iconColor, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "+$pts pts",
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Text(
                  "Tempo: $time",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Spacer(),
                // Seta de "ver detalhe"
                const Text(
                  'Ver detalhe',
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: primary, size: 12),
              ],
            ),

            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFEFF6FF),
                color: primary,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}