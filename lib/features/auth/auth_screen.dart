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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Authentication is intentionally disabled until Firebase is configured.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Protótipo: cadastro e login ainda não estão conectados ao Firebase.'),
    ));
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
                      onPressed: _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(reset ? 'Recuperar acesso' : signUp ? 'Criar conta' : 'Entrar'),
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
                    const Text('Protótipo de interface — nenhuma credencial é enviada ou armazenada.',
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
