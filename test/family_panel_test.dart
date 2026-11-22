import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_messenger/features/family/family_location_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Data = Map<String, dynamic>;

void main() {
  testWidgets('Oculta compartilhamentos quando perde a confirmação do vínculo',
      (tester) async {
    final link = _Link();
    addTearDown(link.updates.close);

    await tester.pumpWidget(MaterialApp(
      home: FamilyLocationPanel(
        link: link,
        contactName: 'Familiar de teste',
        isResponsible: true,
      ),
    ));
    link.updates.add(_Snapshot({}, isFromCache: true));
    await tester.pumpAndSettle();
    expect(find.text('Aguardando conexão para confirmar o vínculo.'), findsOne);
    expect(find.text('Tempo de uso'), findsNothing);

    link.updates.add(_Snapshot({}));
    await tester.pumpAndSettle();
    expect(find.text('Abrir no Google Maps'), findsOne);
    expect(find.text('Aplicativo de teste'), findsOne);
    expect(find.textContaining('Acesso até'), findsNWidgets(2));

    link.updates.add(_Snapshot({}, isFromCache: true));
    await tester.pumpAndSettle();
    expect(find.text('Abrir no Google Maps'), findsNothing);
    expect(find.text('Aplicativo de teste'), findsNothing);
    expect(find.textContaining('Acesso até'), findsNothing);

    link.updates.add(_Snapshot({}));
    await tester.pumpAndSettle();
    expect(find.text('Aplicativo de teste'), findsOne);
    expect(find.textContaining('Acesso até'), findsNWidgets(2));

    link.updates.add(_Snapshot({'revokedAt': Timestamp.now()}));
    await tester.pumpAndSettle();
    expect(find.text('Vínculo encerrado.'), findsOne);
    expect(find.text('Abrir no Google Maps'), findsNothing);
    expect(find.text('Aplicativo de teste'), findsNothing);
    expect(find.textContaining('Acesso até'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

// ignore: subtype_of_sealed_class
class _Link extends Fake implements DocumentReference<_Data> {
  final updates = StreamController<DocumentSnapshot<_Data>>();

  @override
  Stream<DocumentSnapshot<_Data>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      updates.stream;

  @override
  CollectionReference<_Data> collection(String collectionPath) =>
      _SharingCollection(collectionPath);
}

// ignore: subtype_of_sealed_class
class _SharingCollection extends Fake implements CollectionReference<_Data> {
  _SharingCollection(this.path);

  @override
  final String path;

  @override
  DocumentReference<_Data> doc([String? path]) => _SharingDocument(
        this.path == 'sharedLocation'
            ? {
                'latitude': -3.7,
                'longitude': -38.5,
                'createdAt': Timestamp.now()
              }
            : {
                'day': '2026-11-21',
                'createdAt': Timestamp.now(),
                'apps': [
                  {'name': 'Aplicativo de teste', 'minutes': 15},
                ],
              },
      );
}

// ignore: subtype_of_sealed_class
class _SharingDocument extends Fake implements DocumentReference<_Data> {
  _SharingDocument(this.data);

  final _Data data;

  @override
  Stream<DocumentSnapshot<_Data>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) =>
      Stream.multi((controller) => controller.add(_Snapshot(data)));
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<_Data> {
  _Snapshot(this.value, {bool isFromCache = false})
      : metadata = _Metadata(isFromCache);

  final _Data value;

  @override
  final SnapshotMetadata metadata;

  @override
  bool get exists => true;

  @override
  _Data data() => value;
}

class _Metadata extends Fake implements SnapshotMetadata {
  _Metadata(this.isFromCache);

  @override
  final bool isFromCache;

  @override
  bool get hasPendingWrites => false;
}
