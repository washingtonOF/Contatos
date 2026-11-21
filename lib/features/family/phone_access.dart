import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_screen.dart';

class PhoneAccess extends StatelessWidget {
  const PhoneAccess({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final user = snapshot.data;
          if (user != null && user.phoneNumber != null) {
            return FamilyScreen(key: ValueKey(user.uid), user: user);
          }
          return const _PhoneForm();
        },
      );
}

class _PhoneForm extends StatefulWidget {
  const _PhoneForm();

  @override
  State<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<_PhoneForm> {
  final _phone = TextEditingController(text: '+55');
  final _code = TextEditingController();
  String? _verificationId;
  String? _error;
  bool _busy = false;
  bool _signingIn = false;
  int _attempt = 0;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _fail(int attempt, String message) {
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _signIn(int attempt, PhoneAuthCredential credential) async {
    if (!mounted || attempt != _attempt || _signingIn) return;
    _signingIn = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseException catch (error) {
      _fail(
        attempt,
        error.code == 'invalid-verification-code'
            ? 'Código incorreto. Confira o SMS.'
            : 'Não foi possível entrar. Solicite outro código e tente novamente.',
      );
    } finally {
      _signingIn = false;
    }
  }

  Future<void> _sendCode() async {
    final number = _phone.text.trim().replaceAll(RegExp(r'[\s()-]'), '');
    final attempt = ++_attempt;
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(number)) {
      _fail(attempt, 'Informe o código do país, o DDD e o número.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: number,
        verificationCompleted: (credential) => _signIn(attempt, credential),
        verificationFailed: (error) => _fail(
          attempt,
          error.code == 'too-many-requests'
              ? 'Muitas tentativas. Aguarde antes de pedir outro SMS.'
              : 'Não foi possível enviar o SMS. Confira o número e tente novamente.',
        ),
        codeSent: (id, _) {
          if (!mounted || attempt != _attempt) return;
          setState(() {
            _verificationId = id;
            _busy = _signingIn;
            _error = null;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseException {
      _fail(attempt, 'Falha ao solicitar o SMS. Tente novamente.');
    }
  }

  void _confirmCode() {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _fail(_attempt, 'Digite os seis dígitos do SMS.');
      return;
    }
    _signIn(
      _attempt,
      PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sent = _verificationId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Conecta Família')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Text(
                sent ? 'Confirme seu número' : 'Entre com seu celular',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (sent)
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(labelText: 'Código SMS'),
                )
              else
                TextField(
                  controller: _phone,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Celular com DDD',
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : (sent ? _confirmCode : _sendCode),
                child: Text(
                  _busy ? 'Aguarde…' : (sent ? 'Entrar' : 'Enviar SMS'),
                ),
              ),
              if (sent)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _attempt++;
                            _verificationId = null;
                            _error = null;
                            _code.clear();
                          }),
                  child: const Text('Voltar ao número e pedir outro código'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
