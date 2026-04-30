import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/screens/badges_service.dart';

class RecompensasPage extends StatefulWidget {
  const RecompensasPage({super.key});

  @override
  State<RecompensasPage> createState() => _RecompensasPageState();
}

class _RecompensasPageState extends State<RecompensasPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _topicFilter = 'Todos';

  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  // Cores para os cards conquistados (por tema)
  static const _themeColors = {
    'Phishing'      : Color(0xFF1A56DB),
    'Palavras-passe': Color(0xFF7C3AED),
    'Segurança Web' : Color(0xFF0F766E),
    'Redes Sociais' : Color(0xFFEA580C),
    'basica'        : Color(0xFF3B82F6),
  };

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text('Conquistas',
            style: TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          Set<String> conquistados = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            conquistados = Set<String>.from(data['badges'] ?? []);
          }

          final total  = BadgesService.allBadges.length;
          final ganho  = conquistados.length;

          return Column(
            children: [
              _headerProgresso(ganho, total),
              _tabBarCustom(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _abaBasicas(conquistados),
                    _abaPorTemas(conquistados),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _headerProgresso(int ganho, int total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Emblemas Conquistados", style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text("$ganho/$total", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ]),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total > 0 ? ganho / total : 0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, _) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: val, backgroundColor: Colors.white24, color: const Color(0xFF60A5FA), minHeight: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBarCustom() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        labelColor: _primary,
        unselectedLabelColor: Colors.grey,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: "Básicas"), Tab(text: "Por Temas")],
      ),
    );
  }

  // ── ABA BÁSICAS — grid de cards coloridos ──────────────────────────────────
  Widget _abaBasicas(Set<String> conquistados) {
    final basicBadges = BadgesService.allBadges.where((b) => b['categoria'] == 'basica').toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78,
      ),
      itemCount: basicBadges.length,
      itemBuilder: (context, i) {
        final badge      = basicBadges[i];
        final conquistado = conquistados.contains(badge['id']);
        return _badgeCard(badge, conquistado, 'basica');
      },
    );
  }

  // ── ABA POR TEMAS — filtros + grid ────────────────────────────────────────
  Widget _abaPorTemas(Set<String> conquistados) {
    final temas = ['Todos', 'Phishing', 'Palavras-passe', 'Segurança Web', 'Redes Sociais'];
    final filtered = BadgesService.allBadges.where((b) {
      if (b['categoria'] == 'basica') return false;
      if (_topicFilter == 'Todos') return true;
      return b['categoria'] == _topicFilter;
    }).toList();

    return Column(
      children: [
        // Filtros horizontais
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            itemCount: temas.length,
            itemBuilder: (context, i) {
              final t          = temas[i];
              final isSelected = t == _topicFilter;
              return GestureDetector(
                onTap: () => setState(() => _topicFilter = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? _primary : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.88,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final badge       = filtered[i];
              final conquistado = conquistados.contains(badge['id']);
              return _badgeCard(badge, conquistado, badge['categoria'] as String);
            },
          ),
        ),
      ],
    );
  }

  // ── CARD DE EMBLEMA ────────────────────────────────────────────────────────
  Widget _badgeCard(Map<String, dynamic> badge, bool conquistado, String categoria) {
    final cardColor = conquistado
        ? (_themeColors[categoria] ?? _primary)
        : const Color(0xFFF1F5F9);
    final textColor    = conquistado ? Colors.white : Colors.grey;
    final subTextColor = conquistado ? Colors.white.withOpacity(0.75) : Colors.grey.shade400;
    final icon         = badge['icon'] as String? ?? '🏅';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: conquistado
            ? [BoxShadow(color: cardColor.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
        border: conquistado ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone num círculo translúcido
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: conquistado ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  conquistado ? icon : '🔒',
                  style: TextStyle(fontSize: conquistado ? 26 : 22),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(badge['nome'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 3),
            Flexible(
              child: Text(badge['desc'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subTextColor, fontSize: 10)),
            ),
            if (conquistado) ...[
              const SizedBox(height: 6),
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}