import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Importa o motor do Firebase
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'package:projeto_safequest/screens/home_page.dart';

void main() async {
  // 2. Adiciona o 'async' aqui
  // 3. Garante que o Flutter carregou tudo antes de tentar ligar ao Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Inicializa o Firebase
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
        // Dica: scaffoldBackgroundColor transparente pode mostrar um fundo preto
        // se não houver um Stack com imagem por trás!
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
