import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. NOVO: Importa o pacote dotenv
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'package:projeto_safequest/screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. NOVO: Carrega as chaves secretas ANTES de a app arrancar
  await dotenv.load(fileName: ".env");

  // Inicializa o Firebase
  await Firebase.initializeApp();

  runApp(const SafeQuest());
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
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}