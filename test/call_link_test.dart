import 'package:conecta_messenger/features/family/call_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const room = '0123456789abcdef0123456789abcdef01234567';
  final calls = CallLink('https://meet.example.com/reunioes/');

  test('voice and video open the same room with different camera settings', () {
    final voice = calls.forRoom(room, video: false)!;
    final video = calls.forRoom(room, video: true)!;
    expect(voice.host, 'meet.example.com');
    expect(voice.path, '/reunioes/$room');
    expect(video.path, voice.path);
    expect(voice.fragment, 'config.startWithVideoMuted=true');
    expect(video.hasFragment, isFalse);
  });

  test('only HTTPS settings and generated room identifiers are accepted', () {
    expect(CallLink('').forRoom(room, video: true), isNull);
    expect(CallLink('http://meet.example.com').forRoom(room, video: false),
        isNull);
    expect(calls.forRoom('../outra-sala', video: true), isNull);
  });
}
