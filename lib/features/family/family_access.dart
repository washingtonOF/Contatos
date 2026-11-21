import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_screen.dart';
import 'family_screen.dart';
import 'family_profile_editor.dart';

class FamilyAccess extends StatefulWidget {
  const FamilyAccess({super.key});

  @override
  State<FamilyAccess> createState() => _FamilyAccessState();
}

class _FamilyAccessState extends State<FamilyAccess> {
  late final _session = FirebaseAuth.instance.idTokenChanges();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: _session,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
                body: Center(
                    child: Text('Não foi possível verificar sua sessão.')));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final user = snapshot.data;
          if (user == null || !user.emailVerified)
            return const AuthScreen(family: true);
          return _FamilyProfile(key: ValueKey(user.uid), user: user);
        },
      );
}

class _FamilyProfile extends StatefulWidget {
  const _FamilyProfile({super.key, required this.user});

  final User user;

  @override
  State<_FamilyProfile> createState() => _FamilyProfileState();
}

class _FamilyProfileState extends State<_FamilyProfile> {
  late final _profile = FirebaseFirestore.instance
      .collection('familyProfiles')
      .doc(widget.user.uid);
  late final _profileUpdates = _profile.snapshots();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileUpdates,
        builder: (context, snapshot) {
          final profile = snapshot.data?.data();
          if (profile != null) {
            return FamilyScreen(user: widget.user, profile: profile);
          }
          if (snapshot.hasData && !snapshot.hasError) {
            return FamilyProfileEditor(user: widget.user);
          }
          return Scaffold(
            appBar: AppBar(
              title: const Text('Conecta Família'),
              actions: [
                IconButton(
                  tooltip: 'Sair',
                  onPressed: FirebaseAuth.instance.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: Center(
                child: snapshot.hasError
                    ? const Text('Não foi possível carregar seu perfil.')
                    : const CircularProgressIndicator()),
          );
        },
      );
}
