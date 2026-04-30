import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:projeto_safequest/services/app_settings.dart';
import 'package:projeto_safequest/screens/quiz_result_dialog.dart';
import 'package:projeto_safequest/screens/badges_service.dart';
import 'package:projeto_safequest/services/sound_service.dart';
import 'package:projeto_safequest/screens/daily_missions_service.dart';
import 'package:projeto_safequest/screens/coin_animation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TIPOS DE QUIZ
// ─────────────────────────────────────────────────────────────────────────────
enum QuizType { normal, tempo, vf }

// ─────────────────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────────────────
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final bool isVF; // se é questão V/F

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.isVF = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// BANCO DE PERGUNTAS — Normal + V/F por tema
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<QuizQuestion>> _questionBank = {
  'Phishing': [
    QuizQuestion(question: 'Qual é o sinal mais comum de um email de phishing?', options: ['Linguagem urgente solicitando ação imediata','Formatação profissional','Ortografia e gramática corretas','Logotipo da empresa'], correctIndex: 0),
    QuizQuestion(question: 'O que deves fazer ao receber um link suspeito por email?', options: ['Clicar para verificar','Encaminhar para amigos','Não clicar e reportar','Responder a pedir mais informações'], correctIndex: 2),
    QuizQuestion(question: 'Qual destas práticas ajuda a identificar um site de phishing?', options: ['Verificar se começa com https://','Confiar no design visual','Verificar se tem muitas imagens','Ver comentários positivos'], correctIndex: 0),
    QuizQuestion(question: 'O que é "spear phishing"?', options: ['Phishing genérico em massa','Ataque direcionado a uma pessoa','Phishing por SMS','Um tipo de vírus'], correctIndex: 1),
    QuizQuestion(question: 'Qual técnica é comum em emails de phishing?', options: ['Endereços com erros tipográficos','Usar o teu nome correto','Enviar só em horário comercial','Incluir telefone real da empresa'], correctIndex: 0),
    QuizQuestion(question: 'O que é "vishing"?', options: ['Phishing por email','Phishing por chamada telefónica','Phishing por SMS','Phishing por redes sociais'], correctIndex: 1),
    QuizQuestion(question: 'Qual é o objetivo principal do phishing?', options: ['Instalar jogos','Roubar dados sensíveis','Melhorar a segurança','Partilhar conteúdo'], correctIndex: 1),
    QuizQuestion(question: 'Um email legítimo de banco pede normalmente:', options: ['A tua senha completa','Os teus dados de cartão','Que atualize dados num link','Nenhuma destas'], correctIndex: 3),
  ],
  'Palavras-passe': [
    QuizQuestion(question: 'Qual é a característica de uma palavra-passe segura?', options: ['Nome e data de nascimento','≥12 caracteres com letras, números e símbolos','A mesma para todos os serviços','Fácil de memorizar como "123456"'], correctIndex: 1),
    QuizQuestion(question: 'Com que frequência deves alterar as tuas palavras-passe?', options: ['Nunca','Apenas quando suspeitas','Regularmente e perante suspeita','Todos os dias'], correctIndex: 2),
    QuizQuestion(question: 'O que é um gestor de palavras-passe?', options: ['Uma pessoa que gere contas','Ferramenta que armazena e gera passwords','Um ficheiro de texto','Uma extensão que remove passwords'], correctIndex: 1),
    QuizQuestion(question: 'O que é a autenticação de dois fatores (2FA)?', options: ['Usar duas passwords','Segundo método além da password','Login em dois dispositivos','Ter duas contas'], correctIndex: 1),
    QuizQuestion(question: 'Qual destas passwords é mais segura?', options: ['password123','joao1990','Tr0ub4dor&3!xK','qwerty'], correctIndex: 2),
    QuizQuestion(question: 'O que é um ataque de "brute force"?', options: ['Tentar todas as combinações possíveis','Enganar o utilizador','Injetar código malicioso','Intercetar comunicações'], correctIndex: 0),
    QuizQuestion(question: 'Qual é o comprimento mínimo recomendado para uma password segura?', options: ['4 caracteres','6 caracteres','8 caracteres','12 caracteres'], correctIndex: 3),
    QuizQuestion(question: 'O que é um "salt" em criptografia de passwords?', options: ['Um tipo de ataque','Dado aleatório adicionado antes de hash','Uma password fraca','Uma técnica de phishing'], correctIndex: 1),
  ],
  'Redes Sociais': [
    QuizQuestion(question: 'Qual a melhor prática de privacidade nas redes sociais?', options: ['Partilhar tudo publicamente','Limitar quem pode ver as tuas publicações','Aceitar todos os pedidos','Usar o nome real sempre'], correctIndex: 1),
    QuizQuestion(question: 'O que deves evitar partilhar nas redes sociais?', options: ['Fotos de paisagens','Artigos de notícias','Localização em tempo real e dados pessoais','Receitas de culinária'], correctIndex: 2),
    QuizQuestion(question: 'O que é "engenharia social"?', options: ['Criar conteúdo de engenharia','Manipular pessoas para obter informações','Gerir grupos online','Partilhar posts sobre ciência'], correctIndex: 1),
    QuizQuestion(question: 'Como deves reagir a um pedido de amizade de um desconhecido?', options: ['Aceitar sempre','Aceitar se tiverem amigos em comum','Verificar e recusar se suspeito','Ignorar todos'], correctIndex: 2),
    QuizQuestion(question: 'O que é "doxxing"?', options: ['Partilhar documentos online','Publicar dados privados sem consentimento','Criar documentação','Um formato de ficheiro'], correctIndex: 1),
    QuizQuestion(question: 'O que é catfishing?', options: ['Pesca online','Criar perfil falso para enganar outros','Partilhar fotos de animais','Um tipo de malware'], correctIndex: 1),
    QuizQuestion(question: 'Qual é o risco de usar Wi-Fi público para aceder a redes sociais?', options: ['Nenhum risco','As tuas credenciais podem ser intercetadas','Consome mais bateria','A conta pode ser bloqueada'], correctIndex: 1),
    QuizQuestion(question: 'O que é "oversharing"?', options: ['Partilhar demasiada informação pessoal','Partilhar conteúdo de outros','Usar muitas hashtags','Publicar com frequência'], correctIndex: 0),
  ],
  'Segurança Web': [
    QuizQuestion(question: 'O que significa HTTPS?', options: ['O site tem muitas imagens','A ligação é encriptada e mais segura','O site é gratuito','O site é popular'], correctIndex: 1),
    QuizQuestion(question: 'O que é um ataque "Man-in-the-Middle"?', options: ['Um jogo online','Interceção de comunicações entre duas partes','Um tipo de firewall','Um método de encriptação'], correctIndex: 1),
    QuizQuestion(question: 'Qual a melhor prática ao usar Wi-Fi público?', options: ['Aceder ao internet banking normalmente','Partilhar ficheiros livremente','Usar uma VPN','Desativar o antivírus'], correctIndex: 2),
    QuizQuestion(question: 'O que é um cookie?', options: ['Um tipo de vírus','Ficheiro que guarda informação do utilizador','Um método de pagamento','Uma extensão'], correctIndex: 1),
    QuizQuestion(question: 'O que é um ataque de "SQL Injection"?', options: ['Injetar código malicioso numa base de dados','Uma vacina digital','Um método de encriptação','Otimização de websites'], correctIndex: 0),
    QuizQuestion(question: 'O que é um certificado SSL/TLS?', options: ['Um tipo de ataque','Protocolo que encripta comunicações web','Um antivírus online','Uma extensão do browser'], correctIndex: 1),
    QuizQuestion(question: 'O que é Cross-Site Scripting (XSS)?', options: ['Um tipo de cookie','Injeção de scripts maliciosos em websites','Um protocolo seguro','Uma técnica de encriptação'], correctIndex: 1),
    QuizQuestion(question: 'O que é um firewall?', options: ['Um tipo de vírus','Sistema que controla o tráfego de rede','Um tipo de email','Uma rede social'], correctIndex: 1),
  ],
};

// Perguntas Verdadeiro/Falso por tema
const Map<String, List<QuizQuestion>> _vfBank = {
  'Phishing': [
    QuizQuestion(question: 'Um email com linguagem urgente é sempre legítimo.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'O HTTPS garante que um site não é de phishing.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Devo reportar emails suspeitos ao departamento de TI.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Bancos pedem sempre a senha completa por email.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Verificar o endereço do remetente ajuda a identificar phishing.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Links encurtados são sempre seguros de clicar.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'O spear phishing é mais perigoso que o phishing genérico.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
  ],
  'Palavras-passe': [
    QuizQuestion(question: 'Usar a mesma password em vários sites é seguro.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Uma password com 6 caracteres é suficientemente segura.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Gestores de passwords são ferramentas seguras e recomendadas.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'O 2FA adiciona uma camada extra de segurança.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Uma password com apenas letras é muito segura.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Devo partilhar a minha password com colegas de confiança.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Palavras do dicionário tornam uma password mais fraca.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
  ],
  'Redes Sociais': [
    QuizQuestion(question: 'É seguro partilhar a minha localização em tempo real nas redes sociais.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Perfis privados protegem melhor os dados pessoais.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Devo aceitar pedidos de amizade de todos os desconhecidos.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Informação pública nas redes pode ser usada em ataques.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Catfishing é sempre fácil de identificar.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Devo reportar perfis suspeitos às plataformas.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Wi-Fi público é sempre seguro para usar redes sociais.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
  ],
  'Segurança Web': [
    QuizQuestion(question: 'HTTPS garante que o conteúdo do site é seguro e legítimo.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Uma VPN encripta o meu tráfego em redes públicas.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Cookies são sempre maliciosos.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Manter o browser atualizado melhora a segurança.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'SQL Injection pode comprometer uma base de dados inteira.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
    QuizQuestion(question: 'Um firewall substitui completamente um antivírus.', options: ['Verdadeiro', 'Falso'], correctIndex: 1, isVF: true),
    QuizQuestion(question: 'Extensões de browser podem representar riscos de segurança.', options: ['Verdadeiro', 'Falso'], correctIndex: 0, isVF: true),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  final String  tema;
  final String  dificuldade;
  final int     nivel;
  final QuizType quizType;

  const QuizScreen({
    super.key,
    this.tema        = 'Phishing',
    this.dificuldade = 'Iniciante',
    this.nivel       = 1,
    this.quizType    = QuizType.normal,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  static const _primary     = Color(0xFF1A56DB);
  static const _primaryDeep = Color(0xFF1E3A8A);
  static const _bgColor     = Color(0xFFF8FAFC);

  late List<QuizQuestion> _questions;
  int  _currentIndex   = 0;
  int? _selectedOption;
  bool _answered       = false;
  int  _correctAnswers = 0;

  // ── Combo de acertos consecutivos ────────────────────────────────────────
  int  _combo          = 0;    // acertos consecutivos na sessão atual
  int  _maxCombo       = 0;    // melhor combo desta sessão
  bool _showCombo      = false; // animação de combo

  // Temporizador geral
  int    _secondsElapsed = 0;
  Timer? _timer;

  // Temporizador contra o tempo (por questão)
  int    _timeLeft      = 15; // segundos por questão
  Timer? _questionTimer;
  late AnimationController _timerBarCtrl;

  // Progresso
  late AnimationController _progressController;
  late Animation<double>    _progressAnimation;

  final List<int?> _userAnswers = [];

  @override
  void initState() {
    super.initState();

    // Carrega perguntas consoante o tipo
    List<QuizQuestion> bank = widget.quizType == QuizType.vf
        ? List.of(_vfBank[widget.tema] ?? _vfBank['Phishing']!)
        : List.of(_questionBank[widget.tema] ?? _questionBank['Phishing']!);

    final total = bank.length;
    final maxQ = widget.quizType == QuizType.tempo ? min(7, total) : min(5, total);

    // Filtra perguntas consoante a dificuldade (assumindo que as mais difíceis estão no fim da lista)
    if (widget.dificuldade == 'Iniciante') {
      bank = bank.sublist(0, min(maxQ + 1, total));
    } else if (widget.dificuldade == 'Intermédio') {
      int start = (total - maxQ) ~/ 2;
      bank = bank.sublist(start, min(start + maxQ + 1, total));
    } else if (widget.dificuldade == 'Avançado') {
      bank = bank.sublist(total - min(maxQ + 1, total), total);
    }

    bank.shuffle();
    if (bank.length > maxQ) bank = bank.sublist(0, maxQ);
    _questions = bank;

    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _progressAnimation  = Tween<double>(begin: 0, end: _progressValue)
        .animate(CurvedAnimation(parent: _progressController, curve: Curves.easeInOut));
    _progressController.forward();

    _timerBarCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 15));

    _startTimer();
    if (widget.quizType == QuizType.tempo) _startQuestionTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _questionTimer?.cancel();
    _progressController.dispose();
    _timerBarCtrl.dispose();
    super.dispose();
  }

  double get _progressValue => (_currentIndex + 1) / _questions.length;

  void _startTimer() {
    _secondsElapsed = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _startQuestionTimer() {
    _timeLeft = 15;
    _questionTimer?.cancel();
    _timerBarCtrl.reset();
    _timerBarCtrl.forward();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _questionTimer?.cancel();
        if (!_answered) _selectOptionAndRecord(-1); // tempo esgotado
      }
    });
  }

  String get _formattedTime {
    final m = _secondsElapsed ~/ 60;
    final s = _secondsElapsed % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  void _selectOptionAndRecord(int index) {
    if (_answered) return;
    _userAnswers.add(index);
    final isCorrect = index != -1 && index == _questions[_currentIndex].correctIndex;

    _questionTimer?.cancel();

    final soundEnabled = context.read<AppSettings>().soundEnabled;
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
      if (isCorrect) {
        _correctAnswers++;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        _showCombo = _combo >= 2; // mostra badge de combo a partir de 2
      } else {
        _combo     = 0;
        _showCombo = false;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
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

      if (widget.quizType == QuizType.tempo) _startQuestionTimer();
    } else {
      _timer?.cancel();
      _saveResultAndShowSummary();
    }
  }

  // ── Atualiza streak de dias consecutivos ──────────────────────────────────
  Future<bool> _updateStreak(DocumentReference userRef, int percent) async {
    if (percent <= 50) return false;
    try {
      final snap = await userRef.get();
      final data = snap.data() as Map<String, dynamic>? ?? {};

      final now       = DateTime.now();
      final today     = DateTime(now.year, now.month, now.day);
      final lastTs    = data['lastQuizDate'] as Timestamp?;
      final streak    = (data['streak'] ?? 0) as int;

      if (lastTs == null) {
        // Primeiro quiz alguma vez
        await userRef.update({'streak': 1, 'lastQuizDate': Timestamp.fromDate(today)});
        return true;
      }

      final lastDate  = DateTime(lastTs.toDate().year, lastTs.toDate().month, lastTs.toDate().day);
      final diff      = today.difference(lastDate).inDays;

      if (diff == 0) {
        // Já fez um quiz >50% hoje — não muda
        return false;
      } else if (diff == 1) {
        // Dia consecutivo — incrementa
        await userRef.update({'streak': streak + 1, 'lastQuizDate': Timestamp.fromDate(today)});
        return true;
      } else {
        // Perdeu a sequência — recomeça
        await userRef.update({'streak': 1, 'lastQuizDate': Timestamp.fromDate(today)});
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  /// Calcula moedas ganhas por percentagem — escala rigorosa
  static int _calcMoedas(int percent) {
    if (percent <  20) return 0;    // abaixo de 20% — sem moedas
    if (percent <  40) return 15;   // 20–39%
    if (percent <  60) return 30;   // 40–59%
    if (percent <  70) return 50;   // 60–69%
    if (percent <  80) return 80;   // 70–79%
    if (percent <  90) return 100;  // 80–89%
    if (percent < 100) return 120;  // 90–99%
    return 150;                     // 100% perfeito
  }

  Future<void> _saveResultAndShowSummary() async {
    final user         = FirebaseAuth.instance.currentUser;
    final percent      = ((_correctAnswers / _questions.length) * 100).round();
    final pointsMap    = {'Iniciante': 50, 'Intermédio': 100, 'Avançado': 200};
    final basePoints   = pointsMap[widget.dificuldade] ?? 50;

    // ── Multiplicador de combo ────────────────────────────────────────────
    // Combo 2-3: ×1.2 | 4: ×1.5 | 5+: ×2.0
    double comboMultiplier = 1.0;
    if (_maxCombo >= 5) {
      comboMultiplier = 2.0;
    } else if (_maxCombo == 4) comboMultiplier = 1.5;
    else if (_maxCombo >= 2) comboMultiplier = 1.2;

    final rawPoints    = (basePoints * (_correctAnswers / _questions.length)).round();
    final points       = (rawPoints * comboMultiplier).round();
    final timeStr      = _formattedTime;
    final moedasGanhas = _calcMoedas(percent);
    final tipoQuizStr  = widget.quizType == QuizType.tempo ? 'tempo' : widget.quizType == QuizType.vf ? 'vf' : 'normal';

    final questionsData = List.generate(_questions.length, (i) {
      final q          = _questions[i];
      final userAnswer = i < _userAnswers.length ? _userAnswers[i] : null;
      return {
        'question'    : q.question,
        'options'     : q.options,
        'correctIndex': q.correctIndex,
        'userAnswer'  : userAnswer,
        'isCorrect'   : userAnswer != null && userAnswer == q.correctIndex,
      };
    });

    final wrongQuestions = questionsData.where((q) => q['isCorrect'] != true).toList();

    if (!mounted) return;

    final soundEnabled = context.read<AppSettings>().soundEnabled;
    if (soundEnabled) {
      if (percent > 50) {
        SoundService.playVictory();
      } else {
        SoundService.playFail();
      }
    }

    // ── Verifica badges ANTES de abrir o dialog (fix: badge real em vez do combo) ──
    final newBadgeName = await BadgesService.checkAndUnlock(
      tema: widget.tema, percent: percent, tipoQuiz: tipoQuizStr,
    );

    // ── Deteção de Level Up ────────────────────────────────────────────────
    // Cada nível = 250 pontos. Lê os pontos atuais ANTES de atualizar.
    int pontosAntes = 0;
    if (user != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        pontosAntes = ((snap.data())?['pontos'] ?? 0) as int;
      } catch (_) {}
    }
    final nivelAntes  = (pontosAntes ~/ 250) + 1;
    final nivelDepois = ((pontosAntes + points) ~/ 250) + 1;
    final leveledUp   = nivelDepois > nivelAntes;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => QuizResultDialog(
        percent: percent, points: points, correct: _correctAnswers,
        total: _questions.length, timeStr: timeStr, tema: widget.tema,
        newBadge: newBadgeName,   // badge real do Firestore
        comboLabel: _maxCombo >= 2 ? (_maxCombo >= 5 ? '🔥 ×2 COMBO MÁXIMO!' : _maxCombo == 4 ? '⚡ ×1.5 Combo x4!' : '✨ ×1.2 Combo x$_maxCombo!') : null,
        wrongQuestions: wrongQuestions, moedasGanhas: moedasGanhas,
        leveledUp: leveledUp, newNivel: nivelDepois,
      ),
    );

    if (user != null) {
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await Future.wait([
          userRef.collection('quiz_results').add({
            'theme': widget.tema, 'dificuldade': widget.dificuldade,
            'nivel': widget.nivel, 'percent': percent, 'points': points,
            'correct': _correctAnswers, 'total': _questions.length,
            'time': timeStr, 'tipoQuiz': tipoQuizStr, 'maxCombo': _maxCombo,
            'date': FieldValue.serverTimestamp(), 'questions': questionsData,
          }),
          userRef.update({
            'pontos': FieldValue.increment(points),
            'moedas': FieldValue.increment(moedasGanhas),
          }),
        ]);

        // Pontos do clã
        final userSnap = await userRef.get();
        final userData = userSnap.data() ?? {};
        final clanId   = userData['clanId'] as String?;
        if (clanId != null && clanId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('clans').doc(clanId)
              .update({'points': FieldValue.increment(points)});
        }

        // Streak
        final streakUpdated = await _updateStreak(userRef, percent);

        // ── Animações de moedas e streak ──────────────────────────────────
        if (mounted) {
          CoinAnimation.show(context, coins: moedasGanhas);

          // Streak — só no primeiro quiz do dia > 50%
          final updatedSnap = await userRef.get();
          final streak      = ((updatedSnap.data())?['streak'] ?? 0) as int;
          
          if (streakUpdated && streak >= 2) {
            await Future.delayed(const Duration(milliseconds: 1000));
            if (mounted) StreakAnimation.show(context, streak: streak);
          }
        }

        // ── Missões diárias ───────────────────────────────────────────────
        await DailyMissionsService.recordQuiz(
          userRef: userRef,
          percent: percent,
          tema: widget.tema,
          tipoQuiz: tipoQuizStr,
        );
        // Nota: BadgesService.checkAndUnlock já foi chamado antes do dialog
      } catch (_) {}
    }
  }

  // ── Cores das opções ──────────────────────────────────────────────────────
  Color _optionBg(int index) {
    if (!_answered) return Colors.white;
    if (index == _questions[_currentIndex].correctIndex) return const Color(0xFFF0FDF4);
    if (index == _selectedOption) return const Color(0xFFFEF2F2);
    return Colors.white;
  }

  Color _optionBorder(int index) {
    if (!_answered) return const Color(0xFFE5E7EB);
    if (index == _questions[_currentIndex].correctIndex) return const Color(0xFF16A34A);
    if (index == _selectedOption) return const Color(0xFFDC2626);
    return const Color(0xFFE5E7EB);
  }

  Color _optionTextColor(int index) {
    if (!_answered) return _primaryDeep;
    if (index == _questions[_currentIndex].correctIndex) return const Color(0xFF16A34A);
    if (index == _selectedOption) return const Color(0xFFDC2626);
    return Colors.grey;
  }

  Widget _optionIcon(int index) {
    if (!_answered) {
      return Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFCBD5E1), width: 2)));
    }
    if (index == _questions[_currentIndex].correctIndex) return const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22);
    if (index == _selectedOption) return const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22);
    return Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFCBD5E1), width: 2)));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final q        = _questions[_currentIndex];
    final isVF     = widget.quizType == QuizType.vf;
    final isTempo  = widget.quizType == QuizType.tempo;

    // Badge do tipo de quiz
    final typeBadge = isTempo ? ('⏱️ Contra o Tempo') : isVF ? ('✅ Verdadeiro / Falso') : ('📚 Quiz Normal');
    final typeBgColor = isTempo ? const Color(0xFFDC2626) : isVF ? const Color(0xFF7C3AED) : _primary;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryDeep, size: 20),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          children: [
            Text('Quiz: ${widget.tema}', style: const TextStyle(color: _primaryDeep, fontWeight: FontWeight.bold, fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: typeBgColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(typeBadge, style: TextStyle(color: typeBgColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        centerTitle: true,
        // No modo tempo só mostra o countdown de 15s (não o timer geral)
        actions: [
          if (!isTempo)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _TimerBadge(seconds: _secondsElapsed)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de progresso ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Questão ${_currentIndex + 1} de ${_questions.length}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                    Row(children: [
                      // Badge de combo
                      if (_combo >= 2) AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _combo >= 5 ? const Color(0xFFDC2626) : _combo >= 4 ? const Color(0xFFEA580C) : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_combo >= 5 ? '🔥' : _combo >= 4 ? '⚡' : '✨', style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text('Combo ×$_combo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ]),
                      ),
                      if (_combo >= 2) const SizedBox(width: 8),
                      // Tempo
                      if (!isTempo)
                        Text('${_secondsElapsed}s', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (_, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value, minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                    ),
                  ),
                ),
                // Countdown de 15s (só no modo tempo)
                if (isTempo) ...[
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _timerBarCtrl,
                    builder: (_, _) {
                      final remaining = _timeLeft / 15.0;
                      final barColor = remaining > 0.5
                          ? const Color(0xFF16A34A)
                          : remaining > 0.25
                              ? const Color(0xFFD97706)
                              : const Color(0xFFDC2626);
                      return Row(children: [
                        Icon(Icons.timer_rounded, size: 16, color: barColor),
                        const SizedBox(width: 8),
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: remaining.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        )),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: barColor.withOpacity(0.4)),
                          ),
                          child: Text('${_timeLeft}s',
                              style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ]);
                    },
                  ),
                ],
              ],
            ),
          ),

          // ── Conteúdo ──────────────────────────────────────────────────────
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
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Text(q.question, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _primaryDeep, height: 1.5)),
                  ),
                  const SizedBox(height: 20),

                  // Opções
                  if (isVF || q.isVF)
                    // Layout especial para V/F
                    Row(
                      children: [
                        Expanded(child: _buildVFButton(0, '✅ Verdadeiro', const Color(0xFF16A34A))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildVFButton(1, '❌ Falso', const Color(0xFFDC2626))),
                      ],
                    )
                  else
                    ...List.generate(q.options.length, (i) => _buildOptionCard(i, q.options[i])),

                  const SizedBox(height: 20),

                  // Feedback
                  if (_answered) _buildFeedbackCard(q),

                  const SizedBox(height: 16),

                  // Botão próxima
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _answered ? _primary : const Color(0xFFCBD5E1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _answered ? _nextQuestion : null,
                      child: Text(
                        _currentIndex < _questions.length - 1 ? 'Próxima Questão' : 'Ver Resultado',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildOptionCard(int index, String text) {
    return GestureDetector(
      onTap: () => _selectOptionAndRecord(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _optionBg(index),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _optionBorder(index), width: _answered && (index == _questions[_currentIndex].correctIndex || index == _selectedOption) ? 2 : 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          _optionIcon(index),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _optionTextColor(index)))),
        ]),
      ),
    );
  }

  Widget _buildVFButton(int index, String label, Color color) {
    final selected  = _selectedOption == index;
    final isCorrect = _answered && index == _questions[_currentIndex].correctIndex;
    final isWrong   = _answered && selected && !isCorrect;

    return GestureDetector(
      onTap: () => _selectOptionAndRecord(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 80,
        decoration: BoxDecoration(
          color: isCorrect ? color.withOpacity(0.15) : isWrong ? const Color(0xFFDC2626).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _answered ? (isCorrect ? color : isWrong ? const Color(0xFFDC2626) : const Color(0xFFE5E7EB)) : const Color(0xFFE5E7EB), width: _answered && (isCorrect || isWrong) ? 2 : 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isCorrect ? color : isWrong ? const Color(0xFFDC2626) : _primaryDeep)),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(QuizQuestion q) {
    final isCorrect = _selectedOption != null && _selectedOption == q.correctIndex;
    final color     = isCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bgColor   = isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final title     = isCorrect ? 'Correto! 🎉' : _selectedOption == -1 ? 'Tempo esgotado! ⏰' : 'Resposta Incorreta';
    final subtitle  = isCorrect ? 'Muito bem! Continua assim.' : 'A resposta certa era: "${q.options[q.correctIndex]}"';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isCorrect ? Icons.check_circle_rounded : Icons.info_rounded, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: color.withOpacity(0.8))),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMER BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _TimerBadge extends StatelessWidget {
  final int seconds;
  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_outlined, color: Color(0xFFEF4444), size: 16),
        const SizedBox(width: 4),
        Text('${seconds}s', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}