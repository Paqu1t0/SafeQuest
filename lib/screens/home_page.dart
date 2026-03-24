import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/screens/profile_page.dart';
import 'package:projeto_safequest/screens/assistent_page.dart';
import 'package:projeto_safequest/screens/history_page.dart';
import 'package:projeto_safequest/screens/recompensas_page.dart';
import 'package:projeto_safequest/screens/quiz_screen.dart';
import 'package:projeto_safequest/screens/avatar_store_page.dart';
import 'package:projeto_safequest/screens/leaderboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR HELPERS
// ─────────────────────────────────────────────────────────────────────────────
const _avatarEmoji = {
  'default': '👤', 'fox': '🦊', 'cat': '🐱', 'panda': '🐼',
  'lion': '🦁', 'koala': '🐨', 'dragon': '🐉', 'unicorn': '🦄',
};
const _avatarColor = {
  'default': Color(0xFF1A56DB), 'fox': Color(0xFFEA580C),
  'cat': Color(0xFF7C3AED),    'panda': Color(0xFF0F766E),
  'lion': Color(0xFFB45309),   'koala': Color(0xFF4B5563),
  'dragon': Color(0xFFDC2626), 'unicorn': Color(0xFFDB2777),
};

// ─────────────────────────────────────────────────────────────────────────────
// HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const QuizzesDashboard(),
      const RecompensasPage(),
      const AssistantPage(),
      const HistoryPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF1A56DB),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined),        label: 'Quizzes'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Recompensas'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline),   label: 'IA'),
          BottomNavigationBarItem(icon: Icon(Icons.history),               label: 'Histórico'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),        label: 'Perfil'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUIZZES DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class QuizzesDashboard extends StatefulWidget {
  const QuizzesDashboard({super.key});

  @override
  State<QuizzesDashboard> createState() => _QuizzesDashboardState();
}

class _QuizzesDashboardState extends State<QuizzesDashboard>
    with SingleTickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  late TabController _tabController;

  // Tópicos — número de quizzes disponíveis (5 perguntas cada)
  static const _topics = [
    {'name': 'Phishing',       'quizCount': 5, 'icon': Icons.email_outlined},
    {'name': 'Palavras-passe', 'quizCount': 5, 'icon': Icons.lock_outline},
    {'name': 'Redes Sociais',  'quizCount': 5, 'icon': Icons.people_outline},
    {'name': 'Segurança Web',  'quizCount': 5, 'icon': Icons.language},
  ];

  static double _calcProgress(List<QueryDocumentSnapshot> docs, String tema) {
    final filtered = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['theme'] ?? '') == tema;
    }).toList();
    if (filtered.isEmpty) return 0.0;
    double soma = 0;
    for (final doc in filtered) {
      final data = doc.data() as Map<String, dynamic>;
      soma += ((data['percent'] ?? 0) as num).toDouble();
    }
    return (soma / filtered.length / 100.0).clamp(0.0, 1.0);
  }

  static double _calcProgressoGeral(
      List<QueryDocumentSnapshot> docs, List<Map<String, Object>> topics) {
    if (docs.isEmpty) return 0.0;
    double soma = 0;
    for (final t in topics) {
      soma += _calcProgress(docs, t['name'] as String);
    }
    return (soma / topics.length).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Abre seletor: loja de avatares ou galeria ─────────────────────────────
  void _showAvatarSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alterar Avatar',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryDeep)),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFF0F7FF),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.storefront_rounded,
                    color: _primary, size: 24),
              ),
              title: const Text('Avatares da Loja',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Escolhe um avatar desbloqueado',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing:
                  const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AvatarStorePage()));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(user),
      body: Column(
        children: [
          // ── Tab bar Quizzes / Classificação ──────────────────────────────
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuizzesTab(user),
                const LeaderboardPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar com avatar + moedas ───────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(User? user) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 56,
      leading: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snap) {
          String avatarId = 'default';
          if (snap.hasData && snap.data!.exists) {
            final data = snap.data!.data() as Map<String, dynamic>? ?? {};
            avatarId = data['avatar'] ?? 'default';
          }
          final emoji = _avatarEmoji[avatarId] ?? '👤';
          final color = _avatarColor[avatarId] ?? _primary;

          return GestureDetector(
            onTap: () => _showAvatarSelector(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  // Lápis de edição no canto
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 9),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      titleSpacing: 8,
      title: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          String nome = user?.displayName ?? "Utilizador";
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            nome = data?['name'] ?? nome;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SafeQuest',
                  style: TextStyle(
                      color: _primaryDeep,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text('Olá, $nome!',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          );
        },
      ),
      actions: [
        // Badge de moedas — clicável para abrir loja
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snap) {
            int moedas = 0;
            if (snap.hasData && snap.data!.exists) {
              final data = snap.data!.data() as Map<String, dynamic>? ?? {};
              moedas = (data['moedas'] ?? 0) as int;
            }
            return GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AvatarStorePage())),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '$moedas',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Ícone da loja
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AvatarStorePage())),
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: _primary, size: 20),
          ),
        ),
      ],
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12)),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
              color: _primary, borderRadius: BorderRadius.circular(8)),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Quizzes', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Classificação', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Aba Quizzes ───────────────────────────────────────────────────────────
  Widget _buildQuizzesTab(User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('quiz_results')
          .snapshots(),
      builder: (context, quizSnap) {
        final quizDocs = quizSnap.hasData
            ? quizSnap.data!.docs
            : <QueryDocumentSnapshot>[];

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, userSnap) {
            int pontos = 0;
            if (userSnap.hasData && userSnap.data!.exists) {
              final data = userSnap.data!.data() as Map<String, dynamic>?;
              pontos = data?['pontos'] ?? 0;
            }

            final progressoGeral =
                _calcProgressoGeral(quizDocs, _topics);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainScoreCard(pontos, progressoGeral),
                  const SizedBox(height: 25),
                  const Text('Tópicos de Segurança',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryDeep)),
                  const SizedBox(height: 15),
                  ..._topics.map((t) {
                    final progress =
                        _calcProgress(quizDocs, t['name'] as String);
                    return _buildTopicCard(
                        context,
                        t['name'] as String,
                        t['quizCount'] as int,
                        progress,
                        t['icon'] as IconData);
                  }),
                  const SizedBox(height: 25),
                  _buildAICard(context),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Score card ────────────────────────────────────────────────────────────
  Widget _buildMainScoreCard(int pts, double prog) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: _primary, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total de Pontos',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                  Text('$pts',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const Icon(Icons.emoji_events,
                  color: Colors.white24, size: 50),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progresso Geral',
                  style: TextStyle(color: Colors.white)),
              Text('${(prog * 100).toInt()}%',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: prog),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, __) => LinearProgressIndicator(
              value: val,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Topic card — mostra nº de quizzes em vez de lições ────────────────────
  Widget _buildTopicCard(BuildContext context, String title,
      int quizCount, double progress, IconData icon) {
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
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _primary, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E3A8A))),
                    // Nº de quizzes em vez de lições
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$quizCount quizzes',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: _primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${(progress * 100).toInt()}%',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill,
                color: _primary, size: 35),
            onPressed: () => _showDifficultySelector(context, title),
          ),
        ],
      ),
    );
  }

  // ── AI card — encaminha para página IA (tab index 2) ──────────────────────
  Widget _buildAICard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navega para o tab da IA no bottom nav
        final homeState =
            context.findAncestorStateOfType<_HomePageState>();
        homeState?.setState(() => homeState._currentIndex = 2);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                'Precisa de Ajuda?\nConverse com o Assistente IA',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.chat_bubble_outline,
                color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }

  // ── Popups de dificuldade e nível ─────────────────────────────────────────
  void _showDifficultySelector(BuildContext context, String tema) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_outlined,
                  size: 50, color: _primary),
              const SizedBox(height: 16),
              Text(tema,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const Text("Escolha o nível de dificuldade",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _difficultyButton(
                  context, "Iniciante", Colors.green, Icons.bar_chart, tema),
              const SizedBox(height: 12),
              _difficultyButton(context, "Intermédio", Colors.orange,
                  Icons.analytics, tema),
              const SizedBox(height: 12),
              _difficultyButton(context, "Avançado", Colors.red,
                  Icons.stacked_bar_chart, tema),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Voltar",
                      style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _difficultyButton(BuildContext context, String nivel,
      Color cor, IconData icon, String tema) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _showLevelSelector(context, tema, nivel, cor);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                child: Text(nivel,
                    style: TextStyle(
                        color: cor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18))),
            Icon(Icons.play_arrow_rounded, color: cor),
          ],
        ),
      ),
    );
  }

  void _showLevelSelector(BuildContext context, String tema,
      String dificuldade, Color cor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_circle, size: 50, color: cor),
              const SizedBox(height: 16),
              Text("$tema\n$dificuldade",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryDeep)),
              const SizedBox(height: 8),
              const Text("Selecione o Nível",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 15,
                runSpacing: 15,
                alignment: WrapAlignment.center,
                children: List.generate(5, (index) {
                  final level    = index + 1;
                  final isLocked = level > 3;
                  return _buildLevelBox(
                      context, level, isLocked, cor, tema, dificuldade);
                }),
              ),
              const SizedBox(height: 24),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Fechar",
                      style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBox(BuildContext context, int level, bool isLocked,
      Color cor, String tema, String dificuldade) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isLocked
          ? null
          : () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizScreen(
                    tema: tema,
                    dificuldade: dificuldade,
                    nivel: level,
                  ),
                ),
              );
            },
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: isLocked
              ? Colors.grey.withOpacity(0.1)
              : cor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? Colors.grey.withOpacity(0.3)
                : cor.withOpacity(0.5),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: isLocked
            ? const Icon(Icons.lock, color: Colors.grey, size: 28)
            : Text("$level",
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: cor)),
      ),
    );
  }
}