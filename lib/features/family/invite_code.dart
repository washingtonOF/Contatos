import 'dart:math';

String newInviteCode() {
  final random = Random.secure();
  return List.generate(
    20,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
