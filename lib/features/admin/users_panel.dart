import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Read-only view of Firestore profile documents. Firebase Auth accounts
/// cannot be enumerated from a browser; Firestore security rules must allow
/// reads only for verified administrators.
class UsersPanel extends StatefulWidget {
  const UsersPanel({super.key});

  @override
  State<UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<UsersPanel> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Gerenciamento de usuários',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('Perfis disponíveis no Firestore. Esta tela não altera contas do Firebase Authentication.'),
      const SizedBox(height: 20),
      TextField(
        controller: _search,
        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Pesquisar nome ou e-mail',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      if (user == null || !user.emailVerified)
        const Card(child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Sessão não verificada'),
          subtitle: Text('Entre novamente com uma conta verificada.'),
        ))
      else
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Card(child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Não foi possível consultar os perfis'),
                subtitle: Text('Confira as regras do Firestore e se a coleção users existe. Nenhuma permissão foi ampliada automaticamente.'),
              ));
            }
            if (!snapshot.hasData) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ));
            }
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data();
              final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return name.contains(_query) || email.contains(_query);
            }).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${docs.length} perfil(is) exibido(s) — até 100 documentos por consulta'),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(child: ListTile(
                  leading: Icon(Icons.person_search_outlined),
                  title: Text('Nenhum perfil encontrado'),
                  subtitle: Text('Contas do Authentication não aparecem aqui automaticamente. É necessário criar documentos de perfil na coleção users.'),
                )),
              for (final doc in docs)
                Card(child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text((doc.data()['name'] ?? doc.data()['displayName'] ?? 'Sem nome').toString()),
                  subtitle: Text((doc.data()['email'] ?? 'E-mail não informado').toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Detalhes do perfil'),
                      content: SelectableText(
                        'Nome: ${doc.data()['name'] ?? doc.data()['displayName'] ?? 'Não informado'}\n'
                        'E-mail: ${doc.data()['email'] ?? 'Não informado'}\n'
                        'UID: ${doc.id}\n'
                        'Perfil Firestore: somente leitura',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                      ],
                    ),
                  ),
                )),
            ]);
          },
        ),
    ]);
  }
}
