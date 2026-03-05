import 'package:flutter/material.dart';

class RecompensasPage extends StatefulWidget {
  const RecompensasPage({super.key});

  @override
  State<RecompensasPage> createState() => _RecompensasPageState();
}

class _RecompensasPageState extends State<RecompensasPage> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          "Conquistas",
          style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _headerProgresso(),
          _tabBarCustom(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Bloqueia swipe lateral
              children: [
                _abaPorTemas(),
                _abaBasicas(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= HEADER DE PROGRESSO GERAL =================
  Widget _headerProgresso() {
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
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Emblemas Conquistados", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text("7/20", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 7 / 20,
              backgroundColor: Colors.white24,
              color: Color(0xFF60A5FA),
              minHeight: 8,
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
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
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

  // ================= ABA: POR TEMAS (LISTA VERTICAL) =================
  Widget _abaPorTemas() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        // PHISHING
        _tituloTema("Phishing", Icons.email_outlined),
        _badgeVertical("Iniciante em Phishing", "Complete 3 quizzes de Phishing", Icons.mail_outline, true),
        _badgeVertical("Especialista em Phishing", "Complete o módulo de Phishing", Icons.shield_outlined, true),
        _badgeVertical("Mestre Anti-Phishing", "100% em todos os quizzes de Phishing", Icons.emoji_events_outlined, false),
        
        const SizedBox(height: 20),
        
        // PALAVRAS-PASSE
        _tituloTema("Palavras-passe", Icons.lock_outline),
        _badgeVertical("Guardião de Senhas", "Complete 3 quizzes de Palavras-passe", Icons.lock_open_outlined, true),
        _badgeVertical("Mestre das Palavras-passe", "Dominou a segurança de palavras-passe", Icons.verified_user_outlined, true),
        _badgeVertical("Criador de Senhas Fortes", "100% em todos os quizzes de senhas", Icons.workspace_premium_outlined, false),

        const SizedBox(height: 20),
        
        // SEGURANÇA WEB
        _tituloTema("Segurança Web", Icons.language),
        _badgeVertical("Surfista Web", "Complete 3 quizzes de Segurança Web", Icons.language, false),
        _badgeVertical("Navegador Seguro", "Complete o módulo de Segurança Web", Icons.shield_outlined, false),
        _badgeVertical("Guardião da Web", "100% em Segurança Web", Icons.emoji_events_outlined, false),

        const SizedBox(height: 20),
        
        // REDES SOCIAIS
        _tituloTema("Redes Sociais", Icons.people_outline),
        _badgeVertical("Navegador Social", "Complete 3 quizzes de Redes Sociais", Icons.person_search_outlined, true),
        _badgeVertical("Influencer Seguro", "Complete o módulo de Redes Sociais", Icons.star_outline, false),
        _badgeVertical("Protetor Digital", "100% em Redes Sociais", Icons.verified_user_outlined, false),
        
        const SizedBox(height: 40),
      ],
    );
  }

  // ================= ABA: BÁSICAS (GRID) =================
  Widget _abaBasicas() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(20),
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 0.85,
      physics: const BouncingScrollPhysics(),
      children: [
        _badgeBasico("Primeira Vitória", "Complete o primeiro quiz", Icons.emoji_events_outlined, true, Colors.blue),
        _badgeBasico("Estudante Dedicado", "7 dias consecutivos de estudo", Icons.local_fire_department, true, Colors.orange),
        _badgeBasico("Semana de Fogo", "30 dias consecutivos", Icons.local_fire_department, false, Colors.grey),
        _badgeBasico("Aprendiz Rápido", "Complete 5 quizzes em um dia", Icons.bolt, false, Colors.grey),
        _badgeBasico("Perfeccionista", "Obtenha 100% em 10 quizzes", Icons.workspace_premium, false, Colors.grey),
        _badgeBasico("Guru da Segurança", "Complete todos os módulos", Icons.school, false, Colors.grey),
      ],
    );
  }

  // ================= COMPONENTES AUXILIARES =================

  Widget _tituloTema(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icone, color: const Color(0xFF2563EB), size: 22),
          const SizedBox(width: 10),
          Text(titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
        ],
      ),
    );
  }

  // Card em formato de LISTA (Vertical) para manter a coerência com o Histórico
  Widget _badgeVertical(String nome, String desc, IconData icon, bool conquistado) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: conquistado ? Colors.blue.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: conquistado ? const Color(0xFFF0F7FF) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: conquistado ? const Color(0xFF2563EB) : Colors.grey.shade400, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: conquistado ? Colors.black : Colors.grey)),
                Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (conquistado) const Icon(Icons.check_circle, color: Colors.green, size: 18),
        ],
      ),
    );
  }

  Widget _badgeBasico(String nome, String desc, IconData icon, bool conquistado, Color cor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: conquistado ? cor : Colors.grey.shade300, size: 40),
          const SizedBox(height: 12),
          Text(nome, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: conquistado ? Colors.black : Colors.grey.shade400)),
          const SizedBox(height: 4),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 2),
        ],
      ),
    );
  }
}