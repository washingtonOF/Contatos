import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FamilyUsageReport extends StatefulWidget {
  const FamilyUsageReport({
    super.key,
    required this.link,
    required this.contactName,
    required this.isResponsible,
  });

  final DocumentReference<Map<String, dynamic>> link;
  final String contactName;
  final bool isResponsible;

  @override
  State<FamilyUsageReport> createState() => _FamilyUsageReportState();
}

class _FamilyUsageReportState extends State<FamilyUsageReport> {
  static const _channel =
      MethodChannel('com.washingtonof/conecta_messenger/usage');
  static const _lifetime = Duration(hours: 24);
  late final _document = widget.link.collection('sharedUsage').doc('latest');
  late final _updates = _document.snapshots(includeMetadataChanges: true);
  Timer? _timer;
  DateTime? _expires;
  bool _busy = false;
  bool _needsPermission = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _run(Future<void> Function() action, String error) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Exception {
      _notice(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _duration(int minutes) =>
      minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min';

  Future<void> _prepare() async {
    final report = await _channel.invokeMapMethod<String, dynamic>('readToday');
    if (!mounted || report == null) return;
    final authorized = report['authorized'] == true;
    setState(() => _needsPermission = !authorized);
    if (!authorized) return;
    final apps = (report['apps'] as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    if (apps.isEmpty) {
      _notice('Hoje ainda não há aplicativos com pelo menos 1 minuto de uso.');
      return;
    }
    final selected = Set<int>.from(Iterable.generate(apps.length));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Revisar resumo de hoje'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Escolha o que enviar a ${widget.contactName}. O resumo ficará disponível por 24 horas.'),
                const SizedBox(height: 8),
                for (final (index, app) in apps.indexed)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(index),
                    title: Text(app['name'] as String),
                    subtitle: Text(_duration(app['minutes'] as int)),
                    onChanged: (value) => update(() {
                      if (value == true) {
                        selected.add(index);
                      } else {
                        selected.remove(index);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed:
                  selected.isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('Compartilhar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted ||
        accepted != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    await _document.set({
      'day': report['day'],
      'apps': [
        for (final (index, app) in apps.indexed)
          if (selected.contains(index)) app
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(_lifetime + const Duration(minutes: 5)),
      ),
    });
    _notice('Resumo de tempo de uso compartilhado.');
  }

  void _refreshAt(DateTime? expires) {
    if (_expires == expires) return;
    _expires = expires;
    _timer?.cancel();
    if (expires != null && expires.isAfter(DateTime.now())) {
      _timer = Timer(expires.difference(DateTime.now()), () {
        if (mounted) setState(() {});
      });
    }
  }

  String _formatDay(String day) => day.split('-').reversed.join('/');

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _updates,
            builder: (context, snapshot) {
              final document = snapshot.data;
              final data = document?.data();
              final created = (data?['createdAt'] as Timestamp?)?.toDate();
              final expires = created?.add(_lifetime);
              _refreshAt(expires);
              final available = !snapshot.hasError &&
                  document?.metadata.isFromCache == false &&
                  document?.metadata.hasPendingWrites == false &&
                  expires?.isAfter(DateTime.now()) == true;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tempo de uso',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (available) ...[
                    Text('Resumo de ${_formatDay(data!['day'] as String)}'),
                    Text(
                      'Acesso até ${MaterialLocalizations.of(context).formatShortDate(expires!.toLocal())} às '
                      '${TimeOfDay.fromDateTime(expires.toLocal()).format(context)}.',
                    ),
                    for (final app in data['apps'] as List)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(app['name'] as String),
                        trailing: Text(_duration(app['minutes'] as int)),
                      ),
                  ] else if (snapshot.connectionState ==
                      ConnectionState.waiting)
                    const LinearProgressIndicator()
                  else
                    const Text('Nenhum resumo ativo.'),
                  if (!widget.isResponsible) ...[
                    const SizedBox(height: 12),
                    const Text(
                        'Veja até oito apps mais usados hoje e escolha quais tempos compartilhar.'),
                    if (_needsPermission) ...[
                      const SizedBox(height: 8),
                      const Text(
                          'Ative Acesso ao uso para o IsaMig Mensagens nas configurações do Android. Depois, volte e toque em Revisar resumo.'),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => _channel
                                      .invokeMethod<void>('openSettings'),
                                  'Não foi possível abrir as configurações do Android.',
                                ),
                        child: const Text('Abrir configurações'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Revisar resumo'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              _prepare, 'Não foi possível ler o tempo de uso.'),
                    ),
                    if (document?.exists == true)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(_document.delete,
                                'Não foi possível remover o resumo.'),
                        child: const Text('Remover resumo'),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      );
}
