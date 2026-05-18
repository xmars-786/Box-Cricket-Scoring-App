import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/match_model.dart';
import '../models/player_model.dart';
import '../models/ball_log_model.dart';
import '../models/partnership_model.dart';
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
  final RxBool lastBallShown = false.obs;

  StreamSubscription? _ballLogsSub;

  // Getters
  List<BallLog> get ballLogs => _ballLogs;
  List<BallLog> get currentOverBalls => _currentOverBalls;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;

  bool isOverFinished(int matchBallsPerOver) {
    if (_currentOverBalls.isEmpty) return false;
    final legalBalls =
        _currentOverBalls
            .where((b) => b.ballType == 'normal' || b.ballType == 'wicket')
            .length;
    return legalBalls >= matchBallsPerOver ||
        (legalBalls == 0 &&
            _currentOverBalls.isNotEmpty &&
            _currentOverBalls.any(
              (b) => b.ballNumber == 0 && _currentOverBalls.length > 1,
            ));
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
        .limit(500) // fetch more to cover full match (up to 80+ overs)
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
    String? newIncomingBatsmanId,
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
      final maxBatBalls = (match.maxBattingOvers ?? 2) * match.ballsPerOver;
      if (legalBallsFaced >= maxBatBalls) {
        UIUtils.showError(
          'Limit reached! ${batsman.name} has already faced ${match.maxBattingOvers ?? 2} overs.',
        );
        return;
      }

      final totalBowlingBalls =
          (bowler.oversBowled * match.ballsPerOver) + bowler.ballsBowled;
      final maxBowlBalls = (match.maxBowlingOvers ?? 3) * match.ballsPerOver;
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
    String? resultText;
    final String matchId = _matchId.value!;

    try {
      final batch = _firestore.batch();
      final currentScore = match.currentScore;
      final bool isLegalDelivery = ballType != 'wide' && ballType != 'no_ball';

      final wideExtra = _rules.wideRuns.value;
      final noBallExtra = _rules.noBallRuns.value;

      int runIncrease = 0;
      int extraIncrease = 0;
      bool nextIsFreeHit = false;

      // Partnership logic initialization
      PartnershipModel currentPartnership =
          match.activePartnership ??
          PartnershipModel(
            batterAId: match.currentBatsmanId ?? '',
            batterBId: match.currentNonStrikerId ?? '',
            batterAName: batsman.name,
            batterBName:
                match.currentNonStrikerId != null
                    ? (Get.find<MatchController>()
                            .players[match.currentNonStrikerId]
                            ?.name ??
                        'Non-Striker')
                    : 'Non-Striker',
            wicketNumber: match.currentScore.wickets + 1,
          );

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

      // Update Partnership Data
      bool isStrikerA = currentPartnership.batterAId == batsman.id;
      int pRunsA = currentPartnership.batterARuns;
      int pBallsA = currentPartnership.batterABalls;
      int pRunsB = currentPartnership.batterBRuns;
      int pBallsB = currentPartnership.batterBBalls;

      if (isStrikerA) {
        if (ballType == 'normal' || ballType == 'no_ball') {
          pRunsA += runs;
        }
        if (isLegalDelivery) {
          pBallsA += 1;
        }
      } else {
        if (ballType == 'normal' || ballType == 'no_ball') {
          pRunsB += runs;
        }
        if (isLegalDelivery) {
          pBallsB += 1;
        }
      }

      currentPartnership = currentPartnership.copyWith(
        batterARuns: pRunsA,
        batterABalls: pBallsA,
        batterBRuns: pRunsB,
        batterBBalls: pBallsB,
        totalRuns: currentPartnership.totalRuns + runIncrease,
        totalBalls: currentPartnership.totalBalls + (isLegalDelivery ? 1 : 0),
        extras: currentPartnership.extras + extraIncrease,
      );

      int newBalls = currentScore.balls;
      int newOvers = currentScore.overs;
      if (isLegalDelivery) {
        newBalls++;
        if (newBalls >= match.ballsPerOver) {
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
        fielderId: fielderId,
        isFour: (ballType == 'normal' || ballType == 'no_ball') && runs == 4,
        isSix: (ballType == 'normal' || ballType == 'no_ball') && runs == 6,
        isBye: ballType == 'bye',
        isLegBye: ballType == 'leg_bye',
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
          match.customRulesEnabled
              ? (match.maxBattingOvers ?? 2) * match.ballsPerOver
              : 99999;
      final isQuotaReached =
          match.customRulesEnabled &&
          !isWicket &&
          legalBallsFacedNow >= maxBatBalls;

      final isOverEnd =
          isLegalDelivery && newBalls == 0 && newOvers > currentScore.overs;

      if (isOverEnd) {
        lastBallShown.value = false;
      } else if (isLegalDelivery && newBalls == match.ballsPerOver - 1 && !lastBallShown.value) {
        lastBallShown.value = true;
      }

      // ── Build all updates locally (no reads needed) ──────────────────────
      final Map<String, dynamic> matchUpdates = {
        scoreKey: updatedScore.toMap(),
        'last_ball_id': ballId,
        'active_scorer_id': _auth.userId,
        'is_free_hit': nextIsFreeHit,
        'active_partnership': currentPartnership.toMap(),
      };

      // ── Update Batting & Bowling Order ──
      final currentInnings = match.currentInnings;
      final battingOrderKey =
          currentInnings == 'A'
              ? 'team_a_batting_order'
              : 'team_b_batting_order';
      final bowlingOrderKey =
          currentInnings == 'A'
              ? 'team_b_bowling_order' // If A is batting, B is bowling
              : 'team_a_bowling_order';

      final List<String> currentBattingOrder = List<String>.from(
        currentInnings == 'A'
            ? match.teamABattingOrder
            : match.teamBBattingOrder,
      );
      final List<String> currentBowlingOrder = List<String>.from(
        currentInnings == 'A'
            ? match.teamBBowlingOrder
            : match.teamABowlingOrder,
      );

      bool orderChanged = false;
      if (!currentBattingOrder.contains(batsman.id)) {
        currentBattingOrder.add(batsman.id);
        orderChanged = true;
      }
      if (match.currentNonStrikerId != null &&
          !currentBattingOrder.contains(match.currentNonStrikerId!)) {
        // If non-striker is not in list, they usually came in with the striker
        // or just before/after. Adding them here ensures they are tracked.
        currentBattingOrder.add(match.currentNonStrikerId!);
        orderChanged = true;
      }
      if (orderChanged) {
        matchUpdates[battingOrderKey] = currentBattingOrder;
      }

      if (!currentBowlingOrder.contains(bowler.id)) {
        currentBowlingOrder.add(bowler.id);
        matchUpdates[bowlingOrderKey] = currentBowlingOrder;
      }

      if (isOverEnd) matchUpdates['current_bowler_id'] = null;

      // Striker rotation & Last Player logic
      String? nextStriker = match.currentBatsmanId;
      String? nextNonStriker = match.currentNonStrikerId;

      if (!match.customRulesEnabled) {
        if (isLegalDelivery && nextNonStriker != null) {
          final shouldRotate = (runs % 2 != 0);
          if (shouldRotate != isOverEnd) {
            nextStriker = match.currentNonStrikerId;
            nextNonStriker = match.currentBatsmanId;
          }
        }

        if (isWicket) {
          final targetPlayerId = dismissedPlayerId ?? batsman.id;
          if (nextStriker == targetPlayerId) {
            nextStriker = newIncomingBatsmanId;
          } else if (nextNonStriker == targetPlayerId) {
            nextNonStriker = newIncomingBatsmanId;
          }
        }
      } else {
        // Custom rules (Box Cricket style)
        if (isWicket || legalBallsFacedNow >= maxBatBalls) {
          nextStriker = newIncomingBatsmanId;
          // Non-striker remains or is null if no one else
        }
      }

      final teamSize =
          match.currentInnings == 'A'
              ? match.teamAPlayers.length
              : match.teamBPlayers.length;

      print("DEBUG: ScoringController - isWicket: $isWicket");
      print(
        "DEBUG: ScoringController - lastPlayerCanPlay: ${match.lastPlayerCanPlay}",
      );
      print(
        "DEBUG: ScoringController - Wickets: ${updatedScore.wickets} / TeamSize: $teamSize",
      );

      // Final pass for "Last Player Can Play"
      if (match.lastPlayerCanPlay && teamSize > 0) {
        final currentWickets = updatedScore.wickets;
        // If we reach the point where only one player should be on field
        if (currentWickets == teamSize - 1) {
          print("DEBUG: ScoringController - Entering Last Player Mode logic");
          // Identify the surviving player
          String? survivorId;
          if (isWicket) {
            final outId = dismissedPlayerId ?? batsman.id;
            survivorId =
                (outId == match.currentBatsmanId)
                    ? match.currentNonStrikerId
                    : match.currentBatsmanId;
            print(
              "DEBUG: ScoringController - Wicket fell, survivor identified: $survivorId",
            );
          } else {
            // Already in last player mode
            survivorId = nextStriker ?? nextNonStriker;
            print(
              "DEBUG: ScoringController - Already in last player mode, survivor: $survivorId",
            );
          }

          if (survivorId != null) {
            nextStriker = survivorId;
            nextNonStriker = null;
          }
        }
      }

      matchUpdates['current_batsman_id'] = nextStriker;
      matchUpdates['current_non_striker_id'] = nextNonStriker;

      // Handle Partnership Closing on Wicket
      if (isWicket) {
        final completedPartnership = currentPartnership.copyWith(
          isOngoing: false,
        );
        final listKey =
            match.currentInnings == 'A'
                ? 'team_a_partnerships'
                : 'team_b_partnerships';

        final updatedPartnerships =
            match.currentInnings == 'A'
                ? List<PartnershipModel>.from(match.teamAPartnerships)
                : List<PartnershipModel>.from(match.teamBPartnerships);

        updatedPartnerships.add(completedPartnership);
        matchUpdates[listKey] =
            updatedPartnerships.map((e) => e.toMap()).toList();

        // Start new partnership
        if (newIncomingBatsmanId != null) {
          final matchController = Get.find<MatchController>();
          final survivingBatterId =
              (dismissedPlayerId ?? batsman.id) == match.currentBatsmanId
                  ? match.currentNonStrikerId
                  : match.currentBatsmanId;

          final survivingBatterName =
              survivingBatterId != null
                  ? (matchController.players[survivingBatterId]?.name ??
                      'Batter')
                  : 'Batter';
          final newBatterName =
              matchController.players[newIncomingBatsmanId]?.name ??
              'Incoming Batter';

          final newPartnership = PartnershipModel(
            batterAId: survivingBatterId ?? '',
            batterBId: newIncomingBatsmanId,
            batterAName: survivingBatterName,
            batterBName: newBatterName,
            wicketNumber: updatedScore.wickets + 1,
          );
          matchUpdates['active_partnership'] = newPartnership.toMap();
        } else {
          matchUpdates['active_partnership'] = null;
        }
      }

      // ── Innings End Detection ───────────────────────────────────────────
      bool isInningsEnded = false;
      final battingTeamId = match.currentInnings;

      // Check overs first
      if (match.totalOvers > 0 && updatedScore.overs >= match.totalOvers) {
        isInningsEnded = true;
      }

      if (teamSize > 0) {
        final matchController = Get.find<MatchController>();
        final allPlayers = matchController.players;
        final ids =
            battingTeamId == 'A' ? match.teamAPlayers : match.teamBPlayers;
        final maxBatBallsLimit =
            match.customRulesEnabled
                ? (match.maxBattingOvers ?? 2) * match.ballsPerOver
                : 999999;

        int eligibleCount = 0;
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
            eligibleCount++;
          }
        }

        // ──────── INNINGS END OVERRIDE (Critical Fix) ────────
        final minPlayersRequired = match.lastPlayerCanPlay ? 1 : 2;

        print(
          "DEBUG: SC - Wickets: ${updatedScore.wickets}, TeamSize: $teamSize, Eligible: $eligibleCount, MinReq: $minPlayersRequired",
        );

        if (eligibleCount < minPlayersRequired) {
          if (match.lastPlayerCanPlay && eligibleCount == 1) {
            print(
              "DEBUG: SC - BLOCKING INNINGS END (Last Player Can Play is TRUE)",
            );
            isInningsEnded = false;
          } else {
            print("DEBUG: SC - Ending Innings (All Out)");
            isInningsEnded = true;
          }
        }
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
          matchUpdates['current_bowler_id'] = null;
          matchUpdates['is_free_hit'] = false;

          // Close active partnership on innings end
          if (match.activePartnership != null) {
            final completedPartnership = currentPartnership.copyWith(
              isOngoing: false,
            );
            final updatedPartnerships = List<PartnershipModel>.from(
              match.teamAPartnerships,
            );
            updatedPartnerships.add(completedPartnership);
            matchUpdates['team_a_partnerships'] =
                updatedPartnerships.map((e) => e.toMap()).toList();
            matchUpdates['active_partnership'] = null;
          }
        } else {
          // ─── Correct Match Result Calculation ──────────────────────────
          final initialBattingTeamId = match.initialBattingTeam; // Team 1 (Defending)
          final chasingTeamId = initialBattingTeamId == 'A' ? 'B' : 'A'; // Team 2 (Chasing)

          final score1 = initialBattingTeamId == 'A' ? match.teamAScore.runs : match.teamBScore.runs;
          final score2 = updatedScore.runs; // Score of the team currently batting (Chasing team)

          final team1Name = initialBattingTeamId == 'A' ? match.teamAName : match.teamBName;
          final team2Name = initialBattingTeamId == 'A' ? match.teamBName : match.teamAName;
          
          final team1FullId = initialBattingTeamId == 'A' ? match.teamAId : match.teamBId;
          final team2FullId = initialBattingTeamId == 'A' ? match.teamBId : match.teamAId;

          String? winnerId;
          if (score2 > score1) {
            // Case 1: Team 2 wins (Chasing team wins)
            final wicketsLost = updatedScore.wickets;
            // Standard rule: (totalPlayers - 1) - wicketsLost
            // Last player rule: totalPlayers - wicketsLost
            int remainingWickets = (teamSize - 1) - wicketsLost;
            if (match.lastPlayerCanPlay) {
              remainingWickets = teamSize - wicketsLost;
            }
            
            resultText = '$team2Name won by $remainingWickets wickets';
            winnerId = team2FullId;

            print("DEBUG: Match Result - Chasing Team Wins");
            print("Defending ($team1Name): $score1, Chasing ($team2Name): $score2");
            print("Wickets Lost: $wicketsLost, Remaining: $remainingWickets");
          } else if (score1 > score2) {
            // Case 2: Team 1 wins (Defending team wins)
            resultText = '$team1Name won by ${score1 - score2} runs';
            winnerId = team1FullId;

            print("DEBUG: Match Result - Defending Team Wins");
            print("Defending ($team1Name): $score1, Chasing ($team2Name): $score2");
            print("Difference: ${score1 - score2} runs");
          } else {
            // Case 3: Tie
            resultText = 'Match Tied';
            winnerId = null;

            print("DEBUG: Match Result - Tie");
            print("Final Scores: $score1 - $score2");
          }

          matchUpdates['status'] = AppConstants.matchCompleted;
          matchUpdates['completed_at'] = Timestamp.now();
          matchUpdates['result'] = resultText;
          if (winnerId != null) {
            matchUpdates['winner_id'] = winnerId;
          }
          matchUpdates['current_batsman_id'] = null;
          matchUpdates['current_non_striker_id'] = null;
          matchUpdates['current_bowler_id'] = null;
          matchCompleted = true;

          // Close active partnership on match end
          if (match.activePartnership != null) {
            final completedPartnership = currentPartnership.copyWith(
              isOngoing: false,
            );
            final updatedPartnerships = List<PartnershipModel>.from(
              match.teamBPartnerships,
            );
            updatedPartnerships.add(completedPartnership);
            matchUpdates['team_b_partnerships'] =
                updatedPartnerships.map((e) => e.toMap()).toList();
            matchUpdates['active_partnership'] = null;
          }

          // Handle Knockout Progression
          if (match.nextMatchId != null && winnerId != null) {
            final nextMatchRef = _firestore
                .collection(AppConstants.matchesCollection)
                .doc(match.nextMatchId);
            final winnerName =
                winnerId == match.teamAId ? match.teamAName : match.teamBName;

            // Advance winner to Team A or Team B based on matchNumber
            if (match.matchNumber == 1) {
              batch.update(nextMatchRef, {
                'team_a_id': winnerId,
                'team_a_name': winnerName,
              });
            } else if (match.matchNumber == 2) {
              batch.update(nextMatchRef, {
                'team_b_id': winnerId,
                'team_b_name': winnerName,
              });
            }
          }
        }
      }

      // ── Single batch commit — one round-trip to Firestore ─────────────────
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
        if (isLegalDelivery && runIncrease == 0)
          'dot_balls': FieldValue.increment(1),
        if (ballType == 'wide') 'wides_bowled': FieldValue.increment(1),
        if (ballType == 'no_ball') 'no_balls_bowled': FieldValue.increment(1),
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
        // Calculate MOTM
        await saveManOfMatch(match.id, resultText ?? '');
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

        final isTournament = match.tournamentId != null;
        final prefix = isTournament ? 'tournament_' : 'single_';

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
          // Contextual Stats
          '${prefix}matches': FieldValue.increment(1),
          '${prefix}runs': FieldValue.increment(p.runsScored),
          '${prefix}wickets': FieldValue.increment(p.wicketsTaken),
          '${prefix}highest_score': finalHS,
        };

        // MOTM Award
        if (match.manOfMatch == p.id) {
          s['man_of_match_awards'] = FieldValue.increment(1);
        }

        if (p.ballsFaced > 0) {
          s['batting_innings'] = FieldValue.increment(1);
          s['${prefix}batting_innings'] = FieldValue.increment(1);
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
          s['${prefix}bowling_innings'] = FieldValue.increment(1);
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
  Future<void> saveManOfMatch(String matchId, String result) async {
    try {
      final matchRef = _firestore
          .collection(AppConstants.matchesCollection)
          .doc(matchId);
      final matchDoc = await matchRef.get();
      if (!matchDoc.exists) return;
      final match = MatchModel.fromFirestore(matchDoc);

      final playersSnap = await matchRef.collection('players').get();
      if (playersSnap.docs.isEmpty) return;

      String? bestPlayerId;
      String? bestPlayerName;
      Map<String, dynamic>? bestPlayerData;
      double bestScore = -1;

      // Identify winning team
      String winningTeam = '';
      if (result.toLowerCase().contains(match.teamAName.toLowerCase())) {
        winningTeam = 'A';
      } else if (result.toLowerCase().contains(match.teamBName.toLowerCase())) {
        winningTeam = 'B';
      }

      for (final doc in playersSnap.docs) {
        final data = doc.data();
        final teamId = data['team_id'] as String? ?? '';
        
        // STRICT FIX: Skip players not from the winning team (unless it's a tie)
        if (winningTeam.isNotEmpty && teamId != winningTeam) {
          continue; 
        }

        final name = data['name'] as String? ?? 'Unknown';
        final runs = (data['runs_scored'] ?? 0) as int;
        final ballsFaced = (data['balls_faced'] ?? 0) as int;
        final wickets = (data['wickets_taken'] ?? 0) as int;
        final catches = (data['catches'] ?? 0) as int;
        final maidens = (data['maidens_bowled'] ?? 0) as int;
        final runsConceded = (data['runs_conceded'] ?? 0) as int;
        final oversBowled = (data['overs_bowled'] ?? 0).toDouble();

        double motmScore =
            (runs * 1.0) +
            (wickets * 20.0) +
            (catches * 10.0) +
            (maidens * 15.0);

        // Economy Bonus
        if (oversBowled >= 1.0) {
          double econ = runsConceded / oversBowled;
          if (econ < 6.0) motmScore += 10;
        }

        // Strike Rate Bonus
        if (ballsFaced >= 10) {
          double sr = (runs * 100.0) / ballsFaced;
          if (sr > 150.0) motmScore += 10;
        }

        // Winning Team Bonus
        if (winningTeam.isNotEmpty && teamId == winningTeam) {
          motmScore += 10;
        }

        if (motmScore > bestScore) {
          bestScore = motmScore;
          bestPlayerId = doc.id;
          bestPlayerName = name;
          bestPlayerData = data;
        }
      }

      if (bestPlayerId != null && bestPlayerData != null) {
        final teamId = bestPlayerData['team_id'] ?? '';
        final teamName = teamId == 'A' ? match.teamAName : match.teamBName;

        await matchRef.update({
          'man_of_match': bestPlayerId,
          'man_of_match_name': bestPlayerName,
          'man_of_the_match_map': {
            'id': bestPlayerId,
            'name': bestPlayerName,
            'image':
                bestPlayerData['profile_image_url'] ?? bestPlayerData['image'],
            'team': teamName,
          },
        });
      }
    } catch (e) {
      debugPrint('Error saving MOTM: $e');
    }
  }

  /// Manually set Man of the Match and adjust player stats if match is already finalized.
  Future<void> setManualManOfMatch({
    required String matchId,
    required String playerId,
    required String playerName,
  }) async {
    try {
      final matchRef = _firestore
          .collection(AppConstants.matchesCollection)
          .doc(matchId);
      final matchDoc = await matchRef.get();
      if (!matchDoc.exists) return;

      final match = MatchModel.fromFirestore(matchDoc);
      final oldMotmId = match.manOfMatch;

      // 1. Fetch player details for the map
      final playerDoc =
          await matchRef.collection('players').doc(playerId).get();
      final pData = playerDoc.data() ?? {};
      final teamId = pData['team_id'] ?? '';
      final teamName = teamId == 'A' ? match.teamAName : match.teamBName;

      // VALIDATION: Ensure player is from winning team
      String winningTeamId = '';
      if (match.result != null) {
        if (match.result!.toLowerCase().contains(match.teamAName.toLowerCase())) {
          winningTeamId = 'A';
        } else if (match.result!.toLowerCase().contains(match.teamBName.toLowerCase())) {
          winningTeamId = 'B';
        }
      }

      if (winningTeamId.isNotEmpty && teamId != winningTeamId) {
        UIUtils.showError('Select player from winning team only');
        return;
      }

      // 2. Update Match Document
      await matchRef.update({
        'man_of_match': playerId,
        'man_of_match_name': playerName,
        'man_of_the_match_map': {
          'id': playerId,
          'name': playerName,
          'image': pData['profile_image_url'] ?? pData['image'],
          'team': teamName,
        },
      });

      // 2. If match is already finalized, we need to adjust player_stats
      if (matchDoc.data()?['stats_updated'] == true) {
        final batch = _firestore.batch();

        // Decrement old MOTM count
        if (oldMotmId != null && oldMotmId != playerId) {
          batch.update(
            _firestore
                .collection(AppConstants.playerStatsCollection)
                .doc(oldMotmId),
            {'man_of_match_awards': FieldValue.increment(-1)},
          );
        }

        // Increment new MOTM count
        if (oldMotmId != playerId) {
          batch.update(
            _firestore
                .collection(AppConstants.playerStatsCollection)
                .doc(playerId),
            {'man_of_match_awards': FieldValue.increment(1)},
          );
        }

        await batch.commit();
      }

      // Refresh local state if needed (usually handled by stream)
    } catch (e) {
      UIUtils.showError('Failed to update Man of the Match: $e');
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
        final matchDoc = await transaction.get(matchRef);
        final freshMatch = MatchModel.fromFirestore(matchDoc);
        final currentScore = freshMatch.currentScore;

        // Fetch player docs to ensure we don't go below zero
        final batsmanSnap = await transaction.get(batsmanRef);
        final bowlerSnap = await transaction.get(bowlerRef);

        DocumentSnapshot? fielderSnap;
        if (lastBall.fielderId != null) {
          final fielderRef = matchRef
              .collection('players')
              .doc(lastBall.fielderId);
          fielderSnap = await transaction.get(fielderRef);
        }

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

        if (freshMatch.status == AppConstants.matchCompleted) {
          matchUpdates['status'] = AppConstants.matchLive;
          matchUpdates['completed_at'] = null;
          matchUpdates['result'] = null;
        }

        if (freshMatch.isInningsBreak) {
          matchUpdates['is_innings_break'] = false;
        }

        transaction.update(matchRef, matchUpdates);

        // --- Reversing Batsman Stats ---
        if (lastBall.ballType != 'wide' && batsmanSnap.exists) {
          final data = batsmanSnap.data() as Map<String, dynamic>;
          final int currentRuns = data['runs_scored'] ?? 0;
          final int currentBalls = data['balls_faced'] ?? 0;
          final int currentLegal = data['legal_balls_faced'] ?? 0;
          final int currentFours = data['fours'] ?? 0;
          final int currentSixes = data['sixes'] ?? 0;

          final bool isLegal = lastBall.ballType != 'no_ball';

          transaction.update(batsmanRef, {
            'runs_scored': (currentRuns - lastBall.runs).clamp(0, 999),
            'balls_faced': (currentBalls - 1).clamp(0, 999),
            if (isLegal) 'legal_balls_faced': (currentLegal - 1).clamp(0, 999),
            if (lastBall.isFour) 'fours': (currentFours - 1).clamp(0, 999),
            if (lastBall.isSix) 'sixes': (currentSixes - 1).clamp(0, 999),
          });
        }

        // --- Reversing Wicket & Fielders ---
        if (lastBall.isWicket) {
          final targetPlayerId =
              lastBall.dismissedPlayerId ?? lastBall.batsmanId;
          final targetRef = matchRef.collection('players').doc(targetPlayerId);
          transaction.update(targetRef, {
            'is_out': false,
            'dismissed_by': null,
            'dismissal_type': null,
          });

          if (lastBall.fielderId != null &&
              fielderSnap != null &&
              fielderSnap.exists) {
            final fData = fielderSnap.data() as Map<String, dynamic>;
            final int currentCatches = fData['catches'] ?? 0;
            final fielderRef = matchRef
                .collection('players')
                .doc(lastBall.fielderId);
            transaction.update(fielderRef, {
              'catches': (currentCatches - 1).clamp(0, 999),
            });
          }
        }

        // --- Reversing Bowler Stats ---
        if (bowlerSnap.exists) {
          final data = bowlerSnap.data() as Map<String, dynamic>;
          final int currentRunsConceded = data['runs_conceded'] ?? 0;
          final int currentBallsBowled = data['balls_bowled'] ?? 0;
          final int currentWickets = data['wickets_taken'] ?? 0;

          int bowlerRunsToReverse =
              (lastBall.ballType == 'bye' || lastBall.ballType == 'leg_bye'
                  ? 0
                  : totalRunsToReverse);

          transaction.update(bowlerRef, {
            'runs_conceded': (currentRunsConceded - bowlerRunsToReverse).clamp(
              0,
              999,
            ),
            if (lastBall.ballType != 'wide' && lastBall.ballType != 'no_ball')
              'balls_bowled': (currentBallsBowled - 1).clamp(0, 999),
            if (lastBall.isWicket && lastBall.dismissalType != 'run_out')
              'wickets_taken': (currentWickets - 1).clamp(0, 99),
          });
        }

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
