import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart'; // Para os switches estilo iOS modernos
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
          'uid': user!.uid,
          'nickname': user!.displayName?.split(" ").first ?? "Jogador",
          'name': user!.displayName ?? "Utilizador SafeQuest",
          'email': user!.email,
          'phone': "",
          'photoUrl': user!.photoURL ?? "",
          'pontos': 0,
          'bio': "Olá! Estou a aprender cibersegurança no SafeQuest.",
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

  // ================= LÓGICA: APAGAR CONTA COM EMAIL E PASSWORD =================
  Future<void> _deleteAccount(String email, String password) async {
    try {
      if (user != null) {
        // 1. Reautenticar o utilizador
        AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
        await user!.reauthenticateWithCredential(credential);

        // 2. Apagar os dados do utilizador do Firestore
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();

        // 3. Apagar o utilizador da Autenticação do Firebase
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
    final emailController = TextEditingController(text: user?.email ?? "");
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Apagar Conta?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
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
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
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
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7), // Fundo cinza claro para destacar os cartões brancos
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String nickname = "Jogador";
          String nomeReal = user?.displayName ?? "Utilizador SafeQuest";
          int pontos = 0;
          String photoUrl = "";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            nickname = data['nickname'] ?? data['name']?.split(" ").first ?? nickname;
            nomeReal = data['name'] ?? nomeReal;
            pontos = data['pontos'] ?? 0;
            photoUrl = data['photoUrl'] ?? "";
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _header(nickname, nomeReal, pontos, photoUrl),
                const SizedBox(height: 110),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _streakBanner(),
                      const SizedBox(height: 25),
                      _menuPrincipal(context),
                      const SizedBox(height: 25),
                      _logoutButton(context),
                      const SizedBox(height: 12),
                      _deleteButton(context), // <--- BOTÃO APAGAR VOLTOU AQUI!
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

  Widget _header(String nickname, String nomeReal, int pontos, String photoUrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 360, width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text("Perfil", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFE5E7EB),
                      backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!) as ImageProvider 
                        : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : (user?.photoURL != null ? NetworkImage(user!.photoURL!) : null)),
                      child: (user?.photoURL == null && _imageFile == null && photoUrl.isEmpty) ? const Icon(Icons.person, size: 60, color: Color(0xFF9CA3AF)) : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _showAvatarOptions, 
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Color(0xFF2563EB), size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(nickname, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(nomeReal, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -90, left: 20, right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cartões com mais destaque e sombra
              _stat("7", "Dias", Icons.local_fire_department, const Color(0xFFFF6A00), const Color(0xFFFFF0E6)),
              _stat("$pontos", "Pontos", Icons.emoji_events, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
              _stat("4", "Emblemas", Icons.workspace_premium, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
            ],
          ),
        ),
      ],
    );
  }

  // Novo design dos Stats para dar mais destaque
  Widget _stat(String value, String label, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      width: 105, 
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(blurRadius: 15, color: Colors.black.withOpacity(0.08), offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]
      ),
    );
  }

  Widget _streakBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF6A00)]), borderRadius: BorderRadius.circular(25)),
      child: const Row(children: [Icon(Icons.local_fire_department, color: Colors.white, size: 32), SizedBox(width: 14), Expanded(child: Text("7 Dias Consecutivos!\nContinue assim!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
    );
  }

  Widget _menuPrincipal(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: Column(children: [
        ListTile(leading: const Icon(Icons.person_outline), title: const Text("Editar Perfil", style: TextStyle(fontWeight: FontWeight.w500)), trailing: const Icon(Icons.chevron_right, color: Colors.grey), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(onPhotoTap: _showAvatarOptions)))),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ListTile(leading: const Icon(Icons.shield_outlined), title: const Text("Privacidade", style: TextStyle(fontWeight: FontWeight.w500)), trailing: const Icon(Icons.chevron_right, color: Colors.grey), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage()))),
      ]),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: const BorderSide(color: Color(0xFFE2E8F0))
      ),
      onPressed: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false); },
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
        backgroundColor: const Color(0xFFFEF2F2), // Fundo vermelho muito claro
        minimumSize: const Size(double.infinity, 55), 
        side: const BorderSide(color: Color(0xFFFECACA)), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
      ),
      onPressed: _showDeleteConfirmation,
      child: const Text("Apagar Conta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    );
  }
}

// ================= PÁGINA: EDITAR PERFIL =================
class EditProfilePage extends StatefulWidget {
  final VoidCallback onPhotoTap; 
  const EditProfilePage({super.key, required this.onPhotoTap});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final _nicknameController = TextEditingController();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

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
          _nameController.text = data['name'] ?? "";
          _bioController.text = data['bio'] ?? "";
        });
      }
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
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 15), child]));
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

// ================= PÁGINA: PRIVACIDADE E NOTIFICAÇÕES (Estilo Novo) =================
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  String _visibility = "Público";
  bool _emailNotifs = true;
  bool _pushNotifs = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fundo cinza claro
      appBar: AppBar(
        title: const Text("Privacidade", style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.white, 
        foregroundColor: const Color(0xFF1E3A8A)
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // SECÇÃO: Visibilidade do Perfil
            _buildSection(
              title: "Visibilidade do Perfil", 
              icon: Icons.visibility_outlined, 
              child: Column(children: [
                _buildRadioOption("Público", "Todos podem ver o seu perfil", "Público"),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildRadioOption("Amigos", "Apenas amigos podem ver", "Amigos"),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildRadioOption("Privado", "Apenas você pode ver", "Privado"),
              ])
            ),
            
            const SizedBox(height: 20),
            
            // SECÇÃO: Notificações
            _buildSection(
              title: "Notificações", 
              icon: Icons.notifications_none, 
              child: Column(children: [
                _buildSwitchOption("Notificações por Email", _emailNotifs, (val) => setState(() => _emailNotifs = val)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildSwitchOption("Notificações Push", _pushNotifs, (val) => setState(() => _pushNotifs = val)),
              ])
            ),
            
            const SizedBox(height: 35),
            
            // BOTÃO GUARDAR (Igual à imagem)
            SizedBox(
              width: double.infinity, 
              height: 55, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8), // Azul escuro
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ), 
                onPressed: () => Navigator.pop(context), 
                child: const Text("Guardar Alterações", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
              )
            ),
          ],
        ),
      ),
    );
  }

  // Novo design de secção (cartão branco com sombra muito suave)
  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 10),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[700], size: 20), 
                const SizedBox(width: 10), 
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)))
              ]
            ),
          ), 
          child
        ]
      )
    );
  }

  // Novo design dos botões rádio (mais limpos, sem caixa cinza à volta)
  Widget _buildRadioOption(String title, String subtitle, String value) {
    return RadioListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), 
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)), 
      value: value, 
      groupValue: _visibility, 
      activeColor: const Color(0xFF2563EB), 
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      onChanged: (v) => setState(() => _visibility = v.toString())
    );
  }

  // Switches modernos ao estilo iOS (CupertinoSwitch)
  Widget _buildSwitchOption(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: CupertinoSwitch(
        activeColor: const Color(0xFF2563EB),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}