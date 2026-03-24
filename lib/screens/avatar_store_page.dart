import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR STORE PAGE — Loja de avatares com sistema de moedas
// ─────────────────────────────────────────────────────────────────────────────

class AvatarStorePage extends StatefulWidget {
  const AvatarStorePage({super.key});

  @override
  State<AvatarStorePage> createState() => _AvatarStorePageState();
}

class _AvatarStorePageState extends State<AvatarStorePage> {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  final user = FirebaseAuth.instance.currentUser;

  // Definição dos avatares disponíveis
  static const List<Map<String, dynamic>> _avatars = [
    {'id': 'default',  'name': 'Padrão',  'price': 0,   'emoji': '👤', 'color': Color(0xFF1A56DB)},
    {'id': 'fox',      'name': 'Raposa',  'price': 0,   'emoji': '🦊', 'color': Color(0xFFEA580C)},
    {'id': 'cat',      'name': 'Gato',    'price': 100, 'emoji': '🐱', 'color': Color(0xFF7C3AED)},
    {'id': 'panda',    'name': 'Panda',   'price': 150, 'emoji': '🐼', 'color': Color(0xFF0F766E)},
    {'id': 'lion',     'name': 'Leão',    'price': 150, 'emoji': '🦁', 'color': Color(0xFFB45309)},
    {'id': 'koala',    'name': 'Coala',   'price': 150, 'emoji': '🐨', 'color': Color(0xFF4B5563)},
    {'id': 'dragon',   'name': 'Dragão',  'price': 300, 'emoji': '🐉', 'color': Color(0xFFDC2626)},
    {'id': 'unicorn',  'name': 'Unicórnio','price': 300,'emoji': '🦄', 'color': Color(0xFFDB2777)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          int moedas       = 0;
          String equipped  = 'default';
          List<String> owned = ['default', 'fox'];

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            moedas   = (data['moedas']        ?? 0) as int;
            equipped = (data['avatar']        ?? 'default') as String;
            owned    = List<String>.from(data['ownedAvatars'] ?? ['default', 'fox']);
          }

          return CustomScrollView(
            slivers: [
              // ── AppBar ──────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _primaryDeep, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loja de Skins',
                        style: TextStyle(
                            color: _primaryDeep,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text('Personaliza o teu avatar',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                actions: [
                  // Badge de moedas
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '$moedas',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Banner info ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: _gold.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Text('🪙', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ganha moedas completando quizzes e alcançando conquistas!',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Como ganhar moedas ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHowToEarn(),
              ),

              // ── Grid de avatares ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final av = _avatars[index];
                      final id       = av['id'] as String;
                      final isOwned  = owned.contains(id);
                      final isEquipped = equipped == id;
                      return _buildAvatarCard(
                        context, av, isOwned, isEquipped, moedas, owned, equipped,
                      );
                    },
                    childCount: _avatars.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Como ganhar moedas ────────────────────────────────────────────────────
  Widget _buildHowToEarn() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Como Ganhar Moedas',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _primaryDeep)),
          const SizedBox(height: 12),
          _earnRow('🪙', 'Completar Quizzes',
              '50-100 moedas por quiz'),
          _earnRow('🔥', 'Manter Day Streak',
              '25 moedas por dia consecutivo'),
          _earnRow('🏆', 'Desbloquear Conquistas',
              '100-300 moedas por conquista'),
        ],
      ),
    );
  }

  Widget _earnRow(String emoji, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card de avatar ────────────────────────────────────────────────────────
  Widget _buildAvatarCard(
    BuildContext context,
    Map<String, dynamic> av,
    bool isOwned,
    bool isEquipped,
    int moedas,
    List<String> owned,
    String equipped,
  ) {
    final id    = av['id'] as String;
    final name  = av['name'] as String;
    final price = av['price'] as int;
    final emoji = av['emoji'] as String;
    final color = av['color'] as Color;
    final canAfford = moedas >= price;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEquipped
              ? _primary
              : isOwned
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFFE5E7EB),
          width: isEquipped ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: isEquipped
                  ? _primary.withOpacity(0.15)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar emoji
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 38)),
                        if (!isOwned)
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.lock_rounded,
                                color: Colors.white, size: 28),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _primaryDeep)),
                const SizedBox(height: 10),
                // Botão
                SizedBox(
                  width: double.infinity,
                  child: _buildButton(
                      context, id, isOwned, isEquipped, price,
                      canAfford, moedas, owned, equipped),
                ),
              ],
            ),
          ),
          // Check de equipado
          if (isEquipped)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: _primary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String id,
    bool isOwned,
    bool isEquipped,
    int price,
    bool canAfford,
    int moedas,
    List<String> owned,
    String equipped,
  ) {
    if (isEquipped) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEFF6FF),
          foregroundColor: _primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: null,
        child: const Text('Equipada',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }

    if (isOwned) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: () => _equipAvatar(id),
        child: const Text('Equipar',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }

    // Não possui — botão de compra
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            canAfford ? const Color(0xFFF59E0B) : Colors.grey.shade300,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onPressed:
          canAfford ? () => _buyAvatar(context, id, price, moedas, owned) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('$price',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Comprar avatar ────────────────────────────────────────────────────────
  Future<void> _buyAvatar(BuildContext context, String id, int price,
      int moedas, List<String> owned) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Compra',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Row(
          children: [
            const Text('🪙', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('Gastar $price moedas?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Comprar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid);
      final newOwned = [...owned, id];
      await userRef.update({
        'moedas'      : moedas - price,
        'ownedAvatars': newOwned,
      });
      if (mounted) _showPurchaseSuccess(context, id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Animação de compra bem sucedida ───────────────────────────────────────
  void _showPurchaseSuccess(BuildContext context, String avatarId) {
    final emoji = _avatars
        .firstWhere((a) => a['id'] == avatarId,
            orElse: () => {'emoji': '🪙'})['emoji'] as String;

    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => _PurchaseSuccessDialog(emoji: emoji),
    );
  }

  // ── Equipar avatar ────────────────────────────────────────────────────────
  Future<void> _equipAvatar(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .update({'avatar': id});
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PURCHASE SUCCESS DIALOG — animação de compra bem sucedida
// ─────────────────────────────────────────────────────────────────────────────

class _PurchaseSuccessDialog extends StatefulWidget {
  final String emoji;
  const _PurchaseSuccessDialog({required this.emoji});

  @override
  State<_PurchaseSuccessDialog> createState() =>
      _PurchaseSuccessDialogState();
}

class _PurchaseSuccessDialogState extends State<_PurchaseSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _particleCtrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut));
    _fade = CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeIn);

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    _scaleCtrl.forward();
    _particleCtrl.forward();

    // Fecha automaticamente após 2 segundos
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (_, __) => Opacity(
          opacity: _fade.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Partículas de confetti simuladas
                  AnimatedBuilder(
                    animation: _particleCtrl,
                    builder: (_, __) => SizedBox(
                      height: 60,
                      width: double.infinity,
                      child: Stack(
                        children: List.generate(10, (i) {
                          final x = (i * 28.0) % 220;
                          final dy = _particleCtrl.value * 60;
                          return Positioned(
                            left: x,
                            top: dy * (0.5 + (i % 3) * 0.2),
                            child: Opacity(
                              opacity:
                                  (1 - _particleCtrl.value).clamp(0.0, 1.0),
                              child: Text(
                                i % 3 == 0 ? '⭐' : i % 3 == 1 ? '🪙' : '✨',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  // Avatar desbloqueado
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFF59E0B), width: 3),
                    ),
                    child: Center(
                      child: Text(widget.emoji,
                          style: const TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Avatar Desbloqueado!',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vai ao teu perfil para equipar 🎉',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '✨ Clica no avatar para equipar ✨',
                    style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}