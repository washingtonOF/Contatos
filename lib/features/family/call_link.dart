class CallLink {
  CallLink(String address) : _base = Uri.tryParse(address);

  final Uri? _base;

  bool get enabled {
    final base = _base;
    return base != null &&
        base.scheme == 'https' &&
        base.host.isNotEmpty &&
        base.userInfo.isEmpty &&
        !base.hasQuery &&
        !base.hasFragment;
  }

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
