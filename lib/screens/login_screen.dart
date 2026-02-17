import 'package:flutter/material.dart';
import 'package:projeto_safequest/screens/register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/screens/home_page.dart';
import 'package:projeto_safequest/screens/forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFD1E3F5),
            ], // Gradiente padrão do projeto [cite: 60]
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo e Título alinhados com o protótipo [cite: 638]
                  const Icon(Icons.shield, size: 90, color: Color(0xFF1A56DB)),
                  const SizedBox(height: 10),
                  const Text(
                    'SafeQuest',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const Text(
                    'Literacia Digital para Todos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A56DB),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Cartão do Formulário Principal
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Bem-vindo',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        _buildLabel('Email'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildInputDecoration(
                            'seu@email.com',
                            Icons.email_outlined,
                          ),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                              ? 'Insira um email válido'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        _buildLabel('Palavra-passe'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _buildInputDecoration(
                            'Digite a sua palavra-passe',
                            Icons.lock_outline,
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Insira a sua senha'
                              : null,
                        ),

                        // Link Esqueci a Senha alinhado à direita
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordPage(),
                              ),
                            ),
                            child: const Text(
                              'Esqueceu a senha?',
                              style: TextStyle(
                                color: Color(0xFF1A56DB),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Botão Entrar com estilo de "Pílula" [cite: 81]
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A56DB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _handleLogin,
                            child: const Text(
                              'Entrar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Navegação para Registo [cite: 74]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Não tem conta? ',
                        style: TextStyle(color: Color(0xFF1E3A8A)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        ),
                        child: const Text(
                          'Criar Conta',
                          style: TextStyle(
                            color: Color(0xFF1A56DB),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Lógica de Login centralizada [cite: 463]
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } on FirebaseAuthException catch (e) {
        String msg = "Erro ao entrar. Verifique os seus dados.";
        if (e.code == 'user-not-found') msg = "Utilizador não encontrado.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
        fontSize: 15,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF1A56DB), size: 22),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF0F7FF),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
      ),
    );
  }
}
