import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_safequest/main.dart'; // Para retornar ao fluxo principal (SetupGate/AuthGate)

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final nickname = _nicknameController.text.trim();
          
          // Verifica se o nickname já existe
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where('nickname', isEqualTo: nickname)
              .limit(1)
              .get();
              
          if (query.docs.isNotEmpty && query.docs.first.id != user.uid) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Este nickname já está em uso. Escolhe outro.'), backgroundColor: Colors.red, duration: Duration(milliseconds: 2000)),
              );
              setState(() => _isLoading = false);
            }
            return;
          }
          
          // Atualiza o documento do utilizador no Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'nickname': nickname,
            // Se o utilizador veio do Google e ainda não tem o doc criado, 
            // garantimos que o nome e email também ficam gravados.
            'name': user.displayName ?? nickname,
            'email': user.email,
            'photoUrl': user.photoURL ?? "",
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (mounted) {
            // Força a recarga do AuthGate / SetupGate
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthGate()),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao guardar o nickname: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🎮', style: TextStyle(fontSize: 50)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Escolhe o teu Nickname',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Este será o teu nome de jogador na SafeQuest. É assim que serás conhecido nos Clãs e nas Leaderboards!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 40),
                  
                  // Campo Nickname
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextFormField(
                      controller: _nicknameController,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF1A56DB)),
                        hintText: 'ex: CyberNinja',
                        hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'O nickname é obrigatório';
                        }
                        if (value.contains(' ')) {
                          return 'Não podes usar espaços no nickname';
                        }
                        if (value.trim().length < 3) {
                          return 'O nickname deve ter pelo menos 3 letras';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Botão Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56DB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _saveNickname,
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Entrar no Jogo 🚀', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
