import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projeto_safequest/screens/home_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN
// Parâmetro requireNickname:
//   true  → utilizador Google (sem nickname) — mostra 5ª página de escolha
//   false → utilizador registado pela app (já tem nickname) — 4 páginas normais
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final bool requireNickname;
  const OnboardingScreen({super.key, this.requireNickname = false});

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_done') ?? false);
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  // Controladores para a página do nickname (só utilizada quando requireNickname == true)
  final _nicknameCtrl = TextEditingController();
  bool _checkingNick  = false;
  String? _nickError;

  static const _infoPages = [
    _OnboardingPage(
      emoji: '🛡️',
      title: 'Bem-vindo ao SafeQuest!',
      subtitle: 'A tua jornada para dominar a cibersegurança começa aqui.',
      description: 'Aprende a proteger-te online através de quizzes interativos, desafios e conquistas únicas.',
      gradientColors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
    ),
    _OnboardingPage(
      emoji: '🧠',
      title: 'Aprende com Quizzes',
      subtitle: 'Phishing, Passwords, Redes Sociais e muito mais.',
      description: 'Escolhe um tema, nível de dificuldade e tipo de quiz. Ganha XP e moedas a cada resposta certa!',
      gradientColors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    ),
    _OnboardingPage(
      emoji: '⚔️',
      title: 'Junta-te a um Clã',
      subtitle: 'Compete com outros jogadores em batalhas de quiz.',
      description: 'Entra num clã, lança desafios a outros membros e sobe no ranking. Trabalha em equipa para ser o melhor!',
      gradientColors: [Color(0xFFEA580C), Color(0xFFDC2626)],
    ),
    _OnboardingPage(
      emoji: '🏆',
      title: 'Ganha Emblemas',
      subtitle: 'Desbloqueia conquistas e personaliza o teu perfil.',
      description: 'Coleciona emblemas exclusivos, muda o teu avatar e banner. Mostra ao mundo o teu domínio da cibersegurança!',
      gradientColors: [Color(0xFF16A34A), Color(0xFF0F766E)],
    ),
  ];

  int get _totalPages => widget.requireNickname ? _infoPages.length + 1 : _infoPages.length;
  bool get _isNicknamePage => widget.requireNickname && _currentPage == _infoPages.length;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      // Última página: se for nickname, valida e guarda; senão termina direto
      if (_isNicknamePage) {
        _saveNicknameAndFinish();
      } else {
        _finish();
      }
    }
  }

  Future<void> _saveNicknameAndFinish() async {
    final nick = _nicknameCtrl.text.trim();

    // Validação local
    if (nick.isEmpty)        { setState(() => _nickError = 'O nickname é obrigatório'); return; }
    if (nick.length < 3)     { setState(() => _nickError = 'Mínimo 3 caracteres'); return; }
    if (nick.contains(' '))  { setState(() => _nickError = 'Sem espaços no nickname'); return; }

    setState(() { _checkingNick = true; _nickError = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _finish(); return; }

      // Verifica unicidade no Firestore
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nick)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        setState(() { _checkingNick = false; _nickError = 'Este nickname já está em uso'; });
        return;
      }

      // Guarda o nickname no documento do utilizador
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'nickname': nick},
        SetOptions(merge: true),
      );

      _finish();
    } catch (e) {
      setState(() { _checkingNick = false; _nickError = 'Erro ao verificar nickname. Tenta novamente.'; });
    }
  }

  void _finish() async {
    await OnboardingScreen.markDone();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              // Páginas de informação
              ..._infoPages.map((p) => _buildInfoPage(p)),

              // Página de nickname (só quando requireNickname == true)
              if (widget.requireNickname) _buildNicknamePage(),
            ],
          ),

          // Indicadores de página
          Positioned(
            bottom: 120,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),

          // Botão avançar / concluir
          Positioned(
            bottom: 40,
            left: 24, right: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _currentPageColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              onPressed: _checkingNick ? null : _nextPage,
              child: _checkingNick
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: _currentPageColor, strokeWidth: 2))
                  : Text(
                      _isNicknamePage ? 'Começar Aventura 🚀' : _currentPage == _totalPages - 1 ? 'Começar Aventura 🚀' : 'Continuar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          // Botão "Saltar" (só nas páginas de info, não na de nickname)
          if (!_isNicknamePage)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 20,
              child: TextButton(
                onPressed: () {
                  if (widget.requireNickname) {
                    // Vai para a página de nickname
                    _pageCtrl.animateToPage(_infoPages.length, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                  } else {
                    _finish();
                  }
                },
                child: const Text('Saltar', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Color get _currentPageColor {
    if (_isNicknamePage) return const Color(0xFF7C3AED);
    return _infoPages[_currentPage.clamp(0, _infoPages.length - 1)].gradientColors[0];
  }

  Widget _buildInfoPage(_OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: page.gradientColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 180),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.8 + 0.2 * v, child: child)),
                child: Text(page.emoji, style: const TextStyle(fontSize: 90)),
              ),
              const SizedBox(height: 32),
              Text(page.title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(page.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                child: Text(page.description, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNicknamePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 180),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.8 + 0.2 * v, child: child)),
                child: const Text('🎮', style: TextStyle(fontSize: 90)),
              ),
              const SizedBox(height: 28),
              const Text('Escolhe o teu Nickname', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Este será o teu nome no leaderboard e nos clãs.', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // Campo de nickname
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nicknameCtrl,
                  onChanged: (_) => setState(() => _nickError = null),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                  decoration: InputDecoration(
                    hintText: 'ex: CyberNinja',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF7C3AED)),
                    border: InputBorder.none,
                    errorText: _nickError,
                  ),
                ),
              ),
              if (_nickError != null) ...[
                const SizedBox(height: 6),
                Text(_nickError!, style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: const Column(children: [
                  Row(children: [Icon(Icons.check_circle_outline, color: Colors.white70, size: 14), SizedBox(width: 8), Text('Mínimo 3 caracteres, sem espaços', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.check_circle_outline, color: Colors.white70, size: 14), SizedBox(width: 8), Text('Deve ser único — será verificado', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de página de informação
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradientColors;
  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradientColors,
  });
}
