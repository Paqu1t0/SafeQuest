import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD PAGE — Jogadores + Clãs
// ─────────────────────────────────────────────────────────────────────────────

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFFBBF24);
  static const _silver      = Color(0xFF9CA3AF);
  static const _bronze      = Color(0xFFCD7C2F);

  late TabController _tabCtrl;
  final currentUser = FirebaseAuth.instance.currentUser;

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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Classificação Global',
                  style: TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primary.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: _primary, size: 14),
                    SizedBox(width: 4),
                    Text('Top 10', style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Tab bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(8)),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_rounded, size: 15),
                    SizedBox(width: 4),
                    Flexible(child: Text('Jogadores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                )),
                Tab(child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_rounded, size: 15),
                    SizedBox(width: 4),
                    Flexible(child: Text('Clãs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                )),
                Tab(child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_rounded, size: 15),
                    SizedBox(width: 4),
                    Flexible(child: Text('Amigos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                )),
              ],
            ),
          ),
        ),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildPlayersTab(),
              _buildClansTab(),
              _buildFriendsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA JOGADORES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPlayersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('pontos', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhum jogador encontrado.', style: TextStyle(color: Colors.grey)));
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data     = docs[index].data() as Map<String, dynamic>;
            final uid      = docs[index].id;
            final name     = data['name']     ?? data['nickname'] ?? 'Jogador';
            final pontos   = (data['pontos']  ?? 0) as int;
            final avatarId = data['avatar']   ?? 'default';
            final isMe     = uid == currentUser?.uid;
            final nivel    = (pontos ~/ 250) + 1;
            return _buildPlayerCard(index + 1, name, pontos, nivel, avatarId, isMe);
          },
        );
      },
    );
  }

  Widget _buildPlayerCard(int rank, String name, int pontos, int nivel,
      String avatarId, bool isMe) {
    final rankColor = rank == 1 ? _gold : rank == 2 ? _silver : rank == 3 ? _bronze : const Color(0xFF94A3B8);
    final emoji = _avatarEmoji[avatarId] ?? '👤';
    final color = _avatarColor[avatarId] ?? _primary;

    Widget? medal;
    if (rank == 1) medal = const Text('🥇', style: TextStyle(fontSize: 18));
    if (rank == 2) medal = const Text('🥈', style: TextStyle(fontSize: 18));
    if (rank == 3) medal = const Text('🥉', style: TextStyle(fontSize: 18));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? _primary : const Color(0xFFE5E7EB), width: isMe ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: rank <= 3 ? rankColor.withOpacity(0.15) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: rank <= 3 ? rankColor : Colors.grey))),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(13)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isMe ? '$name (Você)' : name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isMe ? _primary : _primaryDeep),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('Nível $nivel', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )),
          // Pontos + medalha
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (medal != null) medal,
            Text('$pontos pts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isMe ? _primary : const Color(0xFF3B82F6))),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA CLÃS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildClansTab() {
    return StreamBuilder<DocumentSnapshot>(
      // Descobre o clã do utilizador atual
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
      builder: (context, userSnap) {
        String? myClanId;
        if (userSnap.hasData && userSnap.data!.exists) {
          final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          myClanId = data['clanId'] as String?;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clans')
              .orderBy('points', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }

            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏰', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  const Text('Nenhum clã ainda!', style: TextStyle(fontWeight: FontWeight.bold, color: _primaryDeep)),
                  const SizedBox(height: 8),
                  const Text('Cria um clã no separador Clã.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ));
            }

            // Só mostra clãs criados por utilizadores reais
            final docs = snap.data!.docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final createdBy = data['createdBy'] as String?;
              return createdBy != null && createdBy.isNotEmpty;
            }).toList();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data     = docs[index].data() as Map<String, dynamic>;
                final clanId   = docs[index].id;
                final name     = data['name']       ?? 'Clã';
                final icon     = data['icon']       ?? '🛡️';
                final points   = (data['points']    ?? 0) as num;
                final members  = (data['memberIds'] as List?)?.length ?? 0;
                final isMyC    = clanId == myClanId;
                return _buildClanCard(index + 1, name, icon, points.toInt(), members, isMyC);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildClanCard(int rank, String name, String icon, int points, int members, bool isMyClan) {
    final rankColor = rank == 1 ? _gold : rank == 2 ? _silver : rank == 3 ? _bronze : const Color(0xFF94A3B8);

    Widget? medal;
    if (rank == 1) medal = const Text('🥇', style: TextStyle(fontSize: 18));
    if (rank == 2) medal = const Text('🥈', style: TextStyle(fontSize: 18));
    if (rank == 3) medal = const Text('🥉', style: TextStyle(fontSize: 18));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isMyClan ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMyClan ? _primary : const Color(0xFFE5E7EB), width: isMyClan ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: rank <= 3 ? rankColor.withOpacity(0.15) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: rank <= 3 ? rankColor : Colors.grey))),
          ),
          const SizedBox(width: 10),
          // Ícone do clã
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(13)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(isMyClan ? '$name (O teu)' : name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isMyClan ? _primary : _primaryDeep),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (isMyClan) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Meu', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.people_outline, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$members membros', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ],
          )),
          // Pontos + medalha
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (medal != null) medal,
            Text('$points pts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isMyClan ? _primary : const Color(0xFF3B82F6))),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ABA AMIGOS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFriendsTab() {
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, mySnap) {
        if (!mySnap.hasData) return const Center(child: CircularProgressIndicator(color: _primary));

        final myData  = mySnap.data!.data() as Map<String, dynamic>? ?? {};
        final friends = List<String>.from(myData['friends'] ?? []);

        if (friends.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('👥', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text('Ainda não tens amigos!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _primaryDeep)),
            const SizedBox(height: 8),
            const Text('Adiciona amigos para ver o ranking.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ]));
        }

        // Inclui o próprio utilizador + amigos
        final allUids = [currentUser!.uid, ...friends];

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchFriendsData(allUids),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _primary));

            final sorted = snap.data!..sort((a, b) => (b['pontos'] as int).compareTo(a['pontos'] as int));
            final myRank = sorted.indexWhere((u) => u['uid'] == currentUser!.uid) + 1;

            return Column(children: [
              // Banner do meu rank entre amigos
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Estás em ${_rankLabel(myRank)} entre os teus amigos!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  )),
                  Text('#$myRank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ]),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final u       = sorted[i];
                    final isMe    = u['uid'] == currentUser!.uid;
                    final rank    = i + 1;
                    final emoji   = _avatarEmoji[u['avatar'] ?? 'default'] ?? '👤';
                    final color   = _avatarColor[u['avatar'] ?? 'default'] ?? _primary;
                    final medal   = rank == 1 ? const Text('🥇', style: TextStyle(fontSize: 22))
                                  : rank == 2 ? const Text('🥈', style: TextStyle(fontSize: 22))
                                  : rank == 3 ? const Text('🥉', style: TextStyle(fontSize: 22))
                                  : null;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMe ? _primary.withOpacity(0.4) : const Color(0xFFE5E7EB),
                          width: isMe ? 1.5 : 1,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        // Rank
                        SizedBox(width: 32, child: medal ?? Text(
                          '#$rank',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                              color: isMe ? _primary : Colors.grey),
                          textAlign: TextAlign.center,
                        )),
                        const SizedBox(width: 8),
                        // Avatar
                        Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(
                              u['nickname'] ?? u['name'] ?? 'Jogador',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                                  color: isMe ? _primary : _primaryDeep),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            )),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)),
                                child: const Text('Tu', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ]),
                          Text('Nível ${((u['pontos'] as int) ~/ 250) + 1}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ])),
                        // Pontos
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${u['pontos']}',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16,
                                color: rank <= 3 ? [_gold, _silver, _bronze][rank - 1] : const Color(0xFF3B82F6))),
                          const Text('pontos', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        ]),
                      ]),
                    );
                  },
                ),
              ),
            ]);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFriendsData(List<String> uids) async {
    final results = <Map<String, dynamic>>[];
    for (final uid in uids) {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>? ?? {};
        results.add({...data, 'uid': uid});
      }
    }
    return results;
  }

  String _rankLabel(int rank) {
    if (rank == 1) return '1.º lugar 🥇';
    if (rank == 2) return '2.º lugar 🥈';
    if (rank == 3) return '3.º lugar 🥉';
    return '$rank.º lugar';
  }
}