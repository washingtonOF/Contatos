import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Web Firebase configuration. Android and iOS require FlutterFire registration.
class ConectaFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyAxuU5MBfZxQuteTtdJoH_47O8EHRvosSY',
        appId: '1:120005149881:web:17829a3479a5da64ca4768',
        messagingSenderId: '120005149881',
        projectId: 'contatos-6c266',
        authDomain: 'contatos-6c266.firebaseapp.com',
        storageBucket: 'contatos-6c266.firebasestorage.app',
        measurementId: 'G-8ZQKLYVTY7',
      );
    }
    throw UnsupportedError('Registre Android/iOS usando flutterfire configure antes de executar.');
  }
}
