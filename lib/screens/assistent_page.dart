import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:connectivity_plus/connectivity_plus.dart';

class AssistantPage extends StatefulWidget {
  final String? initialPrompt; // ← NOVO
  const AssistantPage({super.key, this.initialPrompt}); // ← ATUALIZADO

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  late GenerativeModel _model;
  late ChatSession _chat;
  bool _isLoading = false;
  bool _aiReady = false;

  // ─── CORES ─────────────────────────────────────────────────────────────────
  static const primary      = Color(0xFF2563EB);
  static const primaryDark  = Color(0xFF1D4ED8);
  static const bgPage       = Color(0xFFF3F4F6);
  static const borderColor  = Color(0xFFE5E7EB);
  static const textDark     = Color(0xFF111827);
  static const textMuted    = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _setupAI();

    // ── NOVO: preenche o campo se vier um prompt inicial do QuizDetailPage ──
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = widget.initialPrompt!;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _setupAI() async {
    try {
      // Verifica conectividade antes de inicializar
      final connectivity = await Connectivity().checkConnectivity();
      final hasInternet = connectivity.any((r) => r != ConnectivityResult.none);
      
      if (!hasInternet) {
        if (mounted) {
          setState(() {
            _messages.add({
              "role": "ai",
              "text": "⚠️ **Sem ligação à internet**\n\nO Assistente IA necessita de ligação à internet para funcionar. Por favor, verifica a tua ligação e tenta novamente.",
              "time": DateFormat('HH:mm').format(DateTime.now()),
            });
          });
        }
        return;
      }

      final String manualSafeQuest =
          await rootBundle.loadString('assets/conhecimento_safequest.txt');
      final String myKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();

      if (myKey.isEmpty) {
        if (mounted) {
          setState(() {
            _messages.add({
              "role": "ai",
              "text": "⚠️ **Erro de configuração**\n\nA chave da API não foi encontrada. Contacta o suporte.",
              "time": DateFormat('HH:mm').format(DateTime.now()),
            });
          });
        }
        return;
      }

      _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: myKey);

      final String instrucaoMestra = """
        A partir de agora, tu és o SafeQuest Mentor, um perito em cibersegurança.
        O teu objetivo é ensinar estudantes de forma didática e em Português de Portugal.
        
        AQUI ESTÁ A TUA BASE DE CONHECIMENTO OBRIGATÓRIA:
        $manualSafeQuest
        
        REGRA MÁXIMA: Usa esta base de conhecimento para responder sempre que possível.
        Se perguntarem algo que não está no manual, responde com o teu conhecimento geral, mas sempre focado em segurança defensiva.
      """;

      _chat = _model.startChat(history: [
        Content.text(instrucaoMestra),
        Content.model([
          TextPart("Entendido! Memorizei o Manual da SafeQuest. Estou pronto para ensinar os alunos. Aguardo a primeira pergunta!")
        ]),
      ]);

      if (mounted) {
        setState(() {
          _aiReady = true;
          _messages.add({
            "role": "ai",
            "text": "Olá! Sou o **Mentor SafeQuest** 👋\n\nEstou aqui para te ajudar com qualquer dúvida sobre segurança digital. Como posso ajudar-te hoje?",
            "time": DateFormat('HH:mm').format(DateTime.now()),
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("🚨 ERRO AI SETUP: $e");
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "ai",
            "text": "⚠️ **Erro ao inicializar o Assistente**\n\nNão foi possível conectar ao serviço de IA. Verifica a tua ligação à internet e reinicia a app.",
            "time": DateFormat('HH:mm').format(DateTime.now()),
          });
        });
      }
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final time = DateFormat('HH:mm').format(DateTime.now());
    _controller.clear();

    setState(() {
      _messages.add({"role": "user", "text": text, "time": time});
      _isLoading = true;
    });
    _scrollToBottom();

    // Verifica internet antes de enviar
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasInternet = connectivity.any((r) => r != ConnectivityResult.none);
      
      if (!hasInternet) {
        if (mounted) {
          setState(() {
            _messages.add({
              "role": "ai",
              "text": "⚠️ **Sem ligação à internet**\n\nNão é possível enviar a mensagem sem internet. Verifica a tua ligação e tenta novamente.",
              "time": time,
            });
            _isLoading = false;
          });
          _scrollToBottom();
        }
        return;
      }

      // Se IA não foi inicializada, tenta novamente
      if (!_aiReady) {
        await _setupAI();
        if (!_aiReady) {
          if (mounted) {
            setState(() {
              _messages.add({
                "role": "ai",
                "text": "⚠️ O assistente não conseguiu inicializar. Verifica a tua ligação à internet e tenta novamente.",
                "time": time,
              });
              _isLoading = false;
            });
            _scrollToBottom();
          }
          return;
        }
      }

      final response = await _chat.sendMessage(Content.text(text));
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "ai",
            "text": response.text ?? "Não consegui processar isso.",
            "time": DateFormat('HH:mm').format(DateTime.now()),
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("🚨 ERRO AI SEND: $e");
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "ai",
            "text": "❌ **Não foi possível responder**\n\nOcorreu um erro de ligação. Verifica a tua internet e tenta novamente.",
            "time": time,
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(child: _messageList()),
            if (_isLoading) _typingIndicator(),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 22),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: "Assistente ",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      TextSpan(
                        text: "IA",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Sempre disponível · SafeQuest",
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: primary, size: 12),
                SizedBox(width: 4),
                Text(
                  "Seguro",
                  style: TextStyle(
                    fontSize: 11,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── LISTA DE MENSAGENS ────────────────────────────────────────────────────
  Widget _messageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _chatBubble(msg["role"] == "user", msg["text"], msg["time"]);
      },
    );
  }

  Widget _chatBubble(bool isUser, String text, String time) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 16,
        left: isUser ? 52 : 0,
        right: isUser ? 0 : 52,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
            child: Text(
              isUser ? "Tu" : "Mentor SafeQuest",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isUser ? primary : textMuted,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isUser ? primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: isUser ? null : Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: isUser
                      ? primary.withOpacity(0.22)
                      : const Color(0x0A000000),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _buildText(text, isUser),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
            child: Text(
              time,
              style: const TextStyle(fontSize: 11, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(String text, bool isUser) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
          color: isUser ? Colors.white : const Color(0xFF1F2937),
          fontSize: 14.5,
          height: 1.55,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: primary,
                    backgroundColor: borderColor,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "A escrever...",
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bgPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: textDark,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: "Pergunte sobre segurança...",
                  hintStyle: TextStyle(color: textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
                onSubmitted: (_) => _handleSend(),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _handleSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isLoading
                      ? [Colors.grey.shade300, Colors.grey.shade300]
                      : [primary, primaryDark],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: primary.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                _isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.send_rounded,
                color: _isLoading ? Colors.grey : Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}