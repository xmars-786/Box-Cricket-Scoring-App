import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/ball_log_model.dart';

class MatchDetailController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Rx<String?> currentAnimation = Rx<String?>(null);
  String? _lastBallId;
  StreamSubscription? _ballLogSub;

  void listenToLatestBall(String matchId) {
    _ballLogSub?.cancel();
    
    _ballLogSub = _firestore
        .collection(AppConstants.matchesCollection)
        .doc(matchId)
        .collection(AppConstants.ballLogsCollection)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final ball = BallLog.fromFirestore(doc);

        if (_lastBallId != null && ball.id != _lastBallId) {
          // It's a new ball
          _triggerAnimationIfNeeded(ball);
        }
        _lastBallId = ball.id;
      }
    });
  }

  void _triggerAnimationIfNeeded(BallLog ball) {
    String? animationType;

    if (ball.isWicket) {
      animationType = 'wicket';
    } else if (ball.runs == 6) {
      animationType = 'six';
    } else if (ball.runs == 4) {
      animationType = 'four';
    }

    if (animationType != null) {
      HapticFeedback.heavyImpact();
      currentAnimation.value = animationType;

      // Auto hide after 2.5 seconds
      Timer(const Duration(milliseconds: 2500), () {
        if (currentAnimation.value == animationType) {
          currentAnimation.value = null;
        }
      });
    }
  }

  @override
  void onClose() {
    _ballLogSub?.cancel();
    super.onClose();
  }
}
