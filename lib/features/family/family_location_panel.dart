import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'family_usage_report.dart';

class FamilyLocationPanel extends StatefulWidget {
  const FamilyLocationPanel({
    super.key,
    required this.link,
    required this.contactName,
    required this.isResponsible,
  });

  final DocumentReference<Map<String, dynamic>> link;
  final String contactName;
  final bool isResponsible;

  @override
  State<FamilyLocationPanel> createState() => _FamilyLocationPanelState();
}

class _FamilyLocationPanelState extends State<FamilyLocationPanel> {
  static const _lifetime = Duration(hours: 1);
  late final _location = widget.link.collection('sharedLocation').doc('latest');
  late final _linkUpdates = widget.link.snapshots(includeMetadataChanges: true);
  late final _updates = _location.snapshots(includeMetadataChanges: true);
  Timer? _timer;
  DateTime? _expires;
  bool _busy = false;

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

  Future<void> _share() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartilhar sua localização?'),
        content: Text(
          '${widget.contactName} poderá ver a posição atual por até 1 hora. '
          'Você pode removê-la a qualquer momento.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Compartilhar agora')),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
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
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _notice('Volte ao painel para compartilhar sua posição.');
      return;
    }
    await _location.set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(_lifetime + const Duration(minutes: 5)),
      ),
    });
    _notice('Posição compartilhada.');
  }

  Future<void> _openMap() async {
    final document =
        await _location.get(const GetOptions(source: Source.server));
    final data = document.data();
    final created = (data?['createdAt'] as Timestamp?)?.toDate();
    if (!mounted) return;
    if (data == null ||
        document.metadata.hasPendingWrites ||
        created == null ||
        !created.add(_lifetime).isAfter(DateTime.now())) {
      _notice('A posição compartilhada não está mais disponível.');
      return;
    }
    final location = "${data['latitude']},${data['longitude']}";
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': location,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _notice('Não foi possível abrir o mapa.');
    }
  }

  void _refreshAt(DateTime? expires) {
    if (expires == _expires) return;
    _expires = expires;
    _timer?.cancel();
    if (expires != null && expires.isAfter(DateTime.now())) {
      _timer = Timer(expires.difference(DateTime.now()), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.isResponsible
              ? 'Painel do responsável'
              : 'Compartilhar com responsável'),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _linkUpdates,
          builder: (context, snapshot) {
            final link = snapshot.data;
            if (link?.data()?.containsKey('revokedAt') == true) {
              return const Center(child: Text('Vínculo encerrado.'));
            }
            if (snapshot.hasError || link?.exists == false) {
              return const Center(child: Text('Vínculo indisponível.'));
            }
            if (link == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (link.metadata.isFromCache || link.metadata.hasPendingWrites) {
              return const Center(
                child: Text('Aguardando conexão para confirmar o vínculo.'),
              );
            }
            return _buildSharing();
          },
        ),
      );

  Widget _buildSharing() =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _updates,
        builder: (context, snapshot) {
          final document = snapshot.data;
          final data = document?.data();
          final created =
              (data?['createdAt'] as Timestamp?)?.toDate().toLocal();
          final expires = created?.add(_lifetime);
          _refreshAt(expires);
          final available = !snapshot.hasError &&
              document?.metadata.isFromCache == false &&
              document?.metadata.hasPendingWrites == false &&
              expires?.isAfter(DateTime.now()) == true;
          final colors = Theme.of(context).colorScheme;
          final localizations = MaterialLocalizations.of(context);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: const Icon(Icons.person_outline),
                ),
                title: Text(widget.contactName),
                subtitle: Text(widget.isResponsible
                    ? 'Familiar vinculado'
                    : 'Responsável vinculado'),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: colors.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Última localização',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        available
                            ? 'Compartilhada em ${localizations.formatShortDate(created!)} às ${TimeOfDay.fromDateTime(created).format(context)}.'
                            : snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? 'Conferindo compartilhamento…'
                                : 'Nenhuma localização ativa.',
                      ),
                      if (available) ...[
                        Text(
                          'Acesso até ${localizations.formatShortDate(expires!)} às '
                          '${TimeOfDay.fromDateTime(expires).format(context)}.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('Abrir no Google Maps'),
                          onPressed: _busy
                              ? null
                              : () => _run(
                                    _openMap,
                                    'Não foi possível abrir o mapa.',
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.isResponsible)
                const Text(
                    'A posição aparece quando seu familiar a compartilha pelo próprio celular.')
              else ...[
                Text(
                    'Escolha quando compartilhar sua posição com ${widget.contactName}. A posição fica disponível por 1 hora.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          _share, 'Não foi possível compartilhar sua posição.'),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Compartilhar minha posição'),
                ),
                if (document?.exists == true)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(_location.delete,
                            'Não foi possível remover sua posição.'),
                    child: const Text('Remover minha posição'),
                  ),
              ],
              const SizedBox(height: 20),
              FamilyUsageReport(
                link: widget.link,
                contactName: widget.contactName,
                isResponsible: widget.isResponsible,
              ),
            ],
          );
        },
      );
}
