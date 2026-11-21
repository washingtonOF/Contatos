import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'family_chat.dart';
import 'group_screen.dart';
import 'invite_code.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.user});

  final User user;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _inviteInput = TextEditingController();
  final _search = TextEditingController();
  final _db = FirebaseFirestore.instance;
  late final _links = _db
      .collection('familyLinks')
      .where('members', arrayContains: widget.user.uid)
      .snapshots();

  bool _busy = false;
  String? _invite;

  @override
  void dispose() {
    _inviteInput.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseException {
      if (mounted) _notice(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createInvite() async {
    final code = newInviteCode();
    await _db.collection('familyInvites').doc(code).set({
      'owner': widget.user.uid,
      'phone': widget.user.phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) setState(() => _invite = code);
  }

  Future<void> _acceptInvite() async {
    final code = _inviteInput.text.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(code)) {
      _notice('Cole o código completo do convite.');
      return;
    }
    final invitation = _db.collection('familyInvites').doc(code);
    final data =
        (await invitation.get(const GetOptions(source: Source.server))).data();
    if (!mounted) return;
    final owner = data?['owner'] as String?;
    final phone = data?['phone'] as String?;
    if (owner == null || phone == null || owner == widget.user.uid) {
      _notice('Use um convite criado por outra conta.');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular à família?'),
        content: Text(
          'O responsável $phone verá seu número no painel familiar. '
          'Você poderá desfazer o vínculo a qualquer momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vincular'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    final batch = _db.batch();
    batch.set(_db.collection('familyLinks').doc(code), {
      'members': [owner, widget.user.uid],
      'responsiblePhone': phone,
      'memberPhone': widget.user.phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.delete(invitation);
    await batch.commit();
    if (!mounted) return;
    _inviteInput.clear();
    _notice('Vínculo familiar criado.');
  }

  Future<void> _removeLink(DocumentReference<Map<String, dynamic>> link) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desfazer vínculo?'),
        content: const Text('O vínculo vai desaparecer dos dois aparelhos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await link.update({'revokedAt': FieldValue.serverTimestamp()});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Minha família'),
          actions: [
            IconButton(
              tooltip: 'Sair',
              onPressed: _busy
                  ? null
                  : () => _run(
                        FirebaseAuth.instance.signOut,
                        'Não foi possível sair.',
                      ),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Grupos e conversas'),
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => GroupScreen(user: widget.user),
              )),
            ),
            const SizedBox(height: 16),
            Text('Sua conta: ${widget.user.phoneNumber}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () =>
                      _run(_createInvite, 'Não foi possível criar o convite.'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Gerar convite de responsável'),
            ),
            if (_invite case final code?)
              ListTile(
                title: const Text('Copiar código do convite'),
                subtitle: const Text('Use no outro celular em até 15 minutos.'),
                trailing: const Icon(Icons.copy),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (mounted) _notice('Código copiado.');
                },
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _inviteInput,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Código recebido'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        _acceptInvite,
                        'Convite inválido, expirado ou já usado.',
                      ),
              child: const Text('Conferir convite'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar na família pelo número',
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _links,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ListTile(
                    title: Text('Não foi possível carregar a família.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final query = _search.text.replaceAll(RegExp(r'\D'), '');
                final tiles = <Widget>[];
                for (final link in snapshot.data!.docs) {
                  final data = link.data();
                  if (data.containsKey('revokedAt')) continue;
                  final isResponsible =
                      (data['members'] as List).first == widget.user.uid;
                  final phone =
                      data[isResponsible ? 'memberPhone' : 'responsiblePhone']
                          as String;
                  if (!phone.replaceAll(RegExp(r'\D'), '').contains(query))
                    continue;
                  tiles.add(
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(phone),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FamilyChat(
                            link: link.reference,
                            uid: widget.user.uid,
                            phone: phone,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        isResponsible ? 'Familiar vinculado' : 'Responsável',
                      ),
                      trailing: IconButton(
                        tooltip: 'Desvincular',
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _removeLink(link.reference),
                                  'Não foi possível desfazer o vínculo.',
                                ),
                        icon: const Icon(Icons.link_off),
                      ),
                    ),
                  );
                }
                if (tiles.isEmpty) {
                  return ListTile(
                    title: Text(
                      query.isEmpty
                          ? 'Nenhum familiar vinculado.'
                          : 'Nenhum familiar encontrado.',
                    ),
                  );
                }
                return Column(children: tiles);
              },
            ),
          ],
        ),
      );
}
