import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});
  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  String _query = '';
  bool _saving = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _name.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = _name.text.trim();
    if (uid == null || name.length < 2 || name.length > 60) return;
    setState(() { _saving = true; _notice = null; });
    try {
      await FirebaseFirestore.instance.collection('publicProfiles').doc(uid).set({
        'displayName': name,
        'searchName': name.toLowerCase(),
        'discoverable': true,
      });
      if (mounted) setState(() => _notice = 'Seu perfil agora aparece nas pesquisas.');
    } catch (_) {
      if (mounted) setState(() => _notice = 'Não foi possível publicar seu perfil.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _hide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('publicProfiles').doc(uid).delete();
      if (mounted) setState(() => _notice = 'Seu perfil foi removido da pesquisa.');
    } catch (_) {
      if (mounted) setState(() => _notice = 'Não foi possível remover o perfil.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Pessoas')),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Encontrar pessoas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), labelText: 'Pesquisar por nome público',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          if (_query.length < 2)
            const Text('Digite pelo menos duas letras para pesquisar.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('publicProfiles')
                .where('discoverable', isEqualTo: true)
                .orderBy('searchName')
                .startAt([_query]).endAt(['$_query\uf8ff']).limit(20).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text('Pesquisa indisponível. Verifique a configuração do Firestore e seus índices.');
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((d) => d.id != userId).toList();
                if (docs.isEmpty) return const Text('Nenhuma pessoa encontrada.');
                return Column(children: [
                  for (final doc in docs) ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(doc.data()['displayName'] as String? ?? 'Usuário'),
                    subtitle: const Text('Perfil público do Conecta'),
                  ),
                ]);
              },
            ),
          const Divider(height: 36),
          Text('Meu perfil pesquisável', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Sua participação na pesquisa é opcional. Somente seu nome público será exibido.'),
          const SizedBox(height: 12),
          TextField(controller: _name, maxLength: 60,
            decoration: const InputDecoration(labelText: 'Nome público', border: OutlineInputBorder())),
          FilledButton(onPressed: _saving ? null : _publish, child: const Text('Aparecer nas pesquisas')),
          TextButton(onPressed: _hide, child: const Text('Remover meu perfil da pesquisa')),
          if (_notice != null) Text(_notice!),
        ]),
      )),
    );
  }
}
