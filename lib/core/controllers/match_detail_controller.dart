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
      HapticFeedback.heavyImpact();
    } else if (ball.runs == 6) {
      animationType = 'six';
      HapticFeedback.mediumImpact();
    } else if (ball.runs == 4) {
      animationType = 'four';
      HapticFeedback.mediumImpact();
    } else if (ball.isWide) {
      animationType = 'wide';
      HapticFeedback.lightImpact();
    } else if (ball.isNoBall) {
      animationType = 'no_ball';
      HapticFeedback.lightImpact();
    } else if (ball.runs == 0 && !ball.isExtra) {
      // Funny animation for dot ball?
      // animationType = 'dot';
    }

    if (animationType != null) {
      currentAnimation.value = animationType;

      // Auto hide after 3 seconds for more "funny" impact
      Timer(const Duration(milliseconds: 3000), () {
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
