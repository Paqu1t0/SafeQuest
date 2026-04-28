import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:projeto_safequest/services/app_settings.dart';
import 'package:projeto_safequest/screens/avatar_store_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _syncGoogleData();
  }

  Future<void> _syncGoogleData() async {
    if (user != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final doc = await userDoc.get();
      if (!doc.exists) {
        // Novo utilizador: guarda a foto do Google no Firestore desde o início
        await userDoc.set({
          'uid'     : user!.uid,
          'nickname': user!.displayName?.split(" ").first ?? "Jogador",
          'name'    : user!.displayName ?? "Utilizador SafeQuest",
          'email'   : user!.email,
          'phone'   : "",
          'photoUrl': user!.photoURL ?? "",
          'pontos'  : 0,
          'bio'     : "Olá! Estou a aprender cibersegurança no SafeQuest.",
          'streak'  : 0,
        });
      } else {
        // Utilizador existente: se ainda não tem photoUrl no Firestore mas tem no Google, sincronizar
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final firestorePhoto = data['photoUrl'] as String? ?? '';
        if (firestorePhoto.isEmpty && (user!.photoURL?.isNotEmpty ?? false)) {
          await userDoc.update({'photoUrl': user!.photoURL});
        }
      }
    }
  }

  void _showAvatarOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Alterar Foto", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
              title: const Text("Galeria do Telemóvel"),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (image != null) setState(() { _imageFile = File(image.path); });
              },
            ),
            ListTile(
              leading: const Icon(Icons.stars, color: Colors.amber),
              title: const Text("Loja de Avatares"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A abrir Loja...")));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(String email, String password) async {
    try {
      if (user != null) {
        AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
        await user!.reauthenticateWithCredential(credential);
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
        await user!.delete();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Erro ao apagar conta.";
      if (e.code == 'wrong-password') msg = "Palavra-passe incorreta.";
      if (e.code == 'user-not-found' || e.code == 'invalid-email') msg = "Email incorreto.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  void _showDeleteConfirmation() {
    final emailController    = TextEditingController(text: user?.email ?? "");
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text("Apagar Conta?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Esta ação é irreversível. Todos os teus dados serão perdidos.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: "Confirma o Email",
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                filled: true, fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Palavra-passe",
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                filled: true, fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
                Navigator.pop(context);
                _deleteAccount(emailController.text, passwordController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preenche ambos os campos."), backgroundColor: Colors.red));
              }
            },
            child: const Text("Apagar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Popup de configurações — só sons ──────────────────────────────────────
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configurações',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 20),
              Consumer<AppSettings>(
                builder: (context, settings, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.volume_up_rounded, color: Color(0xFF16A34A), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Efeitos Sonoros', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text('Sons ao responder e no fim do quiz', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        activeColor: const Color(0xFF1A56DB),
                        value: settings.soundEnabled,
                        onChanged: (v) => context.read<AppSettings>().setSoundEnabled(v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String nickname  = "Jogador";
          String nomeReal  = user?.displayName ?? "Utilizador SafeQuest";
          int pontos       = 0;
          int streak       = 0;
          int numBadges    = 0;
          String photoUrl  = "";
          String avatarId  = 'default';
          String bannerId  = 'default';
          String bio       = '';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            nickname  = data['nickname'] ?? data['name']?.split(" ").first ?? nickname;
            nomeReal  = data['name'] ?? nomeReal;
            pontos    = data['pontos']   ?? 0;
            streak    = data['streak']   ?? 0;
            numBadges = (data['badges'] as List?)?.length ?? 0;
            photoUrl  = data['photoUrl'] ?? "";
            avatarId  = data['avatar']   ?? 'default';
            bannerId  = data['banner']   ?? 'default';
            bio       = data['bio']      ?? '';
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _header(nickname, nomeReal, pontos, photoUrl, streak, numBadges, avatarId, bannerId, bio),
                const SizedBox(height: 110),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _streakBanner(streak),
                      const SizedBox(height: 25),
                      _buildProgressCharts(user?.uid),
                      const SizedBox(height: 25),
                      _menuPrincipal(context),
                      const SizedBox(height: 25),

                      _logoutButton(context),
                      const SizedBox(height: 12),
                      
                      _deleteButton(context),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Mapa de avatares (igual ao avatar_store_page) ────────────────────────
  static const _avatarEmoji = {
    'default': '👤', 'fox': '🦊', 'cat': '🐱', 'panda': '🐼',
    'lion': '🦁',   'koala': '🐨', 'dragon': '🐉', 'unicorn': '🦄',
  };
  static const _avatarColor = {
    'default': Color(0xFF1A56DB), 'fox': Color(0xFFEA580C),
    'cat': Color(0xFF7C3AED),    'panda': Color(0xFF0F766E),
    'lion': Color(0xFFB45309),   'koala': Color(0xFF4B5563),
    'dragon': Color(0xFFDC2626), 'unicorn': Color(0xFFDB2777),
  };

  // Cores dos banners (sincronizado com avatar_store_page)
  static List<Color> _getBannerColors(String bannerId) {
    const map = {
      'default' : [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      'sunset'  : [Color(0xFFEA580C), Color(0xFFDC2626)],
      'forest'  : [Color(0xFF16A34A), Color(0xFF0F766E)],
      'galaxy'  : [Color(0xFF7C3AED), Color(0xFF1E3A8A)],
      'gold'    : [Color(0xFFF59E0B), Color(0xFFEA580C)],
      'rose'    : [Color(0xFFDB2777), Color(0xFF9333EA)],
      'ocean'   : [Color(0xFF0891B2), Color(0xFF1A56DB)],
      'midnight': [Color(0xFF1E293B), Color(0xFF334155)],
    };
    return map[bannerId] ?? map['default']!;
  }

  void _showAvatarSelector(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 100),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Alterar Avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close_rounded, color: Colors.grey)),
              ]),
              const SizedBox(height: 20),

              // Galeria do telemóvel
              _avatarOption(ctx,
                icon: Icons.photo_library_rounded, color: const Color(0xFF16A34A),
                bg: const Color(0xFFF0FDF4), title: 'Galeria do Telemóvel',
                subtitle: 'Usa uma foto da galeria',
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (img != null) setState(() => _imageFile = File(img.path));
                },
              ),
              const SizedBox(height: 10),

              // Loja
              _avatarOption(ctx,
                icon: Icons.storefront_rounded, color: const Color(0xFFF59E0B),
                bg: const Color(0xFFFEF3C7), title: 'Avatares da Loja',
                subtitle: 'Escolhe um avatar desbloqueado',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarStorePage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarOption(BuildContext ctx, {required IconData icon, required Color color, required Color bg, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
        ]),
      ),
    );
  }

  Widget _header(String nickname, String nomeReal, int pontos,
      String photoUrl, int streak, int numBadges, String avatarId,
      String bannerId, String bio) {
    final emoji = _avatarEmoji[avatarId] ?? '👤';
    final color = _avatarColor[avatarId] ?? const Color(0xFF1A56DB);
    final hasPhonePhoto   = _imageFile != null;
    // Usa sempre a photoUrl do Firestore (que já inclui a do Google sincronizada)
    final hasNetworkPhoto = photoUrl.isNotEmpty;
    final useStoreAvatar  = !hasPhonePhoto && avatarId != 'default';

    // Cores do banner
    final bannerColors = _getBannerColors(bannerId);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 370,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bannerColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text("Perfil", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showAvatarSelector(context),
                  child: Stack(children: [
                    useStoreAvatar
                        ? Container(
                            width: 96, height: 96,
                            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 48))),
                          )
                        : CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color(0xFFE5E7EB),
                            backgroundImage: hasPhonePhoto
                                ? FileImage(_imageFile!) as ImageProvider
                                : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
                            child: (!hasPhonePhoto && !hasNetworkPhoto)
                                ? const Icon(Icons.person, size: 60, color: Color(0xFF9CA3AF)) : null,
                          ),
                    Positioned(bottom: 0, right: 0, child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Color(0xFF2563EB), size: 18),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(nickname, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(nomeReal, style: const TextStyle(color: Colors.white70)),
                // ── Bio debaixo do nome ──────────────────────────────────
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(bio,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -90, left: 20, right: 20,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _stat("$streak", "Dias", Icons.local_fire_department, const Color(0xFFFF6A00), const Color(0xFFFFF0E6)),
            _stat("$pontos", "Pontos", Icons.emoji_events, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
            _stat("$numBadges", "Emblemas", Icons.workspace_premium, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
          ]),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(blurRadius: 15, color: Colors.black.withOpacity(0.08), offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  Widget _streakBanner(int streak) {
    if (streak == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A56DB), Color(0xFF1E40AF)]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Começa a tua sequência!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 4),
              Text("Faz um quiz hoje para iniciar a tua streak diária.", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF6A00)]),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(children: [
        const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            "$streak Dias Consecutivos!\nContinue assim! Complete um quiz hoje\npara manter a sequência.",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  Widget _menuPrincipal(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text("Editar Perfil", style: TextStyle(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(onPhotoTap: _showAvatarOptions))),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text("Privacidade", style: TextStyle(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage())),
        ),
      ]),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
      },
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout, color: Colors.black87, size: 20),
          SizedBox(width: 8),
          Text("Terminar Sessão", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _deleteButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFFEF2F2),
        minimumSize: const Size(double.infinity, 55),
        side: const BorderSide(color: Color(0xFFFECACA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: _showDeleteConfirmation,
      child: const Text("Apagar Conta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    );
  }

  // ── Gráfico de Progresso por Tema ─────────────────────────────────────────
  static const _temaColors2 = {
    'Phishing'       : Color(0xFF1A56DB),
    'Palavras-passe' : Color(0xFF7C3AED),
    'Segurança Web'  : Color(0xFF0F766E),
    'Redes Sociais'  : Color(0xFFEA580C),
  };
  static const _temas2 = ['Phishing', 'Palavras-passe', 'Segurança Web', 'Redes Sociais'];

  Widget _buildProgressCharts(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('quiz_results')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(children: [
              Row(children: [
                Icon(Icons.bar_chart_rounded, color: Color(0xFF1A56DB), size: 20),
                SizedBox(width: 8),
                Text('Progresso por Tema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              SizedBox(height: 16),
              Text('📊 Faz alguns quizzes para ver o teu progresso aqui!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          );
        }

        final Map<String, List<double>> temasData = {};
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final tema = d['theme'] as String? ?? '';
          if (_temas2.contains(tema)) {
            temasData.putIfAbsent(tema, () => []);
            temasData[tema]!.add((d['percent'] ?? 0).toDouble());
          }
        }

        final barGroups = <BarChartGroupData>[];
        final labels = <String>[];
        int idx = 0;
        for (final tema in _temas2) {
          if (temasData.containsKey(tema)) {
            final avg = temasData[tema]!.fold(0.0, (s, v) => s + v) / temasData[tema]!.length;
            final color = _temaColors2[tema] ?? const Color(0xFF1A56DB);
            barGroups.add(BarChartGroupData(
              x: idx,
              barRods: [BarChartRodData(
                toY: avg,
                color: color,
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true, toY: 100,
                  color: color.withOpacity(0.08),
                ),
              )],
            ));
            labels.add(tema.split(' ')[0]);
            idx++;
          }
        }

        if (barGroups.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.bar_chart_rounded, color: Color(0xFF1A56DB), size: 20),
              SizedBox(width: 8),
              Text('Progresso por Tema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            const Text('Média de acerto por categoria de quiz', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE5E7EB), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 36, interval: 25,
                    getTitlesWidget: (val, _) => Text('${val.toInt()}%',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 32,
                    getTitlesWidget: (val, _) {
                      final i = val.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(labels[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      );
                    },
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${rod.toY.toInt()}%',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 6, children: _temas2.where(temasData.containsKey).map((t) {
              final color = _temaColors2[t] ?? const Color(0xFF1A56DB);
              final count = temasData[t]!.length;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text('$t ($count)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]);
            }).toList()),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE PAGE — com foto própria e dismiss de teclado
// ─────────────────────────────────────────────────────────────────────────────
class EditProfilePage extends StatefulWidget {
  final VoidCallback onPhotoTap;
  const EditProfilePage({super.key, required this.onPhotoTap});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final _nicknameController = TextEditingController();
  final _nameController     = TextEditingController();
  final _bioController      = TextEditingController();
  File? _imageFile;         // foto local selecionada
  String _photoUrl = '';    // foto da rede

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nicknameController.text = data['nickname'] ?? data['name']?.split(" ").first ?? "";
          _nameController.text     = data['name'] ?? "";
          _bioController.text      = data['bio'] ?? "";
          _photoUrl                = data['photoUrl'] ?? user?.photoURL ?? '';
        });
      }
    }
  }

  void _showPhotoOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 120),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Alterar Foto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close_rounded, color: Colors.grey)),
              ]),
              const SizedBox(height: 18),
              _photoOption(ctx,
                icon: Icons.photo_library_rounded, color: const Color(0xFF16A34A),
                bg: const Color(0xFFF0FDF4), title: 'Galeria do Telemóvel',
                subtitle: 'Usa uma foto da galeria',
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (img != null) setState(() => _imageFile = File(img.path));
                },
              ),
              const SizedBox(height: 10),
              _photoOption(ctx,
                icon: Icons.storefront_rounded, color: const Color(0xFFF59E0B),
                bg: const Color(0xFFFEF3C7), title: 'Avatares da Loja',
                subtitle: 'Escolhe um avatar desbloqueado',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarStorePage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoOption(BuildContext ctx, {required IconData icon, required Color color, required Color bg, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
        ]),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final hasPhoto = _imageFile != null;
    final hasNetworkPhoto = _photoUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(title: const Text("Editar Perfil"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Foto de Perfil ───────────────────────────────────────────
              _box("Foto de Perfil", Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: const Color(0xFFE5E7EB),
                          backgroundImage: hasPhoto
                              ? FileImage(_imageFile!) as ImageProvider
                              : hasNetworkPhoto ? NetworkImage(_photoUrl) : null,
                          child: (!hasPhoto && !hasNetworkPhoto)
                              ? const Icon(Icons.person, size: 50, color: Color(0xFF9CA3AF))
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _showPhotoOptions,
                    child: const Text("Alterar Foto"),
                  ),
                ],
              )),
              const SizedBox(height: 20),
              _box("Informações Pessoais", Column(children: [
                _field("Nickname (Visível no jogo)", _nicknameController, Icons.sports_esports),
                _field("Nome Real", _nameController, Icons.person_outline),
                MouseRegion(
                  cursor: SystemMouseCursors.forbidden,
                  child: _field("Email (Bloqueado)", TextEditingController(text: user?.email ?? ""), Icons.lock_outline, readOnly: true, isBlocked: true),
                ),
                _field("Biografia", _bioController, Icons.history_edu, maxLines: 3),
              ])),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF1D4ED8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'nickname': _nicknameController.text, 'name': _nameController.text, 'bio': _bioController.text});
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text("Guardar Alterações", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 15), child,
      ]),
    );
  }

  Widget _field(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool readOnly = false, bool isBlocked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller, maxLines: maxLines, readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label, filled: true, fillColor: isBlocked ? const Color(0xFFF1F5F9) : Colors.white,
          prefixIcon: Icon(icon, color: isBlocked ? Colors.grey : const Color(0xFF1D4ED8)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVACY PAGE — igual ao original
// ─────────────────────────────────────────────────────────────────────────────
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final user = FirebaseAuth.instance.currentUser;
  String _visibility    = 'publico';
  bool   _emailNotifs   = true;
  bool   _pushNotifs    = true;
  bool   _loading       = true;
  bool   _saving        = false;
  bool   _isSendingReset = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (user == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _visibility  = data['privacy']      ?? 'publico';
        _emailNotifs = data['emailNotifs']   ?? true;
        _pushNotifs  = data['pushNotifs']    ?? true;
        _loading     = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (user == null) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'privacy'     : _visibility,
      'emailNotifs' : _emailNotifs,
      'pushNotifs'  : _pushNotifs,
    });
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Definições guardadas!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _resetPassword() async {
    if (user?.uid == null) return;
    setState(() => _isSendingReset = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('passwordResetRequests')
          .add({
        'requestedAt': FieldValue.serverTimestamp(),
        'processed': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de recuperação enviado! Verifica a tua caixa de entrada.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar email: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Privacidade", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
        backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Visibilidade
                  _buildSection(
                    title: "Visibilidade do Perfil",
                    icon: Icons.visibility_outlined,
                    child: Column(children: [
                      _buildRadioOption('publico',  'Público',  'Todos podem ver o seu perfil'),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                      _buildRadioOption('amigos',   'Amigos',   'Apenas amigos podem ver'),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                      _buildRadioOption('privado',  'Privado',  'Apenas tu consegues ver'),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Info sobre a privacidade
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1A56DB).withOpacity(0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Color(0xFF1A56DB), size: 18),
                      SizedBox(width: 10),
                      Expanded(child: Text(
                        'Se puseres "Privado", outros utilizadores não conseguem ver as tuas estatísticas nem conquistas.',
                        style: TextStyle(color: Color(0xFF1A56DB), fontSize: 12),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Notificações
                  _buildSection(
                    title: "Notificações",
                    icon: Icons.notifications_none,
                    child: Column(children: [
                      _buildSwitchOption(
                        'Notificações por Email',
                        'Recebe updates e resumos por email',
                        _emailNotifs,
                        (val) => setState(() => _emailNotifs = val),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                      _buildSwitchOption(
                        'Notificações Push',
                        'Alertas no telemóvel em tempo real',
                        _pushNotifs,
                        (val) => setState(() => _pushNotifs = val),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Text('🔔', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 10),
                      Expanded(child: Text(
                        'As notificações push requerem permissão no telemóvel. Podes gerir isto nas definições do sistema.',
                        style: TextStyle(color: Color(0xFF92400E), fontSize: 12),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // ── Segurança ──────────────────────────────────────────────
                  _buildSection(
                    title: 'Segurança',
                    icon: Icons.lock_outline,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Precisas de alterar a tua palavra-passe? Enviaremos um link seguro para o teu e-mail registado.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _isSendingReset ? null : _resetPassword,
                            icon: _isSendingReset
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.lock_reset, color: Color(0xFF1D4ED8)),
                            label: Text(_isSendingReset ? 'A enviar...' : 'Redefinir Palavra-passe'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1D4ED8),
                              side: const BorderSide(color: Color(0xFF1D4ED8)),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Guardar Alterações", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 20, bottom: 10),
          child: Row(children: [
            Icon(icon, color: Colors.grey[700], size: 20),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A))),
          ]),
        ),
        child,
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildRadioOption(String value, String title, String subtitle) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      value: value, groupValue: _visibility,
      activeColor: const Color(0xFF2563EB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      onChanged: (v) => setState(() => _visibility = v!),
    );
  }

  Widget _buildSwitchOption(String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: CupertinoSwitch(activeColor: const Color(0xFF2563EB), value: value, onChanged: onChanged),
    );
  }
}