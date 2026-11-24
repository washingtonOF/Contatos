import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'family_chat.dart';
import 'family_location_panel.dart';

/// Web-only presentation. Firestore rules, not this widget, enforce access.
class ResponsibleWebDashboard extends StatelessWidget {
  const ResponsibleWebDashboard({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final links = FirebaseFirestore.instance
        .collection('familyLinks')
        .where('members', arrayContains: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('IsaMig Família | Responsável'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: links,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Não foi possível carregar os vínculos.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final dependents = snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final members = data['members'];
                return !data.containsKey('revokedAt') &&
                    data['confirmedByEmail'] == true &&
                    members is List &&
                    members.length == 2 &&
                    members.first == user.uid;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Painel da família',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text('Acompanhe apenas dependentes com vínculo confirmado. Localização e uso dependem do compartilhamento autorizado no aparelho.'),
                  const SizedBox(height: 24),
                  if (dependents.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.family_restroom),
                        title: Text('Nenhum dependente confirmado'),
                        subtitle: Text('O vínculo deve ser criado e confirmado no aplicativo.'),
                      ),
                    ),
                  for (final link in dependents)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                              title: Text(link.data()['memberName'] as String? ?? 'Dependente'),
                              subtitle: const Text('Vínculo confirmado'),
                            ),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.chat_outlined),
                                  label: const Text('Conversar'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => FamilyChat(
                                        link: link.reference,
                                        uid: user.uid,
                                        phone: link.data()['memberName'] as String? ?? 'Dependente',
                                      ),
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  icon: const Icon(Icons.location_on_outlined),
                                  label: const Text('Localização e uso'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => FamilyLocationPanel(
                                        link: link.reference,
                                        contactName: link.data()['memberName'] as String? ?? 'Dependente',
                                        isResponsible: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text('Controles remotos do Android e histórico de navegação ainda não estão habilitados. Câmera e microfone são usados somente em chamadas aceitas.'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
