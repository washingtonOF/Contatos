import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'family_header.dart';
import 'family_presence.dart';
import 'family_requests.dart';
import '../../app_name.dart';

class FamilyProfileEditor extends StatefulWidget {
  const FamilyProfileEditor({
    super.key,
    required this.user,
    this.profile,
    this.online,
    this.embedded = false,
  });

  final User user;
  final bool embedded;
  final Map<String, dynamic>? profile;
  final ValueListenable<bool>? online;

  @override
  State<FamilyProfileEditor> createState() => _FamilyProfileEditorState();
}

enum _FamilySetup { independent, responsible, link }

class _FamilyProfileEditorState extends State<FamilyProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.profile?['name'] as String? ?? widget.user.displayName ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.profile?['phone'] as String? ?? '',
  );
  late final _username = TextEditingController(
    text: widget.profile?['username'] as String? ?? '',
  );
  late Blob? _photo = widget.profile?['photo'] as Blob?;
  bool _busy = false;
  _FamilySetup _setup = _FamilySetup.independent;
  final _responsibleEmail = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _username.dispose();
    _responsibleEmail.dispose();
    super.dispose();
  }

  String get _number => _phone.text.trim().replaceAll(RegExp(r'[\s()-]'), '');

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _choosePhoto() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (!mounted || result == null) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null || file.size > 8 * 1024 * 1024) {
        _notice('Escolha uma imagem de até 8 MB.');
        return;
      }
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final scale =
            math.min(1.0, 196 / math.max(descriptor.width, descriptor.height));
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * scale).round()),
          targetHeight: math.max(1, (descriptor.height * scale).round()),
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final png =
                await frame.image.toByteData(format: ui.ImageByteFormat.png);
            if (mounted && png != null) {
              setState(() => _photo = Blob(png.buffer.asUint8List()));
            }
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    } on Exception {
      _notice('Não foi possível abrir essa foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final document = db.collection('familyProfiles').doc(widget.user.uid);
      final username = _username.text.trim().toLowerCase();
      final previous = widget.profile?['username'] as String?;
      final directory = db.collection('accountDirectory');
      final batch = db.batch();
      if (previous != null && previous != username) {
        batch.delete(directory.doc(previous));
      }
      final name = _name.text.trim();
      if (username.isNotEmpty) {
        batch.set(directory.doc(username), {
          'uid': widget.user.uid,
          'name': name,
          'nameSearch': name.toLowerCase(),
        });
      }
      final data = <String, Object>{
        if (username.isNotEmpty) 'username': username,
        'name': name,
        'phone': _number,
        if (_photo case final photo?) 'photo': photo,
      };
      if (widget.profile != null) {
        batch.update(document, {
          ...data,
          if (username.isEmpty) 'username': FieldValue.delete(),
          if (_photo == null) 'photo': FieldValue.delete(),
        });
      } else {
        batch.set(document,
            {...data, 'supervisor': _setup == _FamilySetup.responsible});
        if (_setup == _FamilySetup.link) {
          addFamilyRequest(
            batch,
            db,
            user: widget.user,
            email: _responsibleEmail.text.trim().toLowerCase(),
            name: _name.text.trim(),
          );
        }
      }
      await batch.commit();
      if (mounted && widget.profile != null) {
        if (widget.embedded) {
          _notice('Perfil atualizado.');
        } else {
          Navigator.pop(context);
        }
      }
    } on FirebaseException catch (error) {
      _notice(error.code == 'permission-denied' &&
              _username.text.trim().isNotEmpty
          ? 'Não foi possível usar esse @username. Confira se já está em uso.'
          : 'Não foi possível salvar seu perfil.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.profile != null;
    final colors = Theme.of(context).colorScheme;
    final status = widget.online;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(editing ? 'Meu perfil' : appName),
              actions: [
                if (!editing)
                  IconButton(
                    tooltip: 'Sair',
                    onPressed: _busy ? null : FirebaseAuth.instance.signOut,
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (editing)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: colors.primaryContainer,
                      foregroundImage:
                          _photo == null ? null : MemoryImage(_photo!.bytes),
                      child: const Icon(Icons.person_outline, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.user.email ?? '',
                              style: Theme.of(context).textTheme.titleMedium),
                          if (status != null)
                            ValueListenableBuilder<bool>(
                              valueListenable: status,
                              builder: (_, online, __) =>
                                  PresenceLabel(online: online),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                const FamilyHeader(
                  icon: Icons.person_outline,
                  title: 'Seu perfil familiar',
                  description: 'Escolha o nome que sua família verá.',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _choosePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                        _photo == null ? 'Adicionar foto' : 'Alterar foto'),
                  ),
                  if (_photo != null)
                    TextButton(
                      onPressed:
                          _busy ? null : () => setState(() => _photo = null),
                      child: const Text('Remover foto'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 60,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                  counterText: '',
                ),
                validator: (value) =>
                    (value?.trim().length ?? 0) < 2 ? 'Informe seu nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: '@username (opcional)',
                  helperText: 'Seu nome e @username aparecerão na pesquisa.',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  final username = value?.trim().toLowerCase() ?? '';
                  return username.isEmpty ||
                          RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)
                      ? null
                      : 'Use de 3 a 24 letras sem acento, números ou _.';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+55 com DDD',
                ),
                validator: (_) => _number.isEmpty ||
                        RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_number)
                    ? null
                    : 'Inclua o código do país e o DDD.',
              ),
              const SizedBox(height: 12),
              Text(
                'Seu celular ajuda os familiares vinculados a encontrar você no painel.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!editing) ...[
                const SizedBox(height: 22),
                DropdownButtonFormField<_FamilySetup>(
                  initialValue: _setup,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Como vai usar o app?'),
                  items: const [
                    DropdownMenuItem(
                        value: _FamilySetup.independent,
                        child: Text('Usar sem vínculo')),
                    DropdownMenuItem(
                        value: _FamilySetup.responsible,
                        child: Text('Configurar como responsável')),
                    DropdownMenuItem(
                        value: _FamilySetup.link,
                        child: Text('Vincular a um responsável')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) setState(() => _setup = value);
                        },
                ),
                if (_setup == _FamilySetup.link) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _responsibleEmail,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                        labelText: 'E-mail do responsável'),
                    validator: (value) => validResponsibleEmail(
                      value?.trim().toLowerCase() ?? '',
                      widget.user,
                    )
                        ? null
                        : 'Informe um e-mail válido diferente do seu.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Seu nome e e-mail serão compartilhados no pedido. O vínculo começa após o aceite.'),
                ],
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy
                    ? 'Aguarde…'
                    : editing
                        ? 'Salvar alterações'
                        : 'Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
