import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'family_header.dart';
import 'family_presence.dart';

class FamilyProfileEditor extends StatefulWidget {
  const FamilyProfileEditor({
    super.key,
    required this.user,
    this.profile,
    this.online,
  });

  final User user;
  final Map<String, dynamic>? profile;
  final ValueListenable<bool>? online;

  @override
  State<FamilyProfileEditor> createState() => _FamilyProfileEditorState();
}

class _FamilyProfileEditorState extends State<FamilyProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.profile?['name'] as String? ?? widget.user.displayName ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.profile?['phone'] as String? ?? '',
  );
  late Blob? _photo = widget.profile?['photo'] as Blob?;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
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
      await FirebaseFirestore.instance
          .collection('familyProfiles')
          .doc(widget.user.uid)
          .set({
        'name': _name.text.trim(),
        'phone': _number,
        if (_photo case final photo?) 'photo': photo,
      });
      if (mounted && widget.profile != null) Navigator.pop(context);
    } on FirebaseException {
      _notice('Não foi possível salvar seu perfil.');
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
      appBar: AppBar(
        title: Text(editing ? 'Meu perfil' : 'Conecta Família'),
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
