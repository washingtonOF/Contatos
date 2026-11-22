import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_name.dart';
import 'features/auth/auth_screen.dart';
import 'features/family/family_access.dart';
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
            child:
                Text('Configure o Firebase Android para iniciar o $appName.'),
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
  final groupInvite = Uri.base.queryParameters['grupo'];
  final family = android ||
      (kIsWeb &&
          groupInvite != null &&
          RegExp(r'^[a-f0-9]{40}$').hasMatch(groupInvite));
  runApp(
    ConectaApp(
      home: family ? const FamilyAccess() : const WelcomeScreen(),
      familyTheme: family,
    ),
  );
}

class ConectaApp extends StatelessWidget {
  const ConectaApp({
    super.key,
    this.home = const WelcomeScreen(),
    this.familyTheme = false,
  });

  final Widget home;
  final bool familyTheme;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: familyTheme
            ? _familyTheme()
            : ThemeData(
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFF1769E0)),
                useMaterial3: true,
              ),
        darkTheme: familyTheme ? _familyTheme(Brightness.dark) : null,
        home: home,
      );
}

ThemeData _familyTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: const Color(0xFF1978E8),
    primary: dark ? const Color(0xFF9ACBFF) : const Color(0xFF071B40),
    onPrimary: dark ? const Color(0xFF071B40) : Colors.white,
    primaryContainer: dark ? const Color(0xFF17385C) : const Color(0xFFE4EFFF),
    onPrimaryContainer:
        dark ? const Color(0xFFDBECFF) : const Color(0xFF102544),
    secondary: dark ? const Color(0xFF79B9FF) : const Color(0xFF1978E8),
    secondaryContainer:
        dark ? const Color(0xFF21354E) : const Color(0xFFEAF3FF),
    onSecondaryContainer:
        dark ? const Color(0xFFCEEAFF) : const Color(0xFF0C4C9C),
    tertiary: dark ? const Color(0xFFFF83C4) : const Color(0xFFE72C92),
    surface: dark ? const Color(0xFF111B2B) : const Color(0xFFF6F9FF),
    surfaceContainer: dark ? const Color(0xFF1C2A40) : Colors.white,
    onSurface: dark ? const Color(0xFFF0F5FF) : const Color(0xFF102544),
    onSurfaceVariant: dark ? const Color(0xFFB0C2DA) : const Color(0xFF53657F),
    outlineVariant: dark ? const Color(0xFF354762) : const Color(0xFFDCE5F2),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: colors.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surfaceContainer,
      foregroundColor: colors.primary,
      titleTextStyle: TextStyle(
        color: colors.primary,
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
        fontSize: 20,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainer,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: colors.secondary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainer,
      indicatorColor: colors.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
        color: colors.onSurface,
        fontSize: 12,
        fontFamily: 'DM Sans',
        fontWeight: FontWeight.w600,
      )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 52,
                      backgroundColor: Color(0xFFEAF3FF),
                      child: Icon(Icons.forum_rounded,
                          size: 56, color: Color(0xFF1769E0)),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      appName,
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1769E0),
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text('Conversas que aproximam.',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 48),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const AuthScreen(
                                  initialMode: AuthMode.signUp))),
                      child: const SizedBox(
                          width: double.infinity,
                          child: Center(child: Text('Começar'))),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const AuthScreen(
                                  initialMode: AuthMode.signIn))),
                      child: const SizedBox(
                          width: double.infinity,
                          child: Center(child: Text('Já tenho uma conta'))),
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
