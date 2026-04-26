import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';
import '../constants/app_constants.dart';
import '../utils/ui_utils.dart';
import '../services/cloudinary_service.dart';
import '../routes/app_routes.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Rxn<AppUser> _currentUser = Rxn<AppUser>();
  final RxBool _isLoading = true.obs;
  final RxnString _error = RxnString();

  @override
  void onInit() {
    super.onInit();
    _initAuth();
  }

  // ─── Getters ────────────────────────────────────────────
  AppUser? get currentUser => _currentUser.value;
  Rxn<AppUser> get currentUserRx => _currentUser;
  bool get isAuthenticated => _currentUser.value != null;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;
  String get userId => _currentUser.value?.uid ?? '';

  // ─── Internal helper: phone → Firebase email ────────────
  /// Firebase Auth requires an email. We derive one from the phone number.
  String _toAuthEmail(String phone) {
    // Strip any non-digit characters, prefix with "p"
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return 'p$digits@boxcricket.local';
  }

  // ─── Initialize Auth Listener ───────────────────────────
  void _initAuth() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await _loadUserProfile(user.uid);
      }

      _auth.authStateChanges().listen((User? firebaseUser) async {
        if (firebaseUser != null) {
          await _loadUserProfile(firebaseUser.uid);
        } else {
          _currentUser.value = null;
        }
        _isLoading.value = false;
      });

      Future.delayed(const Duration(seconds: 5), () {
        if (_isLoading.value) _isLoading.value = false;
      });
    } catch (e) {
      _error.value = 'Auth initialization error: $e';
      _isLoading.value = false;
    }
  }

  /// Load user profile from Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .get();
      if (doc.exists) {
        _currentUser.value = AppUser.fromFirestore(doc);
      } else {
        _currentUser.value = null;
      }
      _error.value = null;
    } catch (e) {
      _error.value = 'Failed to load profile: ${e.toString()}';
    }
  }

  /// Get user name by ID
  Future<String> getUserName(String uid) async {
    if (uid.isEmpty) return 'Unknown';
    try {
      final doc =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .get();
      if (doc.exists) {
        return doc.data()?['name'] ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  // ─── Sign Up (phone + password) ─────────────────────────
  Future<bool> signUpWithPhone({
    required String phone,
    required String password,
    required String name,
    XFile? profileImage,
  }) async {
    try {
      _isLoading.value = true;
      _error.value = null;

      // ── 1. Check for admin pre-registration ───────────────
      final preRegQuery =
          await _firestore
              .collection(AppConstants.usersCollection)
              .where('phone', isEqualTo: phone)
              .where('is_pre_registered', isEqualTo: true)
              .limit(1)
              .get();

      final isPreRegistered = preRegQuery.docs.isNotEmpty;
      final preRegDoc = isPreRegistered ? preRegQuery.docs.first : null;

      // ── 2. If NOT pre-registered, check phone isn't taken ─
      if (!isPreRegistered) {
        final existingQuery =
            await _firestore
                .collection(AppConstants.usersCollection)
                .where('phone', isEqualTo: phone)
                .limit(1)
                .get();

        if (existingQuery.docs.isNotEmpty) {
          throw 'This phone number is already registered. Please sign in.';
        }
      }

      // ── 3. Create Firebase Auth account ───────────────────
      final email = _toAuthEmail(phone);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null)
        throw 'Registration failed. Please try again.';
      final uid = credential.user!.uid;

      // ── 4. Upload profile image if provided ───────────────
      String? imageUrl;
      if (profileImage != null) {
        imageUrl = await CloudinaryService.uploadImage(profileImage);
      }

      await credential.user!.updateDisplayName(
        isPreRegistered ? (preRegDoc!.data()['name'] ?? name) : name,
      );

      // ── 5. Build the user doc ─────────────────────────────
      if (isPreRegistered) {
        // Migrate pre-registration data → new doc with Auth UID
        final preData = preRegDoc!.data();
        final migratedUser = AppUser(
          uid: uid,
          name: preData['name'] ?? name, // keep admin-entered name
          phone: phone,
          role: preData['role'] ?? AppConstants.rolePlayer,
          isApproved: true, // already approved by admin
          isPreRegistered: false, // now a real account
          profileImageUrl: imageUrl, // player's own photo
        );

        // Write new doc, then delete the old pre-reg doc
        final batch = _firestore.batch();
        batch.set(
          _firestore.collection(AppConstants.usersCollection).doc(uid),
          migratedUser.toFirestore(),
        );
        batch.delete(preRegDoc.reference);
        await batch.commit();

        // Pre-registered players are already approved — show & redirect to login
        _isLoading.value = false;
        UIUtils.showSuccess('Account created! You can now sign in.');
        _currentUser.value = null;
        await _auth.signOut();
      } else {
        // Brand-new self-registration — needs admin approval
        final newUser = AppUser(
          uid: uid,
          name: name,
          phone: phone,
          role: AppConstants.rolePlayer,
          isApproved: false,
          profileImageUrl: imageUrl,
        );

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .set(newUser.toFirestore());

        _isLoading.value = false;
        UIUtils.showSuccess(
          'Registration successful! Please wait for admin approval.',
        );
        _currentUser.value = null;
        await _auth.signOut();
      }

      return true;
    } on FirebaseAuthException catch (e) {
      final msg = _getAuthErrorMessage(e.code);
      _error.value = msg;
      UIUtils.showError(msg);
      _isLoading.value = false;
      return false;
    } catch (e) {
      final msg = e.toString();
      _error.value = msg;
      UIUtils.showError(msg);
      _isLoading.value = false;
      return false;
    }
  }

  // ─── Sign In (phone + password) ─────────────────────────
  Future<bool> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      _isLoading.value = true;
      _error.value = null;

      final email = _toAuthEmail(phone);
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doc =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(credential.user?.uid)
              .get();

      if (doc.exists) {
        final user = AppUser.fromFirestore(doc);
        if (!user.isApproved && !user.isAdmin) {
          await _auth.signOut();
          const msg = 'Account pending admin approval.';
          _error.value = msg;
          UIUtils.showError(msg);
          _isLoading.value = false;
          return false;
        }
        _currentUser.value = user;
      }

      _isLoading.value = false;
      Get.offAllNamed(AppRoutes.home);
      return true;
    } on FirebaseAuthException catch (e) {
      final msg = _getAuthErrorMessage(e.code);
      _error.value = msg;
      UIUtils.showError(msg);
      _isLoading.value = false;
      return false;
    } catch (e) {
      final msg = e.toString();
      _error.value = msg;
      UIUtils.showError(msg);
      _isLoading.value = false;
      return false;
    }
  }

  // ─── Sign Out ───────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  // ─── Update User Profile ───────────────────────────────
  Future<void> updateProfile({String? name, String? role}) async {
    if (_currentUser.value == null) return;
    try {
      _currentUser.value = _currentUser.value!.copyWith(name: name, role: role);
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(_currentUser.value!.uid)
          .update({
            if (name != null) 'name': name,
            if (role != null) 'role': role,
          });
    } catch (e) {
      _error.value = e.toString();
    }
  }

  // ─── Helper Methods ─────────────────────────────────────
  void clearError() => _error.value = null;

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'Phone number or password is incorrect.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This phone number is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Sign-in method not enabled. Contact support.';
      default:
        return 'Error ($code). Please try again.';
    }
  }
}
