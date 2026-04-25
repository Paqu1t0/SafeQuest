import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Usa a Cloud Function emailResetPassword para enviar um email
  // com o HTML personalizado SafeQuest (dragão azul + dica de segurança)
  // em vez do email genérico do Firebase Auth.
  Future<void> passwordReset() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    try {
      // Procura o utilizador pelo email no Firestore
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // Email não existe — não revelamos (segurança)
        if (!mounted) return;
        _showDialog(
          'Link enviado!',
          'Se este email estiver registado, recebes um link brevemente. Verifica também o Spam.',
        );
        return;
      }

      final uid = snap.docs.first.id;

      // Escrever aqui aciona a Cloud Function que gera o link seguro
      // e envia o email com o HTML personalizado SafeQuest
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('passwordResetRequests')
          .add({
        'requestedAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      if (!mounted) return;
      _showDialog(
        '📧 Email enviado!',
        'Verifica a tua caixa de entrada (e o Spam) para redefinir a palavra-passe.\n\nO link é válido por 1 hora.',
      );
    } on FirebaseAuthException catch (e) {
      String erro = 'Ocorreu um erro. Tenta novamente.';
      if (e.code == 'user-not-found') erro = 'Não existe nenhum utilizador com este email.';
      if (!mounted) return;
      _showDialog('Erro', erro, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showDialog('Erro', 'Não foi possível enviar o email. Tenta novamente.', isError: true);
    }
  }

  void _showDialog(String title, String content, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            color: isError ? Colors.red : const Color(0xFF1E3A8A),
          ),
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos o extendBodyBehindAppBar para o gradiente cobrir tudo
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
      ),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_reset,
                    size: 90,
                    color: Color(0xFF1A56DB),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Recuperar Senha',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Introduza o seu email para receber o link de recuperação.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF1A56DB), fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // Cartão Branco
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
                        const Text(
                          'Email de Registo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Color(0xFF1A56DB),
                              size: 22,
                            ),
                            hintText: 'exemplo@email.com',
                            filled: true,
                            fillColor: const Color(0xFFF0F7FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                              ? 'Insira um email válido'
                              : null,
                        ),
                        const SizedBox(height: 30),
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
                            onPressed: passwordReset,
                            child: const Text(
                              'Enviar Link',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
