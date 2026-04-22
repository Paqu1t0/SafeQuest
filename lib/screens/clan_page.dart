import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/screens/clan_detail_page.dart';

class ClanPage extends StatefulWidget {
  const ClanPage({super.key});
  @override
  State<ClanPage> createState() => _ClanPageState();
}

class _ClanPageState extends State<ClanPage> {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _gold        = Color(0xFFF59E0B);

  final _searchCtrl  = TextEditingController();
  String _search     = '';
  final user         = FirebaseAuth.instance.currentUser;

  // ── Filtros ───────────────────────────────────────────────────────────────
  String _sortBy      = 'points';   // 'points' | 'members' | 'name'
  int    _minMembers  = 0;
  int    _maxMembers  = 999;
  int    _minPoints   = 0;
  bool   _onlyOpen    = false;      // só clãs com espaço

  static const _clanIcons = [
    '🛡️','⚔️','🔒','💻','🦅','🐉','🦁','🔥','⭐','🏆',
    '🎯','🚀','💎','🌐','🤝','👑','🦊','🐼','🌟','⚡',
    '🎓','🔐','🦄','🗡️',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Clãs', style: TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, userSnap) {
          int    userPontos = 0;
          String? myClanId;

          if (userSnap.hasData && userSnap.data!.exists) {
            final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
            myClanId   = data['clanId'] as String?;
            userPontos = (data['pontos'] ?? 0) as int;
          }

          // Se já pertence a um clã → mostra detalhe
          if (myClanId != null && myClanId.isNotEmpty) {
            return ClanDetailPage(clanId: myClanId, embedded: true);
          }

          return _buildClanList(userPontos);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LISTA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildClanList(int userPontos) {
    return Column(
      children: [
        // Banner
        _buildBanner(),

        // Barra pesquisa + botão filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Procurar clãs...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Botão filtros
              GestureDetector(
                onTap: () => _showFilterSheet(context),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _hasActiveFilters ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _hasActiveFilters ? _primary : const Color(0xFFE5E7EB)),
                  ),
                  child: Icon(Icons.tune_rounded, color: _hasActiveFilters ? Colors.white : _primary, size: 22),
                ),
              ),
            ],
          ),
        ),

        // Chips de filtros ativos
        if (_hasActiveFilters) _buildActiveFilterChips(),

        // Lista
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clans').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _primary));
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              // Só mostra clãs criados por utilizadores reais (tem campo createdBy)
              // e não mostra o clã criado pelo próprio utilizador
              var docs = snap.data!.docs.where((d) {
                final data      = d.data() as Map<String, dynamic>;
                final createdBy = data['createdBy'] as String?;
                // Filtra: deve ter createdBy e não ser o utilizador atual
                return createdBy != null && createdBy.isNotEmpty && createdBy != user?.uid;
              }).toList();

              // Aplica pesquisa
              if (_search.isNotEmpty) {
                docs = docs.where((d) => (d['name'] as String? ?? '').toLowerCase().contains(_search)).toList();
              }

              // Aplica filtros
              docs = docs.where((d) {
                final data    = d.data() as Map<String, dynamic>;
                final members = (data['memberIds'] as List?)?.length ?? 0;
                final points  = (data['points'] ?? 0) as num;
                final maxSize = (data['maxSize'] ?? 20) as int;
                if (members < _minMembers) return false;
                if (members > _maxMembers) return false;
                if (points < _minPoints) return false;
                if (_onlyOpen && members >= maxSize) return false;
                return true;
              }).toList();

              // Ordena
              docs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                switch (_sortBy) {
                  case 'members':
                    final mA = (dataA['memberIds'] as List?)?.length ?? 0;
                    final mB = (dataB['memberIds'] as List?)?.length ?? 0;
                    return mB.compareTo(mA);
                  case 'name':
                    return (dataA['name'] ?? '').toString().compareTo((dataB['name'] ?? '').toString());
                  default: // points
                    return ((dataB['points'] ?? 0) as num).compareTo((dataA['points'] ?? 0) as num);
                }
              });

              // Rank baseado na ordenação por pontos (para o badge)
              final sorted = List.of(docs)
                ..sort((a, b) => ((b['points'] ?? 0) as num).compareTo((a['points'] ?? 0) as num));
              final rankMap = {for (int i = 0; i < sorted.length; i++) sorted[i].id: i + 1};

              if (docs.isEmpty) {
                return const Center(child: Text('Nenhum clã encontrado com esses filtros.', style: TextStyle(color: Colors.grey)));
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('${docs.length} clã${docs.length == 1 ? '' : 's'} encontrado${docs.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryDeep)),
                  ),
                  ...docs.map((d) => _buildClanCard(context, d, rankMap[d.id] ?? 99, userPontos)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  bool get _hasActiveFilters =>
      _sortBy != 'points' || _minMembers > 0 || _minPoints > 0 || _onlyOpen || _maxMembers < 999;

  // ── Banner ────────────────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: Colors.white, size: 26)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Clãs SafeQuest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 3),
          Text('Junta-te ou cria o teu próprio clã!', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        GestureDetector(
          onTap: () => _showCreateClanSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Text('+ Criar', style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ]),
    );
  }

  // ── Chips de filtros ativos ───────────────────────────────────────────────
  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (_sortBy != 'points') {
      chips.add(_filterChip('Ordenar: ${_sortBy == 'members' ? 'Membros' : 'Nome'}', () => setState(() => _sortBy = 'points')));
    }
    if (_minMembers > 0) {
      chips.add(_filterChip('Mín. $_minMembers membros', () => setState(() => _minMembers = 0)));
    }
    if (_maxMembers < 999) {
      chips.add(_filterChip('Máx. $_maxMembers membros', () => setState(() => _maxMembers = 999)));
    }
    if (_minPoints > 0) {
      chips.add(_filterChip('≥ $_minPoints pts', () => setState(() => _minPoints = 0)));
    }
    if (_onlyOpen) {
      chips.add(_filterChip('Só abertos', () => setState(() => _onlyOpen = false)));
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        children: chips,
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: _primary.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, color: _primary, size: 14)),
      ]),
    );
  }

  // ── Bottom sheet de filtros ───────────────────────────────────────────────
  void _showFilterSheet(BuildContext context) {
    String  tempSort       = _sortBy;
    int     tempMinM       = _minMembers;
    int     tempMaxM       = _maxMembers == 999 ? 0 : _maxMembers;
    int     tempMinPts     = _minPoints;
    int     tempMaxPts     = 0;
    bool    tempOnlyOpen   = _onlyOpen;

    final minMCtrl  = TextEditingController(text: tempMinM > 0 ? '$tempMinM' : '');
    final maxMCtrl  = TextEditingController(text: tempMaxM > 0 ? '$tempMaxM' : '');
    final minPtsCtrl= TextEditingController(text: tempMinPts > 0 ? '$tempMinPts' : '');
    final maxPtsCtrl= TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + limpar
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Filtrar Clãs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDeep)),
                  TextButton(
                    onPressed: () {
                      setS(() { tempSort = 'points'; tempMinM = 0; tempMaxM = 0; tempMinPts = 0; tempMaxPts = 0; tempOnlyOpen = false; });
                      minMCtrl.clear(); maxMCtrl.clear(); minPtsCtrl.clear(); maxPtsCtrl.clear();
                    },
                    child: const Text('Limpar', style: TextStyle(color: Colors.grey)),
                  ),
                ]),
                const SizedBox(height: 16),

                // Ordenar por
                const Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryDeep)),
                const SizedBox(height: 8),
                Row(children: [
                  _sortChip('Pontos', 'points', tempSort, (v) => setS(() => tempSort = v)),
                  const SizedBox(width: 8),
                  _sortChip('Membros', 'members', tempSort, (v) => setS(() => tempSort = v)),
                  const SizedBox(width: 8),
                  _sortChip('Nome', 'name', tempSort, (v) => setS(() => tempSort = v)),
                ]),
                const SizedBox(height: 16),

                // Membros — campos com setas
                const Text('Nº de Membros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryDeep)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _arrowField(label: 'Mínimo', ctrl: minMCtrl, onChanged: (v) => tempMinM = int.tryParse(v) ?? 0)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–', style: TextStyle(color: Colors.grey, fontSize: 18))),
                  Expanded(child: _arrowField(label: 'Máximo', ctrl: maxMCtrl, onChanged: (v) => tempMaxM = int.tryParse(v) ?? 0)),
                ]),
                const SizedBox(height: 16),

                // Pontos — campos com setas
                const Text('Pontos do Clã', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryDeep)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _arrowField(label: 'Mínimo', ctrl: minPtsCtrl, onChanged: (v) => tempMinPts = int.tryParse(v) ?? 0)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–', style: TextStyle(color: Colors.grey, fontSize: 18))),
                  Expanded(child: _arrowField(label: 'Máximo', ctrl: maxPtsCtrl, onChanged: (v) => tempMaxPts = int.tryParse(v) ?? 0)),
                ]),
                const SizedBox(height: 16),

                // Só abertos
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Só clãs com espaço', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryDeep)),
                  Switch(value: tempOnlyOpen, onChanged: (v) => setS(() => tempOnlyOpen = v), activeColor: _primary),
                ]),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: () {
                      setState(() {
                        _sortBy     = tempSort;
                        _minMembers = tempMinM;
                        _maxMembers = tempMaxM > 0 ? tempMaxM : 999;
                        _minPoints  = tempMinPts;
                        _onlyOpen   = tempOnlyOpen;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Campo com setas para cima/baixo ───────────────────────────────────────
  Widget _arrowField({required String label, required TextEditingController ctrl, required Function(String) onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _primaryDeep),
          ),
        ),
        // Setas cima/baixo
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                final v = (int.tryParse(ctrl.text) ?? 0) + (label.contains('Pont') ? 100 : 1);
                ctrl.text = '$v';
                onChanged('$v');
              },
              child: const Icon(Icons.keyboard_arrow_up_rounded, color: _primary, size: 20),
            ),
            GestureDetector(
              onTap: () {
                final v = ((int.tryParse(ctrl.text) ?? 0) - (label.contains('Pont') ? 100 : 1)).clamp(0, 999999);
                ctrl.text = '$v';
                onChanged('$v');
              },
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary, size: 20),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  Widget _clanStatBox(String icon, String value, String label) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ]),
    ));
  }

  Widget _sortChip(String label, String value, String current, Function(String) onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  // ── Card de clã ───────────────────────────────────────────────────────────
  Widget _buildClanCard(BuildContext context, QueryDocumentSnapshot doc, int rank, int userPontos) {
    final data     = doc.data() as Map<String, dynamic>;
    final name     = data['name']       ?? 'Clã';
    final desc     = data['description']?? '';
    final members  = (data['memberIds'] as List?)?.length ?? 0;
    final maxSize  = (data['maxSize']   ?? 20) as int;
    final points   = (data['points']    ?? 0) as num;
    final icon     = data['icon']       ?? '🛡️';
    final minPts   = (data['minPoints'] ?? 0) as int;
    final canJoin  = userPontos >= minPts && members < maxSize;

    final rankColor = rank == 1 ? const Color(0xFFFBBF24) : rank == 2 ? const Color(0xFF9CA3AF) : rank == 3 ? const Color(0xFFCD7C2F) : const Color(0xFFE5E7EB);
    final rankTextColor = rank <= 3 ? rankColor : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(icon, style: const TextStyle(fontSize: 28)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDeep)),
            if (desc.isNotEmpty) ...[const SizedBox(height: 2), Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)],
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.people_outline, size: 13, color: Colors.grey), const SizedBox(width: 3),
              Text('$members/$maxSize', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 10),
              const Icon(Icons.trending_up_rounded, size: 13, color: Colors.grey), const SizedBox(width: 3),
              Text('${points.toInt()} pts', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (minPts > 0) ...[
                const SizedBox(width: 10),
                const Icon(Icons.lock_outline, size: 13, color: Color(0xFFF59E0B)), const SizedBox(width: 3),
                Text('≥$minPts pts', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: rankColor.withOpacity(rank <= 3 ? 0.15 : 0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.emoji_events_rounded, color: rankTextColor, size: 13),
              const SizedBox(width: 3),
              Text('#$rank', style: TextStyle(color: rankTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: canJoin ? _primary : Colors.grey.shade300,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: Icon(canJoin ? Icons.group_add_rounded : Icons.lock_rounded, size: 18),
            label: Text(
              members >= maxSize ? 'Clã Cheio' : userPontos < minPts ? 'Precisas de $minPts pts' : 'Juntar-se ao Clã',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: canJoin ? () => _joinClan(context, doc.id, name) : null,
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🏰', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 16),
      const Text('Nenhum clã ainda!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryDeep)),
      const SizedBox(height: 8),
      const Text('Sê o primeiro a criar um clã.', style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Criar Clã', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        onPressed: () => _showCreateClanSheet(context),
      ),
    ]));
  }

  Future<void> _joinClan(BuildContext context, String clanId, String clanName) async {
    // Busca dados completos do clã para mostrar no popup
    final clanSnap = await FirebaseFirestore.instance.collection('clans').doc(clanId).get();
    final clanData = clanSnap.data() as Map<String, dynamic>? ?? {};

    final members   = List<String>.from(clanData['memberIds'] ?? []).length;
    final maxSize   = (clanData['maxSize']   ?? 50) as int;
    final minPts    = (clanData['minPoints'] ?? 0) as int;
    final points    = (clanData['points']    ?? 0) as int;
    final icon      = clanData['icon']        ?? '🏰';
    final desc      = clanData['description'] ?? 'Sem descrição.';

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF3B82F6), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Header do clã ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(children: [
                // Ícone grande
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 32))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(clanName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
                GestureDetector(onTap: () => Navigator.pop(ctx, false), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 22)),
              ]),
            ),

            // ── Stats em grid ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _clanStatBox('🏆', '$points', 'Pontos'),
                const SizedBox(width: 10),
                _clanStatBox('👥', '$members/$maxSize', 'Membros'),
                const SizedBox(width: 10),
                _clanStatBox('⭐', '$minPts', 'Mín. Pontos'),
              ]),
            ),

            // Divisor
            Container(height: 1, color: Colors.white.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),

            // ── Texto de confirmação ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: RichText(text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
                children: [
                  const TextSpan(text: 'Ao juntar-te a '),
                  TextSpan(text: clanName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const TextSpan(text: ', os teus pontos de quiz contribuirão para o score do clã e poderás participar em batalhas e desafios de equipa.'),
                ],
              )),
            ),

            // ── Botões ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.group_add_rounded, size: 18),
                    label: const Text('Juntar-se!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );

    if (confirm != true || user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('users').doc(user!.uid), {'clanId': clanId});
    batch.update(FirebaseFirestore.instance.collection('clans').doc(clanId), {'memberIds': FieldValue.arrayUnion([user!.uid])});
    await batch.commit();
  }

  void _showCreateClanSheet(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _CreateClanSheet(clanIcons: _clanIcons, userId: user?.uid ?? ''));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE CLAN SHEET (igual ao anterior)
// ─────────────────────────────────────────────────────────────────────────────
class _CreateClanSheet extends StatefulWidget {
  final List<String> clanIcons;
  final String userId;
  const _CreateClanSheet({required this.clanIcons, required this.userId});
  @override
  State<_CreateClanSheet> createState() => _CreateClanSheetState();
}

class _CreateClanSheetState extends State<_CreateClanSheet> {
  static const _primary = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _selectedIcon = '🛡️';
  int    _maxSize   = 20;
  int    _minPoints = 0;
  bool   _loading   = false;

  static const _pointOptions = [0, 100, 250, 500, 1000, 2000, 5000];
  static const _sizeOptions  = [5, 10, 15, 20, 30, 50];

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          const Text('Criar Clã', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDeep)),
          const SizedBox(height: 4),
          const Text('Personaliza o teu clã', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),

          const Text('Bandeira / Ícone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _primaryDeep)),
          const SizedBox(height: 12),
          Center(child: Container(width: 72, height: 72, decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _primary.withOpacity(0.3), width: 2)), child: Center(child: Text(_selectedIcon, style: const TextStyle(fontSize: 40))))),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: widget.clanIcons.length,
              itemBuilder: (_, i) {
                final ico = widget.clanIcons[i];
                final sel = ico == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = ico),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 150), decoration: BoxDecoration(color: sel ? _primary.withOpacity(0.15) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? _primary : const Color(0xFFE5E7EB), width: sel ? 2 : 1)), child: Center(child: Text(ico, style: const TextStyle(fontSize: 20)))),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          const Text('Nome do Clã *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _primaryDeep)),
          const SizedBox(height: 8),
          TextField(controller: _nameCtrl, maxLength: 24, decoration: InputDecoration(hintText: 'Ex: CyberGuardians', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 2)), counterStyle: const TextStyle(color: Colors.grey, fontSize: 11))),
          const SizedBox(height: 16),

          const Text('Descrição', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _primaryDeep)),
          const SizedBox(height: 8),
          TextField(controller: _descCtrl, maxLength: 60, decoration: InputDecoration(hintText: 'Breve descrição...', filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 2)), counterStyle: const TextStyle(color: Colors.grey, fontSize: 11))),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Máx. Membros', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _primaryDeep)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _maxSize, isExpanded: true, style: const TextStyle(color: _primaryDeep, fontSize: 14, fontWeight: FontWeight.w600), items: _sizeOptions.map((s) => DropdownMenuItem(value: s, child: Text('$s'))).toList(), onChanged: (v) => setState(() => _maxSize = v!))),
              ),
            ])),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pontos Mínimos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _primaryDeep)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _minPoints, isExpanded: true, style: const TextStyle(color: _primaryDeep, fontSize: 14, fontWeight: FontWeight.w600), items: _pointOptions.map((p) => DropdownMenuItem(value: p, child: Text(p == 0 ? 'Aberto' : '$p pts'))).toList(), onChanged: (v) => setState(() => _minPoints = v!))),
              ),
            ])),
          ]),

          if (_minPoints > 0) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))), child: Row(children: [const Text('🔒', style: TextStyle(fontSize: 14)), const SizedBox(width: 8), Expanded(child: Text('Só utilizadores com ≥ $_minPoints pontos podem entrar.', style: const TextStyle(color: Color(0xFF92400E), fontSize: 12)))])),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              onPressed: _loading ? null : _createClan,
              child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Criar Clã', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _createClan() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome do clã é obrigatório.'), backgroundColor: Colors.red)); return; }
    setState(() => _loading = true);
    try {
      final batch   = FirebaseFirestore.instance.batch();
      final clanRef = FirebaseFirestore.instance.collection('clans').doc();
      batch.set(clanRef, {'name': name, 'description': _descCtrl.text.trim(), 'icon': _selectedIcon, 'points': 0, 'maxSize': _maxSize, 'minPoints': _minPoints, 'memberIds': [widget.userId], 'createdBy': widget.userId, 'createdAt': FieldValue.serverTimestamp(), 'roles': {}});
      batch.update(FirebaseFirestore.instance.collection('users').doc(widget.userId), {'clanId': clanRef.id});
      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}