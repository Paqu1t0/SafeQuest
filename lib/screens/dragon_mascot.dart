import 'dart:math';
import 'package:flutter/material.dart';

──────────────────────────────────────────────────────────────────────────

class DragonMascot extends StatefulWidget {
  final int quizzesDone;
  final int streak;
  final int missionsComplete;
  final int totalMissions;

  const DragonMascot({
    super.key,
    this.quizzesDone = 0,
    this.streak = 0,
    this.missionsComplete = 0,
    this.totalMissions = 4,
  });

  @override
  State<DragonMascot> createState() => _DragonMascotState();
}

class _DragonMascotState extends State<DragonMascot>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _floatCtrl;
  late AnimationController _blinkCtrl;
  late AnimationController _tailCtrl;
  late AnimationController _shieldCtrl;
  late AnimationController _flameCtrl;
  late AnimationController _breatheCtrl;
  late AnimationController _bubbleCtrl;

  // Animations
  late Animation<double> _floatAnim;
  late Animation<double> _blinkAnim;
  late Animation<double> _tailAnim;
  late Animation<double> _shieldAnim;
  late Animation<double> _flameAnim;
  late Animation<double> _breatheAnim;
  late Animation<double> _bubbleAnim;

  @override
  void initState() {
    super.initState();

    // Float — corpo sobe e desce
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Blink — olhos piscam
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _blinkAnim = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut),
    );
    _startBlinking();

    // Tail — cauda balança
    _tailCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _tailAnim = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _tailCtrl, curve: Curves.easeInOut),
    );

    // Shield — escudo oscila
    _shieldCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _shieldAnim = Tween<double>(begin: -0.12, end: 0.12).animate(
      CurvedAnimation(parent: _shieldCtrl, curve: Curves.easeInOut),
    );

    // Flame — chama pulsa
    _flameCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _flameAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );

    // Breathe — barriga expande
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _breatheAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    // Bubble — bolha de diálogo aparece
    _bubbleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _bubbleAnim = CurvedAnimation(parent: _bubbleCtrl, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _bubbleCtrl.forward();
    });
  }

  void _startBlinking() {
    Future.doWhile(() async {
      await Future.delayed(Duration(milliseconds: 3000 + Random().nextInt(2000)));
      if (!mounted) return false;
      await _blinkCtrl.forward();
      await _blinkCtrl.reverse();
      return mounted;
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _blinkCtrl.dispose();
    _tailCtrl.dispose();
    _shieldCtrl.dispose();
    _flameCtrl.dispose();
    _breatheCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  String _getMessage() {
    if (widget.missionsComplete >= widget.totalMissions) {
      return 'Incrível! És um verdadeiro guardião digital! 🏆';
    }
    if (widget.streak > 3) {
      return '${widget.streak} dias seguidos! Estás imparável! ⚡';
    }
    if (widget.missionsComplete >= 2) {
      return 'Quase lá! Falta pouco para completares tudo! 🔥';
    }
    if (widget.quizzesDone > 0) {
      return 'Bom trabalho! Continua assim! 💪';
    }
    return 'Olá! Estou aqui para te proteger! 🛡️ Vamos treinar?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEFF6FF),
            const Color(0xFFF0FDF4).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ECC71).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dragão animado
          AnimatedBuilder(
            animation: Listenable.merge([
              _floatAnim, _blinkAnim, _tailAnim,
              _shieldAnim, _flameAnim, _breatheAnim,
            ]),
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: SizedBox(
                  width: 100,
                  height: 110,
                  child: CustomPaint(
                    painter: _DragonPainter(
                      blinkScale: _blinkAnim.value,
                      tailAngle: _tailAnim.value,
                      shieldAngle: _shieldAnim.value,
                      flameScale: _flameAnim.value,
                      breatheScale: _breatheAnim.value,
                      isHappy: widget.missionsComplete >= widget.totalMissions,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Bolha de diálogo
          Expanded(
            child: ScaleTransition(
              scale: _bubbleAnim,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🐉 Dragão Guardião',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getMessage(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                        height: 1.4,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAGON PAINTER — desenha o dragão com CustomPaint
// ─────────────────────────────────────────────────────────────────────────────

class _DragonPainter extends CustomPainter {
  final double blinkScale;
  final double tailAngle;
  final double shieldAngle;
  final double flameScale;
  final double breatheScale;
  final bool isHappy;

  _DragonPainter({
    required this.blinkScale,
    required this.tailAngle,
    required this.shieldAngle,
    required this.flameScale,
    required this.breatheScale,
    this.isHappy = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Scale everything to fit
    final scale = size.width / 110;
    canvas.save();
    canvas.scale(scale);

    // ── Cauda (animada) ──
    canvas.save();
    canvas.translate(72, 72);
    canvas.rotate(tailAngle);
    canvas.translate(-72, -72);
    final tailPaint = Paint()
      ..color = const Color(0xFF2D7D46)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tailPath = Path()
      ..moveTo(72, 72)
      ..quadraticBezierTo(90, 80, 96, 72)
      ..quadraticBezierTo(102, 64, 88, 60);
    canvas.drawPath(tailPath, tailPaint);
    // Ponta da cauda
    canvas.drawCircle(const Offset(96, 72), 4, Paint()..color = const Color(0xFF34A85A));
    canvas.restore();

    // ── Corpo principal ──
    // Corpo
    final bodyPaint = Paint()..color = const Color(0xFF2ECC71);
    canvas.drawOval(Rect.fromCenter(center: const Offset(55, 62), width: 44 * breatheScale, height: 52), bodyPaint);

    // Barriga
    final bellyPaint = Paint()..color = const Color(0xFFA8F0C6);
    canvas.drawOval(Rect.fromCenter(center: const Offset(55, 65), width: 26 * breatheScale, height: 34), bellyPaint);

    // ── Asas ──
    final wingPaint = Paint()..color = const Color(0xFF27AE60).withOpacity(0.85);
    final leftWing = Path()
      ..moveTo(33, 52)
      ..quadraticBezierTo(18, 38, 22, 28)
      ..quadraticBezierTo(28, 36, 35, 44)
      ..close();
    canvas.drawPath(leftWing, wingPaint);
    final rightWing = Path()
      ..moveTo(77, 52)
      ..quadraticBezierTo(92, 38, 88, 28)
      ..quadraticBezierTo(82, 36, 75, 44)
      ..close();
    canvas.drawPath(rightWing, wingPaint);

    // ── Cabeça ──
    canvas.drawOval(Rect.fromCenter(center: const Offset(55, 36), width: 36, height: 34), bodyPaint);

    // ── Chifres ──
    final hornPaint = Paint()..color = const Color(0xFFF39C12);
    final leftHorn = Path()
      ..moveTo(44, 22)
      ..quadraticBezierTo(40, 12, 44, 8)
      ..quadraticBezierTo(46, 14, 47, 22)
      ..close();
    canvas.drawPath(leftHorn, hornPaint);
    final rightHorn = Path()
      ..moveTo(66, 22)
      ..quadraticBezierTo(70, 12, 66, 8)
      ..quadraticBezierTo(64, 14, 63, 22)
      ..close();
    canvas.drawPath(rightHorn, hornPaint);

    // ── Olhos (com blink) ──
    canvas.save();
    // Escala Y para piscar
    canvas.translate(55, 35);
    canvas.scale(1.0, blinkScale);
    canvas.translate(-55, -35);

    final eyeWhite = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: const Offset(48, 35), width: 10, height: 12), eyeWhite);
    canvas.drawOval(Rect.fromCenter(center: const Offset(62, 35), width: 10, height: 12), eyeWhite);
    // Pupilas
    final pupilPaint = Paint()..color = const Color(0xFF1A1A2E);
    canvas.drawCircle(const Offset(49, 36), 3, pupilPaint);
    canvas.drawCircle(const Offset(63, 36), 3, pupilPaint);
    // Brilho
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(50, 34.5), 1, shinePaint);
    canvas.drawCircle(const Offset(64, 34.5), 1, shinePaint);
    canvas.restore();

    // ── Sorriso ──
    final smilePaint = Paint()
      ..color = const Color(0xFF1A5C30)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final smilePath = Path();
    if (isHappy) {
      smilePath.moveTo(46, 44);
      smilePath.quadraticBezierTo(55, 52, 64, 44);
    } else {
      smilePath.moveTo(48, 44);
      smilePath.quadraticBezierTo(55, 50, 62, 44);
    }
    canvas.drawPath(smilePath, smilePaint);

    // Bochechas rosadas se feliz
    if (isHappy) {
      final blushPaint = Paint()..color = const Color(0xFFFDA4AF).withOpacity(0.5);
      canvas.drawOval(Rect.fromCenter(center: const Offset(43, 42), width: 8, height: 5), blushPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(67, 42), width: 8, height: 5), blushPaint);
    }

    // ── Narinas ──
    final nostrilPaint = Paint()..color = const Color(0xFF1A5C30).withOpacity(0.6);
    canvas.drawCircle(const Offset(52, 41), 1.5, nostrilPaint);
    canvas.drawCircle(const Offset(58, 41), 1.5, nostrilPaint);

    // ── Pernas ──
    final legPaint = Paint()..color = const Color(0xFF27AE60);
    canvas.drawOval(Rect.fromCenter(center: const Offset(44, 84), width: 16, height: 12), legPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(66, 84), width: 16, height: 12), legPaint);

    // ── Garras ──
    final clawPaint = Paint()
      ..color = const Color(0xFF1A5C30)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Garras esquerda
    _drawClaw(canvas, 37, 87, 35, 91, 38, 90, clawPaint);
    _drawClaw(canvas, 41, 89, 40, 93, 43, 91, clawPaint);
    _drawClaw(canvas, 46, 89, 46, 93, 49, 91, clawPaint);
    // Garras direita
    _drawClaw(canvas, 59, 89, 59, 93, 62, 91, clawPaint);
    _drawClaw(canvas, 64, 89, 65, 93, 67, 91, clawPaint);
    _drawClaw(canvas, 69, 87, 72, 91, 69, 90, clawPaint);

    // ── Braço com escudo (animado) ──
    canvas.save();
    canvas.translate(38, 62);
    canvas.rotate(shieldAngle);
    canvas.translate(-38, -62);
    // Braço
    final armPaint = Paint()
      ..color = const Color(0xFF27AE60)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final armPath = Path()
      ..moveTo(33, 62)
      ..quadraticBezierTo(22, 70, 20, 78);
    canvas.drawPath(armPath, armPaint);
    // Escudo
    final shieldDark = Paint()..color = const Color(0xFF1A56DB);
    final shieldPath = Path()
      ..moveTo(8, 70)
      ..lineTo(8, 84)
      ..quadraticBezierTo(15, 92, 22, 84)
      ..lineTo(22, 70)
      ..close();
    canvas.drawPath(shieldPath, shieldDark);
    final shieldLight = Paint()..color = const Color(0xFF3B82F6);
    final shieldInner = Path()
      ..moveTo(11, 72)
      ..lineTo(11, 82)
      ..quadraticBezierTo(15, 88, 19, 82)
      ..lineTo(19, 72)
      ..close();
    canvas.drawPath(shieldInner, shieldLight);
    // Cruz no escudo
    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(15, 73), const Offset(15, 85), crossPaint);
    canvas.drawLine(const Offset(9, 79), const Offset(21, 79), crossPaint);
    canvas.restore();

    // ── Chama (animada) ──
    canvas.save();
    canvas.translate(55, 52);
    canvas.scale(flameScale, flameScale);
    canvas.translate(-55, -52);
    final flameOuter = Paint()..color = const Color(0xFFF39C12).withOpacity(0.8);
    final flameOuterPath = Path()
      ..moveTo(55, 48)
      ..quadraticBezierTo(52, 54, 55, 56)
      ..quadraticBezierTo(58, 54, 55, 48)
      ..close();
    canvas.drawPath(flameOuterPath, flameOuter);
    final flameInner = Paint()..color = const Color(0xFFE74C3C).withOpacity(0.6);
    final flameInnerPath = Path()
      ..moveTo(55, 50)
      ..quadraticBezierTo(53, 55, 55, 57)
      ..quadraticBezierTo(57, 55, 55, 50)
      ..close();
    canvas.drawPath(flameInnerPath, flameInner);
    canvas.restore();

    canvas.restore();
  }

  void _drawClaw(Canvas canvas, double x1, double y1, double x2, double y2, double x3, double y3, Paint paint) {
    final path = Path()
      ..moveTo(x1, y1)
      ..quadraticBezierTo(x2, y2, x3, y3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DragonPainter oldDelegate) {
    return blinkScale != oldDelegate.blinkScale ||
        tailAngle != oldDelegate.tailAngle ||
        shieldAngle != oldDelegate.shieldAngle ||
        flameScale != oldDelegate.flameScale ||
        breatheScale != oldDelegate.breatheScale ||
        isHappy != oldDelegate.isHappy;
  }
}
