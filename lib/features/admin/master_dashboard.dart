import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Read-only administrative shell. Privileged operations require server-side
/// authorization and are intentionally not exposed by this screen.
class MasterDashboard extends StatefulWidget {
  const MasterDashboard({super.key});
  @override
  State<MasterDashboard> createState() => _MasterDashboardState();
}

class _MasterDashboardState extends State<MasterDashboard> {
  int _selected = 0;
  bool _checking = true;
  bool _authorized = false;
  String? _error;
  static const _labels = ['Visão geral', 'Usuários', 'Conversas', 'Segurança', 'Configurações'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.forum_outlined,
    Icons.shield_outlined,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() { _checking = true; _error = null; _authorized = false; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sessão encerrada.');
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh == null || !fresh.emailVerified) {
        throw StateError('E-mail não verificado.');
      }
      final token = await fresh.getIdTokenResult(true);
      if (!mounted) return;
      setState(() => _authorized = token.claims?['admin'] == true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível validar o acesso. Entre novamente.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null || !_authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Central Master')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 52),
          const SizedBox(height: 12),
          Text(_error ?? 'Acesso administrativo não autorizado.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: _verify, child: const Text('Verificar novamente')),
        ])),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central Master Conecta'),
        actions: [
          IconButton(tooltip: 'Atualizar permissões', onPressed: _verify, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _navigation())),
      body: Row(children: [
        if (wide) SizedBox(width: 240, child: _navigation()),
        if (wide) const VerticalDivider(width: 1),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Align(alignment: Alignment.topLeft, child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: _section(),
          )),
        )),
      ]),
    );
  }

  Widget _navigation() => ListView(children: [
    const Padding(padding: EdgeInsets.all(20), child: Text('ADMINISTRAÇÃO', style: TextStyle(fontWeight: FontWeight.bold))),
    for (var i = 0; i < _labels.length; i++)
      ListTile(
        leading: Icon(_icons[i]),
        title: Text(_labels[i]),
        selected: _selected == i,
        onTap: () {
          setState(() => _selected = i);
          if (Scaffold.maybeOf(context)?.isDrawerOpen == true) Navigator.pop(context);
        },
      ),
  ]);

  Widget _section() {
    if (_selected != 0) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_labels[_selected], style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        const Card(child: Padding(
          padding: EdgeInsets.all(24),
          child: ListTile(
            leading: Icon(Icons.construction_outlined, size: 32),
            title: Text('Módulo em desenvolvimento'),
            subtitle: Text('Nenhuma informação privada é carregada e nenhuma alteração é realizada nesta versão.'),
          ),
        )),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Visão geral', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('Painel administrativo do Conecta'),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        const Icon(Icons.verified_user_outlined, color: Color(0xFF1769E0), size: 32),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sessão Master validada', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(FirebaseAuth.instance.currentUser?.email ?? 'Administrador'),
          const Text('Permissão confirmada pelo token Firebase.'),
        ])),
      ]))),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 800 ? 3 : width >= 480 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 3.5 : 2.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _InfoCard(icon: Icons.people_outline, label: 'Usuários', value: 'Aguardando integração'),
            _InfoCard(icon: Icons.forum_outlined, label: 'Conversas', value: 'Aguardando integração'),
            _InfoCard(icon: Icons.security_outlined, label: 'Segurança', value: 'Operações protegidas'),
          ],
        );
      }),
      const SizedBox(height: 16),
      const Card(child: Padding(
        padding: EdgeInsets.all(20),
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Próxima etapa'),
          subtitle: Text('Integrar métricas reais, permissões no backend e trilha de auditoria antes de habilitar ações de gestão.'),
        ),
      )),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    ]),
  ));
}
