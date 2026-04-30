import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssistantPage extends StatefulWidget {
  final String? initialPrompt; // ← NOVO
  const AssistantPage({super.key, this.initialPrompt}); // ← ATUALIZADO

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  late GenerativeModel _model;
  late ChatSession _chat;
  bool _isLoading = false;
  bool _aiReady = false;
  String? _chatId; // null = nova conversa ainda não guardada
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "anon";

  // ─── CORES ─────────────────────────────────────────────────────────────────
  static const primary      = Color(0xFF2563EB);
  static const primaryDark  = Color(0xFF1D4ED8);
  static const bgPage       = Color(0xFFF3F4F6);
  static const borderColor  = Color(0xFFE5E7EB);
  static const textDark     = Color(0xFF111827);
  static const textMuted    = Color(0xFF6B7280);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _setupAI();
    _checkAndLoadLastChat();

    // ── NOVO: preenche o campo se vier um prompt inicial do QuizDetailPage ──
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = widget.initialPrompt!;
      });
    }
  }

  Future<void> _checkAndLoadLastChat() async {
    // Por defeito, começa um novo chat. Mas se o utilizador fechar e abrir a app,
    // podíamos carregar o último aqui. Por agora, deixamos como Novo Chat.
  }

  Future<void> _saveMessage(Map<String, dynamic> msg) async {
    if (_uid == "anon") return;
    
    _chatId ??= "chat_${DateTime.now().millisecondsSinceEpoch}";
    
    final chatDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('ai_chats')
        .doc(_chatId);

    await chatDoc.set({
      'lastUpdate': FieldValue.serverTimestamp(),
      'title': _messages.isNotEmpty ? (_messages.first['text'] as String).characters.take(30).toString() : "Nova Conversa",
    }, SetOptions(merge: true));

    await chatDoc.collection('messages').add({
      ...msg,
      'serverTimestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _startNewChat() async {
    setState(() {
      _messages.clear();
      _chatId = null;
      _isLoading = false;
    });
    await _setupAI(); // reinicia a sessão do modelo
  }

  Future<void> _loadChat(String id) async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('ai_chats')
          .doc(id)
          .collection('messages')
          .orderBy('serverTimestamp')
          .get();

      final List<Map<String, dynamic>> loadedMessages = snap.docs.map((d) {
        final data = d.data();
        return {
          "role": data['role'],
          "text": data['text'],
          "time": data['time'],
        };
      }).toList();

      setState(() {
        _messages.clear();
        _messages.addAll(loadedMessages);
        _chatId = id;
        _isLoading = false;
      });

      // Reconstrói o histórico para o modelo Gemini
      final List<Content> geminiHistory = [];
      // Re-adiciona a instrução mestra (não guardada no Firestore para não duplicar)
      final String manualSafeQuest = await rootBundle.loadString('assets/conhecimento_safequest.txt');
      geminiHistory.add(Content.text("Tu és o SafeQuest Mentor... [Base: $manualSafeQuest]"));
      geminiHistory.add(Content.model([TextPart("Entendido!")]));
      
      for (var m in loadedMessages) {
        if (m['role'] == 'user') {
          geminiHistory.add(Content.text(m['text']));
        } else {
          geminiHistory.add(Content.model([TextPart(m['text'])]));
        }
      }

      _chat = _model.startChat(history: geminiHistory);
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
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
      final String manualSafeQuest =
          await rootBundle.loadString('assets/conhecimento_safequest.txt');
      
      // Fallback robusto para Web e dispositivos onde o dotenv falha
      final String envKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
      final String myKey = envKey.isNotEmpty ? envKey : 'AIzaSyCB7wRXxuXv6o0oaVwxY9OLh_emUhn_eJQ';

      if (myKey.isEmpty) {
        if (mounted) {
          setState(() {
            _messages.add({
              "role": "ai",
              "text": "⚠️ **Assistente Indisponível**\n\nO Mentor SafeQuest não está disponível de momento. Tenta novamente mais tarde.",
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

    final userMsg = {"role": "user", "text": text, "time": time};

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    // Guarda mensagem do utilizador
    await _saveMessage(userMsg);

    try {
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
      final aiMsg = {
        "role": "ai",
        "text": response.text ?? "Não consegui processar isso.",
        "time": DateFormat('HH:mm').format(DateTime.now()),
      };

      if (mounted) {
        setState(() {
          _messages.add(aiMsg);
          _isLoading = false;
        });
        _scrollToBottom();
      }
      
      // Guarda resposta da IA
      await _saveMessage(aiMsg);
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
    super.build(context); // necessário para AutomaticKeepAliveClientMixin
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
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
                      TextSpan(text: "Mentor ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark)),
                      TextSpan(text: "IA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: primary)),
                    ],
                  ),
                ),
                Text(
                  _chatId == null ? "Nova conversa" : "Conversa ativa",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF22C55E), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: textMuted),
            onPressed: () => _showHistoryBottomSheet(context),
          ),
        ],
      ),
    );
  }

  void _showHistoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Histórico de Conversas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                TextButton.icon(
                  onPressed: () { Navigator.pop(ctx); _startNewChat(); },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Novo"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_uid)
                    .collection('ai_chats')
                    .orderBy('lastUpdate', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return const Center(child: Text("Erro ao carregar histórico"));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("Nenhuma conversa guardada."));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final id = docs[i].id;
                      final title = d['title'] ?? "Sem título";
                      final date = d['lastUpdate'] != null ? DateFormat('dd/MM HH:mm').format((d['lastUpdate'] as Timestamp).toDate()) : "";

                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(date, style: const TextStyle(fontSize: 11)),
                        trailing: id == _chatId ? const Icon(Icons.check_circle, color: primary, size: 16) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _loadChat(id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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