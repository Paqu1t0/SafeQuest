import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Chave para controlar o formulário
  final _formKey = GlobalKey<FormState>();

  // Controladores para capturar os dados e comparar as senhas
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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
            colors: [Color(0xFFE3F2FD), Color(0xFFD1E3F5)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Form(
            key: _formKey,
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
                  'Comece a Sua Jornada Digital',
                  style: TextStyle(fontSize: 14, color: Color(0xFF1A56DB)),
                ),
                const SizedBox(height: 30),

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
                          'Criar Conta',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // NOME COMPLETO
                      _buildLabel('Nome Completo'),
                      TextFormField(
                        controller: _nameController,
                        decoration: _buildInputDecoration(
                          'João Silva',
                          Icons.person_outline,
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Insira o seu nome'
                            : null,
                      ),
                      const SizedBox(height: 15),

                      // EMAIL
                      _buildLabel('Email'),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _buildInputDecoration(
                          'seu@email.com',
                          Icons.email_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insira o seu email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Email inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // PALAVRA-PASSE
                      _buildLabel('Palavra-passe'),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: _buildInputDecoration(
                          'Crie uma palavra-passe',
                          Icons.lock_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Crie uma palavra-passe';
                          }
                          if (value.length < 8) return 'Mínimo de 8 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // CONFIRMAR PALAVRA-PASSE
                      _buildLabel('Confirmar Palavra-passe'),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: _buildInputDecoration(
                          'Confirme a palavra-passe',
                          Icons.lock_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirme a palavra-passe';
                          }
                          if (value != _passwordController.text) {
                            return 'As palavras-passe não coincidem';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 25),

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
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              try {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                                UserCredential userCredential =
                                    await FirebaseAuth.instance
                                        .createUserWithEmailAndPassword(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text
                                              .trim(),
                                        );
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userCredential.user!.uid)
                                    .set({
                                      'nome': _nameController.text.trim(),
                                      'email': _emailController.text.trim(),
                                      'pontos': 0,
                                      'createdAt': DateTime.now(),
                                    });
                                // 3. Guarda o nome na firestore
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userCredential.user!.uid)
                                    .set({
                                      'name': _nameController.text.trim(),
                                      'email': _emailController.text.trim(),
                                      'createdAt': DateTime.now(),
                                    });

                                // 4. Fechar o loading e sair da página
                                Navigator.pop(context); // Fecha o dialog
                                Navigator.pop(context); // Volta para o Login

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Conta criada com sucesso!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } on FirebaseAuthException catch (e) {
                                Navigator.pop(context); // Fecha o loading
                                String errorMsg = "Erro ao criar conta";

                                if (e.code == 'email-already-in-password') {
                                  errorMsg = "Este email já está em uso.";
                                }
                                if (e.code == 'weak-password') {
                                  errorMsg = "A palavra-passe é muito fraca.";
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } catch (e) {
                                Navigator.pop(context);
                                print(e);
                              }
                            }
                          },
                          child: const Text(
                            'Criar Conta',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // FOOTER
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Já tem conta? ',
                      style: TextStyle(color: Color(0xFF1E3A8A)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Entrar',
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
    );
  }

  // Estilo visual dos Labels
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A8A),
          fontSize: 14,
        ),
      ),
    );
  }

  // Estilo visual dos Campos de Texto
  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF1A56DB), size: 20),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F7FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
    );
  }
}
