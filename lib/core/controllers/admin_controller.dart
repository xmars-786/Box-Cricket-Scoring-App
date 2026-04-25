import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

class AdminController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxList<AppUser> _pendingUsers = <AppUser>[].obs;
  final RxList<AppUser> _allUsers = <AppUser>[].obs;
  final RxBool _isLoading = false.obs;

  List<AppUser> get pendingUsers => _pendingUsers;
  List<AppUser> get allUsers => _allUsers;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    listenToUsers();
  }

  void listenToUsers() {
    // Listen to pending users
    _firestore
        .collection(AppConstants.usersCollection)
        .where('is_approved', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          _pendingUsers.value =
              snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
        });

    // Listen to all users
    _firestore.collection(AppConstants.usersCollection).snapshots().listen((
      snapshot,
    ) {
      _allUsers.value =
          snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    });
  }

  Future<void> approveUser(String uid, String role) async {
    try {
      _isLoading.value = true;
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update(
        {'is_approved': true, 'role': role},
      );
      _isLoading.value = false;
    } catch (e) {
      _isLoading.value = false;
      Get.snackbar('Error', 'Failed to approve user: $e');
    }
  }

  Future<void> unapproveUser(String uid) async {
    try {
      _isLoading.value = true;
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update(
        {'is_approved': false},
      );
      _isLoading.value = false;
    } catch (e) {
      _isLoading.value = false;
      Get.snackbar('Error', 'Failed to unapprove user: $e');
    }
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update(
        {'role': newRole},
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to update role: $e');
    }
  }

  Future<void> addQuickPlayer(String name, String phone) async {
    try {
      _isLoading.value = true;

      // ── Uniqueness check ─────────────────────────────────
      final existing = await _firestore
          .collection(AppConstants.usersCollection)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _isLoading.value = false;
        Get.snackbar(
          'Duplicate',
          'A player with this phone number already exists.',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return;
      }

      // ── Create Firestore pre-registration doc only ────────
      // No Firebase Auth account — the player creates their own password
      // when they sign up via the app. The pre-reg doc will be migrated then.
      final newDocRef = _firestore.collection(AppConstants.usersCollection).doc();

      final user = AppUser(
        uid: newDocRef.id,
        name: name,
        phone: phone,
        role: AppConstants.rolePlayer,
        isApproved: true,       // pre-approved by admin
        isPreRegistered: true,  // flag: no Auth account yet
      );

      await newDocRef.set(user.toFirestore());
      _isLoading.value = false;
    } catch (e) {
      _isLoading.value = false;
      Get.snackbar('Error', 'Failed to add player: $e');
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).delete();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete user: $e');
    }
  }
}
