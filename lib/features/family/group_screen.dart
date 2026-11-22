import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'family_chat.dart';
import 'invite_code.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({
    super.key,
    required this.user,
    required this.name,
    this.inviteCode,
  });

  final User user;
  final String name;
  final String? inviteCode;

  static void openConversation(
    BuildContext context,
    String uid,
    DocumentSnapshot<Map<String, dynamic>> group, {
    bool replace = false,
  }) {
    final route = MaterialPageRoute<void>(
      builder: (_) => FamilyChat(
        link: group.reference,
        uid: uid,
        phone: group.get('title') as String,
        group: true,
        actions: [
          if (group.get('direct') == false || group.get('owner') == uid)
            IconButton(
              tooltip: 'Participantes e convites',
              icon: const Icon(Icons.group_add),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => _GroupMembers(group: group.reference, uid: uid),
              )),
            ),
        ],
      ),
    );
    final navigator = Navigator.of(context);
    if (replace) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
  }

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _db = FirebaseFirestore.instance;
  late final _code = TextEditingController(text: widget.inviteCode);
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
      {int min = 1, String? description}) {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null) ...[
                Text(description),
                const SizedBox(height: 12),
              ],
              TextField(
                autofocus: true,
                maxLength: limit,
                decoration: InputDecoration(labelText: label),
                onChanged: (text) => value = text.trim(),
              ),
            ],
          ),
          scrollable: true,
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
    if (mounted) Navigator.pop(context);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _readJoinedGroup(
    DocumentReference<Map<String, dynamic>> group,
  ) async {
    try {
      final snapshot = await group.get(const GetOptions(source: Source.server));
      return snapshot.exists ? snapshot : null;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      return null;
    }
  }

  Future<void> _apply() async {
    final inviteText = _code.text.trim().toLowerCase();
    final code =
        RegExp(r'(?:^|[=\s])([a-f0-9]{40})$').firstMatch(inviteText)?.group(1);
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
    final group = _db.collection('groups').doc(groupId);
    final alreadyJoined = await _readJoinedGroup(group);
    if (!mounted) return;
    if (alreadyJoined != null) {
      GroupScreen.openConversation(
        context,
        widget.user.uid,
        alreadyJoined,
        replace: true,
      );
      return;
    }
    final direct = invite.data()?['direct'] as bool?;
    if (direct != true) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Entrar em $title?'),
          content: const Text(
            'Ao entrar no grupo, você poderá ler as mensagens anteriores.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Entrar'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;

      try {
        await group.update({
          'members': FieldValue.arrayUnion([widget.user.uid]),
          'names.${widget.user.uid}': widget.name,
          'lastChange': widget.user.uid,
          'joinInvite': code,
        });
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
        final joinedInParallel = await _readJoinedGroup(group);
        if (!mounted) return;
        if (joinedInParallel != null) {
          GroupScreen.openConversation(
            context,
            widget.user.uid,
            joinedInParallel,
            replace: true,
          );
          return;
        }
        if (direct == false) rethrow;
        // Older invites did not include the conversation type.
      }
      final joined = await _readJoinedGroup(group);
      if (!mounted) return;
      if (joined != null) {
        GroupScreen.openConversation(
          context,
          widget.user.uid,
          joined,
          replace: true,
        );
        return;
      }
    }
    if (!mounted) return;
    final application = _db
        .collection('groups')
        .doc(groupId)
        .collection('applications')
        .doc(widget.user.uid);
    final previous =
        await application.get(const GetOptions(source: Source.server));
    if (!mounted) return;
    if (previous.exists) {
      _notice(
          'Você já enviou um pré-cadastro. Se aprovado, o grupo aparece em Conversas.');
      return;
    }
    final name = await _ask(
      'Solicitar entrada em $title',
      'Nome para o responsável pelo grupo',
      60,
      'Enviar pré-cadastro',
      min: 2,
      description:
          'O criador precisa aprovar a entrada nesta conversa individual.',
    );
    if (name == null || !mounted) return;
    await application.set({
      'name': name,
      'invite': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    _code.clear();
    _notice(
        'Pré-cadastro enviado. Após a aprovação, procure o grupo em Conversas.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nova conversa')),
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
              color: Theme.of(context).colorScheme.surfaceContainer,
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
                    decoration: const InputDecoration(
                        labelText: 'Link ou código do convite'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(_apply),
                    child: const Text('Usar convite'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _GroupMembers extends StatefulWidget {
  const _GroupMembers({required this.group, required this.uid});

  final DocumentReference<Map<String, dynamic>> group;
  final String uid;

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

  Future<void> _addMember() async {
    final username = await showDialog<String>(
      context: context,
      builder: (context) => const _GroupUsernameDialog(),
    );
    if (!mounted || username == null) return;
    final account = await widget.group.firestore
        .collection('accountDirectory')
        .doc(username)
        .get(const GetOptions(source: Source.server));
    if (!mounted) return;
    if (!account.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma conta com esse @username.')),
      );
      return;
    }
    final uid = account.get('uid') as String;
    await widget.group.update({
      'members': FieldValue.arrayUnion([uid]),
      'names.$uid': account.get('name') as String,
      'lastChange': uid,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Participante adicionado.')),
      );
    }
  }

  Future<void> _depart(String uid) async {
    final leaving = uid == widget.uid;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(leaving ? 'Sair do grupo?' : 'Remover participante?'),
        content: const Text('Para voltar, será necessário um novo convite.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(leaving ? 'Sair' : 'Remover'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final group = widget.group;
    final batch = group.firestore.batch();
    batch.update(group, {
      'members': FieldValue.arrayRemove([uid]),
      'names.$uid': FieldValue.delete(),
      'lastChange': uid,
    });
    batch.set(group.collection('departures').doc(uid), {
      'at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    if (mounted && leaving) Navigator.pop(context);
  }

  Future<void> _revokeInvites() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar links anteriores?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    await widget.group
        .update({'invitesRevokedAt': FieldValue.serverTimestamp()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Links anteriores revogados.')),
      );
    }
  }

  Future<void> _invite(String title, bool direct) async {
    final code = newInviteCode();
    await widget.group.firestore.collection('groupInvites').doc(code).set({
      'groupId': widget.group.id,
      'title': title,
      'direct': direct,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final link = Uri.https('www.grupoisamig.com.br', '/', {'grupo': code});
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite copiado. Ele vale por 7 dias.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Participantes e convites')),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _group,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text('Grupo indisponível.'));
            final group = snapshot.data?.data();
            if (group == null)
              return const Center(child: CircularProgressIndicator());
            final members = List<String>.from(group['members'] as List);
            final owner = group['owner'] == widget.uid;
            final direct = group['direct'] == true;
            final names = group['names'] as Map<String, dynamic>;
            final full = members.length >= (group['direct'] == true ? 2 : 50);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (owner)
                  FilledButton.icon(
                    onPressed: _busy || full
                        ? null
                        : () => _run(
                            () => _invite(group['title'] as String, direct)),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar convite para compartilhar'),
                  ),
                if (owner)
                  TextButton(
                    onPressed: _busy ? null : () => _run(_revokeInvites),
                    child: const Text('Revogar links anteriores'),
                  ),
                if (!owner && !direct)
                  TextButton(
                    onPressed:
                        _busy ? null : () => _run(() => _depart(widget.uid)),
                    child: const Text('Sair do grupo'),
                  ),
                if (!direct)
                  OutlinedButton.icon(
                    onPressed: _busy || full ? null : () => _run(_addMember),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Adicionar por @username'),
                  ),
                if (!direct)
                  const ListTile(
                    leading: Icon(Icons.history),
                    title: Text(
                        'Novos participantes podem ver as mensagens anteriores à entrada no grupo.'),
                  ),
                if (full)
                  const ListTile(
                      title: Text('Limite de participantes atingido.')),
                if (!direct)
                  for (final uid in members)
                    ListTile(
                      title: Text(names[uid] as String? ?? 'Participante'),
                      trailing: owner && uid != widget.uid
                          ? TextButton(
                              onPressed:
                                  _busy ? null : () => _run(() => _depart(uid)),
                              child: const Text('Remover'),
                            )
                          : null,
                    ),
                if (direct && owner)
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
                                              final batch = widget
                                                  .group.firestore
                                                  .batch();
                                              batch.update(widget.group, {
                                                'members':
                                                    FieldValue.arrayRemove(
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

class _GroupUsernameDialog extends StatefulWidget {
  const _GroupUsernameDialog();

  @override
  State<_GroupUsernameDialog> createState() => _GroupUsernameDialogState();
}

class _GroupUsernameDialogState extends State<_GroupUsernameDialog> {
  String _username = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Adicionar participante'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '@username',
            helperText: 'A pessoa terá acesso ao histórico.',
          ),
          onChanged: (value) => setState(() {
            _username =
                value.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(_username)
                ? () => Navigator.pop(context, _username)
                : null,
            child: const Text('Adicionar'),
          ),
        ],
      );
}
