import 'package:flutter/material.dart';

/// Read-only Master landing page for the Spark prototype.
/// Privileged account management is intentionally performed offline.
class MasterScreen extends StatelessWidget {
  const MasterScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conecta Master')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.admin_panel_settings, color: Color(0xFF1769E0), size: 64),
        const SizedBox(height: 16),
        Text('Painel Master — modo Spark',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        const Card(child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Seu acesso administrativo foi reconhecido. '
            'Para proteger as contas, o cadastro, a listagem e o bloqueio de '
            'usuários são realizados por uma ferramenta local, não pelo navegador.'),
        )),
        const SizedBox(height: 12),
        const ListTile(
          leading: Icon(Icons.person_add_alt_1),
          title: Text('Criar usuários sem confirmação de e-mail'),
          subtitle: Text('Disponível pela ferramenta administrativa local.'),
        ),
        const ListTile(
          leading: Icon(Icons.manage_accounts),
          title: Text('Gerenciar contas'),
          subtitle: Text('Listar, bloquear e desbloquear pelo computador autorizado.'),
        ),
        const ListTile(
          leading: Icon(Icons.security),
          title: Text('Proteção de credenciais'),
          subtitle: Text('Nenhuma chave administrativa é enviada ao aplicativo Web.'),
        ),
      ]),
    )),
  );
}
