import 'package:flutter/material.dart';
import 'package:projeto_safequest/screens/register_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Chave global para identificar o formulário e validar
  final _formKey = GlobalKey<FormState>();

  // Controladores para capturar o texto digitado
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SingleChildScrollView evita que o teclado esconda os campos e cause erros de layout
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(
            context,
          ).size.height, // Garante que o fundo cubra a tela toda
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE3F2FD), Color(0xFFD1E3F5)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey, // Atribui a chave ao formulário
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield, size: 80, color: Color(0xFF1A56DB)),
                  const SizedBox(height: 10),
                  const Text(
                    'SafeQuest',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const Text(
                    'Literacia Digital para Todos',
                    style: TextStyle(fontSize: 14, color: Color(0xFF1A56DB)),
                  ),
                  const SizedBox(height: 40),

                  // Cartão do Formulário
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
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
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Campo Email com Validação
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildInputDecoration(
                            'seu@email.com',
                            Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira o seu email';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Insira um email válido (ex: nome@gmail.com)';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Campo Palavra-passe com Validação
                        const Text(
                          'Palavra-passe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: _buildInputDecoration(
                            'Digite a sua palavra-passe',
                            Icons.lock_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira a sua palavra-passe';
                            }
                            if (value.length < 8) {
                              return 'A palavra-pass deve ter pelo menos 8 caracteres';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 25),

                        // Botão Entrar
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A56DB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              // Executa a validação de todos os campos do Form
                              if (_formKey.currentState!.validate()) {
                                // Se for válido, podes avançar para a lógica de login
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('A processar Login...'),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'Entrar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),
                        Center(
                          child: TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Esqueceu a palavra-passe?',
                              style: TextStyle(color: Color(0xFF1A56DB)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Não tem conta? '),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Criar Conta',
                          style: TextStyle(
                            color: Color(0xFF1A56DB),
                            fontWeight: FontWeight.bold,
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

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF1A56DB), size: 20),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.blueAccent, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F7FF),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1E3F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1E3F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}
