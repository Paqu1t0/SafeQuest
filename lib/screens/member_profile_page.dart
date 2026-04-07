import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:projeto_safequest/screens/badges_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER PROFILE PAGE — Perfil público de um membro do clã
// ─────────────────────────────────────────────────────────────────────────────

class MemberProfilePage extends StatefulWidget {
  final String uid;
  const MemberProfilePage({super.key, required this.uid});

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage>
    with SingleTickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  late TabController _tabCtrl;
  String _badgeFilter  = 'Todos';
  final _currentUser   = FirebaseAuth.instance.currentUser;

  static const _avatarEmoji = {
    'default': '👤', 'fox': '🦊', 'cat': '🐱', 'panda': '🐼',
    'lion': '🦁', 'koala': '🐨', 'dragon': '🐉', 'unicorn': '🦄',
  };
  static const _avatarColor = {
    'default': Color(0xFF1A56DB), 'fox': Color(0xFFEA580C),
    'cat': Color(0xFF7C3AED), 'panda': Color(0xFF0F766E),
    'lion': Color(0xFFB45309), 'koala': Color(0xFF4B5563),
    'dragon': Color(0xFFDC2626), 'unicorn': Color(0xFFDB2777),
  };
  // Cores dos banners (sincronizado com avatar_store_page)
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

  // Cores para os cards de conquista
  static const _badgeCardColors = [
    Color(0xFF1A56DB), Color(0xFFEA580C), Color(0xFF16A34A),
    Color(0xFF7C3AED), Color(0xFF0F766E), Color(0xFFDC2626),
    Color(0xFFDB2777), Color(0xFFB45309),
  ];

  static const _badgeEmojis = [
    '🎯', '🔥', '⭐', '🏆', '💡', '🛡️', '🚀', '🌟',
    '💎', '🦅', '⚡', '🎓', '🔐', '🌐', '🤝', '👑',
  ];

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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _primary)));
        }

        final data      = snap.data!.data() as Map<String, dynamic>? ?? {};
        final name      = data['name']     ?? data['nickname'] ?? 'Jogador';
        final pontos    = (data['pontos']  ?? 0) as int;
        final streak    = (data['streak']  ?? 0) as int;
        final avatarId  = data['avatar']   ?? 'default';
        final bannerId  = data['banner']   ?? 'default';
        final bio       = data['bio']      ?? '';
        final badges    = List<String>.from(data['badges'] ?? []);
        final nivel     = (pontos ~/ 250) + 1;
        final createdAt = data['createdAt'] as Timestamp?;
        final privacy   = data['privacy']  ?? 'publico';

        final emoji        = _avatarEmoji[avatarId] ?? '👤';
        final color        = _avatarColor[avatarId] ?? _primary;
        final bannerColors = _getBannerColors(bannerId);

        // Verifica privacidade
        if (privacy == 'privado') {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: bannerColors[0], elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
            body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_rounded, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryDeep)),
              const SizedBox(height: 8),
              const Text('Perfil privado', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ])),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: StreamBuilder<DocumentSnapshot>(
            // Lê os dados do utilizador atual para saber se já são amigos
            stream: FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid).snapshots(),
            builder: (context, mySnap) {
              final myData    = mySnap.hasData && mySnap.data!.exists ? mySnap.data!.data() as Map<String, dynamic>? ?? {} : {};
              final myFriends = List<String>.from(myData['friends'] ?? []);
              final myRequests = List.from(myData['friendRequests'] ?? []);
              final isFriend  = myFriends.contains(widget.uid);
              final isPending = myRequests.any((r) => r is Map && r['from'] == widget.uid);
              // Pedido que eu já enviei — verifica no doc do destinatário
              // (simplificado: se já é amigo mostra remover, senão mostra adicionar)

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: bio.isNotEmpty ? 250 : 220,
                    pinned: true,
                    backgroundColor: bannerColors[0],
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: const Text('Voltar', style: TextStyle(color: Colors.white, fontSize: 14)),
                    // ── Botão de amigo no canto superior direito ──────────
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => isFriend
                              ? _removeFriend(context)
                              : _sendFriendRequest(context, name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                isFriend ? Icons.person_remove_rounded : Icons.person_add_rounded,
                                color: Colors.white, size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isFriend ? 'Remover' : 'Adicionar',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: bannerColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 42))),
                              ),
                              const SizedBox(height: 12),
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                              const SizedBox(height: 4),
                              Text('Nível $nivel', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(bio, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontStyle: FontStyle.italic)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ), // fim SliverAppBar

                  // ── Tabs ─────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(color: Colors.white, child: _buildTabBar(badges)),
                  ),

                  SliverFillRemaining(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _buildStatsTab(pontos, streak, badges, nivel, createdAt),
                        _buildAchievementsTab(badges),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── Adicionar amigo ───────────────────────────────────────────────────────
  Future<void> _sendFriendRequest(BuildContext context, String toName) async {
    if (_currentUser == null) return;
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
    final myName = (myDoc.data()?['name'] ?? 'Jogador') as String;
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'friendRequests': FieldValue.arrayUnion([{'from': _currentUser!.uid, 'fromName': myName, 'status': 'pending'}]),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pedido enviado a $toName! 📨'), backgroundColor: Colors.green),
    );
  }

  Future<void> _removeFriend(BuildContext context) async {
    if (_currentUser == null) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid), {'friends': FieldValue.arrayRemove([widget.uid])});
    batch.update(FirebaseFirestore.instance.collection('users').doc(widget.uid), {'friends': FieldValue.arrayRemove([_currentUser!.uid])});
    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amigo removido.'), backgroundColor: Colors.orange));
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar(List<String> badges) {
    final totalBadges  = BadgesService.allBadges.length;
    final earnedBadges = badges.length;

    return TabBar(
      controller: _tabCtrl,
      indicator: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      labelColor: _primary,
      unselectedLabelColor: Colors.grey,
      dividerColor: Colors.transparent,
      padding: const EdgeInsets.all(8),
      indicatorPadding: EdgeInsets.zero,
      tabs: [
        const Tab(text: 'Estatísticas'),
        Tab(text: 'Conquistas ($earnedBadges/$totalBadges)'),
      ],
    );
  }

  // ── Aba Estatísticas ──────────────────────────────────────────────────────
  Widget _buildStatsTab(int pontos, int streak, List<String> badges,
      int nivel, Timestamp? createdAt) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('quiz_results')
          .get(),
      builder: (context, snap) {
        int totalQuizzes = 0;
        double taxaSucesso = 0;
        int melhorStreak = streak;

        if (snap.hasData) {
          totalQuizzes = snap.data!.docs.length;
          if (totalQuizzes > 0) {
            double soma = 0;
            for (final doc in snap.data!.docs) {
              final d = doc.data() as Map<String, dynamic>;
              soma += (d['percent'] ?? 0).toDouble();
            }
            taxaSucesso = soma / totalQuizzes;
          }
        }

        // Usa formato simples sem locale para evitar LocaleDataException
        final membroDesde = createdAt != null
            ? DateFormat('dd/MM/yyyy').format(createdAt.toDate())
            : 'N/A';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Stats cards
              Row(
                children: [
                  _statCard('$streak', 'Dias', Icons.local_fire_department,
                      const Color(0xFFFF6A00), const Color(0xFFFFF0E6)),
                  const SizedBox(width: 10),
                  _statCard('$pontos', 'Pontos', Icons.emoji_events,
                      _primary, const Color(0xFFEFF6FF)),
                  const SizedBox(width: 10),
                  _statCard('${badges.length}', 'Emblemas',
                      Icons.workspace_premium, const Color(0xFF3B82F6),
                      const Color(0xFFEFF6FF)),
                ],
              ),

              const SizedBox(height: 20),

              // Estatísticas detalhadas
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estatísticas de Atividade',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _primaryDeep)),
                    const SizedBox(height: 16),
                    _statRow('Quizzes Completados',
                        '$totalQuizzes', Colors.black),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _statRow(
                        'Taxa de Sucesso',
                        '${taxaSucesso.toStringAsFixed(0)}%',
                        taxaSucesso >= 70
                            ? const Color(0xFF16A34A)
                            : taxaSucesso >= 40
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDC2626)),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _statRow('Membro Desde', membroDesde, Colors.black),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _statRow('Melhor Streak', '$melhorStreak dias',
                        const Color(0xFFFF6A00)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String value, String label, IconData icon,
      Color iconColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryDeep)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: valueColor)),
      ],
    );
  }

  // ── Aba Conquistas ────────────────────────────────────────────────────────
  Widget _buildAchievementsTab(List<String> earnedIds) {
    // Filtros disponíveis
    final filters = [
      'Todos', 'Phishing', 'Palavras-passe',
      'Segurança Web', 'Redes Sociais', 'Básicas'
    ];

    // Só mostra as conquistas que o utilizador ganhou
    final earnedBadges = BadgesService.allBadges
        .where((b) => earnedIds.contains(b['id']))
        .toList();

    // Aplica filtro
    final filtered = _badgeFilter == 'Todos'
        ? earnedBadges
        : earnedBadges.where((b) {
            if (_badgeFilter == 'Básicas') return b['categoria'] == 'basica';
            return b['categoria'] == _badgeFilter;
          }).toList();

    return Column(
      children: [
        // Filtros horizontais
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            itemCount: filters.length,
            itemBuilder: (context, i) {
              final f         = filters[i];
              final isSelected = f == _badgeFilter;
              return GestureDetector(
                onTap: () => setState(() => _badgeFilter = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? _primary
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Grid de conquistas
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏅',
                          style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(
                        _badgeFilter == 'Todos'
                            ? 'Nenhuma conquista ainda.'
                            : 'Sem conquistas em "$_badgeFilter".',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    return _buildBadgeCard(filtered[i], i);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, int index) {
    final cardColor  = _badgeCardColors[index % _badgeCardColors.length];
    final badgeEmoji = _badgeEmojis[index % _badgeEmojis.length];
    final name       = badge['nome'] as String;
    final desc       = badge['desc'] as String;
    final categoria  = badge['categoria'] as String;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(badgeEmoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              categoria == 'basica' ? 'Básica' : categoria,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}