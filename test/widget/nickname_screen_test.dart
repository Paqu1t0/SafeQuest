// test/widget/nickname_screen_test.dart
//
// Testes de Widget — NicknameScreen
// Valida a estrutura visual e a lógica de validação do formulário
// de criação de nickname (sem chamadas reais ao Firebase).
//
// Executar: flutter test test/widget/nickname_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_safequest/screens/nickname_screen.dart';

void main() {
  Widget buildNicknameScreen() => const MaterialApp(home: NicknameScreen());

  // ── Estrutura do ecrã ─────────────────────────────────────────────────────
  group('NicknameScreen — estrutura visual', () {
    testWidgets('exibe o título "Escolhe o teu Nickname"', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());
      expect(find.text('Escolhe o teu Nickname'), findsOneWidget);
    });

    testWidgets('exibe o emoji de jogo 🎮', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());
      expect(find.text('🎮'), findsOneWidget);
    });

    testWidgets('exibe o campo de nickname com hint "ex: CyberNinja"', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());
      expect(find.text('ex: CyberNinja'), findsOneWidget);
    });

    testWidgets('exibe o botão "Entrar no Jogo 🚀"', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());
      expect(find.text('Entrar no Jogo 🚀'), findsOneWidget);
    });

    testWidgets('exibe o texto descritivo sobre clãs e leaderboards', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());
      expect(
        find.textContaining('Clãs'),
        findsWidgets,
      );
    });

    testWidgets('tem exatamente 1 campo de texto', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  // ── Validação do formulário ────────────────────────────────────────────────
  group('NicknameScreen — validação do formulário', () {
    testWidgets('mostra erro ao submeter nickname vazio', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());

      await tester.tap(find.text('Entrar no Jogo 🚀'));
      await tester.pump();

      expect(find.text('O nickname é obrigatório'), findsOneWidget);
    });

    testWidgets('mostra erro ao submeter nickname com apenas 2 caracteres', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());

      await tester.enterText(find.byType(TextFormField), 'ab');
      await tester.tap(find.text('Entrar no Jogo 🚀'));
      await tester.pump();

      expect(find.text('O nickname deve ter pelo menos 3 letras'), findsOneWidget);
    });

    testWidgets('mostra erro ao submeter nickname com espaço', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());

      await tester.enterText(find.byType(TextFormField), 'cyber ninja');
      await tester.tap(find.text('Entrar no Jogo 🚀'));
      await tester.pump();

      expect(find.text('Não podes usar espaços no nickname'), findsOneWidget);
    });

    testWidgets('não mostra erros ao introduzir nickname válido (≥3 chars, sem espaços)',
        (tester) async {
      await tester.pumpWidget(buildNicknameScreen());

      await tester.enterText(find.byType(TextFormField), 'CyberNinja');
      await tester.pump();

      // Não deve existir nenhuma mensagem de erro ainda
      expect(find.text('O nickname é obrigatório'), findsNothing);
      expect(find.text('Não podes usar espaços no nickname'), findsNothing);
      expect(find.text('O nickname deve ter pelo menos 3 letras'), findsNothing);
    });
  });

  // ── Interatividade ─────────────────────────────────────────────────────────
  group('NicknameScreen — interatividade', () {
    testWidgets('campo de texto aceita e exibe o texto inserido', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());

      await tester.enterText(find.byType(TextFormField), 'SafeHero');
      expect(find.text('SafeHero'), findsOneWidget);
    });

    testWidgets('botão está ativo quando não está a carregar', (tester) async {
      await tester.pumpWidget(buildNicknameScreen());

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });
  });
}
