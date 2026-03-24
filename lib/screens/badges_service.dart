import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BADGES SERVICE — verifica e desbloqueia emblemas automaticamente
// ─────────────────────────────────────────────────────────────────────────────

class BadgesService {
  // Definição de todos os emblemas e as suas condições
  static const List<Map<String, dynamic>> _allBadges = [
    // ── BÁSICOS ──────────────────────────────────────────────────────────────
    {
      'id'      : 'primeira_vitoria',
      'nome'    : 'Primeira Vitória',
      'desc'    : 'Complete o primeiro quiz',
      'categoria': 'basica',
      'tipo'    : 'total_quizzes',
      'valor'   : 1,
    },
    {
      'id'      : 'aprendiz_rapido',
      'nome'    : 'Aprendiz Rápido',
      'desc'    : 'Complete 5 quizzes',
      'categoria': 'basica',
      'tipo'    : 'total_quizzes',
      'valor'   : 5,
    },
    {
      'id'      : 'perfeccionista',
      'nome'    : 'Perfeccionista',
      'desc'    : 'Obtenha 100% num quiz',
      'categoria': 'basica',
      'tipo'    : 'percent_100',
      'valor'   : 1,
    },
    {
      'id'      : 'guru_seguranca',
      'nome'    : 'Guru da Segurança',
      'desc'    : 'Complete 20 quizzes',
      'categoria': 'basica',
      'tipo'    : 'total_quizzes',
      'valor'   : 20,
    },

    // ── PHISHING ─────────────────────────────────────────────────────────────
    {
      'id'      : 'iniciante_phishing',
      'nome'    : 'Iniciante em Phishing',
      'desc'    : 'Complete 3 quizzes de Phishing',
      'categoria': 'Phishing',
      'tipo'    : 'quizzes_tema',
      'tema'    : 'Phishing',
      'valor'   : 3,
    },
    {
      'id'      : 'especialista_phishing',
      'nome'    : 'Especialista em Phishing',
      'desc'    : 'Obtenha média ≥ 70% em Phishing',
      'categoria': 'Phishing',
      'tipo'    : 'media_tema',
      'tema'    : 'Phishing',
      'valor'   : 70,
    },
    {
      'id'      : 'mestre_phishing',
      'nome'    : 'Mestre Anti-Phishing',
      'desc'    : '100% em todos os quizzes de Phishing',
      'categoria': 'Phishing',
      'tipo'    : 'todos_100_tema',
      'tema'    : 'Phishing',
      'valor'   : 100,
    },

    // ── PALAVRAS-PASSE ────────────────────────────────────────────────────────
    {
      'id'      : 'guardiao_senhas',
      'nome'    : 'Guardião de Senhas',
      'desc'    : 'Complete 3 quizzes de Palavras-passe',
      'categoria': 'Palavras-passe',
      'tipo'    : 'quizzes_tema',
      'tema'    : 'Palavras-passe',
      'valor'   : 3,
    },
    {
      'id'      : 'mestre_passwords',
      'nome'    : 'Mestre das Palavras-passe',
      'desc'    : 'Obtenha média ≥ 70% em Palavras-passe',
      'categoria': 'Palavras-passe',
      'tipo'    : 'media_tema',
      'tema'    : 'Palavras-passe',
      'valor'   : 70,
    },
    {
      'id'      : 'criador_senhas',
      'nome'    : 'Criador de Senhas Fortes',
      'desc'    : '100% em todos os quizzes de senhas',
      'categoria': 'Palavras-passe',
      'tipo'    : 'todos_100_tema',
      'tema'    : 'Palavras-passe',
      'valor'   : 100,
    },

    // ── SEGURANÇA WEB ─────────────────────────────────────────────────────────
    {
      'id'      : 'surfista_web',
      'nome'    : 'Surfista Web',
      'desc'    : 'Complete 3 quizzes de Segurança Web',
      'categoria': 'Segurança Web',
      'tipo'    : 'quizzes_tema',
      'tema'    : 'Segurança Web',
      'valor'   : 3,
    },
    {
      'id'      : 'navegador_seguro',
      'nome'    : 'Navegador Seguro',
      'desc'    : 'Obtenha média ≥ 70% em Segurança Web',
      'categoria': 'Segurança Web',
      'tipo'    : 'media_tema',
      'tema'    : 'Segurança Web',
      'valor'   : 70,
    },
    {
      'id'      : 'guardiao_web',
      'nome'    : 'Guardião da Web',
      'desc'    : '100% em todos os quizzes de Segurança Web',
      'categoria': 'Segurança Web',
      'tipo'    : 'todos_100_tema',
      'tema'    : 'Segurança Web',
      'valor'   : 100,
    },

    // ── REDES SOCIAIS ─────────────────────────────────────────────────────────
    {
      'id'      : 'navegador_social',
      'nome'    : 'Navegador Social',
      'desc'    : 'Complete 3 quizzes de Redes Sociais',
      'categoria': 'Redes Sociais',
      'tipo'    : 'quizzes_tema',
      'tema'    : 'Redes Sociais',
      'valor'   : 3,
    },
    {
      'id'      : 'influencer_seguro',
      'nome'    : 'Influencer Seguro',
      'desc'    : 'Obtenha média ≥ 70% em Redes Sociais',
      'categoria': 'Redes Sociais',
      'tipo'    : 'media_tema',
      'tema'    : 'Redes Sociais',
      'valor'   : 70,
    },
    {
      'id'      : 'protetor_digital',
      'nome'    : 'Protetor Digital',
      'desc'    : '100% em todos os quizzes de Redes Sociais',
      'categoria': 'Redes Sociais',
      'tipo'    : 'todos_100_tema',
      'tema'    : 'Redes Sociais',
      'valor'   : 100,
    },
  ];

  // ── checkAndUnlock ──────────────────────────────────────────────────────────
  // Chamado no fim de cada quiz. Devolve o nome do PRIMEIRO emblema
  // recém-desbloqueado (para mostrar no popup), ou null se nenhum novo.
  static Future<String?> checkAndUnlock({
    required String tema,
    required int percent,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Carrega todos os quiz_results de uma vez
    final resultsSnap =
        await userRef.collection('quiz_results').get();
    final results = resultsSnap.docs
        .map((d) => d.data())
        .toList();

    // Carrega emblemas já conquistados
    final userSnap = await userRef.get();
    final userData = userSnap.data() as Map<String, dynamic>? ?? {};
    final conquistados =
        List<String>.from(userData['badges'] ?? []);

    String? firstNew; // primeiro emblema novo desta sessão

    for (final badge in _allBadges) {
      final id = badge['id'] as String;
      if (conquistados.contains(id)) continue; // já tem

      final unlocked =
          _checkCondition(badge, results, tema, percent);

      if (unlocked) {
        conquistados.add(id);
        firstNew ??= badge['nome'] as String;
      }
    }

    // Guarda no Firestore se houver novidades
    if (firstNew != null) {
      await userRef.update({'badges': conquistados});
    }

    return firstNew;
  }

  // ── _checkCondition ─────────────────────────────────────────────────────────
  static bool _checkCondition(
    Map<String, dynamic> badge,
    List<Map<String, dynamic>> results,
    String temaAtual,
    int percentAtual,
  ) {
    final tipo  = badge['tipo'] as String;
    final valor = badge['valor'] as int;

    switch (tipo) {
      // Total de quizzes realizados
      case 'total_quizzes':
        return results.length >= valor;

      // Pelo menos 1 quiz com 100%
      case 'percent_100':
        return results.any((r) => (r['percent'] ?? 0) >= 100);

      // Nº de quizzes de um tema específico
      case 'quizzes_tema':
        final tema = badge['tema'] as String;
        final count =
            results.where((r) => r['theme'] == tema).length;
        return count >= valor;

      // Média de um tema ≥ valor
      case 'media_tema':
        final tema = badge['tema'] as String;
        final filtered =
            results.where((r) => r['theme'] == tema).toList();
        if (filtered.isEmpty) return false;
        final soma = filtered.fold<double>(
            0, (s, r) => s + (r['percent'] ?? 0).toDouble());
        return (soma / filtered.length) >= valor;

      // Todos os quizzes de um tema com 100%
      case 'todos_100_tema':
        final tema = badge['tema'] as String;
        final filtered =
            results.where((r) => r['theme'] == tema).toList();
        if (filtered.isEmpty) return false;
        return filtered.every((r) => (r['percent'] ?? 0) >= 100);

      default:
        return false;
    }
  }

  // ── getBadgeStatus ───────────────────────────────────────────────────────────
  // Utilitário para a RecompensasPage: devolve Set com IDs conquistados
  static Future<Set<String>> getBadgeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return Set<String>.from(data['badges'] ?? []);
  }

  // ── allBadges getter ──────────────────────────────────────────────────────
  static List<Map<String, dynamic>> get allBadges => _allBadges;
}