import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'invite_code.dart';

class FamilyPresence {
  FamilyPresence(this.uid, this._db) {
    _lifecycle = AppLifecycleListener(onStateChange: _onStateChange);
    _foreground =
        _lifecycle.binding.lifecycleState == AppLifecycleState.resumed;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _heartbeat());
    _heartbeat();
  }

  final String uid;
  final FirebaseFirestore _db;
  final _session = newInviteCode();
  final online = ValueNotifier(false);
  late final AppLifecycleListener _lifecycle;
  late final Timer _timer;
  List<DocumentReference<Map<String, dynamic>>> _links = [];
  bool _foreground = false;
  bool _pending = false;
  bool _disposed = false;
  int _generation = 0;
  DateTime? _acknowledgedUntil;

  DocumentReference<Map<String, dynamic>> get _own => _db
      .collection('familyProfiles')
      .doc(uid)
      .collection('presence')
      .doc(_session);

  void updateLinks(List<DocumentReference<Map<String, dynamic>>> links) {
    final oldPaths = _links.map((link) => link.path).toSet();
    _links = links;
    if (_foreground && links.any((link) => !oldPaths.contains(link.path))) {
      _heartbeat();
    }
  }

  void _onStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _foreground) return;
    _foreground = resumed;
    if (resumed) {
      _heartbeat();
    } else {
      clear();
    }
  }

  void _heartbeat() {
    if (!_foreground || _disposed) return;
    final now = DateTime.now();
    online.value = _acknowledgedUntil?.isAfter(now) ?? false;
    if (_pending) return;
    _pending = true;
    final generation = _generation;
    final expires = now.add(const Duration(seconds: 90));
    final data = {'uid': uid, 'until': Timestamp.fromDate(expires)};
    for (final link in _links) {
      unawaited(
          _ignoreFailure(link.collection('presence').doc(_session).set(data)));
    }
    unawaited(_own.set(data).then<void>((_) {
      if (!_disposed && _foreground && generation == _generation) {
        _acknowledgedUntil = expires;
        online.value = expires.isAfter(DateTime.now());
      }
    }, onError: (Object _, StackTrace __) {
      // A later heartbeat can recover after the network reconnects.
    }).whenComplete(() {
      _pending = false;
      if (generation != _generation) _heartbeat();
    }));
  }

  void clear() {
    _foreground = false;
    _generation++;
    _acknowledgedUntil = null;
    online.value = false;
    unawaited(_ignoreFailure(_own.delete()));
    for (final link in _links) {
      unawaited(
          _ignoreFailure(link.collection('presence').doc(_session).delete()));
    }
  }

  Future<void> _ignoreFailure(Future<void> write) async {
    try {
      await write;
    } on FirebaseException {
      // The latest presence expires even if the connection is lost.
    }
  }

  void dispose() {
    _disposed = true;
    _timer.cancel();
    _lifecycle.dispose();
    online.dispose();
  }
}

class PresenceLabel extends StatelessWidget {
  const PresenceLabel({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) => Text(
        online ? 'Online' : 'Offline',
        style: TextStyle(
          color: online
              ? Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF8CE6BD)
                  : const Color(0xFF14634D)
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
}

class ContactPresence extends StatefulWidget {
  const ContactPresence({super.key, required this.link, required this.uid});

  final DocumentReference<Map<String, dynamic>> link;
  final String uid;

  @override
  State<ContactPresence> createState() => _ContactPresenceState();
}

class _ContactPresenceState extends State<ContactPresence> {
  late final _statuses = widget.link
      .collection('presence')
      .where('uid', isEqualTo: widget.uid)
      .snapshots();
  Timer? _expiry;
  DateTime? _activeUntil;

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _statuses,
        builder: (context, snapshot) {
          if (snapshot.hasError || !snapshot.hasData)
            return const Text('Status indisponível');
          DateTime? latest;
          for (final doc in snapshot.data!.docs) {
            final until = (doc.data()['until'] as Timestamp).toDate();
            if (latest == null || until.isAfter(latest)) latest = until;
          }
          final timeRemaining = latest?.difference(DateTime.now());
          if (_activeUntil != latest) {
            _activeUntil = latest;
            _expiry?.cancel();
            if (timeRemaining != null && !timeRemaining.isNegative) {
              _expiry = Timer(timeRemaining, () {
                if (mounted) setState(() {});
              });
            }
          }
          return PresenceLabel(
              online: timeRemaining != null && timeRemaining > Duration.zero);
        },
      );
}
