import '../master/master_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum AuthMode { signIn, signUp, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});
  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late AuthMode _mode;
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _changeMode(AuthMode next) {
    _formKey.currentState?.reset();
    setState(() => _mode = next);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      final email = _email.text.trim();
      if (_mode == AuthMode.reset) {
        await auth.sendPasswordResetEmail(email: email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se a conta existir, você receberá instruções por e-mail.')),
        );
      } else if (_mode == AuthMode.signUp) {
        final result = await auth.createUserWithEmailAndPassword(
          email: email, password: _password.text,
        );
        await result.user?.updateDisplayName(_name.text.trim());
        await result.user?.sendEmailVerification();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta criada. Verifique seu e-mail antes de continuar.')),
        );
      } else {
        final result = await auth.signInWithEmailAndPassword(
          email: email, password: _password.text,
        );
        await result.user?.reload();
        if (!mounted) return;
        final claims = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
        final managed = claims.claims?['managed'] == true;
        if (FirebaseAuth.instance.currentUser?.emailVerified != true && !managed) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verifique seu e-mail antes de entrar.')),
          );
        } else {
          final isAdmin = claims.claims?['admin'] == true;
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => _SignedInScreen(isAdmin: isAdmin)),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'email-already-in-use' => 'Este e-mail já está cadastrado.',
        'weak-password' => 'Escolha uma senha mais forte.',
        'invalid-email' => 'E-mail inválido.',
        'too-many-requests' => 'Muitas tentativas. Tente novamente mais tarde.',
        _ => 'Não foi possível concluir. Verifique os dados e tente novamente.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha na conexão. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signUp = _mode == AuthMode.signUp;
    final reset = _mode == AuthMode.reset;
    final title = reset ? 'Recuperar senha' : signUp ? 'Criar sua conta' : 'Bem-vindo de volta';
    return Scaffold(
      appBar: AppBar(title: const Text('Conecta')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.forum_rounded, size: 58, color: Color(0xFF1769E0)),
                    const SizedBox(height: 24),
                    Text(title, textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(reset ? 'Informe seu e-mail para recuperar o acesso.' : 'Seu espaço para conversar e se conectar.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    if (signUp) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Informe seu nome' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                      validator: (v) => v != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                          ? null : 'Informe um e-mail válido',
                    ),
                    if (!reset) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 8 ? 'Use pelo menos 8 caracteres' : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_loading ? 'Aguarde...' : reset ? 'Recuperar acesso' : signUp ? 'Criar conta' : 'Entrar'),
                      ),
                    ),
                    if (!reset && !signUp)
                      TextButton(onPressed: () => _changeMode(AuthMode.reset), child: const Text('Esqueci minha senha')),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _changeMode(signUp || reset ? AuthMode.signIn : AuthMode.signUp),
                      child: Text(signUp || reset ? 'Já tenho uma conta' : 'Criar uma conta'),
                    ),
                    const SizedBox(height: 24),
                    const Text('Autenticação via Firebase. Mensagens ainda em desenvolvimento.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedInScreen extends StatelessWidget {
  const _SignedInScreen({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conecta')),
    body: Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF1769E0), size: 64),
        const SizedBox(height: 16),
        const Text('Você entrou no Conecta!'),
        const Text('As conversas estarão disponíveis em breve.'),
        if (isAdmin) TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MasterScreen()),
          ),
          child: const Text('Abrir Conecta Master'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
            );
          },
          child: const Text('Sair'),
        ),
      ],
    )),
  );
}
