import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'invite_code.dart';

bool validResponsibleEmail(String email, User user) =>
    email.length <= 254 &&
    email != user.email?.toLowerCase() &&
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

void addFamilyRequest(
  WriteBatch batch,
  FirebaseFirestore db, {
  required User user,
  required String email,
  required String name,
}) {
  batch.set(db.collection('familyRequests').doc(newInviteCode()), {
    'sender': user.uid,
    'senderEmail': user.email!.toLowerCase(),
    'recipientEmail': email,
    'name': name,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

class FamilyRequests extends StatefulWidget {
  const FamilyRequests({
    super.key,
    required this.user,
    required this.profile,
  });

  final User user;
  final Map<String, dynamic> profile;

  @override
  State<FamilyRequests> createState() => _FamilyRequestsState();
}

class _FamilyRequestsState extends State<FamilyRequests> {
  final _db = FirebaseFirestore.instance;
  final _email = TextEditingController();
  late final _requestCollection = _db.collection('familyRequests');
  late final _received = _requestCollection
      .where('recipientEmail', isEqualTo: widget.user.email!.toLowerCase())
      .snapshots();
  late final _sent = _requestCollection
      .where('sender', isEqualTo: widget.user.uid)
      .snapshots();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseException {
      _notice('Não foi possível concluir. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!validResponsibleEmail(email, widget.user)) {
      _notice('Informe um e-mail válido diferente do seu.');
      return;
    }
    final batch = _db.batch();
    addFamilyRequest(
      batch,
      _db,
      user: widget.user,
      email: email,
      name: widget.profile['name'] as String,
    );
    await batch.commit();
    if (!mounted) return;
    _email.clear();
    _notice('Pedido registrado. Aguarde a confirmação do responsável.');
  }

  Future<void> _accept(
      QueryDocumentSnapshot<Map<String, dynamic>> request) async {
    final data = request.data();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceitar vínculo familiar?'),
        content: Text(
            '${data['name']} (${data['senderEmail']}) poderá conversar com você pelo app. Seu nome e celular, se cadastrado, ficarão disponíveis à outra conta.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aceitar')),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final batch = _db.batch();
    batch.set(_db.collection('familyLinks').doc(request.id), {
      'members': [widget.user.uid, data['sender']],
      'confirmedByEmail': true,
      'responsibleName': widget.profile['name'],
      'responsiblePhone': widget.profile['phone'],
      'memberName': data['name'],
      'memberPhone': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.delete(request.reference);
    await batch.commit();
    _notice('Vínculo familiar criado.');
  }

  Widget _requests(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream, {
    required bool received,
  }) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Text('Não foi possível carregar os pedidos.');
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.docs.isEmpty) {
            return Text(received
                ? 'Nenhum pedido recebido.'
                : 'Nenhum pedido enviado.');
          }
          return Column(
            children: [
              for (final doc in snapshot.data!.docs)
                _requestTile(doc, received: received),
            ],
          );
        },
      );

  Widget _requestTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool received,
  }) {
    final data = doc.data();
    final created = data['createdAt'] as Timestamp?;
    final active = created != null &&
        created.toDate().add(const Duration(days: 7)).isAfter(DateTime.now());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
          received ? data['name'] as String : data['recipientEmail'] as String),
      subtitle: Text(received
          ? data['senderEmail'] as String
          : active
              ? 'Pendente'
              : 'Expirado'),
      trailing: Wrap(
        children: [
          if (received && active)
            IconButton(
              tooltip: 'Aceitar pedido',
              onPressed: _busy ? null : () => _run(() => _accept(doc)),
              icon: const Icon(Icons.check_circle_outline),
            ),
          IconButton(
            tooltip: received ? 'Recusar pedido' : 'Cancelar pedido',
            onPressed: _busy ? null : () => _run(doc.reference.delete),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supervisor = widget.profile['supervisor'] == true;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('Responsável familiar'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Receber pedidos de vínculo'),
            value: supervisor,
            onChanged: _busy
                ? null
                : (value) => _run(() => _db
                    .collection('familyProfiles')
                    .doc(widget.user.uid)
                    .update({'supervisor': value})),
          ),
          if (supervisor) ...[
            const Text('Pedidos recebidos'),
            _requests(_received, received: true),
            const Divider(),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            enabled: !_busy,
            decoration:
                const InputDecoration(labelText: 'E-mail do responsável'),
          ),
          const SizedBox(height: 8),
          const Text('O pedido mostra seu nome e e-mail ao destinatário.'),
          FilledButton(
            onPressed: _busy ? null : () => _run(_send),
            child: const Text('Pedir vínculo'),
          ),
          const SizedBox(height: 16),
          const Text('Pedidos enviados'),
          _requests(_sent, received: false),
        ],
      ),
    );
  }
}
