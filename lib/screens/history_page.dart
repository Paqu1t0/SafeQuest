import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fundo cinza claro
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Histórico",
          style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 20),
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
            return const Center(child: CircularProgressIndicator());
          }

          // ================= MODO DUMMY DATA =================
          // Se não houver dados, usamos os dados da tua imagem para o design!
          bool isDummy = !snapshot.hasData || snapshot.data!.docs.isEmpty;
          
          List<Map<String, dynamic>> displayData = [];
          int totalQuizzes = 0;
          double media = 0;
          int somaPontos = 0;

          if (isDummy) {
            // DADOS FICTÍCIOS (Iguais à imagem)
            totalQuizzes = 5;
            media = 86;
            somaPontos = 2450;
            displayData = [
              {'theme': 'Phishing', 'dateStr': '19 Dez 2024', 'percent': 100, 'points': 250, 'time': '2m 15s'},
              {'theme': 'Palavras-passe', 'dateStr': '18 Dez 2024', 'percent': 85, 'points': 200, 'time': '3m 45s'},
              {'theme': 'Redes Sociais', 'dateStr': '17 Dez 2024', 'percent': 90, 'points': 220, 'time': '2m 50s'},
              {'theme': 'Phishing', 'dateStr': '16 Dez 2024', 'percent': 75, 'points': 180, 'time': '4m 10s'},
              {'theme': 'Segurança Web', 'dateStr': '15 Dez 2024', 'percent': 80, 'points': 190, 'time': '3m 20s'},
            ];
          } else {
            // DADOS REAIS DA BASE DE DADOS
            final results = snapshot.data!.docs;
            totalQuizzes = results.length;
            double somaPercent = 0;
            
            for (var doc in results) {
              var d = doc.data() as Map<String, dynamic>;
              somaPercent += (d['percent'] ?? 0).toDouble();
              somaPontos += ((d['points'] ?? 0) as num).toInt();
              
              // Formatar a data real
              DateTime date = d['date'] != null ? (d['date'] as Timestamp).toDate() : DateTime.now();
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
                // 1. STATS SUPERIORES
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 15),

                // 2. LISTA DE ITENS
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayData.length,
                  itemBuilder: (context, index) {
                    var data = displayData[index];
                    return _activityItem(
                      data['theme'] ?? "Quiz Geral",
                      data['dateStr'] ?? "",
                      data['time'] ?? "0s",
                      "${data['percent'] ?? 0}%",
                      data['points'] ?? 0,
                      (data['percent'] ?? 0) / 100,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Novo design dos cartões superiores (Iguais à imagem)
  Widget _statCard(String value, String label, IconData icon) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF3B82F6), size: 26),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // Novo design dos itens da lista (Iguais à imagem)
  Widget _activityItem(String title, String date, String time, String percent, int pts, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(percent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 4),
                  Text("+$pts pts", style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text("Tempo: $time", style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const Spacer(),
              // Barra de Progresso azul grossa com cantos arredondados
              SizedBox(
                width: 100, // Largura fixa para a barra ficar alinhada à direita como na imagem
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFEFF6FF), // Fundo azul muito claro
                    color: const Color(0xFF2563EB), // Azul vibrante
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}