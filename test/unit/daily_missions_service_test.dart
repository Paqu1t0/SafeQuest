// test/unit/daily_missions_service_test.dart
//
// Testes Unitários — DailyMissionsService
// Testa isMissionComplete, missionProgress e progressValue
// sem necessitar de Firebase ou rede.
//
// Executar: flutter test test/unit/daily_missions_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_safequest/screens/daily_missions_service.dart';

void main() {
  // ── Fixtures ───────────────────────────────────────────────────────────────
  const quizzes3 = DailyMission(
    id: 'quizzes3', icon: '🎯', title: 'Triathlo do Saber',
    description: 'Faz 3 quizzes hoje', target: 3, rewardMoedas: 80,
  );
  const perfect1 = DailyMission(
    id: 'perfect1', icon: '⭐', title: 'Perfecionista',
    description: 'Termina 1 quiz com 100%', target: 1, rewardMoedas: 120,
  );
  const temas2 = DailyMission(
    id: 'temas2', icon: '🌐', title: 'Explorador',
    description: 'Joga em 2 temas diferentes hoje', target: 2, rewardMoedas: 60,
  );
  const quizzes5 = DailyMission(
    id: 'quizzes5', icon: '🔥', title: 'Máquina de Quizzes',
    description: 'Faz 5 quizzes hoje', target: 5, rewardMoedas: 200,
  );

  // ── isMissionComplete ──────────────────────────────────────────────────────
  group('isMissionComplete', () {
    group('quizzes3 — fazer 3 quizzes no dia', () {
      test('completa com exatamente 3 quizzes', () {
        expect(DailyMissionsService.isMissionComplete(quizzes3, {'quizzesDone': 3}), isTrue);
      });
      test('completa com mais de 3 quizzes', () {
        expect(DailyMissionsService.isMissionComplete(quizzes3, {'quizzesDone': 5}), isTrue);
      });
      test('NÃO completa com 2 quizzes', () {
        expect(DailyMissionsService.isMissionComplete(quizzes3, {'quizzesDone': 2}), isFalse);
      });
      test('NÃO completa com dados vazios', () {
        expect(DailyMissionsService.isMissionComplete(quizzes3, {}), isFalse);
      });
    });

    group('perfect1 — terminar 1 quiz com 100%', () {
      test('completa com 1 quiz perfeito', () {
        expect(DailyMissionsService.isMissionComplete(perfect1, {'perfectDone': 1}), isTrue);
      });
      test('completa com múltiplos quizzes perfeitos', () {
        expect(DailyMissionsService.isMissionComplete(perfect1, {'perfectDone': 3}), isTrue);
      });
      test('NÃO completa sem quizzes perfeitos', () {
        expect(DailyMissionsService.isMissionComplete(perfect1, {'perfectDone': 0}), isFalse);
      });
    });

    group('temas2 — jogar em 2 temas diferentes', () {
      test('completa ao jogar em 2 temas', () {
        expect(DailyMissionsService.isMissionComplete(
            temas2, {'temasDone': ['Phishing', 'Palavras-passe']}), isTrue);
      });
      test('NÃO completa com apenas 1 tema', () {
        expect(DailyMissionsService.isMissionComplete(
            temas2, {'temasDone': ['Phishing']}), isFalse);
      });
      test('NÃO completa com lista de temas nula', () {
        expect(DailyMissionsService.isMissionComplete(temas2, {}), isFalse);
      });
    });

    group('quizzes5 — fazer 5 quizzes no dia', () {
      test('completa com 5 quizzes', () {
        expect(DailyMissionsService.isMissionComplete(quizzes5, {'quizzesDone': 5}), isTrue);
      });
      test('NÃO completa com 4 quizzes', () {
        expect(DailyMissionsService.isMissionComplete(quizzes5, {'quizzesDone': 4}), isFalse);
      });
    });
  });

  // ── missionProgress (0.0 – 1.0) ───────────────────────────────────────────
  group('missionProgress', () {
    test('quizzes3: 0 quizzes → 0.0', () {
      expect(DailyMissionsService.missionProgress(quizzes3, {}), 0.0);
    });
    test('quizzes3: 1 quiz → ~0.333', () {
      expect(
        DailyMissionsService.missionProgress(quizzes3, {'quizzesDone': 1}),
        closeTo(1 / 3, 0.001),
      );
    });
    test('quizzes3: 3 quizzes → 1.0 (completo)', () {
      expect(DailyMissionsService.missionProgress(quizzes3, {'quizzesDone': 3}), 1.0);
    });
    test('quizzes3: não ultrapassa 1.0 com mais de 3 quizzes', () {
      expect(DailyMissionsService.missionProgress(quizzes3, {'quizzesDone': 10}), 1.0);
    });

    test('perfect1: 0 perfeitos → 0.0', () {
      expect(DailyMissionsService.missionProgress(perfect1, {'perfectDone': 0}), 0.0);
    });
    test('perfect1: 1 perfeito → 1.0', () {
      expect(DailyMissionsService.missionProgress(perfect1, {'perfectDone': 1}), 1.0);
    });

    test('temas2: 1 de 2 temas → 0.5', () {
      expect(
        DailyMissionsService.missionProgress(temas2, {'temasDone': ['Phishing']}),
        0.5,
      );
    });
    test('temas2: 2 de 2 temas → 1.0', () {
      expect(
        DailyMissionsService.missionProgress(
            temas2, {'temasDone': ['Phishing', 'Palavras-passe']}),
        1.0,
      );
    });
  });

  // ── progressValue (valor inteiro) ─────────────────────────────────────────
  group('progressValue', () {
    test('quizzes3: retorna valor atual limitado a 3', () {
      expect(DailyMissionsService.progressValue(quizzes3, {'quizzesDone': 2}), 2);
      expect(DailyMissionsService.progressValue(quizzes3, {'quizzesDone': 10}), 3);
    });

    test('quizzes5: retorna valor atual limitado a 5', () {
      expect(DailyMissionsService.progressValue(quizzes5, {'quizzesDone': 3}), 3);
      expect(DailyMissionsService.progressValue(quizzes5, {'quizzesDone': 99}), 5);
    });

    test('perfect1: retorna 0 ou 1', () {
      expect(DailyMissionsService.progressValue(perfect1, {'perfectDone': 0}), 0);
      expect(DailyMissionsService.progressValue(perfect1, {'perfectDone': 5}), 1);
    });

    test('temas2: retorna número de temas únicos, máximo 2', () {
      expect(
        DailyMissionsService.progressValue(
            temas2, {'temasDone': ['Phishing', 'Web', 'Passwords']}),
        2,
      );
    });
  });

  // ── todayKey ───────────────────────────────────────────────────────────────
  group('todayKey', () {
    test('retorna data no formato YYYY-MM-DD', () {
      final key = DailyMissionsService.todayKey();
      // Valida formato: exatamente 10 chars, separadores nas posições 4 e 7
      expect(key.length, 10);
      expect(key[4], '-');
      expect(key[7], '-');
    });

    test('a chave de hoje é consistente quando chamada duas vezes no mesmo segundo', () {
      final key1 = DailyMissionsService.todayKey();
      final key2 = DailyMissionsService.todayKey();
      expect(key1, key2);
    });
  });
}
