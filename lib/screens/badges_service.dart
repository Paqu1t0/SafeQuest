import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BadgesService {
  static const List<Map<String, dynamic>> _allBadges = [
    // ── BÁSICOS ──────────────────────────────────────────────────────────────
    {'id': 'primeira_vitoria',   'nome': 'Primeira Vitória',      'desc': 'Complete o primeiro quiz',              'categoria': 'basica', 'icon': '🏆', 'tipo': 'total_quizzes', 'valor': 1},
    {'id': 'aprendiz_rapido',    'nome': 'Aprendiz Rápido',       'desc': 'Complete 5 quizzes',                    'categoria': 'basica', 'icon': '⚡', 'tipo': 'total_quizzes', 'valor': 5},
    {'id': 'perfeccionista',     'nome': 'Perfeccionista',        'desc': 'Obtenha 100% num quiz',                 'categoria': 'basica', 'icon': '🎯', 'tipo': 'percent_100',   'valor': 1},
    {'id': 'guru_seguranca',     'nome': 'Guru da Segurança',     'desc': 'Complete 20 quizzes',                   'categoria': 'basica', 'icon': '🎓', 'tipo': 'total_quizzes', 'valor': 20},
    {'id': 'estudante_dedicado', 'nome': 'Estudante Dedicado',    'desc': 'Complete 10 quizzes',                   'categoria': 'basica', 'icon': '📚', 'tipo': 'total_quizzes', 'valor': 10},
    {'id': 'velocista',          'nome': 'Velocista',             'desc': 'Complete um quiz contra o tempo',       'categoria': 'basica', 'icon': '⏱️', 'tipo': 'quiz_tipo',     'valor': 'tempo', 'tipoQuiz': 'tempo'},
    {'id': 'detetive',           'nome': 'Detetive',              'desc': 'Complete um quiz Verdadeiro/Falso',     'categoria': 'basica', 'icon': '🔍', 'tipo': 'quiz_tipo',     'valor': 'vf',    'tipoQuiz': 'vf'},
    {'id': 'invicto',            'nome': 'Invicto',               'desc': 'Obtenha 100% em 3 quizzes seguidos',   'categoria': 'basica', 'icon': '👑', 'tipo': 'streak_100',    'valor': 3},
    {'id': 'madrugador',         'nome': 'Madrugador',            'desc': 'Complete 50 quizzes no total',         'categoria': 'basica', 'icon': '🌟', 'tipo': 'total_quizzes', 'valor': 50},
    {'id': 'guerreiro_clan',     'nome': 'Guerreiro do Clã',      'desc': 'Vence uma batalha de quiz no clã',     'categoria': 'basica', 'icon': '⚔️', 'tipo': 'batalha_vitoria', 'valor': 1},

    // ── PHISHING ─────────────────────────────────────────────────────────────
    {'id': 'iniciante_phishing',    'nome': 'Iniciante em Phishing',    'desc': 'Complete 3 quizzes de Phishing',          'categoria': 'Phishing', 'icon': '🛡️', 'tipo': 'quizzes_tema', 'tema': 'Phishing', 'valor': 3},
    {'id': 'especialista_phishing', 'nome': 'Especialista em Phishing', 'desc': 'Obtenha média ≥ 70% em Phishing',         'categoria': 'Phishing', 'icon': '🔒', 'tipo': 'media_tema',   'tema': 'Phishing', 'valor': 70},
    {'id': 'mestre_phishing',       'nome': 'Mestre Anti-Phishing',     'desc': '100% em todos os quizzes de Phishing',    'categoria': 'Phishing', 'icon': '🦅', 'tipo': 'todos_100_tema','tema': 'Phishing', 'valor': 100},
    {'id': 'caçador_phishing',      'nome': 'Caçador de Phishing',      'desc': 'Complete 8 quizzes de Phishing',          'categoria': 'Phishing', 'icon': '🎯', 'tipo': 'quizzes_tema', 'tema': 'Phishing', 'valor': 8},
    {'id': 'detetive_phishing',     'nome': 'Detetive Digital',         'desc': 'Complete quiz V/F de Phishing com 100%',  'categoria': 'Phishing', 'icon': '🔍', 'tipo': 'vf_100_tema',  'tema': 'Phishing', 'valor': 100},

    // ── PALAVRAS-PASSE ────────────────────────────────────────────────────────
    {'id': 'guardiao_senhas',  'nome': 'Guardião de Senhas',       'desc': 'Complete 3 quizzes de Palavras-passe',        'categoria': 'Palavras-passe', 'icon': '🔑', 'tipo': 'quizzes_tema', 'tema': 'Palavras-passe', 'valor': 3},
    {'id': 'mestre_passwords', 'nome': 'Mestre das Palavras-passe','desc': 'Obtenha média ≥ 70% em Palavras-passe',       'categoria': 'Palavras-passe', 'icon': '🔐', 'tipo': 'media_tema',   'tema': 'Palavras-passe', 'valor': 70},
    {'id': 'criador_senhas',   'nome': 'Criador de Senhas Fortes', 'desc': '100% em todos os quizzes de senhas',         'categoria': 'Palavras-passe', 'icon': '💎', 'tipo': 'todos_100_tema','tema': 'Palavras-passe', 'valor': 100},
    {'id': 'vault_keeper',     'nome': 'Vault Keeper',             'desc': 'Complete 8 quizzes de Palavras-passe',       'categoria': 'Palavras-passe', 'icon': '🏦', 'tipo': 'quizzes_tema', 'tema': 'Palavras-passe', 'valor': 8},
    {'id': 'tempo_senhas',     'nome': 'Velocista das Senhas',     'desc': 'Complete quiz contra o tempo de Palavras-passe','categoria': 'Palavras-passe','icon': '⚡','tipo': 'tempo_tema',   'tema': 'Palavras-passe', 'valor': 1},

    // ── SEGURANÇA WEB ─────────────────────────────────────────────────────────
    {'id': 'surfista_web',     'nome': 'Surfista Web',             'desc': 'Complete 3 quizzes de Segurança Web',         'categoria': 'Segurança Web', 'icon': '🌐', 'tipo': 'quizzes_tema', 'tema': 'Segurança Web', 'valor': 3},
    {'id': 'navegador_seguro', 'nome': 'Navegador Seguro',         'desc': 'Obtenha média ≥ 70% em Segurança Web',        'categoria': 'Segurança Web', 'icon': '🛡️', 'tipo': 'media_tema',   'tema': 'Segurança Web', 'valor': 70},
    {'id': 'guardiao_web',     'nome': 'Guardião da Web',          'desc': '100% em todos os quizzes de Segurança Web',  'categoria': 'Segurança Web', 'icon': '🦅', 'tipo': 'todos_100_tema','tema': 'Segurança Web', 'valor': 100},
    {'id': 'hacker_etico',     'nome': 'Hacker Ético',             'desc': 'Complete 8 quizzes de Segurança Web',        'categoria': 'Segurança Web', 'icon': '💻', 'tipo': 'quizzes_tema', 'tema': 'Segurança Web', 'valor': 8},
    {'id': 'https_hero',       'nome': 'HTTPS Hero',               'desc': 'Quiz V/F de Segurança Web com 100%',         'categoria': 'Segurança Web', 'icon': '🔒', 'tipo': 'vf_100_tema',  'tema': 'Segurança Web', 'valor': 100},

    // ── REDES SOCIAIS ─────────────────────────────────────────────────────────
    {'id': 'navegador_social', 'nome': 'Navegador Social',         'desc': 'Complete 3 quizzes de Redes Sociais',        'categoria': 'Redes Sociais', 'icon': '📱', 'tipo': 'quizzes_tema', 'tema': 'Redes Sociais', 'valor': 3},
    {'id': 'influencer_seguro','nome': 'Influencer Seguro',        'desc': 'Obtenha média ≥ 70% em Redes Sociais',       'categoria': 'Redes Sociais', 'icon': '⭐', 'tipo': 'media_tema',   'tema': 'Redes Sociais', 'valor': 70},
    {'id': 'protetor_digital', 'nome': 'Protetor Digital',         'desc': '100% em todos os quizzes de Redes Sociais', 'categoria': 'Redes Sociais', 'icon': '🛡️', 'tipo': 'todos_100_tema','tema': 'Redes Sociais', 'valor': 100},
    {'id': 'social_master',    'nome': 'Social Master',            'desc': 'Complete 8 quizzes de Redes Sociais',       'categoria': 'Redes Sociais', 'icon': '🌟', 'tipo': 'quizzes_tema', 'tema': 'Redes Sociais', 'valor': 8},
    {'id': 'privacidade_pro',  'nome': 'Privacidade Pro',          'desc': 'Quiz contra o tempo de Redes Sociais',      'categoria': 'Redes Sociais', 'icon': '🔐', 'tipo': 'tempo_tema',   'tema': 'Redes Sociais', 'valor': 1},
  ];

  static List<Map<String, dynamic>> get allBadges => _allBadges;

  static Future<String?> checkAndUnlock({
    required String tema,
    required int percent,
    String tipoQuiz = 'normal',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final resultsSnap = await userRef.collection('quiz_results').get();
    final results = resultsSnap.docs.map((d) => d.data()).toList();

    final userSnap = await userRef.get();
    final userData = userSnap.data() as Map<String, dynamic>? ?? {};
    final conquistados = List<String>.from(userData['badges'] ?? []);

    String? firstNew;

    for (final badge in _allBadges) {
      final id = badge['id'] as String;
      if (conquistados.contains(id)) continue;
      if (_checkCondition(badge, results, tema, percent, tipoQuiz)) {
        conquistados.add(id);
        firstNew ??= badge['nome'] as String;
      }
    }

    if (firstNew != null) {
      await userRef.update({'badges': conquistados});
    }
    return firstNew;
  }

  static bool _checkCondition(
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
        final tema  = badge['tema'] as String;
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
        // Verifica se os últimos N quizzes foram todos 100%
        if (results.length < (valor as int)) return false;
        final last = results.reversed.take(valor).toList();
        return last.every((r) => (r['percent'] ?? 0) >= 100);
      case 'batalha_vitoria':
        return (results.where((r) => r['batalhaVitoria'] == true).length) >= (valor as int);
      default:
        return false;
    }
  }

  static Future<Set<String>> getBadgeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return Set<String>.from(data['badges'] ?? []);
  }
}