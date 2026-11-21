import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'family_chat.dart';
import 'family_header.dart';
import 'family_presence.dart';
import 'family_profile_editor.dart';
import 'family_status_screen.dart';
import 'group_screen.dart';
import 'invite_code.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.user, required this.profile});

  final User user;
  final Map<String, dynamic> profile;

  String get name => profile['name'] as String;
  String get phone => profile['phone'] as String;
  Blob? get photo => profile['photo'] as Blob?;

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
      .snapshots()
      .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  late final FamilyPresence _presence;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _linkSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeLinks = [];
  final _profileUpdates = <String, (String, String)>{};

  bool _busy = false;
  String? _invite;

  @override
  void initState() {
    super.initState();
    _presence = FamilyPresence(widget.user.uid, _db);
    _linkSubscription = _links.listen((snapshot) {
      _activeLinks = snapshot.docs
          .where((link) => !link.data().containsKey('revokedAt'))
          .toList();
      _presence
          .updateLinks(_activeLinks.map((link) => link.reference).toList());
      _syncContactProfile();
    }, onError: (Object _) => _presence.updateLinks([]));
  }

  @override
  void didUpdateWidget(covariant FamilyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.phone != widget.phone) {
      _syncContactProfile();
    }
  }

  void _syncContactProfile() {
    for (final link in _activeLinks) {
      final data = link.data();
      final owner = (data['members'] as List).first == widget.user.uid;
      final name = owner ? 'responsibleName' : 'memberName';
      final phone = owner ? 'responsiblePhone' : 'memberPhone';
      final fields = (widget.name, widget.phone);
      if ((data[name] != widget.name || data[phone] != widget.phone) &&
          _profileUpdates[link.id] != fields) {
        _profileUpdates[link.id] = fields;
        unawaited(_updateContactProfile(link.reference, {
          name: widget.name,
          phone: widget.phone,
        }));
      }
    }
  }

  Future<void> _updateContactProfile(
    DocumentReference<Map<String, dynamic>> link,
    Map<String, String> changes,
  ) async {
    try {
      await link.update(changes);
    } on FirebaseException {
      // A linked member can revoke the link before the profile reaches it.
    }
  }

  Future<void> _signOut() async {
    _presence.clear();
    await FirebaseAuth.instance.signOut();
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FamilyProfileEditor(
        user: widget.user,
        profile: widget.profile,
        online: _presence.online,
      ),
    ));
  }

  @override
  void dispose() {
    unawaited(_linkSubscription.cancel());
    _presence.dispose();
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
      'phone': widget.phone,
      'name': widget.name,
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
    final responsibleName = data?['name'] as String? ?? phone;
    final profileShared =
        widget.phone.isEmpty ? 'seu nome' : 'seu nome e celular';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular à família?'),
        content: Text(
          '$responsibleName verá $profileShared no painel familiar. '
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
      'memberPhone': widget.phone,
      'responsibleName': responsibleName,
      'memberName': widget.name,
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

  Widget _overview(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FamilyHeader(
            icon: Icons.groups_outlined,
            title: 'Olá, ${widget.name}',
            description: 'Abra suas conversas ou vincule alguém da família.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Grupos e conversas'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => GroupScreen(user: widget.user),
            )),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('Status de foto e vídeo'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  FamilyStatusScreen(uid: widget.user.uid, links: _activeLinks),
            )),
          ),
        ],
      );

  Widget _invites(BuildContext context) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.person_add_alt_1_outlined),
          title: const Text('Vincular familiar'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        _createInvite,
                        'Não foi possível criar o convite.',
                      ),
              child: const Text('Gerar convite de responsável'),
            ),
            if (_invite case final code?)
              ListTile(
                title: const Text('Copiar código do convite'),
                subtitle: const Text('Válido por 15 minutos'),
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
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        _acceptInvite,
                        'Convite inválido, expirado ou já usado.',
                      ),
              child: const Text('Conferir convite'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Conecta Família'),
          actions: [
            IconButton(
              tooltip: 'Meu perfil',
              onPressed: _openProfile,
              icon: CircleAvatar(
                radius: 16,
                foregroundImage: widget.photo == null
                    ? null
                    : MemoryImage(widget.photo!.bytes),
                child: const Icon(Icons.person_outline, size: 18),
              ),
            ),
            IconButton(
              tooltip: 'Sair',
              onPressed: _busy
                  ? null
                  : () => _run(
                        _signOut,
                        'Não foi possível sair.',
                      ),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _overview(context),
            const SizedBox(height: 12),
            _invites(context),
            const SizedBox(height: 28),
            Text(
              'Familiares vinculados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar por nome ou celular',
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
                final query = _search.text.trim().toLowerCase();
                final digits = query.replaceAll(RegExp(r'\D'), '');
                final tiles = <Widget>[];
                for (final link in snapshot.data!.docs) {
                  final data = link.data();
                  if (data.containsKey('revokedAt')) continue;
                  final isResponsible =
                      (data['members'] as List).first == widget.user.uid;
                  final phone =
                      data[isResponsible ? 'memberPhone' : 'responsiblePhone']
                          as String;
                  final name =
                      data[isResponsible ? 'memberName' : 'responsibleName']
                              as String? ??
                          phone;
                  if (!name.toLowerCase().contains(query) &&
                      (digits.isEmpty ||
                          !phone
                              .replaceAll(RegExp(r'\D'), '')
                              .contains(digits))) {
                    continue;
                  }
                  final members = List<String>.from(data['members'] as List);
                  final otherUid =
                      members.firstWhere((uid) => uid != widget.user.uid);
                  tiles.add(
                    ListTile(
                      key: ValueKey(link.id),
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person_outline,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(name),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FamilyChat(
                            link: link.reference,
                            uid: widget.user.uid,
                            phone: name,
                          ),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (phone.isNotEmpty && phone != name) Text(phone),
                          ContactPresence(link: link.reference, uid: otherUid),
                        ],
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
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(top: 12),
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: tiles),
                );
              },
            ),
          ],
        ),
      );
}
