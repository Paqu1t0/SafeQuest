import 'package:flutter/material.dart';
import 'package:projeto_safequest/screens/register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/screens/home_page.dart';
import 'package:projeto_safequest/screens/forgot_password_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:projeto_safequest/screens/mfa_email_page.dart'; 
import 'package:projeto_safequest/main.dart';
import 'package:projeto_safequest/screens/notification_service.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool('remember_me') ?? false;
    final savedEmail = prefs.getString('saved_email') ?? '';
    if (remembered && savedEmail.isNotEmpty) {
      setState(() {
        _rememberMe = true;
        _emailController.text = savedEmail;
      });
    }
  }

  Future<void> _saveRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_email', _emailController.text.trim());
    } else {
      await prefs.setBool('remember_me', false);
      await prefs.remove('saved_email');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================= LÓGICA: LOGIN GOOGLE =================
  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // Força escolha de conta

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; 

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Persistência de sessão — no mobile o Firebase já usa LOCAL por defeito
      // O "Lembra-me" é gerido via SharedPreferences + MFA gate

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _saveRememberMe();

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MFAEmailPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro no Google Sign-In: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ================= LÓGICA: LOGIN EMAIL =================
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Persistência de sessão — no mobile o Firebase já usa LOCAL por defeito
        // O "Lembra-me" é gerido via SharedPreferences + MFA gate

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await _saveRememberMe();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MFAEmailPage()),
        );
      } on FirebaseAuthException catch (e) {
        String mensagem = "Email ou senha incorretos";
        if (e.code == 'user-not-found') mensagem = "Utilizador não encontrado";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removi a altura fixa (height: double.infinity) que causava o Overflow
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFD1E3F5)],
          ),
        ),
        child: SafeArea( // Protege contra a barra de status e o fundo do ecrã
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icon/icon.png', height: 180),
                    const Text(
                      'SafeQuest',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 40),

                    // CARTÃO BRANCO
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: _buildInputDecoration('Email', Icons.email_outlined),
                            validator: (value) => (value == null || value.isEmpty) ? "Insira o email" : null,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _buildInputDecoration('Palavra-passe', Icons.lock_outline).copyWith(
                              suffixIcon: GestureDetector(
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF1A56DB),
                                  size: 22,
                                ),
                              ),
                            ),
                            validator: (value) => (value == null || value.isEmpty) ? "Insira a senha" : null,
                          ),
                          
                          const SizedBox(height: 8),

                          // LEMBRA-ME + ESQUECEU SENHA
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Checkbox "Lembra-me"
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                        activeColor: const Color(0xFF1A56DB),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        side: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Lembra-me',
                                      style: TextStyle(
                                        color: Color(0xFF1A56DB),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Esqueceu a senha
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Esqueceu a senha?',
                                  style: TextStyle(
                                    color: Color(0xFF1A56DB),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // BOTÃO ENTRAR
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A56DB),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: _handleLogin, 
                              child: const Text('Entrar', style: TextStyle(color: Colors.white, fontSize: 18)),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("ou", style: TextStyle(color: Colors.grey)),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // BOTÃO GOOGLE CORRIGIDO
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                side: const BorderSide(color: Colors.grey),
                              ),
                              icon: Image.network(
                                // Link atualizado e estável para a imagem do Google
                                'https://cdn-icons-png.flaticon.com/512/300/300221.png',
                                height: 24,
                              ),
                              label: const Text('Entrar com Google', style: TextStyle(color: Colors.black87)),
                              onPressed: _handleGoogleSignIn,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Não tem conta? '),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                          child: const Text('Criar Conta', style: TextStyle(color: Color(0xFF1A56DB), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF1A56DB)),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF0F7FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }
}