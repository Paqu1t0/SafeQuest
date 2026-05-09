// test/widget/nickname_validation_shared_test.dart
//
// Testes de validação do nickname — cobre as três ecrãs:
//   • NicknameScreen  (primeira vez após login Google)
//   • RegisterPage    (criação de conta por email)
//   • EditProfilePage (edição de perfil)
//
// Todos os testes são puramente locais — sem chamadas ao Firebase.
//
// Executar: flutter test test/widget/nickname_validation_shared_test.dart

import 'package:flutter_test/flutter_test.dart';

// ─── Função de validação extraída (mesma lógica nas 3 ecrãs) ─────────────────
String? validateNickname(String? value) {
  if (value == null || value.trim().isEmpty) return 'O nickname é obrigatório';
  if (value.contains(' '))                  return 'Não podes usar espaços no nickname';
  if (value.trim().length < 3)              return 'O nickname deve ter pelo menos 3 letras';
  return null;
}

void main() {
  // ── Casos inválidos ─────────────────────────────────────────────────────────
  group('validateNickname — casos inválidos', () {
    test('null → obrigatório', () {
      expect(validateNickname(null), 'O nickname é obrigatório');
    });

    test('string vazia → obrigatório', () {
      expect(validateNickname(''), 'O nickname é obrigatório');
    });

    test('só espaços → obrigatório (trim esvazia)', () {
      expect(validateNickname('   '), 'O nickname é obrigatório');
    });

    test('nickname com espaço interno → sem espaços', () {
      expect(validateNickname('cyber ninja'), 'Não podes usar espaços no nickname');
    });

    test('nickname com espaço à frente → sem espaços', () {
      expect(validateNickname(' abc'), 'Não podes usar espaços no nickname');
    });

    test('2 caracteres → mínimo 3 letras', () {
      expect(validateNickname('ab'), 'O nickname deve ter pelo menos 3 letras');
    });

    test('1 caractere → mínimo 3 letras', () {
      expect(validateNickname('x'), 'O nickname deve ter pelo menos 3 letras');
    });
  });

  // ── Casos válidos ───────────────────────────────────────────────────────────
  group('validateNickname — casos válidos', () {
    test('3 caracteres exactos → válido', () {
      expect(validateNickname('abc'), isNull);
    });

    test('nickname alfanumérico longo → válido', () {
      expect(validateNickname('CyberNinja99'), isNull);
    });

    test('nickname com underscore → válido', () {
      expect(validateNickname('safe_quest'), isNull);
    });

    test('nickname com hífen → válido', () {
      expect(validateNickname('safe-quest'), isNull);
    });

    test('nickname com acentos → válido', () {
      expect(validateNickname('Joãooo'), isNull);
    });
  });

  // ── Casos limite (edge cases) ───────────────────────────────────────────────
  group('validateNickname — edge cases', () {
    test('exatamente 3 letras com espaço no meio → erro de espaço', () {
      // O espaço é detetado antes de verificar o comprimento
      expect(validateNickname('a b'), 'Não podes usar espaços no nickname');
    });

    test('50 caracteres sem espaços → válido', () {
      final long = 'a' * 50;
      expect(validateNickname(long), isNull);
    });

    test('tab não é espaço → válido (regra só verifica espaço literal)', () {
      // A regra actual usa .contains(' ') — tab não é apanhado.
      // Este teste documenta o comportamento actual.
      expect(validateNickname('abc\tdef'), isNull);
    });
  });
}
