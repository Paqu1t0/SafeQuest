import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:projeto_safequest/services/app_settings.dart';
import 'package:projeto_safequest/screens/quiz_result_dialog.dart';
import 'package:projeto_safequest/screens/badges_service.dart';
import 'package:projeto_safequest/services/sound_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE DADOS
// ─────────────────────────────────────────────────────────────────────────────

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// BANCO DE PERGUNTAS (exemplo – substitui/expande conforme necessário)
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<QuizQuestion>> _questionBank = {
  'Phishing': [
    QuizQuestion(
      question: 'Qual é o sinal mais comum de um email de phishing?',
      options: [
        'Linguagem urgente solicitando ação imediata',
        'Formatação profissional',
        'Ortografia e gramática corretas',
        'Logotipo da empresa',
      ],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'O que deves fazer ao receber um link suspeito por email?',
      options: [
        'Clicar para verificar se é legítimo',
        'Encaminhar para amigos',
        'Não clicar e reportar como phishing',
        'Responder a pedir mais informações',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Qual destas práticas ajuda a identificar um site de phishing?',
      options: [
        'Verificar se o URL começa com https://',
        'Confiar no design visual do site',
        'Verificar se tem muitas imagens',
        'Ver se tem muitos comentários positivos',
      ],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'O que é "spear phishing"?',
      options: [
        'Phishing genérico enviado em massa',
        'Ataque direcionado a uma pessoa específica',
        'Phishing feito por SMS',
        'Um tipo de vírus informático',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Qual das seguintes é uma técnica comum usada em emails de phishing?',
      options: [
        'Usar endereços de email com pequenos erros tipográficos',
        'Usar o teu nome correto',
        'Enviar apenas em horário comercial',
        'Incluir o número de telefone real da empresa',
      ],
      correctIndex: 0,
    ),
  ],
  'Palavras-passe': [
    QuizQuestion(
      question: 'Qual é a característica de uma palavra-passe segura?',
      options: [
        'Usar o teu nome e data de nascimento',
        'Ter pelo menos 12 caracteres com letras, números e símbolos',
        'Usar a mesma para todos os serviços',
        'Ser fácil de memorizar como "123456"',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Com que frequência deves alterar as tuas palavras-passe?',
      options: [
        'Nunca, se forem seguras',
        'Apenas quando suspeitas de comprometimento',
        'Regularmente e sempre que haja suspeita de violação',
        'Todos os dias',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'O que é um gestor de palavras-passe?',
      options: [
        'Uma pessoa que gere as tuas contas',
        'Uma ferramenta que armazena e gera palavras-passe seguras',
        'Um ficheiro de texto com as tuas passwords',
        'Uma extensão que remove palavras-passe',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'O que é a autenticação de dois fatores (2FA)?',
      options: [
        'Usar duas palavras-passe diferentes',
        'Um segundo método de verificação além da password',
        'Fazer login em dois dispositivos ao mesmo tempo',
        'Ter duas contas de email',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Qual destas palavras-passe é mais segura?',
      options: [
        'password123',
        'joao1990',
        'Tr0ub4dor&3!xK',
        'qwerty',
      ],
      correctIndex: 2,
    ),
  ],
  'Redes Sociais': [
    QuizQuestion(
      question: 'Qual a melhor prática de privacidade nas redes sociais?',
      options: [
        'Partilhar tudo publicamente',
        'Limitar quem pode ver as tuas publicações',
        'Aceitar todos os pedidos de amizade',
        'Usar o nome real sempre',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'O que deves evitar partilhar nas redes sociais?',
      options: [
        'Fotos de paisagens',
        'Artigos de notícias',
        'Localização em tempo real e dados pessoais',
        'Receitas de culinária',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'O que é "engenharia social" no contexto das redes sociais?',
      options: [
        'Criar conteúdo de engenharia',
        'Manipular pessoas para obter informações confidenciais',
        'Gerir grupos de trabalho online',
        'Partilhar posts sobre ciência',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Como deves reagir a um pedido de amizade de um desconhecido?',
      options: [
        'Aceitar sempre para ter mais seguidores',
        'Aceitar se tiverem amigos em comum',
        'Verificar o perfil e recusar se parecer suspeito',
        'Ignorar todos os pedidos',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'O que é "doxxing"?',
      options: [
        'Partilhar documentos de trabalho online',
        'Publicar informações privadas de alguém sem consentimento',
        'Criar documentação para projetos',
        'Um tipo de formato de ficheiro',
      ],
      correctIndex: 1,
    ),
  ],
  'Segurança Web': [
    QuizQuestion(
      question: 'O que significa HTTPS num endereço web?',
      options: [
        'O site tem muitas imagens',
        'A ligação é encriptada e mais segura',
        'O site é gratuito',
        'O site é muito popular',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'O que é um ataque de "Man-in-the-Middle"?',
      options: [
        'Um jogo online multiplayer',
        'Interceção de comunicações entre duas partes',
        'Um tipo de firewall',
        'Um método de encriptação',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Qual a melhor prática ao usar Wi-Fi público?',
      options: [
        'Aceder ao internet banking normalmente',
        'Partilhar ficheiros livremente',
        'Usar uma VPN para proteger a ligação',
        'Desativar o antivírus para maior velocidade',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'O que é um cookie no contexto web?',
      options: [
        'Um tipo de vírus informático',
        'Um pequeno ficheiro que guarda informação do utilizador no browser',
        'Um método de pagamento online',
        'Uma extensão do browser',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'O que é um ataque de "SQL Injection"?',
      options: [
        'Injetar código malicioso numa base de dados através de formulários web',
        'Um tipo de vacina digital',
        'Um método de encriptação de dados',
        'Uma técnica de otimização de websites',
      ],
      correctIndex: 0,
    ),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  final String tema;
  final String dificuldade;
  final int nivel;

  const QuizScreen({
    super.key,
    this.tema = 'Phishing',
    this.dificuldade = 'Iniciante',
    this.nivel = 1,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // ── cores da app ──────────────────────────────────────────────────────────
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _bgColor     = Color(0xFFF8FAFC);

  // ── estado do quiz ────────────────────────────────────────────────────────
  late List<QuizQuestion> _questions;
  int _currentIndex     = 0;
  int? _selectedOption;
  bool _answered        = false;
  int _correctAnswers   = 0;

  // ── cronómetro ────────────────────────────────────────────────────────────
  int _secondsElapsed   = 0;
  Timer? _timer;

  // ── animação da barra de progresso ────────────────────────────────────────
  late AnimationController _progressController;
  late Animation<double>    _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Carrega perguntas do tema (ou usa Phishing por defeito)
    final allQs = _questionBank[widget.tema] ?? _questionBank['Phishing']!;
    _questions  = List.of(allQs)..shuffle();
    // Limita a 5 perguntas por quiz
    if (_questions.length > 5) _questions = _questions.sublist(0, 5);

    // Animação da barra
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: _progressValue)
        .animate(CurvedAnimation(parent: _progressController, curve: Curves.easeInOut));
    _progressController.forward();

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  double get _progressValue => (_currentIndex + 1) / _questions.length;

  void _startTimer() {
    _secondsElapsed = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsElapsed++);
    });
  }

  String get _formattedTime {
    final m = _secondsElapsed ~/ 60;
    final s = _secondsElapsed % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }


  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      // Anima barra para o próximo valor
      final oldVal = _progressValue;
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered       = false;
      });
      _progressController.reset();
      _progressAnimation = Tween<double>(begin: oldVal, end: _progressValue)
          .animate(CurvedAnimation(parent: _progressController, curve: Curves.easeInOut));
      _progressController.forward();
    } else {
      _timer?.cancel();
      _saveResultAndShowSummary();
    }
  }

  // ── guardar no Firestore ──────────────────────────────────────────────────

  // Guarda as respostas dadas pelo utilizador (índice por pergunta)
  final List<int?> _userAnswers = [];

  void _selectOptionAndRecord(int index) {
    if (_answered) return;
    _userAnswers.add(index);
    final isCorrect = index == _questions[_currentIndex].correctIndex;

    // ── Som de feedback ───────────────────────────────────────────────────
    final soundEnabled =
        context.read<AppSettings>().soundEnabled;
    if (soundEnabled) {
      if (isCorrect) {
        SoundService.playCorrect();
      } else {
        SoundService.playWrong();
      }
    }

    setState(() {
      _selectedOption = index;
      _answered       = true;
      if (isCorrect) _correctAnswers++;
    });
  }

  Future<void> _saveResultAndShowSummary() async {
    final user = FirebaseAuth.instance.currentUser;
    final percent = ((_correctAnswers / _questions.length) * 100).round();

    final pointsMap = {'Iniciante': 50, 'Intermédio': 100, 'Avançado': 200};
    final basePoints = pointsMap[widget.dificuldade] ?? 50;
    final points     = (basePoints * (_correctAnswers / _questions.length)).round();
    final timeStr    = _formattedTime;
    final moedasGanhas = percent >= 70 ? 100 : 50; // calcula antes

    final questionsData = List.generate(_questions.length, (i) {
      final q          = _questions[i];
      final userAnswer = i < _userAnswers.length ? _userAnswers[i] : null;
      return {
        'question'    : q.question,
        'options'     : q.options,
        'correctIndex': q.correctIndex,
        'userAnswer'  : userAnswer,
        'isCorrect'   : userAnswer == q.correctIndex,
      };
    });

    final wrongQuestions =
        questionsData.where((q) => q['isCorrect'] != true).toList();

    String? newBadge;

    // ── Mostra o popup IMEDIATAMENTE, sem esperar o Firestore ────────────────
    if (!mounted) return;

    final soundEnabled = context.read<AppSettings>().soundEnabled;
    if (soundEnabled) {
      if (percent >= 70) SoundService.playVictory();
      else SoundService.playFail();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => QuizResultDialog(
        percent       : percent,
        points        : points,
        correct       : _correctAnswers,
        total         : _questions.length,
        timeStr       : timeStr,
        tema          : widget.tema,
        newBadge      : null, // emblema atualiza depois
        wrongQuestions: wrongQuestions,
        moedasGanhas  : moedasGanhas,
      ),
    );

    // ── Firestore em paralelo (não bloqueia o UI) ────────────────────────────
    if (user != null) {
      try {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        // Todas as escritas em paralelo — muito mais rápido
        await Future.wait([
          userRef.collection('quiz_results').add({
            'theme'      : widget.tema,
            'dificuldade': widget.dificuldade,
            'nivel'      : widget.nivel,
            'percent'    : percent,
            'points'     : points,
            'correct'    : _correctAnswers,
            'total'      : _questions.length,
            'time'       : timeStr,
            'date'       : FieldValue.serverTimestamp(),
            'questions'  : questionsData,
          }),
          userRef.update({
            'pontos': FieldValue.increment(points),
            'moedas': FieldValue.increment(moedasGanhas),
          }),
        ]);

        // Emblemas (pode correr depois)
        newBadge = await BadgesService.checkAndUnlock(
          tema   : widget.tema,
          percent: percent,
        );
      } catch (_) {}
    }
  }

  // ── cor do option card ────────────────────────────────────────────────────

  Color _optionBorderColor(int index) {
    if (!_answered) return const Color(0xFFE5E7EB);
    if (index == _questions[_currentIndex].correctIndex) {
      return const Color(0xFF16A34A);
    }
    if (index == _selectedOption) return const Color(0xFFDC2626);
    return const Color(0xFFE5E7EB);
  }

  Color _optionFillColor(int index) {
    if (!_answered) return Colors.white;
    if (index == _questions[_currentIndex].correctIndex) {
      return const Color(0xFFF0FDF4);
    }
    if (index == _selectedOption) return const Color(0xFFFEF2F2);
    return Colors.white;
  }

  Color _optionTextColor(int index) {
    if (!_answered) return _primaryDeep;
    if (index == _questions[_currentIndex].correctIndex) {
      return const Color(0xFF16A34A);
    }
    if (index == _selectedOption) return const Color(0xFFDC2626);
    return Colors.grey;
  }

  Widget _optionIcon(int index) {
    if (!_answered) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
      );
    }
    if (index == _questions[_currentIndex].correctIndex) {
      return const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22);
    }
    if (index == _selectedOption) {
      return const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22);
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryDeep, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Quiz: ${widget.tema}',
          style: const TextStyle(
            color: _primaryDeep,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _TimerBadge(seconds: _secondsElapsed),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de progresso ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Questão ${_currentIndex + 1} de ${_questions.length}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_secondsElapsed}s',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Conteúdo ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pergunta
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _primaryDeep,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Opções
                  ...List.generate(
                    q.options.length,
                    (index) => _buildOptionCard(index, q.options[index]),
                  ),

                  const SizedBox(height: 24),

                  // Explicação ao responder
                  if (_answered) _buildFeedbackCard(q),

                  const SizedBox(height: 16),

                  // Botão próxima questão / finalizar
                  if (_answered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _nextQuestion,
                        child: Text(
                          _currentIndex < _questions.length - 1
                              ? 'Próxima Questão'
                              : 'Ver Resultado',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: null, // desativado até selecionar resposta
                        child: const Text(
                          'Próxima Questão',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── option card ───────────────────────────────────────────────────────────

  Widget _buildOptionCard(int index, String text) {
    return GestureDetector(
      onTap: () => _selectOptionAndRecord(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _optionFillColor(index),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _optionBorderColor(index),
            width: _answered && (index == _questions[_currentIndex].correctIndex || index == _selectedOption) ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _optionIcon(index),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _optionTextColor(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── feedback card ─────────────────────────────────────────────────────────

  Widget _buildFeedbackCard(QuizQuestion q) {
    final isCorrect = _selectedOption == q.correctIndex;
    final color     = isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bgColor   = isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final icon      = isCorrect ? Icons.check_circle_rounded : Icons.info_rounded;
    final title     = isCorrect ? 'Correto! 🎉' : 'Resposta Incorreta';
    final subtitle  = isCorrect
        ? 'Muito bem! Continua assim.'
        : 'A resposta certa era: "${q.options[q.correctIndex]}"';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET DO TEMPORIZADOR (canto superior direito)
// ─────────────────────────────────────────────────────────────────────────────

class _TimerBadge extends StatelessWidget {
  final int seconds;
  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 4),
          Text(
            '${seconds}s',
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}