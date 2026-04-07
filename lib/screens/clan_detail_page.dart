import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:projeto_safequest/screens/member_profile_page.dart';
import 'package:projeto_safequest/screens/notification_service.dart';
import 'package:projeto_safequest/screens/quiz_screen.dart' show QuizQuestion;

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
  bool _showEmojis  = false; // ← novo

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
    _tabCtrl = TabController(length: 3, vsync: this);
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
            tabs: const [Tab(text: 'Membros'), Tab(text: 'Chat'), Tab(text: '⚔️ Batalhas')],
          ),
        ),
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [_buildMembersTab(myRole, clanData), _buildChatTab(), _buildBattlesTab()],
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
    final isMe       = uid == user?.uid;
    final canManage  = _canManage(myRole) && !isMe && memberRole != 'leader';
    final canBattle  = !isMe; // qualquer membro pode propor batalha

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
          onLongPress: (canManage || canBattle) ? () => _showMemberOptions(context, uid, name, memberRole, myRole) : null,
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

  // ── Envia mensagem de sistema no chat ────────────────────────────────────
  Future<void> _sendSystemMessage(String text) async {
    await FirebaseFirestore.instance
        .collection('clans').doc(widget.clanId).collection('messages').add({
      'text'      : text,
      'uid'       : 'system',
      'senderName': '📢 Sistema',
      'isSystem'  : true,
      'timestamp' : FieldValue.serverTimestamp(),
    });
  }

  Future<void> _promoteUser(BuildContext context, String uid, String currentRole) async {
    final next      = currentRole == 'member' ? 'elder' : 'co-leader';
    final nextLabel = _roleLabels[next] ?? next;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = (snap.data()?['name'] ?? 'Membro') as String;

    await FirebaseFirestore.instance.collection('clans').doc(widget.clanId).update({'roles.$uid': next});
    await _sendSystemMessage('⬆️ $name foi promovido(a) para $nextLabel');

    // Notificação para o utilizador promovido
    await NotificationService.send(
      toUid  : uid,
      title  : '⬆️ Foste promovido(a)!',
      body   : 'Parabéns! Foste promovido(a) para $nextLabel no clã. Continua o excelente trabalho! 🎉',
      type   : 'clan_promoted',
    );

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name promovido(a) para $nextLabel!'), backgroundColor: Colors.green));
  }

  Future<void> _demoteUser(BuildContext context, String uid, String currentRole) async {
    final prev       = currentRole == 'co-leader' ? 'elder' : 'member';
    final prevLabel  = _roleLabels[prev] ?? prev;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = (snap.data()?['name'] ?? 'Membro') as String;

    await FirebaseFirestore.instance.collection('clans').doc(widget.clanId).update({'roles.$uid': prev});
    await _sendSystemMessage('⬇️ $name foi rebaixado(a) para $prevLabel');

    await NotificationService.send(
      toUid  : uid,
      title  : '⬇️ O teu papel no clã mudou',
      body   : 'Foste rebaixado(a) para $prevLabel. Volta a subir completando mais quizzes e contribuindo para o clã!',
      type   : 'clan_demoted',
    );

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name rebaixado(a) para $prevLabel'), backgroundColor: Colors.orange));
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

    await _sendSystemMessage('🚫 $name foi expulso(a) do clã.');

    // Notificação para o utilizador expulso
    await NotificationService.send(
      toUid  : uid,
      title  : '🚫 Foste expulso(a) do clã',
      body   : 'O líder removeu-te do clã. Podes juntar-te a outro clã ou criar o teu próprio!',
      type   : 'clan_kicked',
    );

    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('clans').doc(widget.clanId), {'memberIds': FieldValue.arrayRemove([uid])});
    batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {'clanId': FieldValue.delete()});
    await batch.commit();

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name foi expulso.'), backgroundColor: Colors.red));
  }

  Future<void> _proposeBattle(BuildContext context, String uid, String name) async {
    // Qualquer membro pode propor batalha aberta
    final temas = ['Phishing', 'Palavras-passe', 'Redes Sociais', 'Segurança Web'];
    String? tema;

    tema = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚔️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text('Propor Batalha de Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 4),
            const Text('Qualquer membro pode aceitar!', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            ...temas.map((t) => ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              onTap: () => Navigator.pop(ctx, t),
            )).toList(),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ]),
        ),
      ),
    );

    if (tema == null) return;

    final myDoc  = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    final myName = (myDoc.data()?['name'] ?? 'Desafiante') as String;

    // Batalha aberta — sem "to" específico, qualquer um pode aceitar
    final battleRef = await FirebaseFirestore.instance.collection('clan_battles').add({
      'from'      : user?.uid,
      'fromName'  : myName,
      'to'        : null,    // aberta a qualquer membro
      'toName'    : null,
      'clanId'    : widget.clanId,
      'status'    : 'open',  // open → in_progress → finished
      'tema'      : tema,
      'fromScore' : null,
      'toScore'   : null,
      'createdAt' : FieldValue.serverTimestamp(),
    });

    // Mensagem visual no chat
    await _sendSystemMessage('⚔️ $myName lançou um desafio de Quiz sobre "$tema"!\n🎯 Vai à aba Batalhas para aceitar!');

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Desafio lançado sobre $tema! ⚔️'), backgroundColor: const Color(0xFFEA580C)),
    );
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
      // Input + emojis
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Emoji picker ─────────────────────────────────────────────
            if (_showEmojis) _buildEmojiPicker(),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            // ── Input row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              child: Row(children: [
                // Botão emoji
                GestureDetector(
                  onTap: () => setState(() => _showEmojis = !_showEmojis),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _showEmojis ? _primary.withOpacity(0.1) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _showEmojis ? _primary.withOpacity(0.3) : const Color(0xFFE5E7EB)),
                    ),
                    child: Center(child: Text(_showEmojis ? '⌨️' : '😊', style: const TextStyle(fontSize: 18))),
                  ),
                ),
                const SizedBox(width: 8),
                // Campo de texto
                Expanded(child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escrever mensagem...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) { _sendMessage(); setState(() => _showEmojis = false); },
                    maxLines: null,
                  ),
                )),
                const SizedBox(width: 8),
                // Botão enviar
                GestureDetector(
                  onTap: () { _sendMessage(); setState(() => _showEmojis = false); },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }

  // ── Emoji picker ──────────────────────────────────────────────────────────
  Widget _buildEmojiPicker() {
    // Categorias de emojis
    final categories = {
      '😊 Caras'    : ['😀','😂','😅','😍','🥰','😎','🤩','😜','🤔','😢','😭','😡','🤯','🥳','🤗','😴','🫡','🤝','👏','🙏'],
      '🎮 Jogo'     : ['🏆','⚔️','🛡️','🎯','🎮','🃏','🎲','🏅','🥇','💪','🔥','⚡','💎','🚀','🌟','✨','💡','🎓','🦾','🏆'],
      '👍 Reações'  : ['👍','👎','❤️','💙','💚','💛','🧡','💜','🖤','💯','✅','❌','⭐','🔑','🎉','🎊','🫶','💪','🙌','👊'],
      '🌍 Outros'   : ['🌍','🌊','🔒','💻','📱','📊','🧩','🎵','🌈','🍕','☕','🌙','☀️','❄️','🌺','🦊','🐱','🐼','🦁','🐉'],
    };

    return DefaultTabController(
      length: categories.length,
      child: Container(
        height: 220,
        color: Colors.white,
        child: Column(
          children: [
            // Tab por categoria
            TabBar(
              isScrollable: true,
              indicatorColor: _primary,
              labelColor: _primary,
              unselectedLabelColor: Colors.grey,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 12),
              tabs: categories.keys.map((k) => Tab(text: k)).toList(),
            ),
            // Grid de emojis
            Expanded(
              child: TabBarView(
                children: categories.values.map((emojis) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8, mainAxisSpacing: 4, crossAxisSpacing: 4,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () {
                        final pos = _msgCtrl.selection.baseOffset;
                        final text = _msgCtrl.text;
                        final newText = pos >= 0
                            ? text.substring(0, pos) + emojis[i] + text.substring(pos)
                            : text + emojis[i];
                        _msgCtrl.text = newText;
                        _msgCtrl.selection = TextSelection.collapsed(offset: pos >= 0 ? pos + emojis[i].length : newText.length);
                      },
                      child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 22))),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, bool isMe) {
    final text       = msg['text']       ?? '';
    final senderName = msg['senderName'] ?? 'Jogador';
    final ts         = msg['timestamp']  as Timestamp?;
    final timeStr    = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';
    final isSystem   = msg['isSystem']   == true;

    // ── Mensagem de sistema ────────────────────────────────────────────────
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    // ── Mensagem normal ────────────────────────────────────────────────────
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

  // ── ABA BATALHAS ──────────────────────────────────────────────────────────
  Widget _buildBattlesTab() {
    return Column(
      children: [
        // Botão criar batalha (qualquer membro pode)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Lançar Desafio ⚔️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => _proposeBattle(context, '', ''),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clan_battles')
                .where('clanId', isEqualTo: widget.clanId)
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _primary));
              final battles = snap.data!.docs;

              if (battles.isEmpty) {
                return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('⚔️', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 16),
                  Text('Sem batalhas ainda!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDeep)),
                  SizedBox(height: 8),
                  Text('Lança um desafio acima!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ]));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: battles.length,
                itemBuilder: (context, i) => _buildBattleCard(battles[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBattleCard(QueryDocumentSnapshot doc) {
    final data      = doc.data() as Map<String, dynamic>;
    final from      = data['from']        as String? ?? '';
    final fromName  = data['fromName']    as String? ?? 'Desafiante';
    final toName    = data['toName']      as String?;
    final tema      = data['tema']        as String? ?? 'Phishing';
    final status    = data['status']      as String? ?? 'open';
    final fromScore = data['fromScore']   as int?;
    final toScore   = data['toScore']     as int?;
    final isFrom    = from == user?.uid;
    final isOpen    = status == 'open';
    final bothDone  = fromScore != null && toScore != null;
    final canJoin   = isOpen && !isFrom; // outro membro pode aceitar
    final canPlay   = isFrom && fromScore == null && !isOpen;

    // Para batalhas abertas — quem jogou
    final challenger = fromName;
    final opponent   = toName ?? '???';

    // Vencedor
    String? winner;
    if (bothDone) {
      if (fromScore! > toScore!) winner = fromName;
      else if (toScore! > fromScore!) winner = opponent;
      else winner = 'Empate!';
    }

    final statusColor = bothDone ? const Color(0xFF16A34A)
        : isOpen ? const Color(0xFFEA580C)
        : const Color(0xFFD97706);
    final statusLabel = bothDone ? '✅ Concluída'
        : isOpen ? '🔥 Aberta — entra já!'
        : fromScore == null ? '⏳ À espera do desafiante'
        : '⌛ Aguarda o oponente';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isOpen ? const Color(0xFFEA580C).withOpacity(0.4) : const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header colorido
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            const Text('⚔️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$challenger vs ${isOpen ? "???" : opponent}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryDeep)),
              Text('Tema: $tema', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // Scores (se existirem)
            if (fromScore != null || toScore != null) ...[
              Row(children: [
                Expanded(child: _scoreBox(challenger, fromScore, winner == challenger)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(child: _scoreBox(isOpen ? '???' : opponent, toScore, winner == opponent)),
              ]),
              const SizedBox(height: 10),
            ],

            // Vencedor
            if (winner != null) Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: winner == 'Empate!' ? const Color(0xFFF1F5F9) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                winner == 'Empate!' ? '🤝 Empate!' : '🏆 $winner venceu!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: winner == 'Empate!' ? Colors.grey : const Color(0xFF16A34A), fontSize: 14),
              ),
            ),

            // Botão aceitar batalha aberta
            if (canJoin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                  ),
                  icon: const Icon(Icons.sports_esports_rounded, size: 18),
                  label: const Text('Aceitar e Jogar!', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _acceptAndPlay(doc.id, tema, fromName),
                ),
              ),
            ],

            // Botão jogar (se és o desafiante e ainda não jogaste)
            if (isFrom && fromScore == null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Jogar o meu turno', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _startBattle(doc.id, tema, true),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Aceita batalha aberta e joga de imediato ──────────────────────────────
  Future<void> _acceptAndPlay(String battleId, String tema, String fromName) async {
    final myDoc  = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    final myName = (myDoc.data()?['name'] ?? 'Oponente') as String;

    // Regista o aceitante
    await FirebaseFirestore.instance.collection('clan_battles').doc(battleId).update({
      'to'    : user?.uid,
      'toName': myName,
      'status': 'in_progress',
    });

    await _sendSystemMessage('⚔️ $myName aceitou o desafio de $fromName sobre "$tema"!');

    // Joga de imediato
    if (mounted) _startBattle(battleId, tema, false);
  }

  Widget _scoreBox(String name, int? score, bool isWinner) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isWinner ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isWinner ? const Color(0xFF16A34A).withOpacity(0.4) : const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: _primaryDeep), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(
          score != null ? '$score pts' : '–',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isWinner ? const Color(0xFF16A34A) : Colors.grey),
        ),
        if (isWinner) const Text('🏆', style: TextStyle(fontSize: 14)),
      ]),
    );
  }

  // ── Inicia a batalha de quiz ───────────────────────────────────────────────
  Future<void> _startBattle(String battleId, String tema, bool isFrom) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => BattleQuizScreen(tema: tema)),
    );

    if (result == null || !mounted) return;
    final score = result['points'] as int;
    final field = isFrom ? 'fromScore' : 'toScore';

    await FirebaseFirestore.instance.collection('clan_battles').doc(battleId)
        .update({field: score});

    // Verifica se ambos já jogaram
    final snap = await FirebaseFirestore.instance.collection('clan_battles').doc(battleId).get();
    final data  = snap.data() as Map<String, dynamic>? ?? {};
    final fromS = data['fromScore'] as int?;
    final toS   = data['toScore']   as int?;

    if (fromS != null && toS != null) {
      final fromName = data['fromName'] as String? ?? 'Jogador A';
      final toName   = data['toName']   as String? ?? 'Jogador B';
      await FirebaseFirestore.instance.collection('clan_battles').doc(battleId)
          .update({'status': 'finished'});

      String resultMsg;
      if (fromS > toS)       resultMsg = '🏆 $fromName venceu a batalha!\n$fromName: $fromS pts · $toName: $toS pts';
      else if (toS > fromS)  resultMsg = '🏆 $toName venceu a batalha!\n$toName: $toS pts · $fromName: $fromS pts';
      else                   resultMsg = '🤝 Empate na batalha de $tema!\n$fromS pts cada';

      await _sendSystemMessage(resultMsg);
    } else {
      // Um já jogou, aguarda o outro
      final myDoc  = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      final myName = (myDoc.data()?['name'] ?? 'Jogador') as String;
      await _sendSystemMessage('✅ $myName completou o seu turno ($score pts). À espera do oponente...');
    }
  }
} // fim de _ClanDetailPageState

// ─────────────────────────────────────────────────────────────────────────────
// BATTLE QUIZ SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BattleQuizScreen extends StatefulWidget {
  final String tema;
  const BattleQuizScreen({super.key, required this.tema});

  @override
  State<BattleQuizScreen> createState() => _BattleQuizScreenState();
}

class _BattleQuizScreenState extends State<BattleQuizScreen> {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  // 5 perguntas por tema (reutiliza o banco do quiz_screen via mapa local)
  static const Map<String, List<Map<String, dynamic>>> _bank = {
    'Phishing': [
      {'q': 'Qual é o sinal mais comum de phishing?', 'opts': ['Linguagem urgente','Formatação profissional','Logotipo real','Ortografia correta'], 'c': 0},
      {'q': 'O que é "spear phishing"?', 'opts': ['Phishing em massa','Ataque direcionado','Phishing por SMS','Um vírus'], 'c': 1},
      {'q': 'O que deves fazer com links suspeitos?', 'opts': ['Clicar para verificar','Encaminhar','Não clicar e reportar','Responder'], 'c': 2},
      {'q': 'Bancos pedem a senha completa por email?', 'opts': ['Sempre','Às vezes','Nunca','Só em emergências'], 'c': 2},
      {'q': 'O que é "vishing"?', 'opts': ['Phishing por email','Phishing por chamada','Phishing por SMS','Phishing social'], 'c': 1},
    ],
    'Palavras-passe': [
      {'q': 'Qual é uma boa prática de senha?', 'opts': ['Usar nome e data','≥12 chars com símbolos','Mesma em todos os sites','Fácil de lembrar'], 'c': 1},
      {'q': 'O que é autenticação 2FA?', 'opts': ['Duas senhas','2º método além da senha','Login em 2 devices','Duas contas'], 'c': 1},
      {'q': 'Qual senha é mais segura?', 'opts': ['password123','joao1990','Tr0ub4dor&3!','qwerty'], 'c': 2},
      {'q': 'O que é brute force?', 'opts': ['Tentativa de todas as combinações','Enganar o utilizador','Injetar código','Intercetar comunicações'], 'c': 0},
      {'q': 'Devo partilhar a minha senha com colegas?', 'opts': ['Sim','Apenas de confiança','Nunca','Às vezes'], 'c': 2},
    ],
    'Redes Sociais': [
      {'q': 'Melhor prática de privacidade nas redes?', 'opts': ['Partilhar tudo','Limitar visibilidade','Aceitar todos','Usar nome real'], 'c': 1},
      {'q': 'O que é "catfishing"?', 'opts': ['Pesca online','Perfil falso para enganar','Partilhar fotos','Malware'], 'c': 1},
      {'q': 'O que é "doxxing"?', 'opts': ['Partilhar docs online','Publicar dados privados','Documentação','Formato de ficheiro'], 'c': 1},
      {'q': 'Wi-Fi público é seguro para redes sociais?', 'opts': ['Sim','Com VPN','Não, credenciais podem ser roubadas','Apenas em cafés'], 'c': 2},
      {'q': 'O que devo evitar partilhar online?', 'opts': ['Fotos de paisagens','Localização em tempo real','Artigos de notícias','Receitas'], 'c': 1},
    ],
    'Segurança Web': [
      {'q': 'O que significa HTTPS?', 'opts': ['Site gratuito','Ligação encriptada','Site popular','Sem vírus'], 'c': 1},
      {'q': 'O que é Man-in-the-Middle?', 'opts': ['Jogo online','Interceção de comunicações','Tipo de firewall','Encriptação'], 'c': 1},
      {'q': 'O que é SQL Injection?', 'opts': ['Injetar código numa BD','Vacina digital','Encriptação','Otimização'], 'c': 0},
      {'q': 'Melhor prática em Wi-Fi público?', 'opts': ['Usar internet banking','Partilhar ficheiros','Usar VPN','Desativar antivírus'], 'c': 2},
      {'q': 'O que é XSS?', 'opts': ['Tipo de cookie','Injeção de scripts em websites','Protocolo seguro','Encriptação'], 'c': 1},
    ],
  };

  late List<Map<String, dynamic>> _questions;
  int  _idx           = 0;
  int? _selected;
  bool _answered      = false;
  int  _correct       = 0;

  @override
  void initState() {
    super.initState();
    final bank = List<Map<String, dynamic>>.from(_bank[widget.tema] ?? _bank['Phishing']!);
    bank.shuffle();
    _questions = bank.take(5).toList();
  }

  void _answer(int index) {
    if (_answered) return;
    setState(() {
      _selected = index;
      _answered = true;
      if (index == _questions[_idx]['c']) _correct++;
    });
  }

  void _next() {
    if (_idx < _questions.length - 1) {
      setState(() { _idx++; _selected = null; _answered = false; });
    } else {
      // Retorna os pontos: 20 pts por resposta certa
      final points = _correct * 20;
      Navigator.pop(context, {'points': points, 'correct': _correct, 'total': _questions.length});
    }
  }

  @override
  Widget build(BuildContext context) {
    final q         = _questions[_idx];
    final opts      = List<String>.from(q['opts'] as List);
    final correctIdx = q['c'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEA580C), elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          const Text('⚔️ Batalha de Quiz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(widget.tema, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        centerTitle: true,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 14), child: Center(
            child: Text('${_idx + 1}/${_questions.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
        ],
      ),
      body: Column(children: [
        // Barra progresso
        LinearProgressIndicator(
          value: (_idx + 1) / _questions.length,
          backgroundColor: Colors.white24,
          color: const Color(0xFFEA580C),
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Score atual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFEA580C).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⚔️'), const SizedBox(width: 6),
                  Text('$_correct acertos · ${_correct * 20} pts', style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 20),

              // Pergunta
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
                child: Text(q['q'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _primaryDeep, height: 1.5)),
              ),
              const SizedBox(height: 20),

              // Opções
              ...List.generate(opts.length, (i) {
                Color bg  = Colors.white;
                Color bdr = const Color(0xFFE5E7EB);
                if (_answered) {
                  if (i == correctIdx) { bg = const Color(0xFFF0FDF4); bdr = const Color(0xFF16A34A); }
                  else if (i == _selected) { bg = const Color(0xFFFEF2F2); bdr = const Color(0xFFDC2626); }
                }
                return GestureDetector(
                  onTap: () => _answer(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: bdr, width: 1.5)),
                    child: Row(children: [
                      if (_answered && i == correctIdx) const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                      else if (_answered && i == _selected) const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20)
                      else Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 2))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(opts[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _primaryDeep))),
                    ]),
                  ),
                );
              }),

              const SizedBox(height: 20),
              if (_answered) SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                  ),
                  onPressed: _next,
                  child: Text(_idx < _questions.length - 1 ? 'Próxima →' : 'Ver Resultado 🏆',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}