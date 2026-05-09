// test/unit/nickname_validator_test.dart
//
// Testes Unitários — Validação de Nickname
// Testa a lógica de validação do campo nickname (extraída do NicknameScreen),
// sem necessitar de Firebase, rede ou widgets.
//
// Executar: flutter test test/unit/nickname_validator_test.dart

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Lógica de validação extraída do NicknameScreen de forma idêntica
// ---------------------------------------------------------------------------
String? validateNickname(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'O nickname é obrigatório';
  }
  if (value.contains(' ')) {
    return 'Não podes usar espaços no nickname';
  }
  if (value.trim().length < 3) {
    return 'O nickname deve ter pelo menos 3 letras';
  }
  return null; // válido
}

void main() {
  group('validateNickname — casos válidos', () {
    test('nickname válido com 3 caracteres', () {
      expect(validateNickname('abc'), isNull);
    });

    test('nickname válido com caracteres alfanuméricos', () {
      expect(validateNickname('CyberNinja99'), isNull);
    });

    test('nickname válido com underscores e hífens', () {
      expect(validateNickname('cyber_ninja'), isNull);
    });

    test('nickname longo é válido', () {
      expect(validateNickname('SuperCyberHeroSafeQuest'), isNull);
    });
  });

  group('validateNickname — casos inválidos', () {
    test('nickname nulo retorna erro obrigatório', () {
      expect(validateNickname(null), 'O nickname é obrigatório');
    });

    test('nickname vazio retorna erro obrigatório', () {
      expect(validateNickname(''), 'O nickname é obrigatório');
    });

    test('nickname só com espaços retorna erro obrigatório', () {
      expect(validateNickname('   '), 'O nickname é obrigatório');
    });

    test('nickname com espaço no meio retorna erro de espaços', () {
      expect(validateNickname('cyber ninja'), 'Não podes usar espaços no nickname');
    });

    test('nickname com espaço no início retorna erro de espaços', () {
      expect(validateNickname(' ninja'), 'Não podes usar espaços no nickname');
    });

    test('nickname com apenas 1 caractere retorna erro de tamanho', () {
      expect(validateNickname('a'), 'O nickname deve ter pelo menos 3 letras');
    });

    test('nickname com apenas 2 caracteres retorna erro de tamanho', () {
      expect(validateNickname('ab'), 'O nickname deve ter pelo menos 3 letras');
    });

    test('nickname com exatamente 2 caracteres (sem espaços) retorna erro de tamanho', () {
      expect(validateNickname('XY'), 'O nickname deve ter pelo menos 3 letras');
    });
  });

  group('validateNickname — casos limite', () {
    test('exatamente 3 caracteres sem espaços é válido', () {
      expect(validateNickname('xyz'), isNull);
    });

    test('espaço no final não deve ser válido (contém espaço)', () {
      // 'ab ' contém espaço → erro de espaço, não de tamanho
      expect(validateNickname('ab '), 'Não podes usar espaços no nickname');
    });
  });
}
