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
    apiKey: 'AIzaSyBCy4Pa8O3hfz0S3JCd-Qpz6BMDCfB6fNg',
    appId: '1:82559395274:web:0129ad16c0e568c610db33',
    messagingSenderId: '82559395274',
    projectId: 'boxcricketapp-e9a33',
    authDomain: 'boxcricketapp-e9a33.firebaseapp.com',
    storageBucket: 'boxcricketapp-e9a33.firebasestorage.app',
    measurementId: 'G-0FL52LX0ZE',
  );

  // Go to Firebase Console → Project Settings → General → Web App

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD23DrIaIO-dkB94nlZzbPNqwaAHi_E3O4',
    appId: '1:82559395274:android:5715b79c7ce85b1410db33',
    messagingSenderId: '82559395274',
    projectId: 'boxcricketapp-e9a33',
    storageBucket: 'boxcricketapp-e9a33.firebasestorage.app',
  );

  // TODO: Replace with your actual Firebase Android config

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAdUZykGDnb9hVu91E5tF23rsPfebjtO_c',
    appId: '1:82559395274:ios:d4c6d2030f31d03a10db33',
    messagingSenderId: '82559395274',
    projectId: 'boxcricketapp-e9a33',
    storageBucket: 'boxcricketapp-e9a33.firebasestorage.app',
    iosBundleId: 'com.boxcricket.boxCricket',
  );

  // TODO: Replace with your actual Firebase iOS config
}