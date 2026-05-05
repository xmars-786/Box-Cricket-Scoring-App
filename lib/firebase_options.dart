import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration options.
///
/// IMPORTANT: Replace these placeholder values with your actual Firebase
/// project configuration. You can get these from Firebase Console:
/// 1. Go to https://console.firebase.google.com
/// 2. Select your project → Project Settings → General
/// 3. Add your Web/Android/iOS app and copy the config values
///
/// Alternatively, run: `flutterfire configure` to auto-generate this file.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for '
          '${defaultTargetPlatform.name}',
        );
    }
  }

  // TODO: Replace with your actual Firebase Web config

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDUBi9wBgyvtD0pytCD7lYFClf9q3WXM7U',
    appId: '1:553625928363:web:338c4cb521dee62f5aedee',
    messagingSenderId: '553625928363',
    projectId: 'cricket-app-69f9c',
    authDomain: 'cricket-app-69f9c.firebaseapp.com',
    storageBucket: 'cricket-app-69f9c.firebasestorage.app',
    measurementId: 'G-2VQEB62WKD',
  );

  // Go to Firebase Console → Project Settings → General → Web App

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPGJg2T8CNqYOOkgLmOiRN5A68SkStj6E',
    appId: '1:553625928363:android:495caa338c0d1ef25aedee',
    messagingSenderId: '553625928363',
    projectId: 'cricket-app-69f9c',
    storageBucket: 'cricket-app-69f9c.firebasestorage.app',
  );

  // TODO: Replace with your actual Firebase Android config

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCee0IQ0uktxUuaoTxEjYHcCJGADlREPaQ',
    appId: '1:553625928363:ios:aff2bd06a63a54e15aedee',
    messagingSenderId: '553625928363',
    projectId: 'cricket-app-69f9c',
    storageBucket: 'cricket-app-69f9c.firebasestorage.app',
    iosBundleId: 'com.boxcricket.boxCricket',
  );

  // TODO: Replace with your actual Firebase iOS config
}