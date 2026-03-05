import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
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
          'name': user!.displayName ?? "Utilizador SafeQuest",
          'email': user!.email,
          'phone': "",
          'photoUrl': user!.photoURL ?? "",
          'pontos': 0,
          'mfa_enabled': false,
          'bio': "Olá! Estou a aprender cibersegurança no SafeQuest.",
        });
      }
    }
  }

  // --- FUNÇÃO UNIFICADA DO POP-UP DE FOTO ---
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String nome = "Utilizador";
          String email = user?.email ?? "";
          int pontos = 0;
          String photoUrl = "";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            nome = data['name'] ?? nome;
            pontos = data['pontos'] ?? 0;
            photoUrl = data['photoUrl'] ?? "";
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _header(nome, email, pontos, photoUrl),
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
                      _deleteButton(context, user),
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

  Widget _header(String nome, String email, int pontos, String photoUrl) {
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
                        onTap: _showAvatarOptions, // POP-UP CENTRAL AQUI
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
                Text(nome, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(email, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -90, left: 20, right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat("7", "Dias", Icons.local_fire_department, Colors.orange),
              _stat("$pontos", "Pontos", Icons.monetization_on, Colors.amber),
              _stat("4", "Emblemas", Icons.workspace_premium, const Color(0xFF60A5FA)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) {
    return Container(
      width: 105, padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.06))]),
      child: Column(children: [Icon(icon, color: color), const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
    );
  }

  Widget _streakBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF6A00)]), borderRadius: BorderRadius.circular(25)),
      child: const Row(children: [Icon(Icons.local_fire_department, color: Colors.white, size: 32), SizedBox(width: 14), Expanded(child: Text("7 Dias Consecutivos!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
    );
  }

  Widget _menuPrincipal(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        ListTile(leading: const Icon(Icons.person_outline), title: const Text("Editar Perfil"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(onPhotoTap: _showAvatarOptions)))),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.shield_outlined), title: const Text("Privacidade"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage()))),
      ]),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      onPressed: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false); },
      child: const Text("Terminar Sessão", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
    );
  }

  Widget _deleteButton(BuildContext context, User? user) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 55), side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      onPressed: () {},
      child: const Text("Apagar Conta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    );
  }
}

// ================= PÁGINA: EDITAR PERFIL =================
class EditProfilePage extends StatefulWidget {
  final VoidCallback onPhotoTap; // Passamos a função do Pop-up como parâmetro
  const EditProfilePage({super.key, required this.onPhotoTap});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
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
            // CORREÇÃO: BOTÃO USA O MESMO POP-UP DA PAGINA PRINCIPAL
            _box("Foto de Perfil", Row(children: [
              const CircleAvatar(radius: 35, backgroundColor: Color(0xFF2563EB), child: Icon(Icons.person, color: Colors.white, size: 35)),
              const SizedBox(width: 15),
              OutlinedButton(
                onPressed: widget.onPhotoTap, // CHAMA O MESMO POP-UP
                child: const Text("Alterar Foto")
              ),
            ])),
            const SizedBox(height: 20),
            _box("Informações Pessoais", Column(children: [
              _field("Nome Completo", _nameController, Icons.person_outline),
              MouseRegion(
                cursor: SystemMouseCursors.forbidden,
                child: _field("Email (Bloqueado)", TextEditingController(text: user?.email ?? ""), Icons.lock_outline, readOnly: true, isBlocked: true),
              ),
              _field("Biografia", _bioController, Icons.history_edu, maxLines: 3),
            ])),
            const SizedBox(height: 20),
            _box("Segurança", ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(backgroundColor: Color(0xFFF0F7FF), child: Icon(Icons.lock_reset, color: Color(0xFF1D4ED8))),
              title: const Text("Alterar Palavra-passe", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Enviar link para o e-mail"),
              onTap: () async {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link enviado!")));
              },
            )),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF1D4ED8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'name': _nameController.text, 'bio': _bioController.text});
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

// ================= PÁGINA: PRIVACIDADE =================
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  String _visibility = "Público";
  bool _mfaEnabled = false; 
  final String _phoneNumber = "+351912345678";

  String maskPhone(String phone) {
    return phone.isEmpty ? "" : "*******${phone.substring(phone.length - 3)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Privacidade"), centerTitle: true, elevation: 0, backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSection(title: "Visibilidade do Perfil", icon: Icons.group_outlined, child: Column(children: [
              _buildRadioOption("Público", "Todos os utilizadores", "Público"),
              const SizedBox(height: 10),
              _buildRadioOption("Amigos", "Apenas conexões", "Amigos"),
              const SizedBox(height: 10),
              _buildRadioOption("Privado", "Apenas tu", "Privado"),
            ])),
            const SizedBox(height: 20),
            
            _buildSection(
              title: "Segurança de Acesso",
              icon: Icons.security,
              child: _mfaEnabled 
                ? Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.verified, color: Colors.green),
                        title: const Text("MFA Ativado", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        subtitle: Text("Telemóvel: ${maskPhone(_phoneNumber)}"),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _mfaEnabled = false),
                        child: const Text("Desativar Proteção", style: TextStyle(color: Colors.red)),
                      )
                    ],
                  )
                : Column(
                    children: [
                      const Text("A autenticação de 2 passos adiciona uma camada extra de segurança."),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _mfaEnabled = true),
                          icon: const Icon(Icons.phonelink_lock),
                          label: const Text("Ativar MFA Agora"),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                        ),
                      )
                    ],
                  ),
            ),
            const SizedBox(height: 30),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () => Navigator.pop(context), child: const Text("Guardar Alterações", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
  }

  Widget _buildSection({required String title, IconData? icon, required Widget child}) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [if (icon != null) Icon(icon, color: const Color(0xFF64748B)), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1E3A8A)))]), const SizedBox(height: 20), child]));
  }

  Widget _buildRadioOption(String title, String subtitle, String value) {
    return Container(decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15)), child: RadioListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)), value: value, groupValue: _visibility, activeColor: const Color(0xFF2563EB), onChanged: (v) => setState(() => _visibility = v.toString())));
  }
}