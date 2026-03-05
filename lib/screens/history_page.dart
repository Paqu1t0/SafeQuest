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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          "Histórico",
          style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Acede à subcoleção 'quiz_results' que deve estar dentro do utilizador
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('quiz_results')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Enquanto carrega, mostra o indicador de progresso
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se não houver a coleção ou estiver vazia, mostra mensagem amigável
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState();
          }

          final results = snapshot.data!.docs;
          
          // Cálculos para os cartões superiores
          int totalQuizzes = results.length;
          double somaPercent = 0;
          int somaPontos = 0;

          for (var doc in results) {
            var d = doc.data() as Map<String, dynamic>;
            somaPercent += (d['percent'] ?? 0).toDouble();
            somaPontos = somaPontos + ((d['points'] ?? 0) as num).toInt();
          }
          
          double media = totalQuizzes > 0 ? somaPercent / totalQuizzes : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. STATS SUPERIORES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statCard("$totalQuizzes", "Quizzes", Icons.calendar_today, Colors.blue),
                    _statCard("${media.toStringAsFixed(0)}%", "Média", Icons.trending_up, Colors.blue),
                    _statCard("$somaPontos", "Pontos", Icons.emoji_events_outlined, Colors.blue),
                  ],
                ),
                const SizedBox(height: 30),

                const Text(
                  "Atividade Recente",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 15),

                // 2. LISTA DE ITENS
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    var data = results[index].data() as Map<String, dynamic>;
                    
                    // Tratamento seguro da data para evitar erros se o campo for nulo
                    DateTime date = data['date'] != null 
                        ? (data['date'] as Timestamp).toDate() 
                        : DateTime.now();
                    String formattedDate = DateFormat('dd MMM yyyy').format(date);

                    return _activityItem(
                      data['theme'] ?? "Quiz Geral",
                      formattedDate,
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

  // Widget para quando não há dados
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Ainda não realizaste nenhum quiz!",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _activityItem(String title, String date, String time, String percent, int pts, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(percent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("+$pts pts", style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text("Tempo: $time", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Spacer(),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.blue,
                    minHeight: 6,
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