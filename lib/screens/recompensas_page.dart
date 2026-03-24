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
        title: const Text(
          "Conquistas",
          style: TextStyle(
              color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
        ),
      ),

      // ── StreamBuilder para reagir em tempo real ao Firestore ──────────────
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Set de IDs de emblemas conquistados
          Set<String> conquistados = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            final data =
                snapshot.data!.data() as Map<String, dynamic>? ?? {};
            conquistados =
                Set<String>.from(data['badges'] ?? []);
          }

          final total      = BadgesService.allBadges.length;
          final totalGanho = conquistados.length;

          return Column(
            children: [
              _headerProgresso(totalGanho, total),
              _tabBarCustom(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _abaPorTemas(conquistados),
                    _abaBasicas(conquistados),
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
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Emblemas Conquistados",
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                  Text("$ganho/$total",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.emoji_events_outlined,
                    color: Colors.white, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total > 0 ? ganho / total : 0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: val,
                backgroundColor: Colors.white24,
                color: const Color(0xFF60A5FA),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBarCustom() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        controller: _tabController,
        indicator:
            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        labelColor: const Color(0xFF2563EB),
        unselectedLabelColor: Colors.grey,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Por Temas"),
          Tab(text: "Básicas"),
        ],
      ),
    );
  }

  // ── ABA POR TEMAS ──────────────────────────────────────────────────────────

  Widget _abaPorTemas(Set<String> conquistados) {
    // Filtra só emblemas de tema (não básicos)
    final temas = ['Phishing', 'Palavras-passe', 'Segurança Web', 'Redes Sociais'];
    final temaIcons = {
      'Phishing'       : Icons.email_outlined,
      'Palavras-passe' : Icons.lock_outline,
      'Segurança Web'  : Icons.language,
      'Redes Sociais'  : Icons.people_outline,
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        for (final tema in temas) ...[
          _tituloTema(tema, temaIcons[tema]!),
          ...BadgesService.allBadges
              .where((b) => b['categoria'] == tema)
              .map((b) => _badgeVertical(
                    b['nome'] as String,
                    b['desc'] as String,
                    _iconForBadge(b['id'] as String),
                    conquistados.contains(b['id']),
                  )),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // ── ABA BÁSICAS ────────────────────────────────────────────────────────────

  Widget _abaBasicas(Set<String> conquistados) {
    final basicBadges = BadgesService.allBadges
        .where((b) => b['categoria'] == 'basica')
        .toList();

    final colors = {
      'primeira_vitoria' : Colors.blue,
      'aprendiz_rapido'  : Colors.orange,
      'perfeccionista'   : Colors.purple,
      'guru_seguranca'   : Colors.indigo,
    };

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(20),
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 0.85,
      physics: const BouncingScrollPhysics(),
      children: basicBadges.map((b) {
        final id           = b['id'] as String;
        final conquistado  = conquistados.contains(id);
        final cor          = conquistado
            ? (colors[id] ?? Colors.blue)
            : Colors.grey;
        return _badgeBasico(
          b['nome'] as String,
          b['desc'] as String,
          _iconForBadge(id),
          conquistado,
          cor,
        );
      }).toList(),
    );
  }

  // ── COMPONENTES ────────────────────────────────────────────────────────────

  Widget _tituloTema(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icone, color: const Color(0xFF2563EB), size: 22),
          const SizedBox(width: 10),
          Text(titulo,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A))),
        ],
      ),
    );
  }

  Widget _badgeVertical(
      String nome, String desc, IconData icon, bool conquistado) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: conquistado
              ? Colors.blue.withOpacity(0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: conquistado
            ? [
                BoxShadow(
                    color: Colors.blue.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: conquistado
                  ? const Color(0xFFF0F7FF)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: conquistado
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade400,
                size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: conquistado ? Colors.black : Colors.grey)),
                Text(desc,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (conquistado)
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
        ],
      ),
    );
  }

  Widget _badgeBasico(
      String nome, String desc, IconData icon, bool conquistado, Color cor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: conquistado ? cor.withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: conquistado
            ? [
                BoxShadow(
                    color: cor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: conquistado ? cor : Colors.grey.shade300, size: 40),
          const SizedBox(height: 12),
          Text(nome,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color:
                      conquistado ? Colors.black : Colors.grey.shade400)),
          const SizedBox(height: 4),
          Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 2),
          if (conquistado) ...[
            const SizedBox(height: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ],
      ),
    );
  }

  // ── Ícone por ID de emblema ────────────────────────────────────────────────
  IconData _iconForBadge(String id) {
    const map = {
      'primeira_vitoria'    : Icons.emoji_events_outlined,
      'aprendiz_rapido'     : Icons.bolt,
      'perfeccionista'      : Icons.workspace_premium,
      'guru_seguranca'      : Icons.school,
      'iniciante_phishing'  : Icons.mail_outline,
      'especialista_phishing': Icons.shield_outlined,
      'mestre_phishing'     : Icons.emoji_events_outlined,
      'guardiao_senhas'     : Icons.lock_open_outlined,
      'mestre_passwords'    : Icons.verified_user_outlined,
      'criador_senhas'      : Icons.workspace_premium_outlined,
      'surfista_web'        : Icons.language,
      'navegador_seguro'    : Icons.shield_outlined,
      'guardiao_web'        : Icons.emoji_events_outlined,
      'navegador_social'    : Icons.person_search_outlined,
      'influencer_seguro'   : Icons.star_outline,
      'protetor_digital'    : Icons.verified_user_outlined,
    };
    return map[id] ?? Icons.military_tech_rounded;
  }
}