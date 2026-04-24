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

  // Record a Ball (Transactional)
  Future<void> recordBall({
    required MatchModel match,
    required PlayerModel batsman,
    required PlayerModel bowler,
    required int runs,
    required String ballType,
    bool isWicket = false,
    String? dismissalType,
    String? dismissedPlayerId,
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

    try {
      _isLoading.value = true;
      _error.value = null;

      if (_matchId.value == null) return;
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
        final ballsFaced = batsman.ballsFaced;
        final maxBatBalls = _rules.maxBattingOvers.value * 6;
        if (ballsFaced >= maxBatBalls) {
          UIUtils.showError(
            'Limit reached! ${batsman.name} has already faced 2 overs.',
          );
          return;
        }

        final totalBowlingBalls = (bowler.oversBowled * 6) + bowler.ballsBowled;
        final maxBowlBalls = _rules.maxBowlingOvers.value * 6;
        if (totalBowlingBalls >= maxBowlBalls) {
          UIUtils.showError(
            'Limit reached! ${bowler.name} has already bowled 3 overs.',
          );
          return;
        }
      }

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(matchRef);
        final freshMatch = MatchModel.fromFirestore(snapshot);

        if (freshMatch.lastBallId != match.lastBallId) {
          throw 'Conflict detected. Please reload.';
        }

        final currentScore = freshMatch.currentScore;
        final bool isLegalDelivery =
            ballType != 'wide' && ballType != 'no_ball';

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
          matchId: _matchId.value!,
          innings: freshMatch.currentInnings,
          overNumber: currentScore.overs,
          ballNumber: currentScore.balls,
          batsmanId: batsman.id,
          bowlerId: bowler.id,
          runs: runs,
          ballType: ballType,
          isWicket: isWicket,
          dismissalType: dismissalType,
          dismissedPlayerId: dismissedPlayerId,
          isFreeHit: freshMatch.isFreeHit,
          extraRuns: extraIncrease,
          scoredBy: _auth.userId,
        );

        final scoreKey =
            freshMatch.currentInnings == 'A' ? 'team_a_score' : 'team_b_score';
        final updatedScore = currentScore.copyWith(
          runs: currentScore.runs + runIncrease,
          wickets: isWicket ? currentScore.wickets + 1 : currentScore.wickets,
          overs: newOvers,
          balls: newBalls,
          extras: currentScore.extras + extraIncrease,
          wides:
              ballType == 'wide' ? currentScore.wides + 1 : currentScore.wides,
          noBalls:
              ballType == 'no_ball'
                  ? currentScore.noBalls + 1
                  : currentScore.noBalls,
        );

        transaction.update(matchRef, {
          scoreKey: updatedScore.toMap(),
          'last_ball_id': ballId,
          'active_scorer_id': _auth.userId,
          'is_free_hit': nextIsFreeHit,
        });

        final currentBallsFaced =
            batsman.ballsFaced + (ballType != 'wide' ? 1 : 0);
        final maxBatBalls =
            match.customRulesEnabled ? _rules.maxBattingOvers.value * 6 : 99999;
        final isQuotaReached =
            match.customRulesEnabled &&
            !isWicket &&
            currentBallsFaced >= maxBatBalls;

        if (ballType != 'wide') {
          final isRunOffBat = ballType == 'normal' || ballType == 'no_ball';
          transaction.update(batsmanRef, {
            'balls_faced': FieldValue.increment(1),
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
          };

          if (dismissalType != null) {
            wicketUpdates['dismissal_type'] = dismissalType;
          }

          transaction.update(targetRef, wicketUpdates);
        }

        int bowlerRunsConceded = runIncrease;
        if (ballType == 'bye' || ballType == 'leg_bye') {
          bowlerRunsConceded =
              0; // Byes and leg byes do not count against the bowler
        }

        transaction.update(bowlerRef, {
          'runs_conceded': FieldValue.increment(bowlerRunsConceded),
          if (isLegalDelivery) 'balls_bowled': FieldValue.increment(1),
          if (isWicket && dismissalType != 'run_out')
            'wickets_taken': FieldValue.increment(1),
        });

        final isOverEnd =
            isLegalDelivery && newBalls == 0 && newOvers > currentScore.overs;

        if (isOverEnd) {
          transaction.update(matchRef, {'current_bowler_id': null});
        }

        if (!match.customRulesEnabled) {
          if (isLegalDelivery && freshMatch.currentNonStrikerId != null) {
            final shouldRotate = (runs % 2 != 0);
            if (shouldRotate != isOverEnd) {
              transaction.update(matchRef, {
                'current_batsman_id': freshMatch.currentNonStrikerId,
                'current_non_striker_id': freshMatch.currentBatsmanId,
              });
            }
          }
        } else {
          if (isWicket || currentBallsFaced >= maxBatBalls) {
            transaction.update(matchRef, {
              'current_batsman_id': null,
              'current_non_striker_id': null,
            });
          }
        }

        // --- INNINGS END DETECTION (Inside Transaction) ---
        bool isInningsEnded = false;
        final battingTeamId = freshMatch.currentInnings;
        final teamSize =
            battingTeamId == 'A'
                ? freshMatch.teamAPlayers.length
                : freshMatch.teamBPlayers.length;

        // 1. Wicket-based end (Normal Rules)
        if (!freshMatch.customRulesEnabled && teamSize > 0) {
          final threshold =
              freshMatch.lastPlayerCanPlay ? teamSize : teamSize - 1;
          if (updatedScore.wickets >= threshold) {
            isInningsEnded = true;
          }
        }

        // 2. Overs-based end
        if (freshMatch.totalOvers > 0 &&
            updatedScore.overs >= freshMatch.totalOvers) {
          isInningsEnded = true;
        }

        // 3. Custom Rules end (No eligible batsmen)
        if (freshMatch.customRulesEnabled) {
          final maxBatBalls = _rules.maxBattingOvers.value * 6;
          final battingPlayerIds =
              battingTeamId == 'A'
                  ? freshMatch.teamAPlayers
                  : freshMatch.teamBPlayers;

          bool hasEligibleBatsman = false;
          for (var pid in battingPlayerIds) {
            final pRef = matchRef.collection('players').doc(pid);
            final pSnap = await transaction.get(pRef);
            if (pSnap.exists) {
              final p = PlayerModel.fromMap(pSnap.data()!);

              // We must account for the current ball if this player IS the batsman
              int ballsFacedNow = p.ballsFaced;
              bool isOutNow = p.isOut;

              if (p.id == batsman.id) {
                ballsFacedNow = currentBallsFaced;
                if (isWicket) isOutNow = true;
              } else if (isWicket &&
                  p.id == (dismissedPlayerId ?? batsman.id)) {
                isOutNow = true;
              }

              if (!isOutNow && ballsFacedNow < maxBatBalls) {
                hasEligibleBatsman = true;
                break;
              }
            }
          }
          if (!hasEligibleBatsman) {
            isInningsEnded = true;
          }
        }

        // 4. Target chased logic (2nd innings)
        final initialBattingTeam =
            freshMatch.tossWonBy == 'A'
                ? (freshMatch.tossDecision == 'bat' ? 'A' : 'B')
                : (freshMatch.tossDecision == 'bat' ? 'B' : 'A');
        final isSecondInnings = freshMatch.currentInnings != initialBattingTeam;

        if (isSecondInnings) {
          final firstScore =
              freshMatch.currentInnings == 'A'
                  ? freshMatch.teamBScore
                  : freshMatch.teamAScore;

          if (firstScore.runs > 0) {
            // Ensure there is a target to chase
            int target = firstScore.runs + 1;
            if (updatedScore.runs >= target) {
              isInningsEnded = true;
            }
          }
        }

        if (isInningsEnded) {
          if (!isSecondInnings) {
            // End of First Innings -> Enter Break
            transaction.update(matchRef, {
              'is_innings_break': true,
              'current_batsman_id': null,
              'current_non_striker_id': null,
              'current_bowler_id': null,
              'is_free_hit': false,
            });
          } else {
            // End of Match -> Complete
            final scoreA =
                freshMatch.currentInnings == 'A'
                    ? updatedScore.runs
                    : freshMatch.teamAScore.runs;
            final scoreB =
                freshMatch.currentInnings == 'B'
                    ? updatedScore.runs
                    : freshMatch.teamBScore.runs;

            String resultText = 'Match Tied';
            if (scoreA > scoreB) {
              resultText =
                  '${freshMatch.teamAName} won by ${scoreA - scoreB} runs';
            } else if (scoreB > scoreA) {
              final battingSecond = freshMatch.currentInnings;
              final wicketsDown = updatedScore.wickets;
              final wicketsRemaining =
                  freshMatch.lastPlayerCanPlay
                      ? teamSize - wicketsDown
                      : (teamSize - 1) - wicketsDown;

              resultText =
                  '${freshMatch.teamBName} won by $wicketsRemaining wickets';
            }

            transaction.update(matchRef, {
              'status': AppConstants.matchCompleted,
              'completed_at': Timestamp.now(),
              'result': resultText,
              'current_batsman_id': null,
              'current_non_striker_id': null,
              'current_bowler_id': null,
            });
          }
        }

        transaction.set(
          matchRef.collection(AppConstants.ballLogsCollection).doc(ballId),
          ballLog.toFirestore(),
        );
      });

      _isLoading.value = false;
      // Show localized success message after transaction
      // Note: We can't easily know if isInningsEnded was true inside here
      // without extra state, but the UI will update anyway.
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error recording ball: $e');
    }
  }

  // Undo Last Ball (Transactional Reverse)
  Future<void> startNextInnings(MatchModel match) async {
    try {
      final nextInnings = match.currentInnings == 'A' ? 'B' : 'A';
      await _firestore.collection('matches').doc(match.id).update({
        'current_innings': nextInnings,
        'is_innings_break': false,
      });
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

        final totalRunsToReverse =
            (lastBall.ballType == 'wide'
                ? (lastBall.runs + lastBall.extraRuns)
                : (lastBall.runs + lastBall.extraRuns));

        final rolledBackScore = currentScore.copyWith(
          runs: currentScore.runs - totalRunsToReverse,
          wickets:
              lastBall.isWicket
                  ? currentScore.wickets - 1
                  : currentScore.wickets,
          overs: lastBall.overNumber,
          balls: lastBall.ballNumber,
          extras: currentScore.extras - lastBall.extraRuns,
          wides:
              lastBall.ballType == 'wide'
                  ? currentScore.wides - 1
                  : currentScore.wides,
          noBalls:
              lastBall.ballType == 'no_ball'
                  ? currentScore.noBalls - 1
                  : currentScore.noBalls,
        );

        transaction.update(matchRef, {
          scoreKey: rolledBackScore.toMap(),
          'is_free_hit': lastBall.isFreeHit,
          'last_ball_id':
              _ballLogs.length > 1 ? _ballLogs[_ballLogs.length - 2].id : null,
        });

        if (lastBall.ballType != 'wide') {
          transaction.update(batsmanRef, {
            'balls_faced': FieldValue.increment(-1),
            'runs_scored': FieldValue.increment(-lastBall.runs),
            if (lastBall.isWicket) 'is_out': false,
          });
        }
        transaction.update(bowlerRef, {
          'runs_conceded': FieldValue.increment(-totalRunsToReverse),
          if (lastBall.ballType != 'wide' && lastBall.ballType != 'no_ball')
            'balls_bowled': FieldValue.increment(-1),
          if (lastBall.isWicket) 'wickets_taken': FieldValue.increment(-1),
        });

        // ── Restore bowler if it was set to null (at over end or innings break) ──
        if (freshMatch.currentBowlerId == null) {
          transaction.update(matchRef, {
            'current_bowler_id': lastBall.bowlerId,
          });
        }

        transaction.delete(
          matchRef.collection(AppConstants.ballLogsCollection).doc(lastBall.id),
        );
      });

      _isLoading.value = false;
      // UIUtils.showSuccess('Last ball removed successfully.');
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
