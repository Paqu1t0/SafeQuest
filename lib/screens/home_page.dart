import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:projeto_safequest/screens/profile_page.dart';
import 'package:projeto_safequest/screens/assistent_page.dart';
import 'package:projeto_safequest/screens/history_page.dart';
import 'package:projeto_safequest/screens/recompensas_page.dart';
import 'package:projeto_safequest/screens/quiz_screen.dart';
import 'package:projeto_safequest/screens/avatar_store_page.dart';
import 'package:projeto_safequest/screens/leaderboard_page.dart';
import 'package:projeto_safequest/screens/clan_page.dart';
import 'package:projeto_safequest/screens/friends_page.dart' show FriendsPage;
import 'package:projeto_safequest/screens/notification_service.dart';
import 'package:projeto_safequest/screens/coin_animation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:projeto_safequest/screens/daily_missions_service.dart';

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
  late final PageController _pageCtrl;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    _pages = [
      const QuizzesDashboard(),
      const RecompensasPage(),
      const ClanPage(),
      const AssistantPage(),
      const HistoryPage(),
      const ProfilePage(),
    ];
    // Regista a hora de abertura da app (usado pelas Cloud Functions
    // para não enviar notificações a quem já entrou hoje)
    _atualizarUltimaVisita();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _currentIndex = index);
    _pageCtrl.animateToPage(index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageCtrl,
        physics: const ClampingScrollPhysics(), // swipe ativado entre páginas
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goTo,
        selectedItemColor: const Color(0xFF1A56DB),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined),        label: 'Quizzes'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), label: 'Recompensas'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_rounded),        label: 'Clã'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline),   label: 'IA'),
          BottomNavigationBarItem(icon: Icon(Icons.history),               label: 'Histórico'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),        label: 'Perfil'),
        ],
      ),
    );
  }

  // Grava no Firestore a hora em que o utilizador abriu a app e o FCM Token.
  // As Cloud Functions verificam este valor para enviar notificações.
  Future<void> _atualizarUltimaVisita() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'lastOpenedAt': FieldValue.serverTimestamp(),
            if (token != null) 'fcmToken': token,
          }, SetOptions(merge: true));
          
      // Opcional: Atualizar se o token mudar enquanto a app está aberta
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
      });
    } catch (_) {
      // Falha silenciosa — não é crítico para o utilizador
    }
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
  bool _tipVisible = false; // dica do dia oculta por defeito
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  late TabController _tabController;

  // Cada tópico tem 3 tipos × 3 dificuldades × 3 níveis = 27 quizzes possíveis
  // Mostramos 15 como meta razoável (3 tipos × 5 combinações)
  static const _totalQuizzesPerTopic = 15;

  // Tópicos — título e ícone
  static final _topics = [
    {'name': 'Phishing',       'icon': Icons.email_outlined},
    {'name': 'Palavras-passe', 'icon': Icons.lock_outline},
    {'name': 'Redes Sociais',  'icon': Icons.people_outline},
    {'name': 'Segurança Web',  'icon': Icons.language},
  ];

  // Progresso = quizzes feitos neste tema / meta (15), NÃO a média de percentagens
  static double _calcProgress(List<QueryDocumentSnapshot> docs, String tema) {
    final count = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['theme'] ?? '') == tema;
    }).length;
    return (count / _totalQuizzesPerTopic).clamp(0.0, 1.0);
  }

  // Número de quizzes feitos num tema
  static int _countQuizzes(List<QueryDocumentSnapshot> docs, String tema) {
    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['theme'] ?? '') == tema;
    }).length;
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 120),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Alterar Avatar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _primaryDeep))),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close_rounded, color: Colors.grey)),
              ]),
              const SizedBox(height: 18),

              // Galeria
              _avatarOption(ctx,
                icon: Icons.photo_library_rounded, color: const Color(0xFF16A34A), bg: const Color(0xFFF0FDF4),
                title: 'Galeria do Telemóvel', subtitle: 'Usa uma foto da galeria',
                onTap: () async {
                  Navigator.pop(ctx);
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (img != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Para guardar a foto vai ao separador Perfil.'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),

              // Loja
              _avatarOption(ctx,
                icon: Icons.storefront_rounded, color: const Color(0xFFF59E0B), bg: const Color(0xFFFEF3C7),
                title: 'Avatares da Loja', subtitle: 'Escolhe um avatar desbloqueado',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarStorePage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarOption(BuildContext ctx, {required IconData icon, required Color color, required Color bg, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
        ]),
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
              physics: const NeverScrollableScrollPhysics(),
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
            // Mostra nickname se existir, senão o primeiro nome
            nome = data?['nickname'] ?? (data?['name'] as String?)?.split(' ').first ?? nome;
          }
          return GestureDetector(
            onTap: () {
              // Navega para a aba Perfil (índice 5)
              final homeState = context.findAncestorStateOfType<_HomePageState>();
              homeState?._goTo(5);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SafeQuest',
                    style: TextStyle(
                        color: _primaryDeep,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Row(children: [
                  Text('Olá, $nome!',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Colors.grey),
                ]),
              ],
            ),
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
                key: coinBadgeKey,   // ← GlobalKey para animação de moedas
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Text('🪙', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text('$moedas', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            );
          },
        ),
        // Notificações do clã
        _buildNotificationBell(context, user),
        // Ícone da loja
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AvatarStorePage())),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: _primary, size: 20),
          ),
        ),
        // Ícone de amigos — azul
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => FriendsPage())),
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_rounded,
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
            int    pontos   = 0;
            String bannerId = 'default';
            int    nivel    = 1;

            if (userSnap.hasData && userSnap.data!.exists) {
              final data = userSnap.data!.data() as Map<String, dynamic>?;
              pontos   = data?['pontos']  ?? 0;
              bannerId = data?['banner']  ?? 'default';
              nivel    = ((pontos ~/ 250) + 1);
            }

            final progressoGeral = _calcProgressoGeral(quizDocs, _topics);
            final bannerColors   = _getBannerColors(bannerId);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainScoreCard(pontos, progressoGeral, nivel, bannerColors),
                  const SizedBox(height: 28),
                  const DailyMissionsWidget(),
                  const SizedBox(height: 20),
                  _buildDailyTipCard(),
                  const SizedBox(height: 28),
                  Text('🎮 Arenas de Treino',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: bannerColors[1])),
                  const SizedBox(height: 15),
                  ..._topics.map((t) {
                    final progress  = _calcProgress(quizDocs, t['name'] as String);
                    final doneSoFar = _countQuizzes(quizDocs, t['name'] as String);
                    return _buildTopicCard(context, t['name'] as String, doneSoFar, progress, t['icon'] as IconData, bannerColors[0]);
                  }),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Dica do Dia ──────────────────────────────────────────────────────────
  static const _tips = [
    ('🔐', 'Palavras-passe', 'Usa uma frase longa em vez de uma palavra. Ex: "t@l@p3g@rom@2024!" é muito mais segura que "senha123".'),
    ('🎣', 'Phishing', 'Verifica SEMPRE o remetente de emails antes de clicar em links. Um endereço ligeiramente diferente pode ser uma armadilha.'),
    ('📱', 'Redes Sociais', 'Não partilhes a tua localização em tempo real nas redes sociais. Podes estar a dizer a desconhecidos onde estás.'),
    ('🔒', 'Autenticação', 'Ativa a autenticação de dois fatores (2FA) em todas as tuas contas importantes. É a tua segunda linha de defesa.'),
    ('🌐', 'Wi-Fi Público', 'Evita fazer operações bancárias em Wi-Fi público. Usa sempre uma VPN se precisares de usar redes abertas.'),
    ('💾', 'Backups', 'Faz backups regulares dos teus dados importantes. Se sofreres um ataque de ransomware, terás os dados a salvo.'),
    ('🖥️', 'Atualizações', 'Mantém o teu sistema operativo e apps sempre atualizados. As atualizações corrigem vulnerabilidades de segurança.'),
    ('🔑', 'Gestor de Passwords', 'Usa um gestor de palavras-passe para criar e armazenar senhas únicas para cada serviço. Nunca repitas passwords!'),
    ('📧', 'Email Seguro', 'Desconfia de emails urgentes que pedem dados pessoais ou financeiros. Bancos e empresas legítimas nunca pedem isso por email.'),
    ('🛡️', 'Antivírus', 'Instala um antivírus atualizado no teu dispositivo. Mesmo sendo cauteloso, podes encontrar malware em sites legítimos.'),
    ('👁️', 'Privacidade', 'Revê periodicamente as permissões das tuas apps. Muitas pedem acesso ao microfone e câmara sem necessidade real.'),
    ('🔗', 'Links Suspeitos', 'Antes de clicar num link, passa o rato por cima para ver o URL real. Se não reconheces o domínio, não cliques!'),
    ('💻', 'HTTPS', 'Verifica se os sites têm "https://" e o cadeado no browser antes de inserires dados pessoais ou de pagamento.'),
    ('🧩', 'Engenharia Social', 'Atenção a chamadas inesperadas de "suporte técnico". Empresas legítimas nunca pedem acesso remoto ao teu computador.'),
    ('📲', 'Apps Oficiais', 'Descarrega aplicações apenas das lojas oficiais (App Store, Google Play). Apps de fontes desconhecidas podem conter malware.'),
    ('🗑️', 'Dados Antigos', 'Apaga contas antigas que já não usas. Cada conta abandonada é um potencial ponto de entrada para atacantes.'),
    ('🤝', 'Partilha Segura', 'Nunca partilhes as tuas palavras-passe, mesmo com pessoas de confiança. Cada conta deve ser exclusivamente tua.'),
    ('🔎', 'Pesquisa Segura', 'Pesquisa sobre ti próprio(a) online regularmente. Se encontrares dados sensíveis expostos, toma medidas para os remover.'),
    ('⚡', 'Incidentes', 'Se suspeitares que a tua conta foi comprometida, altera imediatamente a password e ativa o 2FA sem esperar.'),
    ('🌍', 'VPN', 'Uma VPN encripta o teu tráfego de internet, protegendo-te em redes públicas. Vale o investimento para uso regular.'),
  ];

  Widget _buildDailyTipCard() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final tip = _tips[dayOfYear % _tips.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Botão para revelar/esconder a dica ───────────────────────────
        GestureDetector(
          onTap: () => setState(() => _tipVisible = !_tipVisible),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF0891B2).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(9)),
                child: const Text('💡', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dica do Dia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(_tipVisible ? 'Toca para esconder' : 'Toca para revelar a dica!',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(tip.$2, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _tipVisible ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
              ),
            ]),
          ),
        ),

        // ── Conteúdo da dica (colapsável) ────────────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: GestureDetector(
            // Toca no conteúdo da dica para a fechar
            onTap: () => setState(() => _tipVisible = false),
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tip.$1, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(tip.$3,
                  style: const TextStyle(color: Color(0xFF0E7490), fontSize: 13, height: 1.55),
                )),
                const SizedBox(width: 6),
                const Icon(Icons.close_rounded, size: 16, color: Color(0xFF0891B2)),
              ]),
            ),
          ),
          crossFadeState: _tipVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 280),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }

  // ── Sino de notificações — só clã e batalhas ──────────────────────────────
  Widget _buildNotificationBell(BuildContext context, User? user) {
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      // Usa o stream filtrado: só conta notificações de clã/batalhas (não as automáticas)
      stream: NotificationService.unreadStream(user.uid),
      builder: (context, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => NotificationsDialog(uid: user.uid),
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            child: Stack(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_rounded, color: _primary, size: 20),
              ),
              if (count > 0) Positioned(
                top: 2, right: 2,
                child: Container(
                  width: 15, height: 15,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // Mapa de cores dos banners (sincronizado com avatar_store_page)
  static List<Color> _getBannerColors(String bannerId) {
    const map = <String, List<Color>>{
      'default' : [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      'sunset'  : [Color(0xFFEA580C), Color(0xFFDC2626)],
      'forest'  : [Color(0xFF16A34A), Color(0xFF0F766E)],
      'galaxy'  : [Color(0xFF7C3AED), Color(0xFF1E3A8A)],
      'gold'    : [Color(0xFFF59E0B), Color(0xFFEA580C)],
      'rose'    : [Color(0xFFDB2777), Color(0xFF9333EA)],
      'ocean'   : [Color(0xFF0891B2), Color(0xFF1A56DB)],
      'midnight': [Color(0xFF1E293B), Color(0xFF334155)],
    };
    return map[bannerId] ?? map['default']!;
  }

  // ── Score card ────────────────────────────────────────────────────────────
  Widget _buildMainScoreCard(int pts, double prog, int nivel, List<Color> bannerColors) {
    // XP dentro do nível atual (cada nível = 250 pts)
    final xpInLevel    = pts % 250;
    final xpProgress   = xpInLevel / 250.0;
    final xpToNext     = 250 - xpInLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bannerColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total de Pontos', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text('$pts', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ]),
              // Nível no canto direito
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  const Text('NÍVEL', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text('$nivel', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barra de XP
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('XP: $xpInLevel / 250', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('Faltam $xpToNext XP p/ nível ${nivel + 1}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: xpProgress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: val, minHeight: 8, backgroundColor: Colors.white24, color: const Color(0xFFFBBF24)),
            ),
          ),
          const SizedBox(height: 14),
          // Progresso geral
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Progresso Geral', style: TextStyle(color: Colors.white)),
            Text('${(prog * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: prog),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: val, minHeight: 8, backgroundColor: Colors.white24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, String title,
      int doneSoFar, double progress, IconData icon, [Color? accent]) {
    final accentColor = accent ?? _primary;
    final barColor = Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _primaryDeep),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$doneSoFar/$_totalQuizzesPerTopic · ${doneSoFar == 0 ? 'Começa agora!' : '${(progress * 100).toInt()}% completo'}',
                  style: TextStyle(fontSize: 11, color: doneSoFar == 0 ? Colors.grey : barColor, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: val, minHeight: 5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: barColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showDifficultySelector(context, title),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Jogar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
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
        homeState?.setState(() => homeState._currentIndex = 3);
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
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone do tema
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.emoji_events_outlined, size: 32, color: _primary)),
                ),
                const SizedBox(height: 16),
                Text(tema, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDeep), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                const Text("Escolha o nível de dificuldade", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),

                _difficultyButton(context, "Iniciante",  Colors.green,  Icons.bar_chart,         tema, '5–7 questões · Conceitos básicos'),
                const SizedBox(height: 10),
                _difficultyButton(context, "Intermédio", Colors.orange, Icons.analytics,         tema, 'Aprofunda os teus conhecimentos'),
                const SizedBox(height: 10),
                _difficultyButton(context, "Avançado",   Colors.red,    Icons.stacked_bar_chart,  tema, 'Para os verdadeiros especialistas'),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _difficultyButton(BuildContext context, String nivel, Color cor, IconData icon, String tema, String subtitle) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _showSwipeLevelSelector(context, tema, nivel, cor);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: cor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: cor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nivel, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: TextStyle(color: cor.withOpacity(0.7), fontSize: 11)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: cor.withOpacity(0.6), size: 16),
        ]),
      ),
    );
  }

  // ── SWIPE LEVEL SELECTOR — dialog central com tipos de quiz ──────────────
  void _showSwipeLevelSelector(BuildContext context, String tema, String dificuldade, Color cor) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: _SwipeLevelSheet(tema: tema, dificuldade: dificuldade, cor: cor),
      ),
    );
  }

  // Mantém _buildLevelBox para compatibilidade
  Widget _buildLevelBox(BuildContext context, int level, bool isLocked, Color cor, String tema, String dificuldade) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isLocked ? null : () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(tema: tema, dificuldade: dificuldade, nivel: level)));
      },
      child: Container(
        width: 65, height: 65,
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey.withOpacity(0.1) : cor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLocked ? Colors.grey.withOpacity(0.3) : cor.withOpacity(0.5), width: 2),
        ),
        alignment: Alignment.center,
        child: isLocked
            ? const Icon(Icons.lock, color: Colors.grey, size: 28)
            : Text("$level", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: cor)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SWIPE LEVEL SHEET — swipe entre tipos de quiz
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeLevelSheet extends StatefulWidget {
  final String tema;
  final String dificuldade;
  final Color  cor;

  const _SwipeLevelSheet({required this.tema, required this.dificuldade, required this.cor});

  @override
  State<_SwipeLevelSheet> createState() => _SwipeLevelSheetState();
}

class _SwipeLevelSheetState extends State<_SwipeLevelSheet> {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  late PageController _pageCtrl;
  int  _currentPage   = 0;
  int? _selectedLevel;  // ← nível selecionado antes de jogar

  // Definição dos 3 tipos de quiz
  static final _quizTypes = [
    {
      'type'    : QuizType.normal,
      'title'   : 'Quiz Normal',
      'subtitle': '5 perguntas · Sem limite de tempo',
      'icon'    : '📚',
      'desc'    : 'Responde ao teu ritmo. Perguntas de escolha múltipla sobre o tema selecionado.',
      'color'   : Color(0xFF1A56DB),
    },
    {
      'type'    : QuizType.tempo,
      'title'   : 'Contra o Tempo',
      'subtitle': '7 perguntas · 15 segundos cada',
      'icon'    : '⏱️',
      'desc'    : 'Tens 15 segundos por pergunta! Raciocínio rápido e precisão são essenciais.',
      'color'   : Color(0xFFDC2626),
    },
    {
      'type'    : QuizType.vf,
      'title'   : 'Verdadeiro / Falso',
      'subtitle': '7 perguntas · V ou F',
      'icon'    : '✅',
      'desc'    : 'Determina se cada afirmação é verdadeira ou falsa. Simples mas desafiante!',
      'color'   : Color(0xFF7C3AED),
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header com gradiente
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.cor, widget.cor.withOpacity(0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.tema, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(widget.dificuldade, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  ])),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                child: Column(children: [
                  // Instrução
                  const Text('Desliza para escolher o tipo de quiz',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 14),

                  // PageView dos tipos
                  SizedBox(
                    height: 170,
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _quizTypes.length,
                      onPageChanged: (i) => setState(() { _currentPage = i; _selectedLevel = null; }),
                      itemBuilder: (context, i) {
                        final qt     = _quizTypes[i];
                        final active = i == _currentPage;
                        final color  = qt['color'] as Color;

                        return AnimatedScale(
                          scale: active ? 1.0 : 0.92,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color, color.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: active ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))] : [],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(qt['icon'] as String, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(qt['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(qt['subtitle'] as String, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                                  ])),
                                ]),
                                const SizedBox(height: 10),
                                Text(qt['desc'] as String, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.4)),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Indicadores
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_quizTypes.length, (i) {
                      final active = i == _currentPage;
                      final color  = _quizTypes[i]['color'] as Color;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? color : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // Níveis
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Seleciona o Nível',
                        style: TextStyle(fontWeight: FontWeight.bold, color: widget.cor, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (i) {
                          final level     = i + 1;
                          final isLocked  = level > 3;
                          final isSelected = _selectedLevel == level;
                          // Usa a cor da dificuldade escolhida para TUDO
                          final levelColor = widget.cor;
                          return GestureDetector(
                            onTap: isLocked ? null : () => setState(() => _selectedLevel = level),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: isLocked
                                    ? Colors.grey.withOpacity(0.08)
                                    : isSelected
                                        ? levelColor
                                        : levelColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isLocked
                                      ? Colors.grey.withOpacity(0.25)
                                      : levelColor.withOpacity(isSelected ? 1.0 : 0.5),
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow: isSelected ? [BoxShadow(color: levelColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
                              ),
                              alignment: Alignment.center,
                              child: isLocked
                                  ? const Icon(Icons.lock_rounded, color: Colors.grey, size: 22)
                                  : Text('$level',
                                      style: TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : levelColor,
                                      )),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Botão JOGAR — grande, cor da dificuldade
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.cor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _selectedLevel == null ? null : () {
                            final qt = _quizTypes[_currentPage]['type'] as QuizType;
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => QuizScreen(
                                tema: widget.tema, dificuldade: widget.dificuldade,
                                nivel: _selectedLevel!, quizType: qt,
                              ),
                            ));
                          },
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.sports_esports_rounded, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              _selectedLevel == null ? 'Seleciona um nível' : 'Jogar — Nível $_selectedLevel',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}