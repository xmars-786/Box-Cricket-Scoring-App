import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'core/controllers/auth_controller.dart';
import 'core/controllers/match_controller.dart';
import 'core/controllers/scoring_controller.dart';
import 'core/controllers/rules_controller.dart';
import 'core/controllers/theme_controller.dart';
import 'core/controllers/connectivity_controller.dart';
import 'firebase_options.dart';

/// Entry point for the Box Cricket Scoring App.
/// Initializes Firebase and sets up GetX-based state management.
void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
  }

  // Initialize Controllers (Dependency Injection — order matters!)
  Get.put(ThemeController());
  Get.put(AuthController()); // Must be before ScoringController
  Get.put(RulesController()); // Global Rules
  Get.put(MatchController());
  Get.put(ScoringController()); // Depends on AuthController
  Get.put(ConnectivityController());

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const BoxCricketApp());

  // Remove native splash once initialization is done
  FlutterNativeSplash.remove();
}
