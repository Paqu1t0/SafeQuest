// test/unit/badges_service_test.dart
//
// Testes Unitários — BadgesService._checkCondition
// Testa a lógica pura de verificação de condições de badges,
// sem necessitar de Firebase ou rede.
//
// Executar: flutter test test/unit/badges_service_test.dart

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Como _checkCondition é estático e privado, extraímos a lógica aqui
// de forma idêntica para teste isolado.
// ---------------------------------------------------------------------------
bool checkCondition(
  Map<String, dynamic> badge,
  List<Map<String, dynamic>> results,
  String temaAtual,
  int percentAtual,
  String tipoQuiz,
) {
  final tipo  = badge['tipo'] as String;
  final valor = badge['valor'];

  switch (tipo) {
    case 'total_quizzes':
      return results.length >= (valor as int);
    case 'percent_100':
      return results.any((r) => (r['percent'] ?? 0) >= 100);
    case 'quizzes_tema':
      final tema = badge['tema'] as String;
      return results.where((r) => r['theme'] == tema).length >= (valor as int);
    case 'media_tema':
      final tema     = badge['tema'] as String;
      final filtered = results.where((r) => r['theme'] == tema).toList();
      if (filtered.isEmpty) return false;
      final soma = filtered.fold<double>(0, (s, r) => s + (r['percent'] ?? 0).toDouble());
      return (soma / filtered.length) >= (valor as int);
    case 'todos_100_tema':
      final tema     = badge['tema'] as String;
      final filtered = results.where((r) => r['theme'] == tema).toList();
      if (filtered.isEmpty) return false;
      return filtered.every((r) => (r['percent'] ?? 0) >= 100);
    case 'quiz_tipo':
      return tipoQuiz == (badge['tipoQuiz'] as String);
    case 'tempo_tema':
      final tema = badge['tema'] as String;
      return temaAtual == tema && tipoQuiz == 'tempo';
    case 'vf_100_tema':
      final tema = badge['tema'] as String;
      return temaAtual == tema && tipoQuiz == 'vf' && percentAtual >= 100;
    case 'streak_100':
      if (results.length < (valor as int)) return false;
      final last = results.reversed.take(valor).toList();
      return last.every((r) => (r['percent'] ?? 0) >= 100);
    case 'batalha_vitoria':
      return (results.where((r) => r['batalhaVitoria'] == true).length) >= (valor as int);
    default:
      return false;
  }
}

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────
  Map<String, dynamic> quiz({
    String theme = 'Phishing',
    int percent = 80,
    String tipo = 'normal',
    bool batalhaVitoria = false,
  }) =>
      {'theme': theme, 'percent': percent, 'tipoQuiz': tipo, 'batalhaVitoria': batalhaVitoria};

  // ── total_quizzes ──────────────────────────────────────────────────────────
  group('total_quizzes', () {
    final badge = {'tipo': 'total_quizzes', 'valor': 5};

    test('deve desbloquear quando o utilizador tem quizzes suficientes', () {
      final results = List.generate(5, (_) => quiz());
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isTrue);
    });

    test('NÃO deve desbloquear com menos quizzes do que o necessário', () {
      final results = List.generate(4, (_) => quiz());
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isFalse);
    });

    test('deve desbloquear com mais quizzes do que o mínimo', () {
      final results = List.generate(10, (_) => quiz());
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isTrue);
    });
  });

  // ── percent_100 ────────────────────────────────────────────────────────────
  group('percent_100', () {
    final badge = {'tipo': 'percent_100', 'valor': 1};

    test('deve desbloquear quando existe pelo menos um quiz com 100%', () {
      final results = [quiz(percent: 60), quiz(percent: 100)];
      expect(checkCondition(badge, results, 'Phishing', 100, 'normal'), isTrue);
    });

    test('NÃO deve desbloquear se nenhum quiz tem 100%', () {
      final results = [quiz(percent: 99), quiz(percent: 80)];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isFalse);
    });
  });

  // ── quizzes_tema ───────────────────────────────────────────────────────────
  group('quizzes_tema', () {
    final badge = {'tipo': 'quizzes_tema', 'tema': 'Phishing', 'valor': 3};

    test('deve desbloquear com 3 quizzes no tema correto', () {
      final results = [
        quiz(theme: 'Phishing'),
        quiz(theme: 'Phishing'),
        quiz(theme: 'Phishing'),
      ];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isTrue);
    });

    test('NÃO deve contar quizzes de outros temas', () {
      final results = [
        quiz(theme: 'Phishing'),
        quiz(theme: 'Palavras-passe'),
        quiz(theme: 'Segurança Web'),
      ];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isFalse);
    });
  });

  // ── media_tema ─────────────────────────────────────────────────────────────
  group('media_tema', () {
    final badge = {'tipo': 'media_tema', 'tema': 'Phishing', 'valor': 70};

    test('deve desbloquear quando a média do tema é >= 70%', () {
      final results = [
        quiz(theme: 'Phishing', percent: 80),
        quiz(theme: 'Phishing', percent: 70),
        quiz(theme: 'Phishing', percent: 90),
      ];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isTrue);
    });

    test('NÃO deve desbloquear quando a média é inferior a 70%', () {
      final results = [
        quiz(theme: 'Phishing', percent: 50),
        quiz(theme: 'Phishing', percent: 60),
      ];
      expect(checkCondition(badge, results, 'Phishing', 50, 'normal'), isFalse);
    });

    test('NÃO deve desbloquear se não há resultados no tema', () {
      final results = [quiz(theme: 'Segurança Web', percent: 100)];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isFalse);
    });
  });

  // ── todos_100_tema ─────────────────────────────────────────────────────────
  group('todos_100_tema', () {
    final badge = {'tipo': 'todos_100_tema', 'tema': 'Phishing', 'valor': 100};

    test('deve desbloquear quando todos os quizzes do tema têm 100%', () {
      final results = [
        quiz(theme: 'Phishing', percent: 100),
        quiz(theme: 'Phishing', percent: 100),
      ];
      expect(checkCondition(badge, results, 'Phishing', 100, 'normal'), isTrue);
    });

    test('NÃO deve desbloquear se algum quiz do tema não tem 100%', () {
      final results = [
        quiz(theme: 'Phishing', percent: 100),
        quiz(theme: 'Phishing', percent: 90),
      ];
      expect(checkCondition(badge, results, 'Phishing', 90, 'normal'), isFalse);
    });
  });

  // ── quiz_tipo ──────────────────────────────────────────────────────────────
  group('quiz_tipo', () {
    test('deve desbloquear "Velocista" ao completar quiz tipo tempo', () {
      final badge = {'tipo': 'quiz_tipo', 'tipoQuiz': 'tempo'};
      expect(checkCondition(badge, [], 'Phishing', 80, 'tempo'), isTrue);
    });

    test('deve desbloquear "Detetive" ao completar quiz tipo vf', () {
      final badge = {'tipo': 'quiz_tipo', 'tipoQuiz': 'vf'};
      expect(checkCondition(badge, [], 'Phishing', 80, 'vf'), isTrue);
    });

    test('NÃO deve desbloquear com tipo de quiz errado', () {
      final badge = {'tipo': 'quiz_tipo', 'tipoQuiz': 'tempo'};
      expect(checkCondition(badge, [], 'Phishing', 80, 'normal'), isFalse);
    });
  });

  // ── vf_100_tema ────────────────────────────────────────────────────────────
  group('vf_100_tema', () {
    final badge = {'tipo': 'vf_100_tema', 'tema': 'Phishing', 'valor': 100};

    test('deve desbloquear ao completar quiz V/F do tema com 100%', () {
      expect(checkCondition(badge, [], 'Phishing', 100, 'vf'), isTrue);
    });

    test('NÃO deve desbloquear se a percentagem não é 100%', () {
      expect(checkCondition(badge, [], 'Phishing', 90, 'vf'), isFalse);
    });

    test('NÃO deve desbloquear com tema diferente', () {
      expect(checkCondition(badge, [], 'Segurança Web', 100, 'vf'), isFalse);
    });
  });

  // ── streak_100 ─────────────────────────────────────────────────────────────
  group('streak_100', () {
    final badge = {'tipo': 'streak_100', 'valor': 3};

    test('deve desbloquear quando os últimos 3 quizzes foram 100%', () {
      final results = [
        quiz(percent: 50),
        quiz(percent: 100),
        quiz(percent: 100),
        quiz(percent: 100),
      ];
      expect(checkCondition(badge, results, 'Phishing', 100, 'normal'), isTrue);
    });

    test('NÃO deve desbloquear se há um quiz não perfeito nos últimos 3', () {
      final results = [
        quiz(percent: 100),
        quiz(percent: 100),
        quiz(percent: 80),
      ];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isFalse);
    });

    test('NÃO deve desbloquear com menos resultados do que o streak necessário', () {
      final results = [quiz(percent: 100), quiz(percent: 100)];
      expect(checkCondition(badge, results, 'Phishing', 100, 'normal'), isFalse);
    });
  });

  // ── batalha_vitoria ────────────────────────────────────────────────────────
  group('batalha_vitoria', () {
    final badge = {'tipo': 'batalha_vitoria', 'valor': 1};

    test('deve desbloquear ao ganhar pelo menos 1 batalha de clã', () {
      final results = [quiz(batalhaVitoria: true)];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isTrue);
    });

    test('NÃO deve desbloquear sem vitórias em batalhas', () {
      final results = [quiz(batalhaVitoria: false), quiz(batalhaVitoria: false)];
      expect(checkCondition(badge, results, 'Phishing', 80, 'normal'), isFalse);
    });
  });
}
