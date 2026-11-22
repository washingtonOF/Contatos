import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'conversation_inbox.dart';
import 'family_chat.dart';
import 'family_home_layout.dart';
import 'family_location_panel.dart';
import 'family_presence.dart';
import 'family_profile_editor.dart';
import 'family_requests.dart';
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
      .snapshots();
  late final FamilyPresence _presence;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _linkSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _activeLinks = [];
  final _profileUpdates = <String, (String, String)>{};

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _accountResults;
  bool _busy = false;
  bool _linksLoaded = false;
  bool _linksError = false;
  String? _invite;

  @override
  void initState() {
    super.initState();
    final invite = Uri.base.queryParameters['grupo'];
    if (invite != null && RegExp(r'^[a-f0-9]{40}$').hasMatch(invite)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => GroupScreen(
            user: widget.user,
            name: widget.name,
            inviteCode: invite,
          ),
        ));
      });
    }
    _presence = FamilyPresence(widget.user.uid, _db);
    _linkSubscription = _links.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _linksLoaded = true;
        _linksError = false;
        _activeLinks = snapshot.docs
            .where((link) => !link.data().containsKey('revokedAt'))
            .toList();
      });
      _presence
          .updateLinks(_activeLinks.map((link) => link.reference).toList());
      _syncContactProfile();
    }, onError: (Object _) {
      if (!mounted) return;
      setState(() {
        _linksLoaded = true;
        _linksError = true;
        _activeLinks = [];
      });
      _presence.updateLinks([]);
    });
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

  final _messagePreviews = <String, Stream<InboxMessage?>>{};
  int _tab = 0;

  late final _groups = _db
      .collection('groups')
      .where('members', arrayContains: widget.user.uid)
      .snapshots();

  Stream<InboxMessage?> _messages(
      DocumentReference<Map<String, dynamic>> conversation) {
    return _messagePreviews.putIfAbsent(
        conversation.path,
        () => conversation
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .snapshots()
                .map((snapshot) {
              if (snapshot.docs.isEmpty) return null;
              final message = snapshot.docs.first.data();
              final String text;
              if (message['text'] case final String body) {
                text = body;
              } else if (message['fileName'] case final String file) {
                text = 'Arquivo: $file';
              } else if (message.containsKey('latitude')) {
                text = 'Localização compartilhada';
              } else if (message.containsKey('room')) {
                text = message['video'] == true
                    ? 'Chamada de vídeo'
                    : 'Chamada de voz';
              } else {
                text = 'Mensagem';
              }
              return InboxMessage(
                message['sender'] == widget.user.uid ? 'Você: $text' : text,
                (message['createdAt'] as Timestamp?)?.toDate(),
              );
            }));
  }

  (String, String) _contact(QueryDocumentSnapshot<Map<String, dynamic>> link) {
    final data = link.data();
    final responsible = (data['members'] as List).first == widget.user.uid;
    final phone =
        data[responsible ? 'memberPhone' : 'responsiblePhone'] as String;
    return (
      data[responsible ? 'memberName' : 'responsibleName'] as String? ?? phone,
      phone
    );
  }

  void _openChat(DocumentReference<Map<String, dynamic>> link, String name) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FamilyChat(link: link, uid: widget.user.uid, phone: name),
    ));
  }

  Widget _inbox() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _groups,
        builder: (context, snapshot) {
          final items = <(DateTime?, InboxConversation)>[];
          for (final link in _activeLinks) {
            final (name, phone) = _contact(link);
            items.add((
              (link.data()['createdAt'] as Timestamp?)?.toDate(),
              InboxConversation(
                id: link.reference.path,
                title: name,
                phone: phone,
                isGroup: false,
                messages: _messages(link.reference),
                onOpen: () => _openChat(link.reference, name),
              )
            ));
          }
          for (final group in snapshot.data?.docs ?? []) {
            final data = group.data();
            items.add((
              (data['createdAt'] as Timestamp?)?.toDate(),
              InboxConversation(
                id: group.reference.path,
                title: data['title'] as String,
                isGroup: data['direct'] != true,
                messages: _messages(group.reference),
                onOpen: () => GroupScreen.openConversation(
                    context, widget.user.uid, group),
              )
            ));
          }
          items.sort((a, b) => (b.$1?.millisecondsSinceEpoch ?? 0)
              .compareTo(a.$1?.millisecondsSinceEpoch ?? 0));
          return ConversationInbox(
            conversations: [for (final item in items) item.$2],
            loading: !_linksLoaded ||
                snapshot.connectionState == ConnectionState.waiting,
            hasError: _linksError || snapshot.hasError,
          );
        },
      );

  Widget _invites(BuildContext context) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainer,
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
  Widget build(BuildContext context) => FamilyHomeLayout(
        tab: _tab,
        onTabSelected: (tab) => setState(() => _tab = tab),
        onNewConversation: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => GroupScreen(user: widget.user, name: widget.name),
        )),
        onSignOut:
            _busy ? null : () => _run(_signOut, 'Não foi possível sair.'),
        profilePhoto:
            widget.photo == null ? null : MemoryImage(widget.photo!.bytes),
        body: switch (_tab) {
          0 => _inbox(),
          1 => FamilyStatusScreen(
              uid: widget.user.uid, links: _activeLinks, embedded: true),
          2 => _family(context),
          _ => FamilyProfileEditor(
              user: widget.user,
              profile: widget.profile,
              online: _presence.online,
              embedded: true,
            ),
        },
      );

  void _searchAccounts() {
    final input = _search.text.trim().toLowerCase();
    final query = input.startsWith('@') ? input.substring(1) : input;
    if (query.length < 2 || query.length > 60) return;
    final directory = _db.collection('accountDirectory');

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> find() async {
      final matches = await Future.wait([
        if (!input.startsWith('@'))
          directory
              .orderBy('nameSearch')
              .startAt([query])
              .endAt(['$query\uf8ff'])
              .limit(12)
              .get(),
        if (RegExp(r'^[a-z0-9_]{2,24}$').hasMatch(query))
          directory
              .orderBy(FieldPath.documentId)
              .startAt([query])
              .endAt(['$query\uf8ff'])
              .limit(12)
              .get(),
      ]);
      return {
        for (final match in matches)
          for (final doc in match.docs)
            if (doc.data()['uid'] != widget.user.uid) doc.id: doc,
      }.values.take(12).toList();
    }

    setState(() => _accountResults = find());
  }

  Widget _directoryResults() {
    final results = _accountResults;
    if (results == null) return const SizedBox.shrink();
    return FutureBuilder(
      key: ObjectKey(results),
      future: results,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return const ListTile(
              title: Text('Não foi possível pesquisar contas.'));
        }
        final accounts = snapshot.data!;
        if (accounts.isEmpty) {
          return const ListTile(title: Text('Nenhuma conta encontrada.'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(title: Text('Contas encontradas')),
            for (final account in accounts)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(account.data()['name'] as String),
                subtitle: Text('@${account.id}'),
              ),
          ],
        );
      },
    );
  }

  Widget _family(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          FamilyRequests(user: widget.user, profile: widget.profile),
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
            onChanged: (_) => setState(() => _accountResults = null),
            onSubmitted: (_) => _searchAccounts(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Buscar por nome, @username ou celular',
              suffixIcon: IconButton(
                tooltip: 'Buscar contas',
                icon: const Icon(Icons.search),
                onPressed: _searchAccounts,
              ),
            ),
          ),
          _directoryResults(),
          if (_linksError)
            const ListTile(title: Text('Não foi possível carregar a família.'))
          else if (!_linksLoaded)
            const LinearProgressIndicator()
          else
            _familyLinks(context),
        ],
      );

  Widget _familyLinks(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final tiles = <Widget>[];
    for (final link in _activeLinks) {
      final data = link.data();
      final (name, phone) = _contact(link);
      if (!name.toLowerCase().contains(query) &&
          (digits.isEmpty ||
              !phone.replaceAll(RegExp(r'\D'), '').contains(digits))) {
        continue;
      }
      final members = List<String>.from(data['members'] as List);
      final otherUid = members.firstWhere((uid) => uid != widget.user.uid);
      tiles.add(
        ListTile(
          key: ValueKey(link.id),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(name),
          onTap: () => _openChat(link.reference, name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phone.isNotEmpty && phone != name) Text(phone),
              ContactPresence(link: link.reference, uid: otherUid),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data['confirmedByEmail'] == true)
                IconButton(
                  tooltip: 'Painel do vínculo',
                  icon: const Icon(Icons.location_on_outlined),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => FamilyLocationPanel(
                      link: link.reference,
                      contactName: name,
                      isResponsible: members.first == widget.user.uid,
                    ),
                  )),
                ),
              IconButton(
                tooltip: 'Desvincular',
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => _removeLink(link.reference),
                          'Não foi possível desfazer o vínculo.',
                        ),
                icon: const Icon(Icons.link_off),
              ),
            ],
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
      color: Theme.of(context).colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: Column(children: tiles),
    );
  }
}
