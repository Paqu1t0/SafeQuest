import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:projeto_safequest/screens/member_profile_page.dart';

class ClanDetailPage extends StatefulWidget {
  final String clanId;
  final bool   embedded;

  const ClanDetailPage({super.key, required this.clanId, this.embedded = false});

  @override
  State<ClanDetailPage> createState() => _ClanDetailPageState();
}

class _ClanDetailPageState extends State<ClanDetailPage>
    with SingleTickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  late TabController _tabCtrl;
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final user        = FirebaseAuth.instance.currentUser;

  // Papéis
  static const _roleOrder = {'leader': 0, 'co-leader': 1, 'elder': 2, 'member': 3};
  static const _roleLabels = {'leader': '👑 Líder', 'co-leader': '⭐ Co-Líder', 'elder': '🔰 Ancião', 'member': '👤 Membro'};
  static const _roleColors = {
    'leader'    : Color(0xFFFBBF24),
    'co-leader' : Color(0xFF7C3AED),
    'elder'     : Color(0xFF16A34A),
    'member'    : Color(0xFF1A56DB),
  };

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
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Verifica o papel do utilizador atual ──────────────────────────────────
  String _getMyRole(Map<String, dynamic> data) {
    if (data['createdBy'] == user?.uid) return 'leader';
    final roles = data['roles'] as Map<String, dynamic>? ?? {};
    return roles[user?.uid] ?? 'member';
  }

  bool _canManage(String myRole) => myRole == 'leader' || myRole == 'co-leader';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clans').doc(widget.clanId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _primary));
        final data    = snap.data!.data() as Map<String, dynamic>? ?? {};
        final name    = data['name']    ?? 'Clã';
        final icon    = data['icon']    ?? '🛡️';
        final points  = (data['points'] ?? 0) as num;
        final members = (data['memberIds'] as List?)?.length ?? 0;
        final myRole  = _getMyRole(data);

        final body = _buildBody(name, icon, points, members, myRole, data);
        return widget.embedded
            ? body
            : Scaffold(
                backgroundColor: const Color(0xFFF8FAFC),
                appBar: AppBar(
                  backgroundColor: Colors.white, elevation: 0, centerTitle: true,
                  title: const Text('Clã', style: TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                body: body,
              );
      },
    );
  }

  Widget _buildBody(String name, String icon, num points, int members, String myRole, Map<String, dynamic> clanData) {
    return Column(
      children: [
        // Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(icon, style: const TextStyle(fontSize: 26)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('$members membros', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
            Column(children: [
              const Text('🏆', style: TextStyle(fontSize: 16)),
              Text('${points.toInt()} pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ]),
        ),
        // O meu papel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: (_roleColors[myRole] ?? _primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (_roleColors[myRole] ?? _primary).withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_roleLabels[myRole] ?? '👤 Membro', style: TextStyle(color: _roleColors[myRole] ?? _primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            indicator: const BoxDecoration(border: Border(bottom: BorderSide(color: _primary, width: 3))),
            labelColor: _primary, unselectedLabelColor: Colors.grey,
            dividerColor: const Color(0xFFE5E7EB),
            tabs: const [Tab(text: 'Membros'), Tab(text: 'Chat')],
          ),
        ),
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [_buildMembersTab(myRole, clanData), _buildChatTab()],
        )),
      ],
    );
  }

  // ── ABA MEMBROS ────────────────────────────────────────────────────────────
  Widget _buildMembersTab(String myRole, Map<String, dynamic> clanData) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clans').doc(widget.clanId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _primary));
        final data      = snap.data!.data() as Map<String, dynamic>? ?? {};
        final memberIds = List<String>.from(data['memberIds'] ?? []);
        final roles     = Map<String, dynamic>.from(data['roles'] ?? {});
        final createdBy = data['createdBy'] as String? ?? '';

        // Ordena: líder → co-líder → ancião → membro
        memberIds.sort((a, b) {
          String roleA = a == createdBy ? 'leader' : (roles[a] ?? 'member');
          String roleB = b == createdBy ? 'leader' : (roles[b] ?? 'member');
          return (_roleOrder[roleA] ?? 3).compareTo(_roleOrder[roleB] ?? 3);
        });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            ...memberIds.map((uid) {
              final memberRole = uid == createdBy ? 'leader' : (roles[uid] ?? 'member');
              return _buildMemberCard(uid, memberRole, myRole, createdBy);
            }),
            const SizedBox(height: 16),
            _buildLeaveButton(),
          ],
        );
      },
    );
  }

  Widget _buildMemberCard(String uid, String memberRole, String myRole, String createdBy) {
    final isMe     = uid == user?.uid;
    final canManage = _canManage(myRole) && !isMe && memberRole != 'leader';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data     = snap.data!.data() as Map<String, dynamic>? ?? {};
        final name     = data['name']    ?? 'Jogador';
        final pontos   = (data['pontos'] ?? 0) as int;
        final nivel    = (pontos ~/ 250) + 1;
        final avatarId = data['avatar']  ?? 'default';
        final streak   = (data['streak'] ?? 0) as int;
        final emoji    = _avatarEmoji[avatarId] ?? '👤';
        final color    = _avatarColor[avatarId] ?? _primary;
        final roleColor = _roleColors[memberRole] ?? _primary;

        return GestureDetector(
          onTap: isMe ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberProfilePage(uid: uid))),
          onLongPress: canManage ? () => _showMemberOptions(context, uid, name, memberRole, myRole) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isMe ? _primary.withOpacity(0.3) : const Color(0xFFE5E7EB)),
            ),
            child: Row(children: [
              Stack(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
                if (streak > 0)
                  Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isMe ? '$name (Tu)' : name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isMe ? _primary : _primaryDeep)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('Nível $nivel', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Text('  •  ', style: TextStyle(color: Colors.grey)),
                  Text('$pontos pts', style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ])),
              // Badge de papel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_roleLabels[memberRole]?.split(' ').last ?? 'Membro', style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              if (!isMe) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              ],
            ]),
          ),
        );
      },
    );
  }

  // ── Menu de opções do membro (líder/co-líder) ─────────────────────────────
  void _showMemberOptions(BuildContext context, String uid, String name, String memberRole, String myRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_rounded, color: _primaryDeep, size: 20),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDeep)),
            ]),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: (_roleColors[memberRole] ?? _primary).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_roleLabels[memberRole] ?? '', style: TextStyle(color: _roleColors[memberRole] ?? _primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 20),

            // ── PROMOVER ─────────────────────────────────────────────────
            if (_canPromote(myRole, memberRole))
              _optionTile(ctx, Icons.arrow_upward_rounded, const Color(0xFF7C3AED),
                  'Promover para ${_nextRole(memberRole)}',
                  memberRole == 'member' ? 'Torna-se Ancião' : 'Torna-se Co-Líder (apenas Líderes)',
                  () => _promoteUser(ctx, uid, memberRole)),

            // ── REBAIXAR com aviso de expulsão ────────────────────────────
            if (_canDemote(myRole, memberRole))
              _optionTile(ctx, Icons.arrow_downward_rounded, const Color(0xFFD97706),
                  memberRole == 'elder' ? 'Rebaixar para Membro' : 'Rebaixar para Ancião',
                  memberRole == 'elder' ? 'Se continuar a falhar, pode ser expulso' : 'Reduz o papel deste membro',
                  () => _demoteUser(ctx, uid, memberRole)),

            // ── PROPOR BATALHA ────────────────────────────────────────────
            _optionTile(ctx, Icons.sports_esports_rounded, _primary,
                'Propor Batalha de Quiz', 'Desafia este membro para um quiz!',
                () => _proposeBattle(ctx, uid, name)),

            // ── EXPULSAR ──────────────────────────────────────────────────
            if (_canKick(myRole, memberRole))
              _optionTile(ctx, Icons.person_remove_rounded, const Color(0xFFDC2626),
                  'Expulsar do Clã',
                  memberRole == 'co-leader' ? 'Rebaixa primeiro antes de expulsar' : 'Remove permanentemente',
                  memberRole == 'co-leader' ? null : () => _kickUser(ctx, uid, name)),
          ],
        ),
      ),
    );
  }

  bool _canPromote(String myRole, String memberRole) {
    if (myRole == 'leader') return memberRole != 'co-leader';
    if (myRole == 'co-leader') return memberRole == 'member';
    return false;
  }

  bool _canDemote(String myRole, String memberRole) {
    if (myRole == 'leader') return memberRole != 'member';
    if (myRole == 'co-leader') return memberRole == 'elder';
    return false;
  }

  bool _canKick(String myRole, String memberRole) {
    if (myRole == 'leader') return memberRole != 'co-leader';
    if (myRole == 'co-leader') return memberRole == 'member' || memberRole == 'elder';
    return false;
  }

  String _nextRole(String role) {
    if (role == 'member') return '🔰 Ancião';
    if (role == 'elder')  return '⭐ Co-Líder';
    return '';
  }

  Widget _optionTile(BuildContext ctx, IconData icon, Color color, String title, String subtitle, VoidCallback? onTap) {
    final disabled = onTap == null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(disabled ? 0.05 : 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: disabled ? Colors.grey : color, size: 22)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: disabled ? Colors.grey : color)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      onTap: disabled ? null : () { Navigator.pop(ctx); onTap(); },
    );
  }

  Future<void> _promoteUser(BuildContext context, String uid, String currentRole) async {
    final next = currentRole == 'member' ? 'elder' : 'co-leader';
    await FirebaseFirestore.instance.collection('clans').doc(widget.clanId).update({'roles.$uid': next});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Promovido a ${_roleLabels[next]}!'), backgroundColor: Colors.green));
  }

  Future<void> _demoteUser(BuildContext context, String uid, String currentRole) async {
    final prev = currentRole == 'co-leader' ? 'elder' : 'member';
    await FirebaseFirestore.instance.collection('clans').doc(widget.clanId).update({'roles.$uid': prev});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rebaixado a ${_roleLabels[prev]}!'), backgroundColor: Colors.orange));
  }

  Future<void> _kickUser(BuildContext context, String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Expulsar $name?', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('$name será removido do clã permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx, true), child: const Text('Expulsar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('clans').doc(widget.clanId), {'memberIds': FieldValue.arrayRemove([uid])});
    batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {'clanId': FieldValue.delete()});
    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name foi expulso.'), backgroundColor: Colors.red));
  }

  Future<void> _proposeBattle(BuildContext context, String uid, String name) async {
    // Cria o desafio no Firestore
    await FirebaseFirestore.instance.collection('clan_battles').add({
      'from'     : user?.uid,
      'fromName' : 'Eu',
      'to'       : uid,
      'toName'   : name,
      'clanId'   : widget.clanId,
      'status'   : 'pending', // pending → accepted → finished
      'tema'     : 'Phishing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Desafio enviado a $name! 🎯'), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildLeaveButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFFEF2F2), foregroundColor: Colors.red,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: Color(0xFFFECACA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Sair do Clã', style: TextStyle(fontWeight: FontWeight.bold)),
      onPressed: () => _leaveClan(context),
    );
  }

  Future<void> _leaveClan(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sair do Clã?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Tens a certeza que queres sair deste clã?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true || user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('users').doc(user!.uid), {'clanId': FieldValue.delete()});
    batch.update(FirebaseFirestore.instance.collection('clans').doc(widget.clanId), {'memberIds': FieldValue.arrayRemove([user!.uid])});
    await batch.commit();
  }

  // ── ABA CHAT ──────────────────────────────────────────────────────────────
  Widget _buildChatTab() {
    return Column(children: [
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clans').doc(widget.clanId).collection('messages').orderBy('timestamp', descending: false).limit(100).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _primary));
            final msgs = snap.data!.docs;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
            });
            if (msgs.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('💬', style: TextStyle(fontSize: 40)), SizedBox(height: 12), Text('Nenhuma mensagem ainda.', style: TextStyle(color: Colors.grey))]));
            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: msgs.length,
              itemBuilder: (context, i) {
                final msg  = msgs[i].data() as Map<String, dynamic>;
                final isMe = msg['uid'] == user?.uid;
                return _buildMessage(msg, isMe);
              },
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
        child: Row(children: [
          Expanded(child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: 'Escrever mensagem...', hintStyle: TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)), onSubmitted: (_) => _sendMessage(), maxLines: null),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(width: 46, height: 46, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildMessage(Map<String, dynamic> msg, bool isMe) {
    final text       = msg['text']       ?? '';
    final senderName = msg['senderName'] ?? 'Jogador';
    final ts         = msg['timestamp']  as Timestamp?;
    final timeStr    = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4, left: 2), child: Text(senderName, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500))),
        Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? _primary : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
            ),
            child: Text(text, style: TextStyle(color: isMe ? Colors.white : _primaryDeep, fontSize: 14)),
          ),
        ]),
        Padding(padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 2, right: isMe ? 2 : 0), child: Text(timeStr, textAlign: isMe ? TextAlign.right : TextAlign.left, style: const TextStyle(color: Colors.grey, fontSize: 10))),
      ]),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || user == null) return;
    _msgCtrl.clear();
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final data = userDoc.data() as Map<String, dynamic>? ?? {};
    final senderName = data['name'] ?? data['nickname'] ?? 'Jogador';
    await FirebaseFirestore.instance.collection('clans').doc(widget.clanId).collection('messages').add({
      'text': text, 'uid': user!.uid, 'senderName': senderName, 'timestamp': FieldValue.serverTimestamp(),
    });
  }
}