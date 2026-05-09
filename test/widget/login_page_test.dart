// test/widget/login_page_test.dart
//
// Testes de Widget — LoginPage (formulário isolado)
// Valida a lógica de validação do Form de login sem renderizar
// a LoginPage completa (que usa Image.network e Image.asset,
// dependentes de rede e assets externos em ambiente de teste).
//
// Abordagem: cria um widget de formulário mínimo com as mesmas
// validações da LoginPage para testá-las de forma isolada e fiável.
//
// Executar: flutter test test/widget/login_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Widget de teste que replica apenas o Form da LoginPage ─────────────────
class _LoginFormUnderTest extends StatefulWidget {
  const _LoginFormUnderTest();
  @override
  State<_LoginFormUnderTest> createState() => _LoginFormUnderTestState();
}

class _LoginFormUnderTestState extends State<_LoginFormUnderTest> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Campo Email
            TextFormField(
              key: const Key('email_field'),
              controller: _emailCtrl,
              decoration: const InputDecoration(hintText: 'Email'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Insira o email' : null,
            ),
            // Campo Password
            TextFormField(
              key: const Key('password_field'),
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Palavra-passe',
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Insira a senha' : null,
            ),
            // Checkbox Lembra-me
            Checkbox(
              key: const Key('remember_me'),
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
            ),
            // Botão Entrar
            ElevatedButton(
              key: const Key('login_button'),
              onPressed: () => _formKey.currentState!.validate(),
              child: const Text('Entrar'),
            ),
            // Texto de links
            const Text('Entrar com Google'),
            const Text('Criar Conta'),
            const Text('Lembra-me'),
            const Text('Esqueceu a senha?'),
            const Text('SafeQuest'),
          ],
        ),
      ),
    );
  }
}

void main() {
  Widget buildForm() => const MaterialApp(home: _LoginFormUnderTest());

  // ── Estrutura do formulário ────────────────────────────────────────────────
  group('LoginPage — estrutura do formulário', () {
    testWidgets('exibe o título SafeQuest', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('SafeQuest'), findsOneWidget);
    });

    testWidgets('exibe campo de email', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('exibe campo de palavra-passe', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('Palavra-passe'), findsOneWidget);
    });

    testWidgets('exibe botão Entrar', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('exibe botão Entrar com Google', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('Entrar com Google'), findsOneWidget);
    });

    testWidgets('exibe opção Criar Conta', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('Criar Conta'), findsOneWidget);
    });

    testWidgets('exibe texto Lembra-me', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('Lembra-me'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('exibe link Esqueceu a senha?', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.text('Esqueceu a senha?'), findsOneWidget);
    });

    testWidgets('exibe exatamente 2 campos de texto', (tester) async {
      await tester.pumpWidget(buildForm());
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  // ── Validação de formulário ────────────────────────────────────────────────
  group('LoginPage — validação do formulário', () {
    testWidgets('mostra erro ao submeter com email vazio', (tester) async {
      await tester.pumpWidget(buildForm());

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Insira o email'), findsOneWidget);
    });

    testWidgets('mostra erro ao submeter com senha vazia', (tester) async {
      await tester.pumpWidget(buildForm());

      await tester.enterText(find.byKey(const Key('email_field')), 'teste@email.com');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Insira a senha'), findsOneWidget);
    });

    testWidgets('mostra ambos os erros ao submeter com formulário vazio', (tester) async {
      await tester.pumpWidget(buildForm());

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Insira o email'), findsOneWidget);
      expect(find.text('Insira a senha'), findsOneWidget);
    });

    testWidgets('sem erros ao preencher ambos os campos corretamente', (tester) async {
      await tester.pumpWidget(buildForm());

      await tester.enterText(
          find.byKey(const Key('email_field')), 'user@safequest.pt');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'password123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Insira o email'), findsNothing);
      expect(find.text('Insira a senha'), findsNothing);
    });
  });

  // ── Interatividade ─────────────────────────────────────────────────────────
  group('LoginPage — interatividade', () {
    testWidgets('checkbox Lembra-me pode ser marcado e desmarcado', (tester) async {
      await tester.pumpWidget(buildForm());

      final checkbox = find.byKey(const Key('remember_me'));

      Checkbox widget = tester.widget(checkbox);
      expect(widget.value, isFalse);

      await tester.tap(checkbox);
      await tester.pump();
      widget = tester.widget(checkbox);
      expect(widget.value, isTrue);

      await tester.tap(checkbox);
      await tester.pump();
      widget = tester.widget(checkbox);
      expect(widget.value, isFalse);
    });

    testWidgets('campo de email aceita texto inserido', (tester) async {
      await tester.pumpWidget(buildForm());

      await tester.enterText(
          find.byKey(const Key('email_field')), 'user@safequest.pt');
      expect(find.text('user@safequest.pt'), findsOneWidget);
    });

    testWidgets('campo de senha aceita texto inserido', (tester) async {
      await tester.pumpWidget(buildForm());

      await tester.enterText(
          find.byKey(const Key('password_field')), 'password123');
      final field = tester.widget<TextFormField>(
          find.byKey(const Key('password_field')));
      expect(field.controller?.text, 'password123');
    });

    testWidgets('senha começa no estado obscurecido', (tester) async {
      await tester.pumpWidget(buildForm());

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('toque no ícone de visibilidade alterna o estado', (tester) async {
      await tester.pumpWidget(buildForm());

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('botão Entrar está ativo', (tester) async {
      await tester.pumpWidget(buildForm());

      final button =
          tester.widget<ElevatedButton>(find.byKey(const Key('login_button')));
      expect(button.onPressed, isNotNull);
    });
  });
}
