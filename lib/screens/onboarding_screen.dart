import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projeto_safequest/screens/home_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN — aparece só na primeira vez que o utilizador entra
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

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

  static const _pages = [
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
      subtitle: 'Compite com outros jogadores em batalhas de quiz.',
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

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await OnboardingScreen.markDone();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // PageView principal
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) => _buildPage(_pages[i]),
          ),

          // Botão Skip (só nas primeiras 3 páginas)
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: 52,
              right: 24,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Saltar', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),

          // Indicadores + botão em baixo
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _currentPage;
                        final color = _pages[_currentPage].gradientColors[0];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? color : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Botão
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _pages[_currentPage].gradientColors[0],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        onPressed: _nextPage,
                        child: Text(
                          _currentPage < _pages.length - 1 ? 'Continuar →' : 'Começar Aventura! 🚀',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _pages[_currentPage].gradientColors[0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: page.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 140),
          child: Column(
            children: [
              const Spacer(),
              // Emoji icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, val, __) => Transform.scale(
                  scale: val,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(page.emoji, style: const TextStyle(fontSize: 64)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Título
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              // Description
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  page.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

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
