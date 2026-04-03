import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:projeto_safequest/services/app_settings.dart';
import 'package:projeto_safequest/screens/avatar_store_page.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alterar Avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 20),

            // Opção 1 — Galeria do telemóvel
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFF0FDF4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A), size: 24),
              ),
              title: const Text('Foto do Telemóvel', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Usa uma foto da tua galeria', style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (image != null) setState(() => _imageFile = File(image.path));
              },
            ),
            const SizedBox(height: 12),

            // Opção 2 — Câmara
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFF0F7FF),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1A56DB).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1A56DB), size: 24),
              ),
              title: const Text('Câmara', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Tira uma nova foto', style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                if (image != null) setState(() => _imageFile = File(image.path));
              },
            ),
            const SizedBox(height: 12),

            // Opção 3 — Loja de avatares
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFFEF3C7),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFFF59E0B), size: 24),
              ),
              title: const Text('Avatares da Loja', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Escolhe um avatar desbloqueado', style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarStorePage()));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _header(String nickname, String nomeReal, int pontos,
      String photoUrl, int streak, int numBadges, String avatarId,
      String bannerId, String bio) {
    final emoji = _avatarEmoji[avatarId] ?? '👤';
    final color = _avatarColor[avatarId] ?? const Color(0xFF1A56DB);
    final hasPhonePhoto  = _imageFile != null;
    final hasNetworkPhoto = photoUrl.isNotEmpty || user?.photoURL != null;
    final useStoreAvatar = !hasPhonePhoto && avatarId != 'default';

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
                                : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : (user?.photoURL != null ? NetworkImage(user!.photoURL!) : null)),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE PAGE — igual ao original
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
  bool _isSendingReset = false;

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
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (user?.email == null) return;
    setState(() => _isSendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email de recuperação enviado! Verifica a tua caixa de entrada."), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar email: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text("Editar Perfil"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _box("Foto de Perfil", Row(children: [
              const CircleAvatar(radius: 35, backgroundColor: Color(0xFF2563EB), child: Icon(Icons.person, color: Colors.white, size: 35)),
              const SizedBox(width: 15),
              OutlinedButton(onPressed: widget.onPhotoTap, child: const Text("Alterar Foto")),
            ])),
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
            const SizedBox(height: 20),
            _box("Segurança", Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Precisas de alterar a tua palavra-passe? Enviaremos um link seguro para o teu e-mail registado.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: _isSendingReset ? null : _resetPassword,
                  icon: _isSendingReset
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_reset, color: Color(0xFF1D4ED8)),
                  label: Text(_isSendingReset ? "A enviar..." : "Redefinir Palavra-passe"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1D4ED8),
                    side: const BorderSide(color: Color(0xFF1D4ED8)),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            )),
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
  String _visibility = "Público";
  bool _emailNotifs  = true;
  bool _pushNotifs   = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Privacidade", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
        backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSection(title: "Visibilidade do Perfil", icon: Icons.visibility_outlined,
              child: Column(children: [
                _buildRadioOption("Público", "Todos podem ver o seu perfil", "Público"),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildRadioOption("Amigos", "Apenas amigos podem ver", "Amigos"),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildRadioOption("Privado", "Apenas você pode ver", "Privado"),
              ]),
            ),
            const SizedBox(height: 20),
            _buildSection(title: "Notificações", icon: Icons.notifications_none,
              child: Column(children: [
                _buildSwitchOption("Notificações por Email", _emailNotifs, (val) => setState(() => _emailNotifs = val)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildSwitchOption("Notificações Push", _pushNotifs, (val) => setState(() => _pushNotifs = val)),
              ]),
            ),
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => Navigator.pop(context),
                child: const Text("Guardar Alterações", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
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
      ]),
    );
  }

  Widget _buildRadioOption(String title, String subtitle, String value) {
    return RadioListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      value: value, groupValue: _visibility,
      activeColor: const Color(0xFF2563EB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      onChanged: (v) => setState(() => _visibility = v.toString()),
    );
  }

  Widget _buildSwitchOption(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: CupertinoSwitch(activeColor: const Color(0xFF2563EB), value: value, onChanged: onChanged),
    );
  }
}