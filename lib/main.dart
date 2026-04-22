import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:projeto_safequest/services/app_settings.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'package:projeto_safequest/screens/home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/mfa_email_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin localNotifsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  await _configurarNotificacoes();
  
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
     print("Recebi mensagem com a app aberta!");
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
      // ── StreamBuilder mantém sessão ──────────────────────────────────────
      home: const _AuthGate(),
      routes: {
        '/login'   : (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home'    : (_) => const HomePage(),
      },
    );
  }
}

// ── AuthGate — gere sessão + MFA + aviso de internet ──────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _internetChecked = false;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInternet();
  }

  Future<void> _checkInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final online = result.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _hasInternet = online;
          _internetChecked = true;
        });
        if (!online) {
          _showNoInternetDialog();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasInternet = false;
          _internetChecked = true;
        });
        _showNoInternetDialog();
      }
    }
  }

  void _showNoInternetDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 48),
          title: const Text(
            'Sem Ligação à Internet',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
          ),
          content: const Text(
            'Não foi detetada ligação à internet.\n\n'
            '⚠️ O Assistente IA e algumas funcionalidades não estarão disponíveis sem internet.\n\n'
            'Podes continuar a usar a app, mas com funcionalidades limitadas.',
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56DB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // A inicializar
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB))),
          );
        }
        // Utilizador autenticado → verifica MFA
        if (snapshot.hasData && snapshot.data != null) {
          return _MfaGate(user: snapshot.data!);
        }
        // Não autenticado → Login
        return const LoginPage();
      },
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

      // Só salta MFA se: "Lembra-me" ativo + MFA verificado < 30 dias + mesmo user
      if (rememberMe &&
          mfaTimestamp > 0 &&
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
    return const HomePage();
  }
}

