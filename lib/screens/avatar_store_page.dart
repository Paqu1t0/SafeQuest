import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR STORE PAGE — Avatares + Banners com sistema de moedas
// ─────────────────────────────────────────────────────────────────────────────

class AvatarStorePage extends StatefulWidget {
  const AvatarStorePage({super.key});

  @override
  State<AvatarStorePage> createState() => _AvatarStorePageState();
}

class _AvatarStorePageState extends State<AvatarStorePage>
    with SingleTickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabCtrl;

  // ── Avatares ──────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _avatars = [
    {'id': 'default',  'name': 'Padrão',     'price': 0,   'emoji': '👤', 'color': Color(0xFF1A56DB)},
    {'id': 'fox',      'name': 'Raposa',     'price': 0,   'emoji': '🦊', 'color': Color(0xFFEA580C)},
    {'id': 'cat',      'name': 'Gato',       'price': 100, 'emoji': '🐱', 'color': Color(0xFF7C3AED)},
    {'id': 'panda',    'name': 'Panda',      'price': 150, 'emoji': '🐼', 'color': Color(0xFF0F766E)},
    {'id': 'lion',     'name': 'Leão',       'price': 150, 'emoji': '🦁', 'color': Color(0xFFB45309)},
    {'id': 'koala',    'name': 'Koala',      'price': 150, 'emoji': '🐨', 'color': Color(0xFF4B5563)},
    {'id': 'dragon',   'name': 'Dragão',     'price': 300, 'emoji': '🐉', 'color': Color(0xFFDC2626)},
    {'id': 'unicorn',  'name': 'Unicórnio',  'price': 300, 'emoji': '🦄', 'color': Color(0xFFDB2777)},
  ];

  // ── Banners — gradientes do fundo do perfil ───────────────────────────────
  static const List<Map<String, dynamic>> _banners = [
    {
      'id'     : 'default',
      'name'   : 'Azul Padrão',
      'price'  : 0,
      'emoji'  : '🔵',
      'colors' : [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      'desc'   : 'O banner original da SafeQuest',
    },
    {
      'id'     : 'sunset',
      'name'   : 'Pôr do Sol',
      'price'  : 150,
      'emoji'  : '🌅',
      'colors' : [Color(0xFFEA580C), Color(0xFFDC2626)],
      'desc'   : 'Tons quentes de laranja e vermelho',
    },
    {
      'id'     : 'forest',
      'name'   : 'Floresta',
      'price'  : 150,
      'emoji'  : '🌿',
      'colors' : [Color(0xFF16A34A), Color(0xFF0F766E)],
      'desc'   : 'Verde profundo como a natureza',
    },
    {
      'id'     : 'galaxy',
      'name'   : 'Galáxia',
      'price'  : 250,
      'emoji'  : '🌌',
      'colors' : [Color(0xFF7C3AED), Color(0xFF1E3A8A)],
      'desc'   : 'Roxo e azul do cosmos',
    },
    {
      'id'     : 'gold',
      'name'   : 'Ouro',
      'price'  : 300,
      'emoji'  : '✨',
      'colors' : [Color(0xFFF59E0B), Color(0xFFEA580C)],
      'desc'   : 'Dourado e radiante',
    },
    {
      'id'     : 'rose',
      'name'   : 'Rosa',
      'price'  : 200,
      'emoji'  : '🌸',
      'colors' : [Color(0xFFDB2777), Color(0xFF9333EA)],
      'desc'   : 'Rosa vibrante e elegante',
    },
    {
      'id'     : 'ocean',
      'name'   : 'Oceano',
      'price'  : 200,
      'emoji'  : '🌊',
      'colors' : [Color(0xFF0891B2), Color(0xFF1A56DB)],
      'desc'   : 'Azul profundo do mar',
    },
    {
      'id'     : 'midnight',
      'name'   : 'Meia-Noite',
      'price'  : 250,
      'emoji'  : '🌙',
      'colors' : [Color(0xFF1E293B), Color(0xFF334155)],
      'desc'   : 'Escuro e misterioso',
    },
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          int    moedas        = 0;
          String equippedAv    = 'default';
          String equippedBn    = 'default';
          List<String> ownedAv = ['default', 'fox'];
          List<String> ownedBn = ['default'];

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            moedas       = (data['moedas']         ?? 0) as int;
            equippedAv   = (data['avatar']          ?? 'default') as String;
            equippedBn   = (data['banner']          ?? 'default') as String;
            ownedAv      = List<String>.from(data['ownedAvatars'] ?? ['default', 'fox']);
            ownedBn      = List<String>.from(data['ownedBanners'] ?? ['default']);
          }

          return CustomScrollView(
            slivers: [
              // ── AppBar ────────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryDeep, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Loja de Skins', style: TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Personaliza o teu perfil', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                actions: [
                  // Badge moedas
                  GestureDetector(
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        const Text('🪙', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text('$moedas', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                    ),
                  ),
                ],
                bottom: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(border: Border(bottom: BorderSide(color: _primary, width: 3))),
                  labelColor: _primary,
                  unselectedLabelColor: Colors.grey,
                  dividerColor: const Color(0xFFE5E7EB),
                  tabs: const [
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('👤  Avatares')])),
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🎨  Banners')])),
                  ],
                ),
              ),

              // ── Banner info ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _gold.withOpacity(0.35)),
                  ),
                  child: const Row(children: [
                    Text('🪙', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Ganha moedas completando quizzes e conquistas!',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF92400E)),
                    )),
                  ]),
                ),
              ),

              // ── Conteúdo das tabs ─────────────────────────────────────────
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // ── ABA AVATARES ─────────────────────────────────────────
                    GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82,
                      ),
                      itemCount: _avatars.length,
                      itemBuilder: (context, index) {
                        final av      = _avatars[index];
                        final id      = av['id'] as String;
                        final isOwned = ownedAv.contains(id);
                        final isEq    = equippedAv == id;
                        return _buildAvatarCard(context, av, isOwned, isEq, moedas, ownedAv);
                      },
                    ),

                    // ── ABA BANNERS ──────────────────────────────────────────
                    GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78,
                      ),
                      itemCount: _banners.length,
                      itemBuilder: (context, index) {
                        final bn      = _banners[index];
                        final id      = bn['id'] as String;
                        final isOwned = ownedBn.contains(id);
                        final isEq    = equippedBn == id;
                        return _buildBannerCard(context, bn, isOwned, isEq, moedas, ownedBn);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Card de avatar ────────────────────────────────────────────────────────
  Widget _buildAvatarCard(BuildContext context, Map<String, dynamic> av, bool isOwned, bool isEq, int moedas, List<String> owned) {
    final id       = av['id'] as String;
    final name     = av['name'] as String;
    final price    = av['price'] as int;
    final emoji    = av['emoji'] as String;
    final color    = av['color'] as Color;
    final canAfford = moedas >= price;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isEq ? _primary : const Color(0xFFE5E7EB), width: isEq ? 2 : 1),
        boxShadow: [BoxShadow(color: isEq ? _primary.withOpacity(0.12) : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(18)),
                child: Center(child: Stack(alignment: Alignment.center, children: [
                  Text(emoji, style: const TextStyle(fontSize: 36)),
                  if (!isOwned) Container(
                    width: 68, height: 68,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
                  ),
                ])),
              ),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryDeep)),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: _avatarBtn(context, id, isOwned, isEq, price, canAfford, moedas, owned)),
            ]),
          ),
          if (isEq) Positioned(top: 8, right: 8, child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
          )),
        ],
      ),
    );
  }

  Widget _avatarBtn(BuildContext context, String id, bool isOwned, bool isEq, int price, bool canAfford, int moedas, List<String> owned) {
    if (isEq) return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEFF6FF), foregroundColor: _primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
      onPressed: null,
      child: const Text('Equipada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
    if (isOwned) return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
      onPressed: () => _equipAvatar(id),
      child: const Text('Equipar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: canAfford ? _gold : Colors.grey.shade300, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
      onPressed: canAfford ? () => _buyAvatar(context, id, price, moedas, owned) : null,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🪙', style: TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text('$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  // ── Card de banner ────────────────────────────────────────────────────────
  Widget _buildBannerCard(BuildContext context, Map<String, dynamic> bn, bool isOwned, bool isEq, int moedas, List<String> owned) {
    final id       = bn['id'] as String;
    final name     = bn['name'] as String;
    final price    = bn['price'] as int;
    final emoji    = bn['emoji'] as String;
    final colors   = bn['colors'] as List<Color>;
    final desc     = bn['desc'] as String;
    final canAfford = moedas >= price;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isEq ? colors[0] : const Color(0xFFE5E7EB), width: isEq ? 2 : 1),
        boxShadow: [BoxShadow(color: isEq ? colors[0].withOpacity(0.2) : Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Column(children: [
            // Preview do banner
            Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isOwned ? colors : [Colors.grey.shade300, Colors.grey.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(child: Stack(alignment: Alignment.center, children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                if (!isOwned) Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  child: const Center(child: Icon(Icons.lock_rounded, color: Colors.white, size: 30)),
                ),
              ])),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryDeep)),
                const SizedBox(height: 3),
                Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: _bannerBtn(context, id, isOwned, isEq, price, canAfford, moedas, owned, colors[0])),
              ]),
            ),
          ]),
          if (isEq) Positioned(top: 8, right: 8, child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: colors[0], shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
          )),
        ],
      ),
    );
  }

  Widget _bannerBtn(BuildContext context, String id, bool isOwned, bool isEq, int price, bool canAfford, int moedas, List<String> owned, Color color) {
    if (isEq) return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.15), foregroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
      onPressed: null,
      child: const Text('Equipado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
    if (isOwned) return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
      onPressed: () => _equipBanner(id),
      child: const Text('Equipar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: canAfford ? _gold : Colors.grey.shade300, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
      onPressed: canAfford ? () => _buyBanner(context, id, price, moedas, owned) : null,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🪙', style: TextStyle(fontSize: 11)),
        const SizedBox(width: 3),
        Text(price == 0 ? 'Grátis' : '$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  // ── Comprar avatar ────────────────────────────────────────────────────────
  Future<void> _buyAvatar(BuildContext context, String id, int price, int moedas, List<String> owned) async {
    final confirm = await _confirmBuy(context, '🪙 Gastar $price moedas neste avatar?');
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        'moedas': moedas - price, 'ownedAvatars': [...owned, id],
      });
      if (mounted) _showSuccess(context, '👤 Avatar desbloqueado!');
    } catch (e) { if (mounted) _showError(context, '$e'); }
  }

  Future<void> _equipAvatar(String id) async {
    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'avatar': id});
  }

  // ── Comprar banner ────────────────────────────────────────────────────────
  Future<void> _buyBanner(BuildContext context, String id, int price, int moedas, List<String> owned) async {
    if (price == 0) {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'ownedBanners': [...owned, id]});
      return;
    }
    final confirm = await _confirmBuy(context, '🪙 Gastar $price moedas neste banner?');
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
        'moedas': moedas - price, 'ownedBanners': [...owned, id],
      });
      if (mounted) _showSuccess(context, '🎨 Banner desbloqueado!');
    } catch (e) { if (mounted) _showError(context, '$e'); }
  }

  Future<void> _equipBanner(String id) async {
    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'banner': id});
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<bool?> _confirmBuy(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Compra', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Comprar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $msg'), backgroundColor: Colors.red));
  }
}