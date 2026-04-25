import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DAILY MISSIONS SERVICE
// Firestore: users/{uid}/daily_missions/{YYYY-MM-DD}
//   { quizzesDone, perfectDone, temasDone[], moedas_claimed, date }
// ─────────────────────────────────────────────────────────────────────────────

class DailyMission {
  final String id;
  final String icon;
  final String title;
  final String description;
  final int    target;
  final int    rewardMoedas;

  const DailyMission({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.target,
    required this.rewardMoedas,
  });
}

// Missões fixas diárias — top-level para ser acessível por todos os widgets
const _missions = [
  DailyMission(id: 'quizzes3',  icon: '🎯', title: 'Triathlo do Saber',   description: 'Faz 3 quizzes hoje',             target: 3,  rewardMoedas: 80),
  DailyMission(id: 'perfect1',  icon: '⭐', title: 'Perfecionista',        description: 'Termina 1 quiz com 100%',         target: 1,  rewardMoedas: 120),
  DailyMission(id: 'temas2',    icon: '🌐', title: 'Explorador',           description: 'Joga em 2 temas diferentes hoje', target: 2,  rewardMoedas: 60),
  DailyMission(id: 'quizzes5',  icon: '🔥', title: 'Máquina de Quizzes',  description: 'Faz 5 quizzes hoje',             target: 5,  rewardMoedas: 200),
];

class DailyMissionsService {
  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  /// Chamado após cada quiz para atualizar progresso
  static Future<void> recordQuiz({
    required DocumentReference userRef,
    required int percent,
    required String tema,
    required String tipoQuiz,
  }) async {
    final key     = todayKey();
    final docRef  = userRef.collection('daily_missions').doc(key);
    final snap    = await docRef.get();

    final data    = snap.exists ? snap.data() as Map<String, dynamic>? ?? {} : {};
    final quizzes = (data['quizzesDone'] ?? 0) as int;
    final perfect = (data['perfectDone'] ?? 0) as int;
    final temas   = List<String>.from(data['temasDone'] ?? []);
    final claimed = List<String>.from(data['claimed']   ?? []);

    if (!temas.contains(tema)) temas.add(tema);

    await docRef.set({
      'date'        : key,
      'quizzesDone' : quizzes + 1,
      'perfectDone' : percent == 100 ? perfect + 1 : perfect,
      'temasDone'   : temas,
      'claimed'     : claimed,
    }, SetOptions(merge: true));
  }

  /// Verifica se uma missão foi completada
  static bool isMissionComplete(DailyMission mission, Map<String, dynamic> data) {
    switch (mission.id) {
      case 'quizzes3': return (data['quizzesDone'] ?? 0) >= 3;
      case 'quizzes5': return (data['quizzesDone'] ?? 0) >= 5;
      case 'perfect1': return (data['perfectDone'] ?? 0) >= 1;
      case 'temas2':   return ((data['temasDone'] as List?)?.length ?? 0) >= 2;
      default: return false;
    }
  }

  /// Progresso de uma missão (0.0 – 1.0)
  static double missionProgress(DailyMission mission, Map<String, dynamic> data) {
    switch (mission.id) {
      case 'quizzes3': return ((data['quizzesDone'] ?? 0) as int).clamp(0, 3) / 3.0;
      case 'quizzes5': return ((data['quizzesDone'] ?? 0) as int).clamp(0, 5) / 5.0;
      case 'perfect1': return ((data['perfectDone'] ?? 0) as int).clamp(0, 1).toDouble();
      case 'temas2':   return (((data['temasDone'] as List?)?.length ?? 0) as int).clamp(0, 2) / 2.0;
      default: return 0;
    }
  }

  static int progressValue(DailyMission mission, Map<String, dynamic> data) {
    switch (mission.id) {
      case 'quizzes3': return ((data['quizzesDone'] ?? 0) as int).clamp(0, 3);
      case 'quizzes5': return ((data['quizzesDone'] ?? 0) as int).clamp(0, 5);
      case 'perfect1': return ((data['perfectDone'] ?? 0) as int).clamp(0, 1);
      case 'temas2':   return (((data['temasDone'] as List?)?.length ?? 0)).clamp(0, 2);
      default: return 0;
    }
  }

  /// Recolhe a recompensa
  static Future<void> claimReward(String uid, String missionId, int moedas) async {
    final key    = todayKey();
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_missions').doc(key);
    await docRef.update({'claimed': FieldValue.arrayUnion([missionId])});
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'moedas': FieldValue.increment(moedas)});
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY MISSIONS WIDGET — para incluir na home_page
// ─────────────────────────────────────────────────────────────────────────────

class DailyMissionsWidget extends StatefulWidget {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  const DailyMissionsWidget({super.key});

  @override
  State<DailyMissionsWidget> createState() => _DailyMissionsWidgetState();
}

class _DailyMissionsWidgetState extends State<DailyMissionsWidget>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double>   _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final key = DailyMissionsService.todayKey();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('daily_missions').doc(key)
          .snapshots(),
      builder: (context, snap) {
        final data    = (snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String,dynamic>? 
            : null) ?? <String,dynamic>{};
        final claimed          = List<String>.from(data['claimed'] ?? []);
        final completedCount   = _missions.where((m) => DailyMissionsService.isMissionComplete(m, data)).length;
        final claimableCount   = _missions.where((m) =>
            DailyMissionsService.isMissionComplete(m, data) && !claimed.contains(m.id)).length;
        final allDone          = completedCount == _missions.length && claimableCount == 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: claimableCount > 0
                  ? DailyMissionsWidget._gold.withOpacity(0.5)
                  : const Color(0xFFE5E7EB),
              width: claimableCount > 0 ? 1.5 : 1,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              // ── Header clicável ──────────────────────────────────────────
              GestureDetector(
                onTap: _toggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    // Ícone com animação de "por receber"
                    Stack(children: [
                      const Text('📋', style: TextStyle(fontSize: 20)),
                      if (claimableCount > 0) Positioned(
                        top: -2, right: -4,
                        child: Container(
                          width: 14, height: 14,
                          decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                          child: Center(child: Text('$claimableCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Missões Diárias', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DailyMissionsWidget._primaryDeep)),
                      Text(
                        claimableCount > 0
                            ? '$claimableCount recompensa${claimableCount > 1 ? 's' : ''} por receber! 🎁'
                            : allDone
                                ? 'Todas completas! ✅'
                                : '$completedCount/${_missions.length} concluídas',
                        style: TextStyle(
                          fontSize: 11,
                          color: claimableCount > 0 ? const Color(0xFFEA580C) : Colors.grey,
                          fontWeight: claimableCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ])),
                    // Progresso circular compacto
                    _CompactProgress(completed: completedCount, total: _missions.length),
                    const SizedBox(width: 10),
                    const _MidnightCountdown(),
                    const SizedBox(width: 6),
                    // Seta animada
                    RotationTransition(
                      turns: _rotate,
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 22),
                    ),
                  ]),
                ),
              ),

              // ── Conteúdo expansível ──────────────────────────────────────
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: Column(children: [
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    ..._missions.map((m) => _MissionCard(mission: m, data: data, uid: uid, claimed: claimed)),
                  ]),
                ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        );
      },
    );
  }
}

// Progresso circular mini
class _CompactProgress extends StatelessWidget {
  final int completed;
  final int total;
  const _CompactProgress({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : completed / total;
    return SizedBox(
      width: 36, height: 36,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: frac, strokeWidth: 3,
          backgroundColor: const Color(0xFFE5E7EB),
          color: frac == 1.0 ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
        ),
        Text('$completed/$total', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
      ]),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final DailyMission           mission;
  final Map<String, dynamic>   data;
  final String                 uid;
  final List<String>           claimed;

  static const _gold = Color(0xFFF59E0B);
  static const _primary = Color(0xFF1A56DB);

  const _MissionCard({required this.mission, required this.data, required this.uid, required this.claimed});

  @override
  Widget build(BuildContext context) {
    final isComplete  = DailyMissionsService.isMissionComplete(mission, data);
    final isClaimed   = claimed.contains(mission.id);
    final progress    = DailyMissionsService.missionProgress(mission, data);
    final current     = DailyMissionsService.progressValue(mission, data);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimed ? const Color(0xFFD1FAE5) : isComplete ? _gold.withOpacity(0.5) : const Color(0xFFE5E7EB),
          width: isComplete && !isClaimed ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Ícone com estado
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isClaimed ? const Color(0xFFF0FDF4) : isComplete ? _gold.withOpacity(0.15) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(isClaimed ? '✅' : mission.icon, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),

        // Conteúdo
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(mission.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isClaimed ? Colors.grey : const Color(0xFF1E3A8A)))),
            // Recompensa
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🪙', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 2),
                Text('+${mission.rewardMoedas}', style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 11)),
              ]),
            ),
          ]),
          const SizedBox(height: 3),
          Text(mission.description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),

          // Barra de progresso
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => LinearProgressIndicator(
                    value: val, minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: isClaimed ? const Color(0xFF16A34A) : isComplete ? _gold : _primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$current/${mission.target}', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ])),

        // Botão reclamar (se completo e não reclamado)
        if (isComplete && !isClaimed) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              await DailyMissionsService.claimReward(uid, mission.id, mission.rewardMoedas);
              if (context.mounted) {
                _showPremiumRewardDialog(context, mission);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _gold, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Text('Receber!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],

        // Tick se já reclamado
        if (isClaimed) ...[
          const SizedBox(width: 10),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
        ],
      ]),
    );
  }
  void _showPremiumRewardDialog(BuildContext context, DailyMission mission) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text(
                    'Missão Cumprida!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mission.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        Text(
                          '+${mission.rewardMoedas}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF78350F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Incrível!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut).value,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }
}

// Countdown até meia noite
class _MidnightCountdown extends StatefulWidget {
  const _MidnightCountdown();
  @override
  State<_MidnightCountdown> createState() => _MidnightCountdownState();
}

class _MidnightCountdownState extends State<_MidnightCountdown> {
  late String _timeLeft;

  @override
  void initState() {
    super.initState();
    _update();
    // Atualiza a cada minuto
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));
      if (mounted) setState(_update);
      return mounted;
    });
  }

  void _update() {
    final now      = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff     = midnight.difference(now);
    final h        = diff.inHours;
    final m        = diff.inMinutes % 60;
    _timeLeft      = '${h}h ${m.toString().padLeft(2,'0')}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.access_time_rounded, size: 10, color: Colors.grey),
        const SizedBox(width: 3),
        Text(_timeLeft, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
