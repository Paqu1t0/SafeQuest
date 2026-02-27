import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // Certifica-te que a classe se chama LoginPage ou LoginScreen

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          String nome = "Utilizador";
          String email = user?.email ?? "";
          int pontos = 0;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            nome = data['name'] ?? nome;
            pontos = data['pontos'] ?? 0;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _header(nome, email, pontos),
                const SizedBox(height: 110),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _streakBanner(),
                      const SizedBox(height: 25),
                      _menu(context),
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

  // ================= DESIGN ORIGINAL DO PERFIL =================
  Widget _header(String nome, String email, int pontos) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 360,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text("Perfil", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFFE5E7EB),
                  child: Icon(Icons.person, size: 60, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 14),
                Text(nome, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat("7", "Dias", Icons.local_fire_department, Colors.orange),
              _stat("$pontos", "Pontos", Icons.emoji_events, const Color(0xFF2563EB)),
              _stat("4", "Emblemas", Icons.workspace_premium, const Color(0xFF60A5FA)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.06), offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _streakBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF6A00)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: const Row(
        children: [
          Icon(Icons.local_fire_department, color: Colors.white, size: 32),
          SizedBox(width: 14),
          Expanded(child: Text("7 Dias Consecutivos!\nComplete um quiz hoje para manter a sequência.", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Editar Perfil"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text("Privacidade"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage())),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
        }
      },
      child: const Text("Terminar Sessão", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
    );
  }

  // ================= POP-UP APAGAR CONTA CORRIGIDO =================
  Widget _deleteButton(BuildContext context, User? user) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 55), side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      onPressed: () {
        final emailCtrl = TextEditingController();
        final passCtrl = TextEditingController();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Apagar Conta"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Por segurança, introduza os seus dados para confirmar."),
                const SizedBox(height: 15),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Palavra-passe", border: OutlineInputBorder())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              TextButton(
                onPressed: () async {
                  try {
                    AuthCredential cred = EmailAuthProvider.credential(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
                    await user?.reauthenticateWithCredential(cred);
                    await FirebaseFirestore.instance.collection("users").doc(user?.uid).delete();
                    await user?.delete();
                    if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dados incorretos."), backgroundColor: Colors.red));
                  }
                }, 
                child: const Text("Apagar", style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );
      },
      child: const Text("Apagar Conta", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    );
  }
}

// ================= PÁGINA EDITAR PERFIL ORIGINAL (MANTÉM DESIGN E AUTO-LOAD) =================
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
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
          _phoneController.text = data['phone'] ?? "";
          _bioController.text = data['bio'] ?? "";
        });
      }
    }
  }

  void _enviarEmailRedefinicao(BuildContext context) async {
    if (user?.email != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-mail enviado!"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0.5, centerTitle: true,
        title: const Text("Editar Perfil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          label: const Text("Voltar", style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Ícone de Perfil Estilizado
            _box("Foto de Perfil", Row(children: [
              const CircleAvatar(radius: 35, backgroundColor: Color(0xFF2563EB), child: Icon(Icons.person, color: Colors.white, size: 35)),
              const SizedBox(width: 15),
              OutlinedButton(onPressed: () {}, child: const Text("Alterar Foto")),
            ])),
            const SizedBox(height: 20),
            _box("Informações Pessoais", Column(children: [
              _field("Nome Completo", _nameController, icon: Icons.person_outline),
              _field("Email", TextEditingController(text: user?.email ?? ""), icon: Icons.email_outlined, readOnly: true),
              _field("Telemóvel", _phoneController, icon: Icons.phone_android_outlined),
              _field("Biografia", _bioController, maxLines: 3),
            ])),
            const SizedBox(height: 20),
            _box("Segurança", ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.lock_reset, color: Color(0xFF1D4ED8))),
              title: const Text("Alterar Palavra-passe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Link enviado por e-mail", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _enviarEmailRedefinicao(context),
            )),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF1D4ED8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
                  'name': _nameController.text, 'phone': _phoneController.text, 'bio': _bioController.text,
                });
                if (mounted) Navigator.pop(context);
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 15), child,
      ]),
    );
  }

  Widget _field(String label, TextEditingController controller, {int maxLines = 1, IconData? icon, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
          const SizedBox(height: 8),
          TextField(
            controller: controller, maxLines: maxLines, readOnly: readOnly,
            decoration: InputDecoration(
              filled: true, 
              fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white, 
              prefixIcon: icon != null ? Icon(icon, size: 20) : null, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB)))
            ),
          ),
        ],
      ),
    );
  }
}

// ================= PRIVACIDADE ORIGINAL =================
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  String _visibility = "Público";
  bool _showEmail = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text("Privacidade", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          label: const Text("Voltar", style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _box("Visibilidade do Perfil", Column(children: ["Público", "Amigos", "Privado"].map((opt) => RadioListTile(
            title: Text(opt), value: opt, groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v.toString()),
          )).toList())),
          const SizedBox(height: 20),
          _box("Informações de Contacto", SwitchListTile(title: const Text("Mostrar Email"), value: _showEmail, onChanged: (v) => setState(() => _showEmail = v))),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF1D4ED8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context),
            child: const Text("Guardar Alterações", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _box(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10), child,
      ]),
    );
  }
}