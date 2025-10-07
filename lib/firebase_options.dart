import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'firebase_options.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw JsonUnsupportedObjectError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
            'DefaultFirebaseOptions have not been configured for ios - '
            'you can reconfigure this by running the FlutterFire CLI again.');
      case TargetPlatform.macOS:
        throw UnsupportedError(
            'DefaultFirebaseOptions have not been configured for macos - '
            'you can reconfigure this by running the FlutterFire CLI again.');
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3H9dy6NgTeNYUtoBQr-48x-qYlw802PI',
    appId: '1:972970472851:android:e36ba79ec98c43b504e466',
    messagingSenderId: '972970472851',
    projectId: 'push-test-15206',
    storageBucket: 'push-test-15206.firebasestorage.app',
  );
}
