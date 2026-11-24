import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../admin/master_dashboard.dart';
import '../family/family_header.dart';
import 'package:flutter/material.dart';
import '../../app_name.dart';

enum AuthMode { signIn, signUp, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen(
      {super.key, this.initialMode = AuthMode.signIn, this.family = false});
  final AuthMode initialMode;
  final bool family;

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

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final account = await GoogleSignIn(scopes: ['email']).signIn();
        if (account == null) return; // Seletor de conta cancelado.
        final tokens = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: tokens.accessToken,
          idToken: tokens.idToken,
        );
        await auth.signInWithCredential(credential);
      }
      final user = auth.currentUser;
      if (user == null) throw StateError('Conta Google não autenticada.');
      await user.getIdToken(true);
      if (!mounted) return;
      if (!user.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confirme seu e-mail para continuar.')),
        );
        return;
      }
      if (!widget.family) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const _SignedInScreen()),
        );
      }
      // No modo família, FamilyAccess observa a sessão e abre o perfil.
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'account-exists-with-different-credential'
          ? 'Já existe uma conta com este e-mail. Entre pelo método anterior para vincular o Google.'
          : 'Não foi possível entrar com Google. Confira a configuração do Firebase.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao Google. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          const SnackBar(
              content: Text(
                  'Se a conta existir, você receberá instruções por e-mail.')),
        );
      } else if (_mode == AuthMode.signUp) {
        final result = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
        await result.user?.updateDisplayName(_name.text.trim());
        await result.user?.sendEmailVerification();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Conta criada. Verifique seu e-mail antes de continuar.')),
        );
      } else {
        final result = await auth.signInWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
        await result.user?.reload();
        if (!mounted) return;
        if (FirebaseAuth.instance.currentUser?.emailVerified != true) {
          if (!widget.family) await auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Verifique seu e-mail antes de entrar.')),
          );
        } else if (widget.family) {
          await auth.currentUser?.getIdToken(true);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const _SignedInScreen()),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
    final title = reset
        ? 'Recuperar senha'
        : signUp
            ? 'Criar sua conta'
            : 'Bem-vindo de volta';
    return Scaffold(
      appBar: widget.family ? null : AppBar(title: const Text(appName)),
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
                    if (widget.family) ...[
                      FamilyHeader(
                        icon: reset ? Icons.lock_reset : Icons.forum_outlined,
                        showBrand: true,
                        title: reset
                            ? 'Recupere sua senha'
                            : signUp
                                ? 'Crie sua conta'
                                : 'Entre na sua conta',
                        description: reset
                            ? 'Enviaremos um link para redefinir sua senha.'
                            : signUp
                                ? 'Confirme seu e-mail para acessar seu perfil familiar.'
                                : 'Use seu e-mail e sua senha para acessar suas conversas.',
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const Icon(Icons.forum_rounded,
                          size: 58, color: Color(0xFF1769E0)),
                      const SizedBox(height: 24),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                          reset
                              ? 'Informe seu e-mail para recuperar o acesso.'
                              : 'Seu espaço para conversar e se conectar.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                    ],
                    if (signUp) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                            labelText: 'Nome',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: widget.family
                                ? null
                                : const OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Informe seu nome'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: widget.family
                              ? null
                              : const OutlineInputBorder()),
                      validator: (v) => v != null &&
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v.trim())
                          ? null
                          : 'Informe um e-mail válido',
                    ),
                    if (!reset) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: [
                          signUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password
                        ],
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border:
                              widget.family ? null : const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip:
                                _obscure ? 'Mostrar senha' : 'Ocultar senha',
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 8
                            ? 'Use pelo menos 8 caracteres'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_loading
                            ? 'Aguarde...'
                            : reset
                                ? 'Recuperar acesso'
                                : signUp
                                    ? 'Criar conta'
                                    : 'Entrar'),
                      ),
                    ),
                    if (!reset) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Continuar com Google'),
                      ),
                    ],
                    if (!reset && !signUp)
                      TextButton(
                          onPressed: _loading
                              ? null
                              : () => _changeMode(AuthMode.reset),
                          child: const Text('Esqueci minha senha')),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => _changeMode(signUp || reset
                              ? AuthMode.signIn
                              : AuthMode.signUp),
                      child: Text(signUp || reset
                          ? 'Já tenho uma conta'
                          : 'Criar uma conta'),
                    ),
                    const SizedBox(height: 24),
                    if (!widget.family)
                      const Text(
                          'Autenticação via Firebase. Mensagens ainda em desenvolvimento.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
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

class _SignedInScreen extends StatefulWidget {
  const _SignedInScreen();

  @override
  State<_SignedInScreen> createState() => _SignedInScreenState();
}

class _SignedInScreenState extends State<_SignedInScreen> {
  late final Future<bool> _isAdmin = _checkAdmin();

  Future<bool> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return false;
    final token = await user.getIdTokenResult(true);
    return token.claims?['admin'] == true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(appName)),
    body: Center(
      child: FutureBuilder<bool>(
        future: _isAdmin,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasError) {
            return const Text('Não foi possível validar suas permissões. Entre novamente.');
          }
          final admin = snapshot.data == true;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (admin) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MasterDashboard())),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Abrir Central Master'),
                ),
                const SizedBox(height: 20),
              ],
              const Icon(Icons.check_circle_outline, color: Color(0xFF1769E0), size: 64),
              const SizedBox(height: 16),
              Text(admin ? 'Central Master · $appName' : 'Você entrou no $appName!'),
              const SizedBox(height: 12),
              Text(admin
                  ? 'Acesso administrativo reconhecido. Ferramentas de gestão em desenvolvimento.'
                  : 'As conversas estarão disponíveis em breve.',
                  textAlign: TextAlign.center),
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
          );
        },
      ),
    ),
  );
}
