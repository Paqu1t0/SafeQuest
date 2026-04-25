import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class NotificationService {
  static Future<void> send({
    required String toUid,
    required String title,
    required String body,
    required String type, 
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .add({
      'title'    : title,
      'body'     : body,
      'type'     : type,
      'read'     : false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markAllRead(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications')
        .where('read', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // Só notificações de clã, batalhas e amigos (exclui automáticas quiz_reminder)
  static const _allowedTypes = [
    'friend_added',
    'clan_promoted',
    'clan_demoted',
    'clan_kicked',
    'clan_battle',
  ];

  static Stream<QuerySnapshot> stream(String uid) {
    // Sem orderBy para não precisar de índice composto no Firestore.
    // A ordenação é feita no widget (sort por createdAt descendente).
    return FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications')
        .where('type', whereIn: _allowedTypes)
        .limit(30)
        .snapshots();
  }

  /// Contagem de não lidas — apenas notificações de clã/batalhas
  static Stream<QuerySnapshot> unreadStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications')
        .where('type', whereIn: _allowedTypes)
        .where('read', isEqualTo: false)
        .snapshots();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS OVERLAY — Dialog central com lista de notificações
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsDialog extends StatelessWidget {
  final String uid;
  const NotificationsDialog({super.key, required this.uid});

  static const _typeIcon = {
    'friend_added'  : ('👥', Color(0xFF16A34A)),
    'clan_promoted' : ('⬆️', Color(0xFF7C3AED)),
    'clan_demoted'  : ('⬇️', Color(0xFFD97706)),
    'clan_kicked'   : ('🚫', Color(0xFFDC2626)),
    'quiz_reminder' : ('🎯', Color(0xFF1A56DB)),
    'clan_battle'   : ('⚔️', Color(0xFFEA580C)),
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1A56DB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(children: [
                const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(child: Text('Notificações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
                GestureDetector(
                  onTap: () async {
                    await NotificationService.markAllRead(uid);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Lidas', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 22)),
              ]),
            ),

            // Lista
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: NotificationService.stream(uid),
                builder: (context, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('🔔', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text('Sem notificações', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ]),
                    );
                  }

                  final rawDocs = snap.data!.docs;
                  // Ordena no cliente por createdAt (desc) — evita índice composto Firestore
                  final docs = [...rawDocs]..sort((a, b) {
                    final aTs = (a.data() as Map<String, dynamic>)['createdAt'];
                    final bTs = (b.data() as Map<String, dynamic>)['createdAt'];
                    if (aTs == null) return 1;
                    if (bTs == null) return -1;
                    return (bTs as dynamic).compareTo(aTs as dynamic);
                  });

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc   = docs[i];
                      final data  = doc.data() as Map<String, dynamic>;
                      final title = data['title'] ?? '';
                      final body  = data['body']  ?? '';
                      final type  = data['type']  ?? 'quiz_reminder';
                      final read  = data['read']  == true;

                      final iconData = _typeIcon[type] ?? ('🔔', const Color(0xFF1A56DB));
                      final bgColor  = read ? Colors.white : iconData.$2.withOpacity(0.05);

                      Future<void> deleteDoc() async {
                        await FirebaseFirestore.instance
                            .collection('users').doc(uid)
                            .collection('notifications').doc(doc.id)
                            .delete();
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          Dismissible(
                            key: ValueKey(doc.id),
                            direction: DismissDirection.endToStart,
                            // Fundo vermelho com ícone de lixo ao deslizar para a esquerda
                            background: Container(
                              color: const Color(0xFFDC2626),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                  SizedBox(height: 2),
                                  Text('Apagar', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            onDismissed: (_) => deleteDoc(),
                            child: GestureDetector(
                              // Tap — marca como lida
                              onTap: () async {
                                if (!read) {
                                  await FirebaseFirestore.instance
                                      .collection('users').doc(uid)
                                      .collection('notifications').doc(doc.id)
                                      .update({'read': true});
                                }
                              },
                              // Long press — confirma e apaga
                              onLongPress: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    title: const Text('Apagar notificação?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    content: const Text('Esta notificação será removida permanentemente.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Apagar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) await deleteDoc();
                              },
                              child: Container(
                                color: bgColor,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(color: iconData.$2.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                    child: Center(child: Text(iconData.$1, style: const TextStyle(fontSize: 20))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(title, style: TextStyle(fontWeight: read ? FontWeight.w500 : FontWeight.bold, fontSize: 14, color: const Color(0xFF1E3A8A)))),
                                      if (!read) Container(width: 8, height: 8, decoration: BoxDecoration(color: iconData.$2, shape: BoxShape.circle)),
                                    ]),
                                    const SizedBox(height: 3),
                                    Text(body, style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
                                  ])),
                                  // Indicador visual de swipe
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6, top: 12),
                                    child: Icon(Icons.swipe_left_outlined, color: Color(0xFFE2E8F0), size: 14),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}