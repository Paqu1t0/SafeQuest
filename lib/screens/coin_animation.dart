import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL KEY para o badge de moedas no AppBar
// Coloca este key no widget do badge: coinBadgeKey
// ─────────────────────────────────────────────────────────────────────────────
final GlobalKey coinBadgeKey = GlobalKey();

// ─────────────────────────────────────────────────────────────────────────────
// COIN ANIMATION — moedas voam DO centro PARA o badge no canto superior direito
// ─────────────────────────────────────────────────────────────────────────────
class CoinAnimation {
  static void show(BuildContext context, {required int coins}) {
    final overlay = Overlay.of(context);

    // Descobre a posição do badge de moedas
    Offset target = const Offset(30, 30); // fallback canto sup. direito
    final renderBox = coinBadgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final pos  = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      target = Offset(pos.dx + size.width / 2, pos.dy + size.height / 2);
    }

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _CoinFlyOverlay(
      coins: coins,
      target: target,
      onDone: () => entry.remove(),
    ));
    overlay.insert(entry);
  }
}

class _CoinFlyOverlay extends StatefulWidget {
  final int    coins;
  final Offset target;
  final VoidCallback onDone;
  const _CoinFlyOverlay({required this.coins, required this.target, required this.onDone});

  @override
  State<_CoinFlyOverlay> createState() => _CoinFlyOverlayState();
}

class _CoinFlyOverlayState extends State<_CoinFlyOverlay> with TickerProviderStateMixin {
  static const _count = 10;
  final _rnd = Random();
  late List<AnimationController> _ctrls;
  late List<Animation<Offset>>   _positions;
  late List<Animation<double>>   _opacities;
  late List<double>              _sizes;
  bool _showBadge  = false;
  bool _badgeDone  = false;

  @override
  void initState() {
    super.initState();
    final screen = WidgetsBinding.instance.platformDispatcher.views.first;
    final sw     = screen.physicalSize.width / screen.devicePixelRatio;
    final sh     = screen.physicalSize.height / screen.devicePixelRatio;
    final origin = Offset(sw / 2, sh / 2 - 40);

    _sizes  = List.generate(_count, (_) => 16 + _rnd.nextDouble() * 14);
    _ctrls  = List.generate(_count, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500 + i * 60),
      );
      // stagger: each coin starts a bit later
      Future.delayed(Duration(milliseconds: i * 55), () {
        if (mounted) ctrl.forward();
      });
      return ctrl;
    });

    _positions = List.generate(_count, (i) {
      // slight random spread from center before flying to target
      final spread = Offset(
        (_rnd.nextDouble() - 0.5) * 80,
        (_rnd.nextDouble() - 0.5) * 80,
      );
      final mid = origin + spread;

      // 3-stop path: origin → spread → target
      return TweenSequence<Offset>([
        TweenSequenceItem(
          tween: Tween(begin: origin, end: mid)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: mid, end: widget.target)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 70,
        ),
      ]).animate(_ctrls[i]);
    });

    _opacities = List.generate(_count, (i) => TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_ctrls[i]));

    // Mostra badge quando a última moeda chegar
    _ctrls.last.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showBadge = true);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _badgeDone = true);
          Future.delayed(const Duration(milliseconds: 350), widget.onDone);
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        // Moedas voando
        ...List.generate(_count, (i) => AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, __) {
            final pos = _positions[i].value;
            return Positioned(
              left: pos.dx - _sizes[i] / 2,
              top : pos.dy - _sizes[i] / 2,
              child: Opacity(
                opacity: _opacities[i].value.clamp(0.0, 1.0),
                child: Text('🪙', style: TextStyle(fontSize: _sizes[i])),
              ),
            );
          },
        )),

        // Badge "+X" aparece no alvo quando moedas chegam
        if (_showBadge) Positioned(
          left: widget.target.dx - 44,
          top : widget.target.dy - 36,
          child: AnimatedOpacity(
            opacity: _badgeDone ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.6), blurRadius: 12, spreadRadius: 2)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('+${widget.coins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK ANIMATION — popup central mais longo e vistoso
// ─────────────────────────────────────────────────────────────────────────────
class StreakAnimation {
  static void show(BuildContext context, {required int streak}) {
    if (streak < 2) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _StreakOverlay(
      streak: streak,
      onDone: () => entry.remove(),
    ));
    overlay.insert(entry);
  }
}

class _StreakOverlay extends StatefulWidget {
  final int streak;
  final VoidCallback onDone;
  const _StreakOverlay({required this.streak, required this.onDone});
  @override
  State<_StreakOverlay> createState() => _StreakOverlayState();
}

class _StreakOverlayState extends State<_StreakOverlay> with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _flameCtrl;
  late AnimationController _exitCtrl;
  late AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();

    _flameCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);

    _particleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    // Duração total: 4.5 segundos
    Future.delayed(const Duration(milliseconds: 4100), () {
      if (mounted) _exitCtrl.forward();
      Future.delayed(const Duration(milliseconds: 400), widget.onDone);
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose(); _flameCtrl.dispose();
    _exitCtrl.dispose(); _particleCtrl.dispose();
    super.dispose();
  }

  String get _label {
    if (widget.streak >= 30) return '🌟 Lendário!';
    if (widget.streak >= 14) return '💎 Incrível!';
    if (widget.streak >= 7)  return '🏆 Semana completa!';
    if (widget.streak >= 5)  return '⚡ Imparável!';
    if (widget.streak >= 3)  return '🎯 Boa sequência!';
    return '✅ Dia consecutivo!';
  }

  Color get _color {
    if (widget.streak >= 7)  return const Color(0xFFDC2626);
    if (widget.streak >= 5)  return const Color(0xFFEA580C);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enterCtrl, _exitCtrl]),
      builder: (_, __) {
        final enterScale = CurvedAnimation(parent: _enterCtrl, curve: Curves.elasticOut).value;
        final exitOpacity = 1.0 - _exitCtrl.value;

        return IgnorePointer(
          child: Opacity(
            opacity: exitOpacity.clamp(0.0, 1.0),
            child: Stack(children: [
              // Fundo semitransparente
              Positioned.fill(child: Container(color: Colors.black.withOpacity(0.35 * exitOpacity))),

              // Partículas de chama ao redor
              ..._buildParticles(),

              // Card principal
              Center(
                child: Transform.scale(
                  scale: enterScale,
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 50, spreadRadius: 8)],
                      border: Border.all(color: _color.withOpacity(0.3), width: 2),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Chama pulsante
                      AnimatedBuilder(
                        animation: _flameCtrl,
                        builder: (_, __) {
                          final s = 1.0 + _flameCtrl.value * 0.18;
                          return Transform.scale(
                            scale: s,
                            child: Text(
                              widget.streak >= 7 ? '🔥🔥🔥' : '🔥',
                              style: TextStyle(fontSize: widget.streak >= 7 ? 42 : 64),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Número de dias com animação de contador
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: widget.streak),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => Text(
                          '$v',
                          style: TextStyle(
                            fontSize: 72, fontWeight: FontWeight.w900,
                            color: _color, height: 1,
                          ),
                        ),
                      ),

                      Text(
                        'dias consecutivos',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 14),

                      // Badge do nível de streak
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _color.withOpacity(0.4)),
                        ),
                        child: Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),

                      const SizedBox(height: 12),
                      Text('Continua assim! 💪', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles() {
    final rnd = Random(42);
    return List.generate(12, (i) {
      final angle  = (i / 12) * 2 * pi;
      final radius = 160.0 + rnd.nextDouble() * 40;
      return AnimatedBuilder(
        animation: _particleCtrl,
        builder: (_, __) {
          final t     = (_particleCtrl.value + i / 12) % 1.0;
          final scale = sin(t * pi);
          final cx    = MediaQuery.of(context).size.width / 2;
          final cy    = MediaQuery.of(context).size.height / 2;
          return Positioned(
            left: cx + cos(angle) * radius * (0.8 + scale * 0.2) - 10,
            top : cy + sin(angle) * radius * (0.8 + scale * 0.2) - 10,
            child: Opacity(
              opacity: (scale * 0.8).clamp(0.0, 1.0),
              child: Text(
                i % 3 == 0 ? '✨' : i % 3 == 1 ? '🔥' : '⭐',
                style: TextStyle(fontSize: 14 + scale * 8),
              ),
            ),
          );
        },
      );
    });
  }
}