import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'invite_code.dart';

class FamilyChat extends StatefulWidget {
  const FamilyChat({
    super.key,
    required this.link,
    required this.uid,
    required this.phone,
    this.group = false,
    this.actions = const [],
  });

  final DocumentReference<Map<String, dynamic>> link;
  final String uid;
  final String phone;
  final bool group;
  final List<Widget> actions;

  @override
  State<FamilyChat> createState() => _FamilyChatState();
}

enum _Attachment { location, file, voice, video }

class _FamilyChatState extends State<FamilyChat> {
  static const _fileLimit = 25 * 1024 * 1024;
  static final _callBase = Uri.tryParse(
    const String.fromEnvironment('CONECTA_CALL_BASE_URL'),
  );
  static bool get _callsEnabled {
    final base = _callBase;
    return base != null &&
        base.scheme == 'https' &&
        base.host.isNotEmpty &&
        base.userInfo.isEmpty &&
        !base.hasQuery;
  }

  final _text = TextEditingController();
  bool _sending = false;
  late final _link = widget.link.snapshots();
  late final _messages = widget.link
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await action();
    } on Exception {
      _notice(failure);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _post(Map<String, Object> content) async {
    await widget.link.collection('messages').add({
      ...content,
      'sender': widget.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      await _post({'text': text});
      if (mounted) _text.clear();
    }, 'Não foi possível enviar a mensagem.');
  }

  Future<void> _shareLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _notice('Ative a localização do Android para compartilhar sua posição.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      _notice('Permita a localização nas configurações do Android.');
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (!mounted) return;
    await _post(
        {'latitude': position.latitude, 'longitude': position.longitude});
  }

  Reference _attachment(String messageId, String sender) =>
      FirebaseStorage.instance
          .ref('attachments/${widget.link.path}/$sender/$messageId');

  Future<void> _shareFile() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || !mounted) return;
    final file = picked.files.single;
    final path = file.path;
    if (path == null ||
        file.size > _fileLimit ||
        file.size <= 0 ||
        file.name.isEmpty ||
        file.name.length > 180) {
      _notice(
          'Escolha um arquivo de até 25 MB com nome de até 180 caracteres.');
      return;
    }
    final message = widget.link.collection('messages').doc();
    final attachment = _attachment(message.id, widget.uid);
    final upload = await attachment.putFile(
      File(path),
      SettableMetadata(contentType: 'application/octet-stream'),
    );
    try {
      await message.set({
        'sender': widget.uid,
        'fileName': file.name,
        'fileSize': upload.totalBytes,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      try {
        await attachment.delete();
      } on FirebaseException {
        // Storage rules preserve the object if the message was committed.
      }
      rethrow;
    }
  }

  Future<void> _save(String messageId, Map<String, dynamic> data) =>
      _run(() async {
        final name =
            (data['fileName'] as String).replaceAll(RegExp(r'[/\\]'), '_');
        final legacy = data['file'];
        final bytes = legacy is Blob
            ? legacy.bytes
            : await _attachment(messageId, data['sender'] as String)
                .getData(_fileLimit);
        if (bytes == null) {
          _notice('Arquivo indisponível.');
          return;
        }
        await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar arquivo recebido',
          fileName: name == '.' || name == '..' ? 'arquivo' : name,
          bytes: bytes,
        );
      }, 'Não foi possível salvar o arquivo.');

  Future<void> _openLocation(Map<String, dynamic> data) async {
    final coordinates = "${data['latitude']},${data['longitude']}";
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': coordinates,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _notice('Não foi possível abrir o mapa.');
    }
  }

  Future<void> _joinCall(String room, bool video) async {
    if (!_callsEnabled) {
      _notice('O serviço de chamadas ainda precisa ser configurado.');
      return;
    }
    final base = _callBase!;
    final segments = base.pathSegments.where((segment) => segment.isNotEmpty);
    final uri = base.replace(
      pathSegments: [...segments, room],
      fragment: video ? '' : 'config.startWithVideoMuted=true',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _notice('Não foi possível abrir a chamada.');
    }
  }

  Future<void> _startCall(bool video) async {
    final room = newInviteCode();
    await _post({'room': room, 'video': video});
    if (mounted) await _joinCall(room, video);
  }

  Future<void> _attach(_Attachment value) {
    return switch (value) {
      _Attachment.location =>
        _run(_shareLocation, 'Não foi possível compartilhar a localização.'),
      _Attachment.file =>
        _run(_shareFile, 'Não foi possível compartilhar o arquivo.'),
      _Attachment.voice =>
        _run(() => _startCall(false), 'Não foi possível iniciar a chamada.'),
      _Attachment.video =>
        _run(() => _startCall(true), 'Não foi possível iniciar a chamada.'),
    };
  }

  Widget _message(String messageId, Map<String, dynamic> data) {
    if (data['text'] case final String text) return Text(text);
    if (data['latitude'] != null) {
      final time = (data['createdAt'] as Timestamp?)?.toDate().toLocal();
      final timestamp = time == null
          ? ''
          : MaterialLocalizations.of(context).formatShortDate(time);
      final hour =
          time == null ? '' : TimeOfDay.fromDateTime(time).format(context);
      return TextButton.icon(
        onPressed: () =>
            _run(() => _openLocation(data), 'Não foi possível abrir o mapa.'),
        icon: const Icon(Icons.location_on_outlined),
        label: Text('Localização compartilhada $timestamp $hour'.trim()),
      );
    }
    if (data['fileName'] case final String file) {
      return TextButton.icon(
        onPressed: _sending ? null : () => _save(messageId, data),
        icon: const Icon(Icons.download),
        label: Text(file),
      );
    }
    if (data['room'] case final String room) {
      final video = data['video'] == true;
      final sent = (data['createdAt'] as Timestamp?)?.toDate();
      final open = sent != null &&
          DateTime.now().difference(sent) < const Duration(minutes: 30);
      return TextButton.icon(
        onPressed: open && _callsEnabled && !_sending
            ? () => _run(
                  () => _joinCall(room, video),
                  'Não foi possível abrir a chamada.',
                )
            : null,
        icon: Icon(video ? Icons.videocam_outlined : Icons.call_outlined),
        label: Text(!open
            ? 'Convite de chamada expirado'
            : video
                ? 'Entrar na chamada de vídeo'
                : 'Entrar na chamada de voz'),
      );
    }
    return const Text('Mensagem indisponível.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.phone), actions: widget.actions),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _link,
          builder: (context, link) {
            if (link.hasError) {
              return const Center(
                child: Text('Não foi possível abrir a conversa.'),
              );
            }
            if (!link.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = link.data!.data();
            if (data == null || data.containsKey('revokedAt')) {
              return const Center(child: Text('Este vínculo foi encerrado.'));
            }
            return Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _messages,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child:
                              Text('Não foi possível carregar as mensagens.'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data!.docs;
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text('Comece a conversa com uma mensagem.'),
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index].data();
                          final names = data['names'] as Map<String, dynamic>?;
                          final mine = message['sender'] == widget.uid;
                          final colors = Theme.of(context).colorScheme;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Card(
                              color: mine
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.group && !mine)
                                      Text(
                                        names?[message['sender']] as String? ??
                                            'Ex-participante',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    _message(messages[index].id, message),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PopupMenuButton<_Attachment>(
                          tooltip: 'Compartilhar ou ligar',
                          enabled: !_sending,
                          icon: const Icon(Icons.add),
                          onSelected: _attach,
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: _Attachment.location,
                                child: Text('Compartilhar localização atual')),
                            const PopupMenuItem(
                                value: _Attachment.file,
                                child: Text('Selecionar arquivo')),
                            if (_callsEnabled) ...[
                              const PopupMenuItem(
                                  value: _Attachment.voice,
                                  child: Text('Chamada de voz')),
                              const PopupMenuItem(
                                  value: _Attachment.video,
                                  child: Text('Chamada de vídeo')),
                            ],
                          ],
                        ),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            enabled: !_sending,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration:
                                const InputDecoration(hintText: 'Mensagem'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Enviar',
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
