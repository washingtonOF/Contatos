import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

const _statusLimit = 25 * 1024 * 1024;
const _statusLifetime = Duration(hours: 24);

class FamilyStatusScreen extends StatefulWidget {
  const FamilyStatusScreen({super.key, required this.uid, required this.links});

  final String uid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> links;

  @override
  State<FamilyStatusScreen> createState() => _FamilyStatusScreenState();
}

class _FamilyStatusScreenState extends State<FamilyStatusScreen> {
  bool _publishing = false;

  String _contact(QueryDocumentSnapshot<Map<String, dynamic>> link) {
    final data = link.data();
    final owner = (data['members'] as List).first == widget.uid;
    return data[owner ? 'memberName' : 'responsibleName'] as String? ??
        data[owner ? 'memberPhone' : 'responsiblePhone'] as String;
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _publish() async {
    final link = await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Com quem vai compartilhar?'),
        children: [
          for (final link in widget.links)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, link),
              child: Text(_contact(link)),
            ),
        ],
      ),
    );
    if (!mounted || link == null) return;
    setState(() => _publishing = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
      );
      if (!mounted || picked == null) return;
      final file = picked.files.single;
      final type = switch (file.extension?.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'mp4' => 'video/mp4',
        _ => null,
      };
      final path = file.path;
      if (path == null ||
          type == null ||
          file.size <= 0 ||
          file.size > _statusLimit) {
        _notice('Selecione uma foto ou vídeo MP4 de até 25 MB.');
        return;
      }

      final status = link.reference.collection('statuses').doc();
      final storage = FirebaseStorage.instance
          .ref('statuses/${link.id}/${widget.uid}/${status.id}');
      final upload = await storage.putFile(
          File(path), SettableMetadata(contentType: type));
      try {
        await status.set({
          'sender': widget.uid,
          'mediaType': type,
          'size': upload.totalBytes,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        try {
          await storage.delete();
        } on FirebaseException {
          // The storage rules preserve the file if the status was committed.
        }
        rethrow;
      }
      _notice('Status publicado para ${_contact(link)} por 24 horas.');
    } on Exception {
      _notice('Não foi possível publicar seu status.');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Status')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FilledButton.icon(
              onPressed: _publishing || widget.links.isEmpty ? null : _publish,
              icon: const Icon(Icons.add_a_photo_outlined),
              label:
                  Text(_publishing ? 'Publicando…' : 'Publicar foto ou vídeo'),
            ),
            const SizedBox(height: 12),
            if (widget.links.isEmpty)
              const Text('Vincule um familiar para compartilhar um status.')
            else
              const Text(
                  'Cada publicação fica disponível por 24 horas para o familiar escolhido.'),
            const SizedBox(height: 16),
            for (final link in widget.links)
              _ContactStatuses(
                key: ValueKey(link.id),
                contact: _contact(link),
                uid: widget.uid,
                link: link.reference,
              ),
          ],
        ),
      );
}

class _ContactStatuses extends StatefulWidget {
  const _ContactStatuses({
    super.key,
    required this.contact,
    required this.uid,
    required this.link,
  });

  final String contact;
  final String uid;
  final DocumentReference<Map<String, dynamic>> link;

  @override
  State<_ContactStatuses> createState() => _ContactStatusesState();
}

class _ContactStatusesState extends State<_ContactStatuses> {
  late final _statuses = widget.link
      .collection('statuses')
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots();

  Timer? _expiry;
  DateTime? _nextExpiry;
  bool _removing = false;

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  void _refreshAt(DateTime? next) {
    if (_nextExpiry == next) return;
    _nextExpiry = next;
    _expiry?.cancel();
    if (next != null) {
      _expiry = Timer(next.difference(DateTime.now()), () {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _remove(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover este status?'),
        content:
            const Text('A publicação deixará de aparecer para seu familiar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (!mounted || confirmed != true || _removing) return;
    setState(() => _removing = true);
    try {
      await doc.reference.delete();
      try {
        await FirebaseStorage.instance
            .ref('statuses/${widget.link.id}/${widget.uid}/${doc.id}')
            .delete();
      } on FirebaseException {
        // Deleting the publication also blocks access to its media.
      }
    } on FirebaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível remover o status.')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(widget.contact),
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _statuses,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ListTile(title: Text('Status indisponível.'));
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final now = DateTime.now();
                final current = snapshot.data!.docs.where((doc) {
                  final created = doc.data()['createdAt'] as Timestamp?;
                  return created != null &&
                      created.toDate().add(_statusLifetime).isAfter(now);
                }).toList();
                _refreshAt(current.isEmpty
                    ? null
                    : (current.last.get('createdAt') as Timestamp)
                        .toDate()
                        .add(_statusLifetime));
                if (current.isEmpty) {
                  return const ListTile(
                      title: Text('Nenhuma publicação recente.'));
                }
                return Column(
                  children: [
                    for (final doc in current)
                      ListTile(
                        leading: Icon(doc.get('mediaType') == 'video/mp4'
                            ? Icons.play_circle_outline
                            : Icons.image_outlined),
                        title: Text(doc.get('sender') == widget.uid
                            ? 'Seu status'
                            : 'Status de ${widget.contact}'),
                        subtitle: Text(TimeOfDay.fromDateTime(
                          (doc.get('createdAt') as Timestamp)
                              .toDate()
                              .toLocal(),
                        ).format(context)),
                        trailing: doc.get('sender') == widget.uid
                            ? IconButton(
                                tooltip: 'Remover status',
                                onPressed:
                                    _removing ? null : () => _remove(doc),
                                icon: const Icon(Icons.delete_outline),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => _StatusMedia(
                            reference: FirebaseStorage.instance.ref(
                              'statuses/${widget.link.id}/${doc.get('sender')}/${doc.id}',
                            ),
                            video: doc.get('mediaType') == 'video/mp4',
                          ),
                        )),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _StatusMedia extends StatefulWidget {
  const _StatusMedia({required this.reference, required this.video});

  final Reference reference;
  final bool video;

  @override
  State<_StatusMedia> createState() => _StatusMediaState();
}

class _StatusMediaState extends State<_StatusMedia> {
  late final Future<Object?> _load = _loadMedia();

  Future<Uint8List?> _loadMedia() async {
    if (!widget.video) return widget.reference.getData(_statusLimit);
    await _prepareVideo();
    return null;
  }

  VideoPlayerController? _video;
  Directory? _temporary;

  Future<void> _prepareVideo() async {
    final root = await getTemporaryDirectory();
    final folder = await root.createTemp('status-');
    _temporary = folder;
    if (!mounted) {
      await folder.delete(recursive: true);
      return;
    }
    final file = File('${folder.path}/video.mp4');
    try {
      await widget.reference.writeToFile(file);
    } on Exception {
      if (await folder.exists()) await folder.delete(recursive: true);
      rethrow;
    }
    if (!mounted) {
      if (await folder.exists()) await folder.delete(recursive: true);
      return;
    }
    final controller = VideoPlayerController.file(file);
    _video = controller;
    await controller.initialize();
  }

  @override
  void dispose() {
    final controller = _video;
    final folder = _temporary;
    if (folder != null && controller != null) {
      unawaited(_clearVideo(controller, folder));
    }
    super.dispose();
  }

  Future<void> _clearVideo(
      VideoPlayerController controller, Directory folder) async {
    try {
      await controller.dispose();
      if (await folder.exists()) await folder.delete(recursive: true);
    } on Exception {
      // The OS can reclaim the temporary directory.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Status')),
        body: Center(
          child: FutureBuilder<Object?>(
            future: _load,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Este status está indisponível.');
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (!widget.video) {
                final bytes = snapshot.data;
                if (bytes is! Uint8List)
                  return const Text('Imagem indisponível.');
                return Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('Imagem indisponível.'),
                );
              }
              final controller = _video!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                      child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  )),
                  VideoProgressIndicator(controller, allowScrubbing: true),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (_, value, __) => IconButton(
                      tooltip: value.isPlaying ? 'Pausar' : 'Reproduzir',
                      onPressed:
                          value.isPlaying ? controller.pause : controller.play,
                      icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}
