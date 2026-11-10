import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});
  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;
  List<Map<String, dynamic>> _users = [];
  final _functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      await _functions.httpsCallable('createManagedUser').call({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });
      _password.clear();
      if (!mounted) return;
      setState(() => _message = 'Conta criada. Entregue a senha inicial por canal seguro.');
      await _loadUsers();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _message = 'Não foi possível criar a conta: ${e.code}.');
    } catch (_) {
      if (mounted) setState(() => _message = 'Serviço indisponível. Verifique a configuração do backend.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _functions.httpsCallable('listManagedUsers').call();
      final data = Map<String, dynamic>.from(response.data as Map);
      final users = (data['users'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _users = users);
    } catch (_) {
      if (mounted) setState(() => _message = 'Não foi possível carregar os usuários.');
    }
  }

  Future<void> _toggle(Map<String, dynamic> user) async {
    try {
      await _functions.httpsCallable('setManagedUserDisabled').call({
        'uid': user['uid'], 'disabled': user['disabled'] != true,
      });
      await _loadUsers();
    } catch (_) {
      if (mounted) setState(() => _message = 'Não foi possível alterar o acesso.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conecta Master')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Gerenciar contas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Acesso restrito. As operações exigem permissão de administrador no Firebase.'),
        const SizedBox(height: 24),
        Form(key: _form, child: Column(children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome'),
            validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Informe o nome' : null),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: (v) => v != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? null : 'E-mail inválido'),
          TextFormField(controller: _password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Senha inicial (12+ caracteres)'),
            validator: (v) => (v?.length ?? 0) < 12 ? 'Mínimo de 12 caracteres' : null),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _create, child: const Text('Criar conta')),
        ])),
        if (_message != null) Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
        const Divider(height: 40),
        Row(children: [
          const Expanded(child: Text('Usuários (primeiros 50)')),
          IconButton(onPressed: _loadUsers, tooltip: 'Atualizar lista', icon: const Icon(Icons.refresh)),
        ]),
        for (final user in _users)
          ListTile(
            title: Text((user['name'] as String?)?.isNotEmpty == true ? user['name'] as String : (user['email'] ?? '') as String),
            subtitle: Text((user['email'] ?? '') as String),
            trailing: TextButton(
              onPressed: () => _toggle(user),
              child: Text(user['disabled'] == true ? 'Desbloquear' : 'Bloquear'),
            ),
          ),
      ]),
    )),
  );
}
