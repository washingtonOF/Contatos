import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'features/auth/auth_screen.dart';
import 'features/family/phone_access.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final options = ConectaFirebaseOptions.currentPlatform;
  if (android && options == null) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Configure o Firebase Android para iniciar o Conecta.'),
          ),
        ),
      ),
    );
    return;
  }
  await Firebase.initializeApp(options: options);
  if (android) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }
  runApp(
    ConectaApp(home: android ? const PhoneAccess() : const WelcomeScreen()),
  );
}

class ConectaApp extends StatelessWidget {
  const ConectaApp({super.key, this.home = const WelcomeScreen()});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Conecta',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1769E0)),
      useMaterial3: true,
    ),
    home: home,
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 52,
                      backgroundColor: Color(0xFFEAF3FF),
                      child: Icon(Icons.forum_rounded, size: 56, color: Color(0xFF1769E0)),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Conecta',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1769E0),
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text('Conversas que aproximam.', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 48),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen(initialMode: AuthMode.signUp))),
                      child: const SizedBox(width: double.infinity, child: Center(child: Text('Começar'))),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AuthScreen(initialMode: AuthMode.signIn))),
                      child: const SizedBox(width: double.infinity, child: Center(child: Text('Já tenho uma conta'))),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Autenticação protegida pelo Firebase',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

}
