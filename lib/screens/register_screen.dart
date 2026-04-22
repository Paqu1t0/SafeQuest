import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey             = GlobalKey<FormState>();
  final _nameController      = TextEditingController();
  final _nicknameController  = TextEditingController();
  final _emailController     = TextEditingController();
  final _passwordController  = TextEditingController();
  final _confirmController   = TextEditingController();
  bool _obscurePw  = true;
  bool _obscureCfm = true;
  bool _loading    = false;

  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email   : _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await cred.user!.updateDisplayName(_nameController.text.trim());

      // Guarda todos os dados no Firestore numa única operação
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name'        : _nameController.text.trim(),
        'nickname'    : _nicknameController.text.trim(),
        'email'       : _emailController.text.trim(),
        'pontos'      : 0,
        'moedas'      : 0,
        'streak'      : 0,
        'nivel'       : 1,
        'avatar'      : 'default',
        'banner'      : 'default',
        'ownedAvatars': ['default', 'fox'],
        'ownedBanners': ['default'],
        'badges'      : [],
        'friends'     : [],
        'friendRequests': [],
        'privacy'     : 'publico',
        'emailNotifs' : true,
        'pushNotifs'  : true,
        'createdAt'   : FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // Volta para o login

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Conta criada! Bem-vindo ao SafeQuest!'), backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Erro ao criar conta.';
      if (e.code == 'email-already-in-use') msg = 'Este email já está em uso.';
      if (e.code == 'weak-password')        msg = 'A palavra-passe é muito fraca.';
      if (e.code == 'invalid-email')        msg = 'Email inválido.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFD1E3F5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(children: [
                // Logo
                const Icon(Icons.shield_rounded, size: 70, color: _primary),
                const SizedBox(height: 8),
                const Text('SafeQuest', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primaryDeep)),
                const Text('Comece a Sua Jornada Digital', style: TextStyle(fontSize: 13, color: _primary)),
                const SizedBox(height: 28),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Center(child: Text('Criar Conta', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: _primaryDeep))),
                    const SizedBox(height: 22),

                    // Nome completo
                    _label('Nome Completo'),
                    _field(_nameController, 'João Silva', Icons.person_outline,
                        validator: (v) => (v == null || v.isEmpty) ? 'Insira o seu nome' : null),
                    const SizedBox(height: 14),

                    // Nickname — o que aparece na app
                    _label('Nickname'),
                    _field(_nicknameController, 'Escolhe um nickname único', Icons.alternate_email_rounded,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Escolhe um nickname';
                          if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                          if (v.contains(' ')) return 'Sem espaços no nickname';
                          return null;
                        }),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4, bottom: 2),
                      child: Text('Será o teu nome exibido na app e no leaderboard', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ),
                    const SizedBox(height: 14),

                    // Email
                    _label('Email'),
                    _field(_emailController, 'seu@email.com', Icons.email_outlined,
                        type: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Insira o seu email';
                          if (!v.contains('@') || !v.contains('.')) return 'Email inválido';
                          return null;
                        }),
                    const SizedBox(height: 14),

                    // Palavra-passe
                    _label('Palavra-passe'),
                    _passField(_passwordController, 'Crie uma palavra-passe', _obscurePw,
                        () => setState(() => _obscurePw = !_obscurePw),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Crie uma palavra-passe';
                          if (v.length < 8) return 'Mínimo 8 caracteres';
                          return null;
                        }),
                    const SizedBox(height: 14),

                    // Confirmar
                    _label('Confirmar Palavra-passe'),
                    _passField(_confirmController, 'Confirme a palavra-passe', _obscureCfm,
                        () => setState(() => _obscureCfm = !_obscureCfm),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirme a palavra-passe';
                          if (v != _passwordController.text) return 'As palavras-passe não coincidem';
                          return null;
                        }),
                    const SizedBox(height: 24),

                    // Botão
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          elevation: 0,
                        ),
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Criar Conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // Footer
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Já tem conta? ', style: TextStyle(color: _primaryDeep)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Entrar', style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: _primaryDeep, fontSize: 13)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl, keyboardType: type, validator: validator,
    decoration: _dec(hint, icon),
  );

  Widget _passField(TextEditingController ctrl, String hint, bool obscure, VoidCallback toggle, {
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl, obscureText: obscure, validator: validator,
    decoration: _dec(hint, Icons.lock_outline).copyWith(
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _primary, size: 20),
        onPressed: toggle,
      ),
    ),
  );

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, color: _primary, size: 20),
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
    filled: true, fillColor: const Color(0xFFF0F7FF),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.5)),
    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
  );
}