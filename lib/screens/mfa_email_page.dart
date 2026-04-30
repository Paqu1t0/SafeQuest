import 'dart:async'; // NOVO: Para o temporizador
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Mantemos a segurança!
import 'package:projeto_safequest/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MFAEmailPage extends StatefulWidget {
  const MFAEmailPage({super.key});

  @override
  State<MFAEmailPage> createState() => _MFAEmailPageState();
}

class _MFAEmailPageState extends State<MFAEmailPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  String _codigoGerado = ""; // Vai guardar o código real gerado pela app

  // NOVO: Variáveis para o temporizador de reenvio
  Timer? _timer;
  int _remainingSeconds = 60; // 60 segundos por defeito
  bool _canResend = false;

  static DateTime? _lastEmailSentTime;

  @override
  void initState() {
    super.initState();
    // Envia o código automaticamente quando o ecrã abre, 
    // mas apenas se não tiver enviado nos últimos 30 segundos
    // para evitar duplicação se o widget for recriado pelo StreamBuilder
    if (_lastEmailSentTime == null || DateTime.now().difference(_lastEmailSentTime!).inSeconds > 30) {
      _lastEmailSentTime = DateTime.now();
      _enviarCodigoEmail(isResend: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancelamos o temporizador para evitar erros de memória
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ================= TEMPORIZADOR DE REENVIO =================
  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel(); // Cancela qualquer timer anterior

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  // ================= ENVIO REAL VIA EMAILJS (MANTEMOS A SEGURANÇA) =================
  Future<void> _enviarCodigoEmail({required bool isResend}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    if (isResend) {
      setState(() => _isLoading = true);
    }

    // 1. Gera um código aleatório de 6 dígitos
    _codigoGerado = (Random().nextInt(900000) + 100000).toString();

    try {
      // 2. Guarda na Base de Dados (Para auditoria do TFC)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'mfa_code': _codigoGerado,
        'mfa_timestamp': FieldValue.serverTimestamp(),
        'mfa_verified': false,
      }, SetOptions(merge: true));

      // 3. Resolve as chaves (protegendo contra cache antigo na Web onde a string pode vir vazia em vez de nula)
      final String serviceId = (dotenv.env['EMAILJS_SERVICE_ID'] ?? '').trim().isNotEmpty ? dotenv.env['EMAILJS_SERVICE_ID']!.trim() : 'service_rt72hfc';
      final String templateId = (dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '').trim().isNotEmpty ? dotenv.env['EMAILJS_TEMPLATE_ID']!.trim() : 'template_4j7usel';
      final String publicKey = (dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '').trim().isNotEmpty ? dotenv.env['EMAILJS_PUBLIC_KEY']!.trim() : 'b1RGSw2ImcD06VoT5';
      final String privateKey = (dotenv.env['EMAILJS_PRIVATE_KEY'] ?? '').trim().isNotEmpty ? dotenv.env['EMAILJS_PRIVATE_KEY']!.trim() : 'syskG7nDtzV1evVHVzI17';

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      
      final Map<String, dynamic> payload = {
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': user.email,
          'mfa_code': _codigoGerado,
        }
      };

      // Na Web, o EmailJS REJEITA pedidos com accessToken/PrivateKey por segurança (CORS).
      // No Mobile, alguns templates podem exigir a Private Key para funcionar.
      if (!kIsWeb) {
        payload['accessToken'] = privateKey;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isLoading = false;
        });
        // Inicia ou reinicia o temporizador após envio bem-sucedido
        _startTimer();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro EmailJS: ${response.body}")));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro de ligação: $e")));
      }
    }
  }

  // ================= VALIDAÇÃO DO CÓDIGO =================
  Future<void> _verificarEEntrar() async {
    String codigoIntroduzido = _controllers.map((c) => c.text).join();
    
    // Verifica se os 6 campos estão preenchidos
    if (codigoIntroduzido.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insere o código completo de 6 dígitos.")));
      return;
    }

    if (codigoIntroduzido == _codigoGerado) {
      setState(() => _isLoading = true);
      
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;

        // Marca na BD que o MFA foi validado com sucesso usando set com merge
        // Isto previne erros caso o documento do utilizador ainda não exista
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'mfa_verified': true,
        }, SetOptions(merge: true));

        // ── NOVO: Guarda sessão MFA no SharedPreferences (30 dias) ──
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('mfa_verified_at', DateTime.now().millisecondsSinceEpoch);
        await prefs.setString('mfa_uid', uid ?? '');

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthGate()), (route) => false);
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro ao verificar código: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Código incorreto! Verifica o teu e-mail."), backgroundColor: Colors.red),
      );
    }
  }

  // ================= INTERFACE VISUAL =================
  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? "utilizador@email.com";
    // Cor de fundo azul claro
    const backgroundColor = Color(0xFFF1F7FF); 
    // Cor azul escuro para ícones e botões
    const primaryColor = Color(0xFF1A56DB);

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  60).clamp(0.0, double.infinity),
            ),
            child: Column(
                children: [
                  // 1. CABEÇALHO COM BOTÃO VOLTAR
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => FirebaseAuth.instance.signOut(),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back_ios, size: 16, color: primaryColor),
                            Text(" Voltar", style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // 2. LOGO SAFEQUEST E TÍTULO
                  Column(
                    children: [
                      Image.asset('assets/icon/icon.png', height: 180),
                      const SizedBox(height: 30),
                      const Text(
                        "Verifique o seu Email",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          children: [
                            const TextSpan(text: "Enviámos um código de 6 dígitos para "),
                            TextSpan(text: userEmail, style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // 3. CARTÃO BRANCO CENTRAL (CAMPOS DE PIN E REENVIO)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        // CAMPOS DE PIN (6 campos arredondados) — responsivos
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final boxWidth = ((constraints.maxWidth - 50) / 6).clamp(36.0, 50.0);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (index) => _otpBox(index, boxWidth)),
                            );
                          },
                        ),
                        const SizedBox(height: 25),
                        // TEXTO DE REENVIO COM TEMPORIZADOR
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _canResend 
                            ? GestureDetector(
                                key: const ValueKey(1),
                                onTap: _isLoading ? null : () => _enviarCodigoEmail(isResend: true),
                                child: const Text(
                                  "Reenviar código agora",
                                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              )
                            : Text(
                                key: const ValueKey(2),
                                "Reenviar código em ${_remainingSeconds}s",
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // 4. CARTÕES DE INFORMAÇÃO INFERIORES
                  _buildInfoCard(
                    icon: Icons.shield_outlined,
                    title: "Segurança da sua conta",
                    text: "Este código expira em 10 minutos. Nunca partilhe o código com ninguém.",
                    primaryColor: primaryColor,
                  ),
                  
                  const SizedBox(height: 10),

                  // Info sobre sessão de 30 dias
                  _buildInfoCard(
                    icon: Icons.schedule_rounded,
                    title: "Sessão de 30 dias",
                    text: "Após verificar, não precisará de inserir o código durante 30 dias neste dispositivo.",
                    primaryColor: primaryColor,
                  ),

                  const SizedBox(height: 30),

                  // 5. INDICADOR DE CARREGAMENTO (Auto-Submit)
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: primaryColor))
                  else
                    const SizedBox(height: 55),
                ],
              ),
          ),
        ),
      ),
    );
  }

  // WIDGET PARA OS CAMPOS DE PIN — responsivo e perfeitamente centrado
  Widget _otpBox(int index, double boxWidth) {
    return SizedBox(
      width: boxWidth,
      height: boxWidth * 1.25, // Proporção mais retangular
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center, // Centra na vertical
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.zero, // Remove padding extra que corta os números
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15), 
            borderSide: const BorderSide(color: Color(0xFFD1E3F5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15), 
            borderSide: const BorderSide(color: Color(0xFFD1E3F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15), 
            borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          } else if (value.isNotEmpty && index == 5) {
            // Unfocus the keyboard automatically
            _focusNodes[index].unfocus();
            // Automatically verify the code
            _verificarEEntrar();
          }
        },
      ),
    );
  }

  // WIDGET PARA OS CARTÕES DE INFO
  Widget _buildInfoCard({
    required IconData icon, 
    required String title, 
    required String text, 
    required Color primaryColor,
    bool isDemo = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDemo ? const Color(0xFFFFF8E1) : Colors.white, // Amarelo claro para demo
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}