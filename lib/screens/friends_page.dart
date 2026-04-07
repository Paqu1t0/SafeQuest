import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/screens/member_profile_page.dart';
import 'package:projeto_safequest/screens/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FRIENDS PAGE — pedidos de amizade com aceitar/rejeitar
// Estrutura Firestore:
//   users/{uid}/friendRequests: [{from, fromName, status}]  ← pendentes recebidos
//   users/{uid}/friends: [uid1, uid2, ...]                  ← amigos aceites
// ─────────────────────────────────────────────────────────────────────────────

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  final user        = FirebaseAuth.instance.currentUser;
  final _searchCtrl = TextEditingController();
  String _search    = '';
  bool   _searching = false;
  List<Map<String, dynamic>> _searchResults = [];

  late TabController _tabCtrl;

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
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Pesquisa de utilizadores ──────────────────────────────────────────────
  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) { setState(() { _searchResults = []; _searching = false; }); return; }
    setState(() => _searching = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .limit(10).get();
      if (mounted) setState(() {
        _searchResults = snap.docs.where((d) => d.id != user?.uid).map((d) => {'uid': d.id, ...d.data()}).toList();
        _searching = false;
      });
    } catch (_) { setState(() => _searching = false); }
  }

  // ── Enviar pedido de amizade ──────────────────────────────────────────────
  Future<void> _sendFriendRequest(String toUid, String toName) async {
    if (user == null) return;
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final myName = (myDoc.data()?['name'] ?? 'Jogador') as String;

    // Adiciona pedido no documento do destinatário
    await FirebaseFirestore.instance.collection('users').doc(toUid).update({
      'friendRequests': FieldValue.arrayUnion([{
        'from'    : user!.uid,
        'fromName': myName,
        'status'  : 'pending',
      }]),
    });

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pedido enviado a $toName! 📨'), backgroundColor: Colors.green),
    );
  }

  // ── Aceitar pedido ────────────────────────────────────────────────────────
  Future<void> _acceptRequest(String fromUid, String fromName, List requests) async {
    if (user == null) return;
    final myDoc  = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final myName = (myDoc.data()?['name'] ?? 'Jogador') as String;

    final batch = FirebaseFirestore.instance.batch();
    final myRef   = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final fromRef = FirebaseFirestore.instance.collection('users').doc(fromUid);
    batch.update(myRef,   {'friends': FieldValue.arrayUnion([fromUid])});
    batch.update(fromRef, {'friends': FieldValue.arrayUnion([user!.uid])});
    final updatedRequests = requests.where((r) => r['from'] != fromUid).toList();
    batch.update(myRef, {'friendRequests': updatedRequests});
    await batch.commit();

    // Notificações para ambos
    await NotificationService.send(
      toUid : fromUid,
      title : '👥 $myName aceitou o teu pedido!',
      body  : 'Já são amigos! Podem ver os perfis um do outro e competir nas classificações.',
      type  : 'friend_added',
    );

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fromName é agora teu amigo! 🎉'), backgroundColor: Colors.green),
    );
  }

  // ── Rejeitar pedido ───────────────────────────────────────────────────────
  Future<void> _rejectRequest(String fromUid, List requests) async {
    if (user == null) return;
    final updatedRequests = requests.where((r) => r['from'] != fromUid).toList();
    await FirebaseFirestore.instance.collection('users').doc(user!.uid)
        .update({'friendRequests': updatedRequests});
  }

  // ── Remover amigo ─────────────────────────────────────────────────────────
  Future<void> _removeFriend(String uid) async {
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('users').doc(user!.uid), {'friends': FieldValue.arrayRemove([uid])});
    batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {'friends': FieldValue.arrayRemove([user!.uid])});
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryDeep, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Amigos', style: TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicator: const BoxDecoration(border: Border(bottom: BorderSide(color: _primary, width: 3))),
          labelColor: _primary, unselectedLabelColor: Colors.grey,
          dividerColor: const Color(0xFFE5E7EB),
          tabs: [
            const Tab(text: 'Amigos'),
            // Pedidos com badge de contagem
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (_, snap) {
                int count = 0;
                if (snap.hasData && snap.data!.exists) {
                  final requests = List.from((snap.data!.data() as Map<String, dynamic>?)?['friendRequests'] ?? []);
                  count = requests.length;
                }
                return Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Pedidos'),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]));
              },
            ),
            const Tab(text: 'Pesquisar'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snap) {
          final myData  = snap.hasData && snap.data!.exists ? snap.data!.data() as Map<String, dynamic>? ?? {} : {};
          final friends  = List<String>.from(myData['friends'] ?? []);
          final requests = List.from(myData['friendRequests'] ?? []);

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _buildFriendsTab(friends),
              _buildRequestsTab(requests),
              _buildSearchTab(friends, requests),
            ],
          );
        },
      ),
    );
  }

  // ── ABA AMIGOS ────────────────────────────────────────────────────────────
  Widget _buildFriendsTab(List<String> friends) {
    if (friends.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('👥', style: TextStyle(fontSize: 52)),
        SizedBox(height: 16),
        Text('Ainda não tens amigos!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryDeep)),
        SizedBox(height: 8),
        Text('Usa a aba "Pesquisar" para encontrar jogadores.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${friends.length} amigo${friends.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDeep)),
          );
        }
        final uid = friends[i - 1];
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final data     = snap.data!.data() as Map<String, dynamic>? ?? {};
            final name     = data['name']    ?? 'Jogador';
            final pontos   = (data['pontos'] ?? 0) as int;
            final avatarId = data['avatar']  ?? 'default';
            final nivel    = (pontos ~/ 250) + 1;
            return _userCard(
              uid: uid, name: name, pontos: pontos, nivel: nivel, avatarId: avatarId,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                // Botão remover visível
                GestureDetector(
                  onTap: () => _confirmRemove(uid, name),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ]),
            );
          },
        );
      },
    );
  }

  // ── ABA PEDIDOS ───────────────────────────────────────────────────────────
  Widget _buildRequestsTab(List requests) {
    if (requests.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('📭', style: TextStyle(fontSize: 52)),
        SizedBox(height: 16),
        Text('Sem pedidos pendentes.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryDeep)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, i) {
        final req     = requests[i] as Map<String, dynamic>;
        final fromUid  = req['from']     as String;
        final fromName = req['fromName'] as String? ?? 'Jogador';

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(fromUid).snapshots(),
          builder: (context, snap) {
            final data     = snap.hasData && snap.data!.exists ? snap.data!.data() as Map<String, dynamic>? ?? {} : {};
            final pontos   = (data['pontos'] ?? 0) as int;
            final avatarId = data['avatar']  ?? 'default';
            final nivel    = (pontos ~/ 250) + 1;

            return _userCard(
              uid: fromUid, name: fromName, pontos: pontos, nivel: nivel, avatarId: avatarId,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                // Rejeitar
                GestureDetector(
                  onTap: () => _rejectRequest(fromUid, requests),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                // Aceitar
                GestureDetector(
                  onTap: () => _acceptRequest(fromUid, fromName, requests),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 20),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  // ── ABA PESQUISAR ─────────────────────────────────────────────────────────
  Widget _buildSearchTab(List<String> friends, List requests) {
    final pendingUids = requests.map((r) => (r as Map<String, dynamic>)['from'] as String).toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) { setState(() => _search = v); _searchUsers(v); },
              decoration: InputDecoration(
                hintText: 'Pesquisar pelo nome...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey, size: 18), onPressed: () { _searchCtrl.clear(); setState(() { _search = ''; _searchResults = []; }); }) : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        if (_searching) const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2))
        else if (_search.length >= 2 && _searchResults.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Text('Nenhum jogador encontrado.', style: TextStyle(color: Colors.grey)))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: _searchResults.length,
              itemBuilder: (context, i) {
                final u        = _searchResults[i];
                final uid      = u['uid'] as String;
                final name     = u['name']    ?? 'Jogador';
                final pontos   = (u['pontos'] ?? 0) as int;
                final avatarId = u['avatar']  ?? 'default';
                final nivel    = (pontos ~/ 250) + 1;
                final isFriend = friends.contains(uid);
                final isPending = pendingUids.contains(uid);

                return _userCard(
                  uid: uid, name: name, pontos: pontos, nivel: nivel, avatarId: avatarId,
                  trailing: isFriend
                      ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)), child: const Text('Amigo ✓', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)))
                      : isPending
                          ? Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)), child: const Text('Pendente', style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 12)))
                          : GestureDetector(
                              onTap: () => _sendFriendRequest(uid, name as String),
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(10)), child: const Text('Adicionar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Card de utilizador ────────────────────────────────────────────────────
  Widget _userCard({required String uid, required String name, required int pontos, required int nivel, required String avatarId, required Widget trailing}) {
    final emoji = _avatarEmoji[avatarId] ?? '👤';
    final color = _avatarColor[avatarId] ?? _primary;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberProfilePage(uid: uid))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(13)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryDeep)),
            const SizedBox(height: 2),
            Row(children: [
              Text('Nível $nivel', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Text('  •  ', style: TextStyle(color: Colors.grey)),
              Text('$pontos pts', style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ])),
          trailing,
        ]),
      ),
    );
  }

  Future<void> _confirmRemove(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remover $name?', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) await _removeFriend(uid);
  }
}