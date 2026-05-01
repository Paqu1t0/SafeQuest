import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:projeto_safequest/services/app_settings.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'package:projeto_safequest/screens/home_page.dart';
import 'package:projeto_safequest/screens/onboarding_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:projeto_safequest/screens/nickname_screen.dart';
import 'screens/mfa_email_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin localNotifsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
 
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Aqui fizeste perfeitamente bem!
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Envolvemos as notificações num try-catch para proteger o arranque da app
  try {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
    await _configurarNotificacoes();
  } catch (e) {
    debugPrint("Aviso: Notificações não suportadas neste browser (normal no iPhone). Erro: $e");
  }
  
  // Forçar logout se o "Lembra-me" não estiver ativo OU se passaram 30 dias do MFA
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? false;
  final mfaTimestamp = prefs.getInt('mfa_verified_at') ?? 0;
  final savedUid = prefs.getString('mfa_uid') ?? '';
  final now = DateTime.now().millisecondsSinceEpoch;
  final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
  
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser != null) {
    if (!rememberMe) {
      await FirebaseAuth.instance.signOut();
    } else if (mfaTimestamp == 0 || (now - mfaTimestamp) >= thirtyDaysMs || savedUid != currentUser.uid) {
      // MFA expirou ou mudou de utilizador -> Obriga a fazer Login de novo
      await FirebaseAuth.instance.signOut();
    }
  }
  
  final settings = AppSettings();
  await settings.load();
  runApp(ChangeNotifierProvider.value(value: settings, child: const SafeQuest()));
}

Future<void> _configurarNotificacoes() async {
  final messaging = FirebaseMessaging.instance;
  
  // 1. Pede permissão ao utilizador
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // 2. CRIA O CANAL PARA O ANDROID (Isto resolve o bloqueio do Samsung!)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'safequest_channel', // TEM DE SER IGUAL AO DO MANIFEST
    'Missões SafeQuest', // O nome que aparece nas definições do telemóvel
    description: 'Avisos sobre quizzes e recompensas.',
    importance: Importance.max, // Importância MÁXIMA para forçar o pop-up
  );

  await localNotifsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 3. Força a notificação a aparecer mesmo com a app aberta (Opcional, mas útil)
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     debugPrint("Recebi mensagem com a app aberta!");
  });
}

class SafeQuest extends StatelessWidget {
  const SafeQuest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeQuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A56DB)),
        useMaterial3: true,
      ),
      // ── Verifica a sessão através do AuthGate ─────────────────
      home: const AuthGate(),
      routes: {
        '/login'   : (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home'    : (_) => const HomePage(),
      },
    );
  }
}

// ── AuthGate — gere sessão + MFA + aviso de internet ──────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isOnline = true;
  bool _wasOffline = false; // track if we need to reload on reconnect
  bool _offlineBannerDismissed = false;

  // Features que requerem internet
  static const _offlineFeatures = [
    ('🤖', 'Assistente IA'),
    ('💬', 'Chat do Clã'),
    ('⚔️', 'Batalhas de Quiz'),
    ('🏆', 'Classificação'),
    ('📊', 'Sincronização de dados'),
  ];

  @override
  void initState() {
    super.initState();
    _checkAndListen();
  }

  Future<void> _checkAndListen() async {
    // Verificação inicial
    try {
      final result = await Connectivity().checkConnectivity();
      final online = result.any((r) => r != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    } catch (_) {
      if (mounted) setState(() => _isOnline = false);
    }

    // Ouve mudanças de conectividade em tempo real
    Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      final online = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_isOnline;
      setState(() {
        _isOnline = online;
        if (online && wasOffline) {
          _wasOffline = true;
          _offlineBannerDismissed = false;
        }
        if (!online) {
          _offlineBannerDismissed = false; 
        }
      });
      // Auto-reload: quando internet volta, recarrega a página (reseta o estado)
      if (online && wasOffline && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _wasOffline = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB))),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return _MfaGate(user: snapshot.data!);
            }
            return const LoginPage();
          },
        ),
        // ── Banner de sem internet (aparece por cima de tudo) ──────────────
        if (!_isOnline && !_offlineBannerDismissed) _buildOfflineBanner(),
        // ── Banner de internet restaurada ──────────────────────────────────
        if (_isOnline && _wasOffline) _buildOnlineBanner(),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Dismissible(
          key: const Key('offline_banner'),
          direction: DismissDirection.up,
          onDismissed: (_) => setState(() => _offlineBannerDismissed = true),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Sem ligação à internet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                    Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 16), // Dica de swipe
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Funcionalidades indisponíveis sem internet:',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _offlineFeatures.map((f) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(f.$1, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(f.$2, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500)),
                          ]),
                        )).toList(),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('Desliza para cima para ignorar este aviso.',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontStyle: FontStyle.italic)),
                          ),
                          Icon(Icons.swipe_up_rounded, color: Colors.grey, size: 14),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Row(children: [
            Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Internet restaurada! Todas as funcionalidades estão disponíveis.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            Text('✅', style: TextStyle(fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

// ── MfaGate — verifica se MFA é necessário ────────────────────────────────
class _MfaGate extends StatefulWidget {
  final User user;
  const _MfaGate({required this.user});
  @override
  State<_MfaGate> createState() => _MfaGateState();
}

class _MfaGateState extends State<_MfaGate> {
  bool _loading = true;
  bool _needsMfa = false;

  @override
  void initState() {
    super.initState();
    _checkMfa();
  }

  Future<void> _checkMfa() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      final mfaTimestamp = prefs.getInt('mfa_verified_at') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000; // 30 dias em ms
      final savedUid = prefs.getString('mfa_uid') ?? '';

      // Só salta MFA se: MFA verificado < 30 dias + mesmo user
      if (mfaTimestamp > 0 &&
          (now - mfaTimestamp) < thirtyDaysMs &&
          savedUid == widget.user.uid) {
        // MFA válido — skip
        if (mounted) setState(() { _loading = false; _needsMfa = false; });
      } else {
        // MFA necessário (primeiro login, outro dispositivo, ou 30 dias expirados)
        if (mounted) setState(() { _loading = false; _needsMfa = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _needsMfa = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB))),
      );
    }
    if (_needsMfa) {
      return const MFAEmailPage();
    }
    return _SetupGate(user: widget.user);
  }
}

// ── SetupGate — verifica Onboarding e Nickname ────────────────────────────
class _SetupGate extends StatefulWidget {
  final User user;
  const _SetupGate({required this.user});

  @override
  State<_SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends State<_SetupGate> {
  bool _loading = true;
  bool _needsOnboarding = false;
  bool _needsNickname = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    try {
      final showOnboarding = await OnboardingScreen.shouldShow();
      if (showOnboarding) {
        if (mounted) setState(() { _loading = false; _needsOnboarding = true; });
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
      final nickname = doc.data()?['nickname'] as String?;
      
      if (nickname == null || nickname.trim().isEmpty) {
        if (mounted) setState(() { _loading = false; _needsNickname = true; });
        return;
      }

      if (mounted) setState(() { _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; }); // Se falhar, avança (segurança)
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB))),
      );
    }
    if (_needsOnboarding) {
      return const OnboardingScreen();
    }
    if (_needsNickname) {
      return const NicknameScreen();
    }
    return const HomePage();
  }
}

