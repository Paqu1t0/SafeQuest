import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  late GenerativeModel _model;
  late ChatSession _chat;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupAI();
  }

  Future<void> _setupAI() async {
    print("📚 A LER O MANUAL DA SAFEQUEST...");

    try {
      // 1. Lê o ficheiro de texto dos assets
      final String manualSafeQuest = await rootBundle.loadString('assets/conhecimento_safequest.txt');

      // 2. Vai buscar a chave ao .env
      final String myKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();

      // 3. Inicia o modelo
      _model = GenerativeModel(
        model: 'gemini-2.5-flash', 
        apiKey: myKey,
      );
      
      // 4. Injeta a personalidade e o manual de uma só vez (RAG)
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
        Content.model([TextPart("Entendido! Memorizei o Manual da SafeQuest. Estou pronto para ensinar os alunos com base nas regras que me deste. Aguardo a primeira pergunta!")]),
      ]);
      
      // 5. Mostra a mensagem no ecrã quando estiver pronta
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "ai",
            "text": "Olá! Sou o Mentor SafeQuest. Acabei de rever os meus manuais. Qual é a tua dúvida de segurança de hoje?",
            "time": DateFormat('HH:mm').format(DateTime.now()),
          });
        });
      }
      
    } catch (e) {
      print("🚨 ERRO AO CARREGAR IA OU MANUAL: $e");
    }
  }

  Future<void> _handleSend() async {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text;
    final time = DateFormat('HH:mm').format(DateTime.now());

    setState(() {
      _messages.add({"role": "user", "text": userText, "time": time});
      _isLoading = true;
    });
    _controller.clear();

    try {
      final response = await _chat.sendMessage(Content.text(userText));
      
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "ai", 
            "text": response.text ?? "Não consegui processar isso.",
            "time": DateFormat('HH:mm').format(DateTime.now()),
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({"role": "ai", "text": "Erro de ligação: $e", "time": time});
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _chatBubble(msg["role"] == "user", msg["text"], msg["time"]);
                },
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Assistente IA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Sempre disponível", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(bool isUser, String text, String time) {
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            text,
            style: TextStyle(color: isUser ? Colors.white : Colors.black, height: 1.4),
          ),
        ),
        Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Pergunte sobre segurança...",
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              height: 50, width: 50,
              decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}