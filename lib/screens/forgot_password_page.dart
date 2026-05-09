import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey         = GlobalKey<FormState>();
  bool  _loading         = false;

  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      _showDialog(
        '📧 Email enviado!',
        'Se este email estiver registado, receberás um link para redefinir a palavra-passe.\n\nVerifica também a pasta de Spam.\nO link é válido por 1 hora.',
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'user-not-found':
          // Por segurança, não revelamos se o email existe ou não
          _showDialog(
            '📧 Email enviado!',
            'Se este email estiver registado, receberás um link para redefinir a palavra-passe.\n\nVerifica também a pasta de Spam.',
            isSuccess: true,
          );
          return;
        case 'invalid-email':
          msg = 'Email inválido. Verifica e tenta novamente.';
          break;
        case 'too-many-requests':
          msg = 'Muitos pedidos. Aguarda alguns minutos e tenta novamente.';
          break;
        default:
          msg = 'Não foi possível enviar o email. Tenta novamente.';
      }
      _showDialog('Erro', msg);
    } catch (_) {
      if (!mounted) return;
      _showDialog('Erro', 'Não foi possível enviar o email. Verifica a tua ligação e tenta novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDialog(String title, String content, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            color: isSuccess ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isSuccess) Navigator.pop(context); // Volta para o login após sucesso
            },
            child: Text(
              isSuccess ? 'Ir para o Login' : 'OK',
              style: const TextStyle(fontWeight: FontWeight.bold, color: _primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryDeep),
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Ícone
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, size: 60, color: _primary),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  const Text(
                    'Recuperar Senha',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDeep),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Introduz o teu email e enviaremos um link para redefinires a palavra-passe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 36),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label
                        const Text(
                          'Email de Registo',
                          style: TextStyle(fontWeight: FontWeight.w600, color: _primaryDeep, fontSize: 14),
                        ),
                        const SizedBox(height: 10),

                        // Campo email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: _primaryDeep, fontSize: 15),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined, color: _primary, size: 20),
                            hintText: 'exemplo@email.com',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF0F7FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: _primary, width: 1.5),
                            ),
                            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Insere o teu email';
                            if (!v.contains('@') || !v.contains('.')) return 'Email inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Botão
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                              elevation: 0,
                            ),
                            icon: _loading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              _loading ? 'A enviar...' : 'Enviar Link de Recuperação',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _loading ? null : _sendReset,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: const Column(
                      children: [
                        Row(children: [
                          Icon(Icons.info_outline_rounded, color: _primary, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('O link expira em 1 hora.', style: TextStyle(color: _primaryDeep, fontSize: 12, fontWeight: FontWeight.w600))),
                        ]),
                        SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.mark_email_read_outlined, color: _primary, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Verifica também a pasta de Spam.', style: TextStyle(color: _primaryDeep, fontSize: 12, fontWeight: FontWeight.w600))),
                        ]),
                        SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.security_rounded, color: _primary, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Por segurança, o link só pode ser usado uma vez.', style: TextStyle(color: _primaryDeep, fontSize: 12, fontWeight: FontWeight.w600))),
                        ]),
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
