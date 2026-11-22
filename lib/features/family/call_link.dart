class CallLink {
  CallLink(String address) : _base = Uri.tryParse(address);

  final Uri? _base;

  static bool inviteIsActive(DateTime? sent, DateTime now) =>
      sent != null &&
      !sent.isAfter(now) &&
      now.isBefore(sent.add(const Duration(minutes: 30)));

  bool get enabled {
    final base = _base;
    return base != null &&
        base.scheme == 'https' &&
        base.host.isNotEmpty &&
        base.userInfo.isEmpty &&
        !base.hasQuery &&
        !base.hasFragment;
  }

  Uri? get server => enabled ? _base : null;

  Uri? forRoom(String room, {required bool video}) {
    if (!enabled || !RegExp(r'^[a-f0-9]{40}$').hasMatch(room)) return null;
    final base = _base!;
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        room
      ],
      fragment: video ? null : 'config.startWithVideoMuted=true',
    );
  }
}
