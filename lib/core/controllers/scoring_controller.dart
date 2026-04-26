import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/match_model.dart';
import '../models/player_model.dart';
import '../models/ball_log_model.dart';
import '../constants/app_constants.dart';
import '../utils/ui_utils.dart';
import 'rules_controller.dart';
import 'auth_controller.dart';
import 'match_controller.dart';

class ScoringController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  late RulesController _rules;
  late AuthController _auth;

  final RxnString _matchId = RxnString();
  final RxList<BallLog> _ballLogs = <BallLog>[].obs;
  final RxList<BallLog> _currentOverBalls = <BallLog>[].obs;
  final RxBool _isLoading = false.obs;
  final RxnString _error = RxnString();

  StreamSubscription? _ballLogsSub;

  // Getters
  List<BallLog> get ballLogs => _ballLogs;
  List<BallLog> get currentOverBalls => _currentOverBalls;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;

  bool get isOverFinished {
    if (_currentOverBalls.isEmpty) return false;
    final legalBalls =
        _currentOverBalls
            .where((b) => b.ballType == 'normal' || b.ballType == 'wicket')
            .length;
    return legalBalls >= AppConstants.ballsPerOver ||
        (legalBalls == 0 &&
            _currentOverBalls.isNotEmpty &&
            _currentOverBalls.any(
              (b) => b.ballNumber == 0 && _currentOverBalls.length > 1,
            ));
    // Simplified: Actually, if currentScore.balls is 0 but match was started/live, it might mean over end.
  }

  /// Get ball logs for a specific innings (A or B)
  List<BallLog> getBallsForInnings(String innings) {
    return _ballLogs.where((b) => b.innings == innings).toList();
  }

  // Initialize for a Match
  void initForMatch(String matchId) {
    _matchId.value = matchId;
    _listenToBallLogs();
  }

  // Listen to Ball Logs (Real-time)
  void _listenToBallLogs() {
    _ballLogsSub?.cancel();
    if (_matchId.value == null) return;

    _ballLogsSub = _firestore
        .collection(AppConstants.matchesCollection)
        .doc(_matchId.value)
        .collection(AppConstants.ballLogsCollection)
        .orderBy('timestamp', descending: true)
        .limit(60) // fetch more to cover both innings
        .snapshots()
        .listen((snapshot) {
          final allLogs =
              snapshot.docs
                  .map((doc) => BallLog.fromFirestore(doc))
                  .toList()
                  .reversed
                  .toList(); // ascending by timestamp

          _ballLogs.assignAll(allLogs);

          if (_ballLogs.isNotEmpty) {
            final lastBall = _ballLogs.last;
            // Only take balls from the SAME innings as the last ball
            _currentOverBalls.assignAll(
              _ballLogs
                  .where(
                    (b) =>
                        b.overNumber == lastBall.overNumber &&
                        b.innings == lastBall.innings,
                  )
                  .toList(),
            );
          } else {
            _currentOverBalls.clear();
          }
        });
  }

  // Record a Ball (Fast Batch Write)
  Future<void> recordBall({
    required MatchModel match,
    required PlayerModel batsman,
    required PlayerModel bowler,
    required int runs,
    required String ballType,
    bool isWicket = false,
    String? dismissalType,
    String? dismissedPlayerId,
    String? fielderId,
  }) async {
    if (_matchId.value == null) return;
    HapticFeedback.mediumImpact();

    if (!match.scorerIds.contains(_auth.userId) &&
        !(_auth.currentUser?.isAdmin ?? false)) {
      UIUtils.showError(
        'Permission denied. You are not an assigned scorer or admin.',
      );
      return;
    }

    if (batsman == null || bowler == null) {
      UIUtils.showError('Striker or Bowler not selected!');
      return;
    }

    final matchRef = _firestore
        .collection(AppConstants.matchesCollection)
        .doc(_matchId.value);
    final batsmanRef = matchRef.collection('players').doc(batsman.id);
    final bowlerRef = matchRef.collection('players').doc(bowler.id);
    final ballId = _uuid.v4();

    if (match.customRulesEnabled) {
      final legalBallsFaced = batsman.legalBallsFaced;
      final maxBatBalls = (match.maxBattingOvers ?? 2) * 6;
      if (legalBallsFaced >= maxBatBalls) {
        UIUtils.showError(
          'Limit reached! ${batsman.name} has already faced ${match.maxBattingOvers ?? 2} overs.',
        );
        return;
      }

      final totalBowlingBalls = (bowler.oversBowled * 6) + bowler.ballsBowled;
      final maxBowlBalls = (match.maxBowlingOvers ?? 3) * 6;
      if (totalBowlingBalls >= maxBowlBalls) {
        UIUtils.showError(
          'Limit reached! ${bowler.name} has already bowled ${match.maxBowlingOvers ?? 3} overs.',
        );
        return;
      }
    }

    bool firstInningsCompleted = false;
    bool matchCompleted = false;
    String toastMessage = '';
    final String matchId = _matchId.value!;

    try {
      final currentScore = match.currentScore;
      final bool isLegalDelivery = ballType != 'wide' && ballType != 'no_ball';

      final wideExtra = _rules.wideRuns.value;
      final noBallExtra = _rules.noBallRuns.value;

      int runIncrease = 0;
      int extraIncrease = 0;
      bool nextIsFreeHit = false;

      if (ballType == 'wide') {
        runIncrease = wideExtra + runs;
        extraIncrease = wideExtra + runs;
      } else if (ballType == 'no_ball') {
        runIncrease = noBallExtra + runs;
        extraIncrease = noBallExtra;
        nextIsFreeHit = _rules.freeHitEnabled.value;
      } else if (ballType == 'bye' || ballType == 'leg_bye') {
        runIncrease = runs;
        extraIncrease = runs;
      } else {
        runIncrease = runs;
      }

      int newBalls = currentScore.balls;
      int newOvers = currentScore.overs;
      if (isLegalDelivery) {
        newBalls++;
        if (newBalls >= AppConstants.ballsPerOver) {
          newOvers++;
          newBalls = 0;
        }
      }

      final ballLog = BallLog(
        id: ballId,
        matchId: matchId,
        innings: match.currentInnings,
        overNumber: currentScore.overs,
        ballNumber: currentScore.balls,
        batsmanId: batsman.id,
        nonStrikerId: match.currentNonStrikerId,
        bowlerId: bowler.id,
        runs: runs,
        ballType: ballType,
        isWicket: isWicket,
        dismissalType: dismissalType,
        dismissedPlayerId: dismissedPlayerId,
        isFreeHit: match.isFreeHit,
        extraRuns: extraIncrease,
        scoredBy: _auth.userId,
      );

      final scoreKey =
          match.currentInnings == 'A' ? 'team_a_score' : 'team_b_score';
      final updatedScore = currentScore.copyWith(
        runs: currentScore.runs + runIncrease,
        wickets: isWicket ? currentScore.wickets + 1 : currentScore.wickets,
        overs: newOvers,
        balls: newBalls,
        extras: currentScore.extras + extraIncrease,
        wides: ballType == 'wide' ? currentScore.wides + 1 : currentScore.wides,
        noBalls:
            ballType == 'no_ball'
                ? currentScore.noBalls + 1
                : currentScore.noBalls,
      );

      final legalBallsFacedNow =
          batsman.legalBallsFaced + (isLegalDelivery ? 1 : 0);
      final maxBatBalls =
          match.customRulesEnabled ? (match.maxBattingOvers ?? 2) * 6 : 99999;
      final isQuotaReached =
          match.customRulesEnabled &&
          !isWicket &&
          legalBallsFacedNow >= maxBatBalls;

      final isOverEnd =
          isLegalDelivery && newBalls == 0 && newOvers > currentScore.overs;

      // ── Build all updates locally (no reads needed) ──────────────────────
      final Map<String, dynamic> matchUpdates = {
        scoreKey: updatedScore.toMap(),
        'last_ball_id': ballId,
        'active_scorer_id': _auth.userId,
        'is_free_hit': nextIsFreeHit,
      };

      if (isOverEnd) matchUpdates['current_bowler_id'] = null;

      // Striker rotation
      if (!match.customRulesEnabled) {
        String? nextStriker = match.currentBatsmanId;
        String? nextNonStriker = match.currentNonStrikerId;

        if (isLegalDelivery && nextNonStriker != null) {
          final shouldRotate = (runs % 2 != 0);
          if (shouldRotate != isOverEnd) {
            nextStriker = match.currentNonStrikerId;
            nextNonStriker = match.currentBatsmanId;
          }
        }

        if (isWicket) {
          final targetPlayerId = dismissedPlayerId ?? batsman.id;
          if (nextStriker == targetPlayerId) nextStriker = null;
          if (nextNonStriker == targetPlayerId) nextNonStriker = null;

          if (match.lastPlayerCanPlay) {
            final battingTeamSize =
                match.currentInnings == 'A'
                    ? match.teamAPlayers.length
                    : match.teamBPlayers.length;
            if (battingTeamSize > 0 &&
                updatedScore.wickets == battingTeamSize - 1) {
              if (nextStriker == null && nextNonStriker != null) {
                nextStriker = nextNonStriker;
                nextNonStriker = null;
              }
            }
          }
        }

        matchUpdates['current_batsman_id'] = nextStriker;
        matchUpdates['current_non_striker_id'] = nextNonStriker;
      } else {
        if (isWicket || legalBallsFacedNow >= maxBatBalls) {
          matchUpdates['current_batsman_id'] = null;
          matchUpdates['current_non_striker_id'] = null;
        }
      }

      // ── Innings End Detection (local, no reads) ───────────────────────────
      bool isInningsEnded = false;
      final battingTeamId = match.currentInnings;
      final teamSize =
          battingTeamId == 'A'
              ? match.teamAPlayers.length
              : match.teamBPlayers.length;

      if (!match.customRulesEnabled && teamSize > 0) {
        final threshold = match.lastPlayerCanPlay ? teamSize : teamSize - 1;
        if (updatedScore.wickets >= threshold) isInningsEnded = true;
      }

      if (match.totalOvers > 0 && updatedScore.overs >= match.totalOvers) {
        isInningsEnded = true;
      }

      if (match.customRulesEnabled) {
        final matchController = Get.find<MatchController>();
        final allPlayers = matchController.players;
        final ids =
            battingTeamId == 'A' ? match.teamAPlayers : match.teamBPlayers;
        final maxBatBallsLimit = (match.maxBattingOvers ?? 2) * 6;
        bool hasEligible = false;
        for (final pid in ids) {
          final p = allPlayers[pid];
          if (p == null) continue;
          int legalNow = p.legalBallsFaced;
          bool isOutNow = p.isOut;
          if (p.id == batsman.id) {
            legalNow = legalBallsFacedNow;
            if (isWicket) isOutNow = true;
          } else if (isWicket && p.id == (dismissedPlayerId ?? batsman.id)) {
            isOutNow = true;
          }
          if (!isOutNow && legalNow < maxBatBallsLimit) {
            hasEligible = true;
            break;
          }
        }
        if (!hasEligible) isInningsEnded = true;
      }

      if (match.isSecondInnings) {
        final target = match.targetScore;
        if (target > 0 && updatedScore.runs >= target) isInningsEnded = true;
      }

      if (isInningsEnded) {
        if (!match.isSecondInnings) {
          firstInningsCompleted = true;
          toastMessage =
              '1st Innings Completed: ${match.teamAName} vs ${match.teamBName}';
          matchUpdates['is_innings_break'] = true;
          matchUpdates['current_batsman_id'] = null;
          matchUpdates['current_non_striker_id'] = null;
          matchUpdates['current_bowler_id'] = null;
          matchUpdates['is_free_hit'] = false;
        } else {
          final scoreA =
              match.currentInnings == 'A'
                  ? updatedScore.runs
                  : match.teamAScore.runs;
          final scoreB =
              match.currentInnings == 'B'
                  ? updatedScore.runs
                  : match.teamBScore.runs;

          String resultText = 'Match Tied';
          if (scoreA > scoreB) {
            resultText = '${match.teamAName} won by ${scoreA - scoreB} runs';
          } else if (scoreB > scoreA) {
            final wicketsDown = updatedScore.wickets;
            final wicketsRemaining =
                match.lastPlayerCanPlay
                    ? teamSize - wicketsDown
                    : (teamSize - 1) - wicketsDown;
            resultText = '${match.teamBName} won by $wicketsRemaining wickets';
          }

          matchUpdates['status'] = AppConstants.matchCompleted;
          matchUpdates['completed_at'] = Timestamp.now();
          matchUpdates['result'] = resultText;
          matchUpdates['current_batsman_id'] = null;
          matchUpdates['current_non_striker_id'] = null;
          matchUpdates['current_bowler_id'] = null;
          matchCompleted = true;
        }
      }

      // ── Single batch commit — one round-trip to Firestore ─────────────────
      final batch = _firestore.batch();

      batch.update(matchRef, matchUpdates);

      if (ballType != 'wide') {
        final isRunOffBat = ballType == 'normal' || ballType == 'no_ball';
        batch.update(batsmanRef, {
          'balls_faced': FieldValue.increment(1),
          if (isLegalDelivery) 'legal_balls_faced': FieldValue.increment(1),
          if (isRunOffBat) 'runs_scored': FieldValue.increment(runs),
          if (isRunOffBat && runs == 4) 'fours': FieldValue.increment(1),
          if (isRunOffBat && runs == 6) 'sixes': FieldValue.increment(1),
          if (isQuotaReached) 'is_out': true,
          if (isQuotaReached) 'dismissal_type': 'retired_out',
        });
      }

      if (isWicket) {
        final targetPlayerId = dismissedPlayerId ?? batsman.id;
        final targetRef = matchRef.collection('players').doc(targetPlayerId);
        final Map<String, dynamic> wicketUpdates = {
          'is_out': true,
          'dismissed_by': bowler.id,
          if (dismissalType != null) 'dismissal_type': dismissalType,
        };
        batch.update(targetRef, wicketUpdates);

        if (fielderId != null &&
            dismissalType != null &&
            dismissalType.toLowerCase().contains('caught')) {
          batch.update(matchRef.collection('players').doc(fielderId), {
            'catches': FieldValue.increment(1),
          });
        }
      }

      int bowlerRunsConceded = runIncrease;
      if (ballType == 'bye' || ballType == 'leg_bye') bowlerRunsConceded = 0;

      batch.update(bowlerRef, {
        'runs_conceded': FieldValue.increment(bowlerRunsConceded),
        if (isLegalDelivery) 'balls_bowled': FieldValue.increment(1),
        if (isWicket && dismissalType != 'run_out')
          'wickets_taken': FieldValue.increment(1),
      });

      batch.set(
        matchRef.collection(AppConstants.ballLogsCollection).doc(ballId),
        ballLog.toFirestore(),
      );

      await batch.commit();

      if (firstInningsCompleted) UIUtils.showSuccess(toastMessage);

      if (matchCompleted) {
        _saveManOfMatch(matchId);
        _pushMatchStatsToGlobal(matchId);
        final matchController = Get.find<MatchController>();
        final authController = Get.find<AuthController>();
        if (authController.userId != null) {
          matchController.loadMyMatches(authController.userId!, refresh: true);
        }
        matchController.loadCompletedMatches(refresh: true);
      }
    } catch (e) {
      UIUtils.showError('Error recording ball: $e');
    }
  }

  // ─── Push Match Stats to Global Collection ─────────────────────────────────
  Future<void> _pushMatchStatsToGlobal(String matchId) async {
    try {
      final matchDoc =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .get();
      if (!matchDoc.exists) return;

      final match = MatchModel.fromFirestore(matchDoc);
      final data = matchDoc.data() as Map<String, dynamic>;
      if (data['stats_updated'] == true) return;

      final playersSnap = await matchDoc.reference.collection('players').get();
      final batch = _firestore.batch();

      // Fetch existing users to check highest score (non-blocking if many, but usually small team)
      final List<String> playerIds = playersSnap.docs.map((d) => d.id).toList();
      final userSnaps = await Future.wait(
        playerIds.map(
          (id) =>
              _firestore.collection(AppConstants.usersCollection).doc(id).get(),
        ),
      );
      final Map<String, int> existingHS = {
        for (var snap in userSnaps)
          snap.id: (snap.data()?['highest_score'] ?? 0) as int,
      };

      for (final doc in playersSnap.docs) {
        final p = PlayerModel.fromMap(doc.data());
        final statsRef = _firestore
            .collection(AppConstants.playerStatsCollection)
            .doc(p.id);
        final userRef = _firestore
            .collection(AppConstants.usersCollection)
            .doc(p.id);

        // Calculate Win/Loss
        bool isWin = false;
        bool isLoss = false;
        if (match.result != null &&
            !match.result!.toLowerCase().contains('tied')) {
          final res = match.result!.toLowerCase();
          final myTeamName =
              (p.teamId == 'A' ? match.teamAName : match.teamBName)
                  .toLowerCase();
          if (res.contains(myTeamName)) {
            isWin = true;
          } else {
            isLoss = true;
          }
        }

        // Batting Best
        int currentBest = existingHS[p.id] ?? 0;
        int matchBest = p.runsScored;
        int finalHS = matchBest > currentBest ? matchBest : currentBest;

        // Overall Stats Map
        final Map<String, dynamic> s = {
          'matches': FieldValue.increment(1),
          'runs': FieldValue.increment(p.runsScored),
          'balls_faced': FieldValue.increment(p.ballsFaced),
          'wickets': FieldValue.increment(p.wicketsTaken),
          'fours': FieldValue.increment(p.fours),
          'sixes': FieldValue.increment(p.sixes),
          'runs_conceded': FieldValue.increment(p.runsConceded),
          'maidens': FieldValue.increment(p.maidens),
          'wide_balls': FieldValue.increment(p.widesBowled),
          'no_balls': FieldValue.increment(p.noBallsBowled),
          'wins': FieldValue.increment(isWin ? 1 : 0),
          'losses': FieldValue.increment(isLoss ? 1 : 0),
          'highest_score': finalHS,
        };

        if (p.ballsFaced > 0) {
          s['batting_innings'] = FieldValue.increment(1);
          if (!p.isOut) s['not_outs'] = FieldValue.increment(1);
          if (p.runsScored == 0 && p.isOut)
            s['ducks'] = FieldValue.increment(1);
          if (p.runsScored >= 100)
            s['hundreds'] = FieldValue.increment(1);
          else if (p.runsScored >= 50)
            s['fifties'] = FieldValue.increment(1);
          else if (p.runsScored >= 30)
            s['thirties'] = FieldValue.increment(1);
        }

        if (p.ballsBowled > 0 || p.oversBowled > 0) {
          s['bowling_innings'] = FieldValue.increment(1);
          // Store overs as whole + fractional balls (e.g. 2.3)
          final double overValue = p.oversBowled + (p.ballsBowled / 10.0);
          s['overs'] = FieldValue.increment(overValue);
          if (p.wicketsTaken >= 5)
            s['five_wkts'] = FieldValue.increment(1);
          else if (p.wicketsTaken >= 3)
            s['three_wkts'] = FieldValue.increment(1);

          // Update Best Bowling if current is better
          // This is tricky with FieldValue.increment, but we can't do it perfectly in a batch without reading.
          // For now, we update it in match stats sub-collection which is already done.
        }

        batch.set(statsRef, s, SetOptions(merge: true));

        // Update AppUser for quick lists
        batch.update(userRef, {
          'total_runs': FieldValue.increment(p.runsScored),
          'total_wickets': FieldValue.increment(p.wicketsTaken),
          'matches_played': FieldValue.increment(1),
          'highest_score': finalHS,
        });
      }

      batch.update(matchDoc.reference, {'stats_updated': true});
      await batch.commit();
    } catch (e) {
      debugPrint('Error updating global stats: $e');
    }
  }

  // ─── Man of the Match Calculation ──────────────────────────────────────────
  Future<void> _saveManOfMatch(String matchId) async {
    try {
      final matchRef = _firestore
          .collection(AppConstants.matchesCollection)
          .doc(matchId);

      // Fetch all players from the match sub-collection
      final playersSnap = await matchRef.collection('players').get();
      if (playersSnap.docs.isEmpty) return;

      String? bestPlayerId;
      String? bestPlayerName;
      int bestScore = -1;

      for (final doc in playersSnap.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unknown';
        final runs = (data['runs_scored'] ?? 0) as int;
        final wickets = (data['wickets_taken'] ?? 0) as int;
        final catches = (data['catches'] ?? 0) as int;

        final motmScore = (runs * 1) + (wickets * 20) + (catches * 10);
        if (motmScore > bestScore) {
          bestScore = motmScore;
          bestPlayerId = doc.id;
          bestPlayerName = name;
        }
      }

      if (bestPlayerId != null) {
        await matchRef.update({
          'man_of_match': bestPlayerId,
          'man_of_match_name': bestPlayerName,
        });
      }
    } catch (e) {
      // Non-critical — don't surface to user
    }
  }

  // Undo Last Ball (Transactional Reverse)
  // ─── Start Next Innings (Transactional) ─────────────
  Future<void> startNextInnings(MatchModel match) async {
    try {
      final nextInnings = match.currentInnings == 'A' ? 'B' : 'A';
      final batch = _firestore.batch();

      final matchRef = _firestore
          .collection(AppConstants.matchesCollection)
          .doc(match.id);

      batch.update(matchRef, {
        'current_innings': nextInnings,
        'is_innings_break': false,
        'current_batsman_id': null,
        'current_non_striker_id': null,
        'current_bowler_id': null,
      });

      await batch.commit();

      UIUtils.showSuccess('Second Innings Started! Team $nextInnings to bat.');
    } catch (e) {
      UIUtils.showError('Failed to start next innings: $e');
    }
  }

  Future<void> undoLastBall(MatchModel match) async {
    if (_matchId.value == null || _ballLogs.isEmpty) return;
    HapticFeedback.heavyImpact();

    final lastBall = _ballLogs.last;
    if (lastBall.scoredBy != _auth.userId &&
        !(_auth.currentUser?.isAdmin ?? false)) {
      UIUtils.showError(
        'You can only undo balls scored by yourself or as an admin.',
      );
      return;
    }

    // --- Innings Boundary Check ---
    if (match.currentInnings != lastBall.innings) {
      UIUtils.showError('Cannot undo balls from the previous innings.');
      return;
    }

    try {
      _isLoading.value = true;
      final matchRef = _firestore
          .collection(AppConstants.matchesCollection)
          .doc(_matchId.value);
      final batsmanRef = matchRef.collection('players').doc(lastBall.batsmanId);
      final bowlerRef = matchRef.collection('players').doc(lastBall.bowlerId);

      await _firestore.runTransaction((transaction) async {
        final scoreKey =
            lastBall.innings == 'A' ? 'team_a_score' : 'team_b_score';
        final freshMatch = MatchModel.fromFirestore(
          await transaction.get(matchRef),
        );
        final currentScore = freshMatch.currentScore;

        // Correct reversal logic to match recordBall logic:
        // Wide: runIncrease = wideExtra + runs, extraIncrease = wideExtra + runs
        // NoBall: runIncrease = noBallExtra + runs, extraIncrease = noBallExtra
        // Bye/LegBye: runIncrease = runs, extraIncrease = runs
        // Normal: runIncrease = runs, extraIncrease = 0

        int totalRunsToReverse = 0;
        if (lastBall.ballType == 'wide') {
          totalRunsToReverse = lastBall.extraRuns;
        } else if (lastBall.ballType == 'no_ball') {
          totalRunsToReverse = lastBall.runs + lastBall.extraRuns;
        } else if (lastBall.ballType == 'bye' ||
            lastBall.ballType == 'leg_bye') {
          totalRunsToReverse = lastBall.extraRuns;
        } else {
          totalRunsToReverse = lastBall.runs;
        }

        final rolledBackScore = currentScore.copyWith(
          runs: (currentScore.runs - totalRunsToReverse).clamp(0, 9999),
          wickets:
              lastBall.isWicket
                  ? (currentScore.wickets - 1).clamp(0, 20)
                  : currentScore.wickets,
          overs: lastBall.overNumber,
          balls: lastBall.ballNumber,
          extras: (currentScore.extras - lastBall.extraRuns).clamp(0, 999),
          wides:
              lastBall.ballType == 'wide'
                  ? (currentScore.wides - 1).clamp(0, 999)
                  : currentScore.wides,
          noBalls:
              lastBall.ballType == 'no_ball'
                  ? (currentScore.noBalls - 1).clamp(0, 999)
                  : currentScore.noBalls,
        );

        final Map<String, dynamic> matchUpdates = {
          scoreKey: rolledBackScore.toMap(),
          'is_free_hit': lastBall.isFreeHit,
          'last_ball_id':
              _ballLogs.length > 1 ? _ballLogs[_ballLogs.length - 2].id : null,
        };

        // If match was completed, bring it back to live
        if (freshMatch.status == AppConstants.matchCompleted) {
          matchUpdates['status'] = AppConstants.matchLive;
          matchUpdates['completed_at'] = null;
          matchUpdates['result'] = null;
        }

        // If it was innings break, remove it
        if (freshMatch.isInningsBreak) {
          matchUpdates['is_innings_break'] = false;
        }

        transaction.update(matchRef, matchUpdates);

        if (lastBall.ballType != 'wide') {
          transaction.update(batsmanRef, {
            'balls_faced': FieldValue.increment(-1),
            'runs_scored': FieldValue.increment(-lastBall.runs),
          });
        }

        if (lastBall.isWicket) {
          final targetPlayerId =
              lastBall.dismissedPlayerId ?? lastBall.batsmanId;
          final targetRef = matchRef.collection('players').doc(targetPlayerId);
          transaction.update(targetRef, {
            'is_out': false,
            'dismissed_by': null,
            'dismissal_type': null,
          });

          // Reverse fielder stats if applicable
          // Note: In current recordBall, catches are only incremented if dismissalType contains 'caught'
          if (lastBall.dismissalType != null &&
              lastBall.dismissalType!.toLowerCase().contains('caught')) {
            // We'd need fielderId from the log to reverse it perfectly.
            // BallLog currently doesn't store fielderId explicitly, but it might be in dismissal description?
            // Actually, let's check if we should add fielderId to BallLog.
          }
        }

        transaction.update(bowlerRef, {
          'runs_conceded': FieldValue.increment(
            -(lastBall.ballType == 'bye' || lastBall.ballType == 'leg_bye'
                ? 0
                : totalRunsToReverse),
          ),
          if (lastBall.ballType != 'wide' && lastBall.ballType != 'no_ball')
            'balls_bowled': FieldValue.increment(-1),
          if (lastBall.isWicket && lastBall.dismissalType != 'run_out')
            'wickets_taken': FieldValue.increment(-1),
        });

        // ── Restore exact state (Striker, Non-Striker, Bowler) ──
        transaction.update(matchRef, {
          'current_batsman_id': lastBall.batsmanId,
          'current_non_striker_id': lastBall.nonStrikerId,
          'current_bowler_id': lastBall.bowlerId,
        });

        transaction.delete(
          matchRef.collection(AppConstants.ballLogsCollection).doc(lastBall.id),
        );
      });

      _isLoading.value = false;
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error undoing ball: $e');
    }
  }

  // Player Selection
  Future<void> selectBatsman(
    String matchId,
    String playerId,
    bool isStriker,
  ) async {
    try {
      final field = isStriker ? 'current_batsman_id' : 'current_non_striker_id';
      await _firestore
          .collection(AppConstants.matchesCollection)
          .doc(matchId)
          .update({field: playerId});
    } catch (e) {
      _error.value = 'Failed to select batsman: $e';
    }
  }

  Future<void> selectBowler(String matchId, String playerId) async {
    try {
      await _firestore
          .collection(AppConstants.matchesCollection)
          .doc(matchId)
          .update({'current_bowler_id': playerId});
    } catch (e) {
      _error.value = 'Failed to select bowler: $e';
    }
  }

  void clear() {
    _ballLogsSub?.cancel();
    _matchId.value = null;
    _ballLogs.clear();
  }

  @override
  void onInit() {
    super.onInit();
    _rules = Get.find<RulesController>();
    _auth = Get.find<AuthController>();
  }

  @override
  void onClose() {
    _ballLogsSub?.cancel();
    super.onClose();
  }
}
