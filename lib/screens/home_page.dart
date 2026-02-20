import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/screens/profile_page.dart'; // Verifica se o caminho está correto

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 1. Variável para controlar qual página está visível
  int _currentIndex = 0;

  // 2. Lista de páginas da aplicação
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const QuizzesDashboard(), // Página 0: Dashboard de Quizzes
      const Center(child: Text("Recompensas (Brevemente)")),
      const Center(child: Text("IA (Brevemente)")),
      const Center(child: Text("Histórico (Brevemente)")),
      const ProfilePage(), // Página 4: O teu Perfil (Alex Silva)
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 3. O IndexedStack mantém o estado das páginas ao trocar
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // 4. Aqui é onde a magia acontece: muda o índice ao clicar
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF1A56DB),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Quizzes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Recompensas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'IA',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Histórico',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// --- CLASSE DA DASHBOARD (O CONTEÚDO ORIGINAL DA TUA HOME) ---
class QuizzesDashboard extends StatelessWidget {
  const QuizzesDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.shield, color: Color(0xFF1A56DB), size: 35),
        ),
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            String nomeDisplay = "Utilizador";
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>?;
              nomeDisplay = data?['name'] ?? "Utilizador";
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SafeQuest',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Olá, $nomeDisplay!',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFF0F7FF),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: Color(0xFF1A56DB),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          int pontos = 0;
          double progressoGeral = 0.0;

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            pontos = data?['pontos'] ?? 0;
            progressoGeral = (data?['progresso'] ?? 0.0).toDouble();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainScoreCard(pontos, progressoGeral),
                const SizedBox(height: 25),
                const Text(
                  'Tópicos de Segurança',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 15),
                _buildTopicCard(
                  context,
                  'Phishing',
                  '12 lições',
                  0.75,
                  Icons.email_outlined,
                ),
                _buildTopicCard(
                  context,
                  'Palavras-passe',
                  '8 lições',
                  0.60,
                  Icons.lock_outline,
                ),
                _buildTopicCard(
                  context,
                  'Redes Sociais',
                  '10 lições',
                  0.40,
                  Icons.people_outline,
                ),
                _buildTopicCard(
                  context,
                  'Segurança Web',
                  '15 lições',
                  0.25,
                  Icons.language,
                ),
                const SizedBox(height: 25),
                _buildAICard(),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- MÉTODOS AUXILIARES DA DASHBOARD ---

  void _showDifficultySelector(BuildContext context, String tema) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 50,
                color: Color(0xFF1A56DB),
              ),
              const SizedBox(height: 16),
              Text(
                tema,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Escolha o nível de dificuldade",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _difficultyButton(
                context,
                "Iniciante",
                Colors.green,
                Icons.bar_chart,
                tema,
              ),
              const SizedBox(height: 12),
              _difficultyButton(
                context,
                "Intermédio",
                Colors.orange,
                Icons.analytics,
                tema,
              ),
              const SizedBox(height: 12),
              _difficultyButton(
                context,
                "Avançado",
                Colors.red,
                Icons.stacked_bar_chart,
                tema,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Voltar"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _difficultyButton(
    BuildContext context,
    String nivel,
    Color cor,
    IconData icon,
    String tema,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cor),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                nivel,
                style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Icon(Icons.play_arrow_rounded, color: cor),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(
    BuildContext context,
    String title,
    String subtitle,
    double progress,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1A56DB), size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: const Color(0xFF1A56DB),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill,
              color: Color(0xFF1A56DB),
              size: 35,
            ),
            onPressed: () => _showDifficultySelector(context, title),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard(int pts, double prog) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A56DB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total de Pontos',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '$pts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.emoji_events, color: Colors.white24, size: 50),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso Geral',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                '${(prog * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: prog,
            minHeight: 10,
            backgroundColor: Colors.white24,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildAICard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Precisa de Ajuda?\nConverse com o Assistente IA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}
