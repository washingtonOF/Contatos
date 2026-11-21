import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'family_chat.dart';
import 'invite_code.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.user});

  final User user;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _db = FirebaseFirestore.instance;
  final _code = TextEditingController();
  late final _groups = _db
      .collection('groups')
      .where('members', arrayContains: widget.user.uid)
      .snapshots();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseException {
      if (mounted)
        _notice(
            'Não foi possível concluir. Confira os dados e tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, String label, int limit, String button,
      {int min = 1}) {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            maxLength: limit,
            decoration: InputDecoration(labelText: label),
            onChanged: (text) => value = text.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (value.length >= min) Navigator.pop(context, value);
              },
              child: Text(button),
            ),
          ],
        );
      },
    );
  }

  Future<void> _create({required bool direct}) async {
    final title = await _ask(
      direct ? 'Nova conversa individual' : 'Novo grupo',
      direct ? 'Nome da conversa' : 'Nome do grupo',
      60,
      'Criar',
    );
    if (title == null || !mounted) return;
    await _db.collection('groups').add({
      'title': title,
      'owner': widget.user.uid,
      'members': [widget.user.uid],
      'names': {widget.user.uid: 'Criador da conversa'},
      'direct': direct,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _apply() async {
    final inviteText = _code.text.trim().toLowerCase();
    final code =
        RegExp(r'(?:^|\s)([a-f0-9]{40})$').firstMatch(inviteText)?.group(1);
    if (code == null) {
      _notice('Cole o código completo de convite.');
      return;
    }
    final invite = await _db
        .collection('groupInvites')
        .doc(code)
        .get(const GetOptions(source: Source.server));
    if (!mounted || !invite.exists) return;
    final groupId = invite.get('groupId') as String;
    final title = invite.get('title') as String;
    final name = await _ask(
      'Solicitar entrada em $title',
      'Nome para o responsável pelo grupo',
      60,
      'Enviar pré-cadastro',
      min: 2,
    );
    if (name == null || !mounted) return;
    await _db
        .collection('groups')
        .doc(groupId)
        .collection('applications')
        .doc(widget.user.uid)
        .set({
      'name': name,
      'invite': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    _code.clear();
    _notice('Pré-cadastro enviado. Aguarde a aprovação para entrar.');
  }

  void _open(QueryDocumentSnapshot<Map<String, dynamic>> group) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FamilyChat(
        link: group.reference,
        uid: widget.user.uid,
        phone: group.get('title') as String,
        group: true,
        actions: [
          if (group.get('owner') == widget.user.uid)
            IconButton(
              tooltip: 'Gerenciar convites e pré-cadastros',
              icon: const Icon(Icons.group_add),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => _GroupMembers(group: group.reference),
              )),
            ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Grupos e conversas')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed:
                      _busy ? null : () => _run(() => _create(direct: false)),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Criar grupo'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      _busy ? null : () => _run(() => _create(direct: true)),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Nova conversa'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Tenho um convite'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    decoration:
                        const InputDecoration(labelText: 'Código do convite'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(_apply),
                    child: const Text('Fazer pré-cadastro'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Suas conversas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _groups,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ListTile(
                      title: Text('Não foi possível carregar suas conversas.'));
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final groups = snapshot.data!.docs;
                if (groups.isEmpty) {
                  return const ListTile(
                      title: Text('Você ainda não participa de conversas.'));
                }
                final colors = Theme.of(context).colorScheme;
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final group in groups)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                            child: Icon(group.get('direct') == true
                                ? Icons.chat_outlined
                                : Icons.group_outlined),
                          ),
                          title: Text(group.get('title') as String),
                          subtitle: Text(group.get('direct') == true
                              ? 'Conversa individual'
                              : 'Grupo'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(group),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
}

class _GroupMembers extends StatefulWidget {
  const _GroupMembers({required this.group});

  final DocumentReference<Map<String, dynamic>> group;

  @override
  State<_GroupMembers> createState() => _GroupMembersState();
}

class _GroupMembersState extends State<_GroupMembers> {
  late final _group = widget.group.snapshots();
  late final _applications =
      widget.group.collection('applications').snapshots();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Não foi possível concluir a operação.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite(String title) async {
    final code = newInviteCode();
    await widget.group.firestore.collection('groupInvites').doc(code).set({
      'groupId': widget.group.id,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await Clipboard.setData(ClipboardData(
      text:
          'Entre no Conecta Família, confirme seu e-mail e use este convite para $title:\n$code',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite copiado. Ele vale por 7 dias.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Convites e pré-cadastros')),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _group,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text('Grupo indisponível.'));
            final group = snapshot.data?.data();
            if (group == null)
              return const Center(child: CircularProgressIndicator());
            final members = List<String>.from(group['members'] as List);
            final full = members.length >= (group['direct'] == true ? 2 : 50);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FilledButton.icon(
                  onPressed: _busy || full
                      ? null
                      : () => _run(() => _invite(group['title'] as String)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar convite para compartilhar'),
                ),
                if (full)
                  const ListTile(
                      title: Text('Limite de participantes atingido.')),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _applications,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const ListTile(
                          title: Text('Pré-cadastros indisponíveis.'));
                    if (!snapshot.hasData)
                      return const LinearProgressIndicator();
                    final applications = snapshot.data!.docs;
                    if (applications.isEmpty) {
                      return const ListTile(
                          title: Text('Nenhum pré-cadastro recebido.'));
                    }
                    return Column(children: [
                      for (final entry in applications)
                        ListTile(
                          title: Text(entry.get('name') as String),
                          subtitle: Text(members.contains(entry.id)
                              ? 'Participante'
                              : 'Aguardando aprovação'),
                          trailing: members.contains(entry.id)
                              ? TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() async {
                                            final batch =
                                                widget.group.firestore.batch();
                                            batch.update(widget.group, {
                                              'members': FieldValue.arrayRemove(
                                                  [entry.id]),
                                              'names.${entry.id}':
                                                  FieldValue.delete(),
                                              'lastChange': entry.id,
                                            });
                                            batch.delete(entry.reference);
                                            await batch.commit();
                                          }),
                                  child: const Text('Remover'),
                                )
                              : FilledButton(
                                  onPressed: _busy || full
                                      ? null
                                      : () => _run(() => widget.group.update({
                                            'members': FieldValue.arrayUnion(
                                                [entry.id]),
                                            'names.${entry.id}':
                                                entry.get('name'),
                                            'lastChange': entry.id,
                                          })),
                                  child: const Text('Aprovar'),
                                ),
                        ),
                    ]);
                  },
                ),
              ],
            );
          },
        ),
      );
}
