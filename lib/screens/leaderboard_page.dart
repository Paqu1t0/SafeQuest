import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEADERBOARD PAGE — Classificação global com dados reais do Firestore
// ─────────────────────────────────────────────────────────────────────────────

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFFBBF24);
  static const _silver      = Color(0xFF9CA3AF);
  static const _bronze      = Color(0xFFCD7C2F);

  // Mapa de emoji por avatar id
  static const _avatarEmoji = {
    'default': '👤',
    'fox'    : '🦊',
    'cat'    : '🐱',
    'panda'  : '🐼',
    'lion'   : '🦁',
    'koala'  : '🐨',
    'dragon' : '🐉',
    'unicorn': '🦄',
  };

  static const _avatarColor = {
    'default': Color(0xFF1A56DB),
    'fox'    : Color(0xFFEA580C),
    'cat'    : Color(0xFF7C3AED),
    'panda'  : Color(0xFF0F766E),
    'lion'   : Color(0xFFB45309),
    'koala'  : Color(0xFF4B5563),
    'dragon' : Color(0xFFDC2626),
    'unicorn': Color(0xFFDB2777),
  };

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Classificação Global',
          style: TextStyle(
              color: _primaryDeep,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.trending_up_rounded, color: _primary, size: 16),
                SizedBox(width: 4),
                Text('Top 10',
                    style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('pontos', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _primary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhum jogador encontrado.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data() as Map<String, dynamic>;
              final uid      = docs[index].id;
              final name     = data['name'] ?? data['nickname'] ?? 'Jogador';
              final pontos   = (data['pontos'] ?? 0) as int;
              final avatarId = data['avatar'] ?? 'default';
              final isMe     = uid == currentUser?.uid;
              final rank     = index + 1;

              // Calcula nível (1 ponto = 1pt, nível a cada 250)
              final nivel = (pontos ~/ 250) + 1;

              return _buildPlayerCard(
                  rank, name, pontos, nivel, avatarId, isMe);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlayerCard(int rank, String name, int pontos, int nivel,
      String avatarId, bool isMe) {
    Color rankColor;
    Widget rankWidget;

    if (rank == 1) {
      rankColor  = _gold;
      rankWidget = _rankBadge('#1', _gold);
    } else if (rank == 2) {
      rankColor  = _silver;
      rankWidget = _rankBadge('#2', _silver);
    } else if (rank == 3) {
      rankColor  = _bronze;
      rankWidget = _rankBadge('#3', _bronze);
    } else {
      rankColor  = const Color(0xFF94A3B8);
      rankWidget = _rankBadge('#$rank', const Color(0xFFE2E8F0));
    }

    final emoji = _avatarEmoji[avatarId] ?? '👤';
    final color = _avatarColor[avatarId] ?? _primary;

    // Medalha para top 3
    Widget? medal;
    if (rank == 1) medal = const Text('🥇', style: TextStyle(fontSize: 20));
    if (rank == 2) medal = const Text('🥈', style: TextStyle(fontSize: 20));
    if (rank == 3) medal = const Text('🥉', style: TextStyle(fontSize: 20));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? _primary : const Color(0xFFE5E7EB),
          width: isMe ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: isMe
                  ? _primary.withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          rankWidget,
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),

          // Nome + nível
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$name (Você)' : name,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isMe ? _primary : _primaryDeep),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nível $nivel  •  ',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Pontos + medalha
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (medal != null) medal,
              Text(
                '$pontos pts',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isMe ? _primary : const Color(0xFF3B82F6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(String label, Color color) {
    final isTop3 = label == '#1' || label == '#2' || label == '#3';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isTop3 ? color.withOpacity(0.15) : color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isTop3 ? color : Colors.white),
        ),
      ),
    );
  }
}