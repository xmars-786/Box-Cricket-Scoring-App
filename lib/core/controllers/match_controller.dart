import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/match_model.dart';
import '../models/player_model.dart';
import '../models/user_model.dart';
import '../controllers/auth_controller.dart';
import '../constants/app_constants.dart';
import '../models/player_stats_model.dart';
import '../utils/ui_utils.dart';

class MatchController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final RxList<MatchModel> _liveMatches = <MatchModel>[].obs;
  final RxList<MatchModel> _myMatches = <MatchModel>[].obs;
  final RxList<MatchModel> _completedMatches = <MatchModel>[].obs;

  // Pagination for My Matches
  DocumentSnapshot? _lastMyMatchDoc;
  final RxBool _hasMoreMyMatches = true.obs;
  bool get hasMoreMyMatches => _hasMoreMyMatches.value;

  // Pagination for History
  DocumentSnapshot? _lastHistoryDoc;
  final RxBool _hasMoreHistory = true.obs;
  bool get hasMoreHistory => _hasMoreHistory.value;

  // History Filter State
  final RxnString _historyStatus = RxnString(AppConstants.matchCompleted);
  final Rxn<DateTime> _historyStartDate = Rxn<DateTime>();
  final Rxn<DateTime> _historyEndDate = Rxn<DateTime>();
  final RxnBool _historyIsTournament = RxnBool();

  static const int _pageSize = 10;

  final Rxn<MatchModel> _selectedMatch = Rxn<MatchModel>();
  final RxMap<String, PlayerModel> _players = <String, PlayerModel>{}.obs;
  final RxBool _isLoading = false.obs;
  final RxBool _isMyMatchesLoading = false.obs;
  final RxBool _isHistoryLoading = false.obs;
  final RxnString _error = RxnString();

  StreamSubscription? _liveMatchesSub;
  StreamSubscription? _myMatchesSub;
  StreamSubscription? _historyMatchesSub;
  StreamSubscription? _selectedMatchSub;
  StreamSubscription? _playersSub;

  @override
  void onInit() {
    super.onInit();

    // Use delay to avoid 'setState during build' error
    Future.microtask(() {
      listenToLiveMatches();
      loadCompletedMatches(refresh: true);

      final authController = Get.find<AuthController>();
      if (authController.userId != null) {
        loadMyMatches(authController.userId!, refresh: true);
      }
    });

    // Auto-load matches when auth state changes
    final authController = Get.find<AuthController>();
    ever(authController.currentUserRx, (AppUser? user) {
      if (user != null) {
        loadMyMatches(user.uid, refresh: true);
      } else {
        _myMatches.clear();
      }
    });
  }

  // ─── Getters ─────────────────────────────────────────
  List<MatchModel> get liveMatches => _liveMatches;
  List<MatchModel> get myMatches => _myMatches;
  List<MatchModel> get completedMatches => _completedMatches;
  MatchModel? get selectedMatch => _selectedMatch.value;
  Rxn<MatchModel> get selectedMatchRx => _selectedMatch;
  Map<String, PlayerModel> get players => _players;
  bool get isLoading =>
      _isLoading.value || _isMyMatchesLoading.value || _isHistoryLoading.value;
  bool get isMyMatchesLoading => _isMyMatchesLoading.value;
  bool get isHistoryLoading => _isHistoryLoading.value;
  String? get error => _error.value;

  // ─── Listen to Live Matches ─────────────────────────
  void listenToLiveMatches() {
    _liveMatchesSub?.cancel();
    _liveMatchesSub = _firestore
        .collection(AppConstants.matchesCollection)
        .where('status', isEqualTo: AppConstants.matchLive)
        .snapshots()
        .listen(
          (snapshot) {
            final matches =
                snapshot.docs
                    .map((doc) => MatchModel.fromFirestore(doc))
                    .toList();
            // Sort in memory by startedAt descending
            matches.sort((a, b) {
              final dateA = a.startedAt ?? a.createdAt;
              final dateB = b.startedAt ?? b.createdAt;
              return dateB.compareTo(dateA);
            });
            _liveMatches.value = matches;
          },
          onError: (e) {
            _error.value = 'Error loading live matches: $e';
          },
        );
  }

  // ─── Load User's Matches with Pagination ────────────
  Future<void> loadMyMatches(String userId, {bool refresh = false}) async {
    if (refresh) {
      _lastMyMatchDoc = null;
      _hasMoreMyMatches.value = true;
    }

    if (!_hasMoreMyMatches.value || _isMyMatchesLoading.value) return;

    try {
      Future.microtask(() => _isMyMatchesLoading.value = true);

      // For the first page, we'll use a stream listener to keep it live
      if (_lastMyMatchDoc == null) {
        _myMatchesSub?.cancel();
        _myMatchesSub = _firestore
            .collection(AppConstants.matchesCollection)
            .where('created_by', isEqualTo: userId)
            .limit(_pageSize)
            .snapshots()
            .listen(
              (snapshot) {
                if (snapshot.docs.isNotEmpty) {
                  _lastMyMatchDoc = snapshot.docs.last;
                  final matches =
                      snapshot.docs
                          .map((doc) => MatchModel.fromFirestore(doc))
                          .toList();
                  matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  _myMatches.assignAll(matches);

                  if (snapshot.docs.length < _pageSize) {
                    _hasMoreMyMatches.value = false;
                  }
                } else {
                  _myMatches.clear();
                  _hasMoreMyMatches.value = false;
                }
                _isMyMatchesLoading.value = false;
                _error.value = null;
              },
              onError: (e) {
                _error.value = 'Error listening to matches: $e';
                _isMyMatchesLoading.value = false;
              },
            );
      } else {
        // Pagination for subsequent pages
        var query = _firestore
            .collection(AppConstants.matchesCollection)
            .where('created_by', isEqualTo: userId)
            .orderBy('created_at', descending: true)
            .startAfterDocument(_lastMyMatchDoc!)
            .limit(_pageSize);

        final snapshot = await query.get();

        if (snapshot.docs.length < _pageSize) {
          _hasMoreMyMatches.value = false;
        }

        if (snapshot.docs.isNotEmpty) {
          _lastMyMatchDoc = snapshot.docs.last;
          final newMatches =
              snapshot.docs
                  .map((doc) => MatchModel.fromFirestore(doc))
                  .toList();

          for (var match in newMatches) {
            if (!_myMatches.any((m) => m.id == match.id)) {
              _myMatches.add(match);
            }
          }
        }
        _isMyMatchesLoading.value = false;
      }
    } catch (e) {
      _error.value = 'Error loading matches: $e';
      _isMyMatchesLoading.value = false;
      print('Pagination error: $e');
    }
  }

  // ─── Load Match History with Pagination ─────────────
  Future<void> loadCompletedMatches({
    bool refresh = false,
    String? status = 'KEEP_CURRENT', // Marker to keep current status
    DateTime? startDate,
    DateTime? endDate,
    bool? isTournament,
    bool clearFilters = false,
  }) async {
    if (clearFilters) {
      _historyStatus.value = AppConstants.matchCompleted;
      _historyStartDate.value = null;
      _historyEndDate.value = null;
      _historyIsTournament.value = null;
      refresh = true;
    } else {
      if (status != 'KEEP_CURRENT') _historyStatus.value = status;
      if (startDate != null || refresh) _historyStartDate.value = startDate;
      if (endDate != null || refresh) _historyEndDate.value = endDate;
      if (isTournament != null || refresh)
        _historyIsTournament.value = isTournament;
    }

    if (refresh) {
      _lastHistoryDoc = null;
      _hasMoreHistory.value = true;
      _completedMatches.clear();
    }

    if (!_hasMoreHistory.value || _isHistoryLoading.value) return;

    try {
      _isHistoryLoading.value = true;

      Query query = _firestore.collection(AppConstants.matchesCollection);

      // Apply Filters
      if (_historyStatus.value != null) {
        query = query.where('status', isEqualTo: _historyStatus.value);
      }

      if (_historyIsTournament.value != null) {
        if (_historyIsTournament.value!) {
          query = query.where('tournament_id', isNotEqualTo: null);
        } else {
          query = query.where('tournament_id', isEqualTo: null);
        }
      }

      if (_historyStartDate.value != null) {
        query = query.where(
          'created_at',
          isGreaterThanOrEqualTo: _historyStartDate.value,
        );
      }
      if (_historyEndDate.value != null) {
        // End of day
        final end = DateTime(
          _historyEndDate.value!.year,
          _historyEndDate.value!.month,
          _historyEndDate.value!.day,
          23,
          59,
          59,
        );
        query = query.where('created_at', isLessThanOrEqualTo: end);
      }

      query = query.orderBy('created_at', descending: true).limit(_pageSize);

      if (_lastHistoryDoc != null) {
        query = query.startAfterDocument(_lastHistoryDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _pageSize) {
        _hasMoreHistory.value = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastHistoryDoc = snapshot.docs.last;
        final newMatches =
            snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();

        final Set<String> existingIds =
            _completedMatches.map((m) => m.id).toSet();
        for (var match in newMatches) {
          if (!existingIds.contains(match.id)) {
            _completedMatches.add(match);
          }
        }
      }

      _isHistoryLoading.value = false;
      _error.value = null;
    } catch (e) {
      _error.value = 'Error loading match history: $e';
      _isHistoryLoading.value = false;
      print('Pagination error: $e');
    }
  }

  // ─── Create Match ──────────────────────────────────
  Future<String?> createMatch({
    required String title,
    required String createdBy,
    required int totalOvers,
    required String teamAName,
    required String teamBName,
    required String groundName,
    required List<PlayerModel> teamAPlayers,
    required List<PlayerModel> teamBPlayers,
    required List<String> scorerIds,
    required String tossWonBy,
    required String tossDecision,
    String? teamACaptainId,
    String? teamAViceCaptainId,
    String? teamBCaptainId,
    String? teamBViceCaptainId,
    bool customRulesEnabled = false,
    bool lastPlayerCanPlay = false,
    int? maxBattingOvers,
    int? maxBowlingOvers,
    String? tournamentId,
    String? tournamentName,
    String? round,
    String? teamAId,
    String? teamBId,
    String? existingMatchId,
    int? matchNumber,
    int ballsPerOver = 6,
  }) async {
    try {
      _isLoading.value = true;
      _error.value = null;

      _error.value = null;

      final matchId = existingMatchId ?? _uuid.v4();

      final match = MatchModel(
        id: matchId,
        title: title,
        createdBy: createdBy,
        totalOvers: totalOvers,
        teamAName: teamAName,
        teamBName: teamBName,
        groundName: groundName,
        teamAPlayers: teamAPlayers.map((p) => p.id).toList(),
        teamBPlayers: teamBPlayers.map((p) => p.id).toList(),
        scorerIds: scorerIds,
        status: AppConstants.matchLive,
        startedAt: DateTime.now(),
        currentInnings:
            tossWonBy == 'A'
                ? (tossDecision == 'bat' ? 'A' : 'B')
                : (tossDecision == 'bat' ? 'B' : 'A'),

        teamACaptainId: teamACaptainId,
        teamAViceCaptainId: teamAViceCaptainId,
        teamBCaptainId: teamBCaptainId,
        teamBViceCaptainId: teamBViceCaptainId,
        tossWonBy: tossWonBy,
        tossDecision: tossDecision,
        customRulesEnabled: customRulesEnabled,
        lastPlayerCanPlay: lastPlayerCanPlay,
        maxBowlingOvers: maxBowlingOvers,
        createdAt: DateTime.now(),
        tournamentId: tournamentId,
        tournamentName: tournamentName,
        round: round,
        teamAId: teamAId,
        teamBId: teamBId,
        matchNumber: matchNumber,
        ballsPerOver: ballsPerOver,
      );

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(AppConstants.matchesCollection).doc(matchId),
        match.toFirestore(),
      );

      for (var player in teamAPlayers) {
        batch.set(
          _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .collection('players')
              .doc(player.id),
          player.copyWith(teamId: 'A').toMap(),
        );
      }
      for (var player in teamBPlayers) {
        batch.set(
          _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .collection('players')
              .doc(player.id),
          player.copyWith(teamId: 'B').toMap(),
        );
      }

      await batch.commit();

      // Refresh the list immediately so it shows up in "My Matches"
      loadMyMatches(createdBy, refresh: true);

      _isLoading.value = false;
      return matchId;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _error.value = msg;
      UIUtils.showError(msg);
      _isLoading.value = false;
      return null;
    }
  }

  // ─── Fetch Players Once (Future) ───────────────────
  Future<void> fetchPlayers(String matchId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.matchesCollection)
          .doc(matchId)
          .collection('players')
          .get();

      final newPlayers = <String, PlayerModel>{};
      for (final doc in snapshot.docs) {
        final player = PlayerModel.fromMap(doc.data());
        newPlayers[player.id] = player;
      }
      _players.value = newPlayers;
    } catch (e) {
      print('Error fetching players: $e');
    }
  }

  // ─── Listen to Single Match (Real-time) ─────────────
  void listenToMatch(String matchId) {
    _selectedMatchSub?.cancel();
    _selectedMatchSub = _firestore
        .collection(AppConstants.matchesCollection)
        .doc(matchId)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _selectedMatch.value = MatchModel.fromFirestore(doc);
          }
        });

    _playersSub?.cancel();
    _playersSub = _firestore
        .collection(AppConstants.matchesCollection)
        .doc(matchId)
        .collection('players')
        .snapshots()
        .listen((snapshot) {
          final newPlayers = <String, PlayerModel>{};
          for (final doc in snapshot.docs) {
            final player = PlayerModel.fromMap(doc.data());
            newPlayers[player.id] = player;
          }
          _players.value = newPlayers;
        });
  }

  // ─── Start Match ───────────────────────────────────
  Future<void> startMatch(String matchId) async {
    await _firestore
        .collection(AppConstants.matchesCollection)
        .doc(matchId)
        .update({
          'status': AppConstants.matchLive,
          'started_at': Timestamp.now(),
        });

    // Refresh lists to reflect status change
    final authController = Get.find<AuthController>();
    if (authController.userId != null) {
      loadMyMatches(authController.userId!, refresh: true);
    }
    loadCompletedMatches(refresh: true);
  }

  // ─── End Match ─────────────────────────────────────
  Future<void> endMatch(
    String matchId,
    String result, {
    String? winnerId,
  }) async {
    final matchRef = _firestore
        .collection(AppConstants.matchesCollection)
        .doc(matchId);

    await matchRef.update({
      'status': AppConstants.matchCompleted,
      'completed_at': Timestamp.now(),
      'result': result,
      'winner_id': winnerId,
    });

    // Handle Knockout Progression
    final matchDoc = await matchRef.get();
    final match = MatchModel.fromFirestore(matchDoc);

    if (match.nextMatchId != null && winnerId != null) {
      final nextMatchRef = _firestore
          .collection(AppConstants.matchesCollection)
          .doc(match.nextMatchId);
      final nextMatchDoc = await nextMatchRef.get();

      if (nextMatchDoc.exists) {
        final nextMatch = MatchModel.fromFirestore(nextMatchDoc);
        final winnerName =
            winnerId == match.teamAId ? match.teamAName : match.teamBName;

        // Use matchNumber to decide which slot (Team A or B) the winner takes in the next match
        // Typically Match 1 winner goes to Team A, Match 2 winner goes to Team B
        if (match.matchNumber == 1) {
          await nextMatchRef.update({
            'team_a_id': winnerId,
            'team_a_name': winnerName,
          });
        } else if (match.matchNumber == 2) {
          await nextMatchRef.update({
            'team_b_id': winnerId,
            'team_b_name': winnerName,
          });
        }
      }
    }

    // Refresh lists to reflect status change
    final authController = Get.find<AuthController>();
    if (authController.userId != null) {
      loadMyMatches(authController.userId!, refresh: true);
    }
    loadCompletedMatches(refresh: true);
  }

  // ─── Delete Match ──────────────────────────────────
  Future<bool> deleteMatch(String matchId) async {
    try {
      _isLoading.value = true;

      // 1. Fetch the match first to check if stats were updated
      final matchDoc =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .get();

      if (!matchDoc.exists) {
        _isLoading.value = false;
        return false;
      }

      final matchData = matchDoc.data() as Map<String, dynamic>;
      final bool statsUpdated = matchData['stats_updated'] ?? false;
      final match = MatchModel.fromFirestore(matchDoc);

      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      Future<void> _commitIfFull() async {
        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      // 2. Revert Global Stats if they were pushed
      if (statsUpdated) {
        final playersQuery =
            await _firestore
                .collection(AppConstants.matchesCollection)
                .doc(matchId)
                .collection('players')
                .get();

        for (final doc in playersQuery.docs) {
          final p = PlayerModel.fromMap(doc.data());
          final statsRef = _firestore
              .collection(AppConstants.playerStatsCollection)
              .doc(p.id);
          final userRef = _firestore
              .collection(AppConstants.usersCollection)
              .doc(p.id);

          // Calculate Win/Loss reversal
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

          final isTournament = match.tournamentId != null;
          final prefix = isTournament ? 'tournament_' : 'single_';

          // Reversal Map
          final Map<String, dynamic> rev = {
            'matches': FieldValue.increment(-1),
            'runs': FieldValue.increment(-p.runsScored),
            'balls_faced': FieldValue.increment(-p.ballsFaced),
            'wickets': FieldValue.increment(-p.wicketsTaken),
            'fours': FieldValue.increment(-p.fours),
            'sixes': FieldValue.increment(-p.sixes),
            'runs_conceded': FieldValue.increment(-p.runsConceded),
            'maidens': FieldValue.increment(-p.maidens),
            'wide_balls': FieldValue.increment(-p.widesBowled),
            'no_balls': FieldValue.increment(-p.noBallsBowled),
            'wins': FieldValue.increment(isWin ? -1 : 0),
            'losses': FieldValue.increment(isLoss ? -1 : 0),

            '${prefix}matches': FieldValue.increment(-1),
            '${prefix}runs': FieldValue.increment(-p.runsScored),
            '${prefix}wickets': FieldValue.increment(-p.wicketsTaken),
          };

          if (match.manOfMatch == p.id) {
            rev['man_of_match_awards'] = FieldValue.increment(-1);
          }

          if (p.ballsFaced > 0) {
            rev['batting_innings'] = FieldValue.increment(-1);
            rev['${prefix}batting_innings'] = FieldValue.increment(-1);
            if (!p.isOut) rev['not_outs'] = FieldValue.increment(-1);
            if (p.runsScored == 0 && p.isOut)
              rev['ducks'] = FieldValue.increment(-1);
            if (p.runsScored >= 100)
              rev['hundreds'] = FieldValue.increment(-1);
            else if (p.runsScored >= 50)
              rev['fifties'] = FieldValue.increment(-1);
            else if (p.runsScored >= 30)
              rev['thirties'] = FieldValue.increment(-1);
          }

          if (p.ballsBowled > 0 || p.oversBowled > 0) {
            rev['bowling_innings'] = FieldValue.increment(-1);
            rev['${prefix}bowling_innings'] = FieldValue.increment(-1);
            final double overValue = p.oversBowled + (p.ballsBowled / 10.0);
            rev['overs'] = FieldValue.increment(-overValue);
            if (p.wicketsTaken >= 5)
              rev['five_wkts'] = FieldValue.increment(-1);
            else if (p.wicketsTaken >= 3)
              rev['three_wkts'] = FieldValue.increment(-1);
          }

          batch.set(statsRef, rev, SetOptions(merge: true));
          operationCount++;
          await _commitIfFull();

          batch.update(userRef, {
            'total_runs': FieldValue.increment(-p.runsScored),
            'total_wickets': FieldValue.increment(-p.wicketsTaken),
            'matches_played': FieldValue.increment(-1),
          });
          operationCount++;
          await _commitIfFull();
        }
      }

      // 3. Delete players subcollection
      final playersQuery =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .collection('players')
              .get();
      for (final doc in playersQuery.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await _commitIfFull();
      }

      // 4. Delete ball logs subcollection
      final ballLogsQuery =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .collection(AppConstants.ballLogsCollection)
              .get();
      for (final doc in ballLogsQuery.docs) {
        batch.delete(doc.reference);
        operationCount++;
        await _commitIfFull();
      }

      // 5. Delete main document
      batch.delete(
        _firestore.collection(AppConstants.matchesCollection).doc(matchId),
      );
      await batch.commit();

      // Remove from local lists immediately to update UI
      _myMatches.removeWhere((m) => m.id == matchId);
      _completedMatches.removeWhere((m) => m.id == matchId);
      _liveMatches.removeWhere((m) => m.id == matchId);

      _isLoading.value = false;
      return true;
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error deleting match: $e');
      return false;
    }
  }

  Future<String?> performRematch({
    required MatchModel match,
    required String tossWonBy,
    required String tossDecision,
    required String currentUserId,
  }) async {
    try {
      _isLoading.value = true;

      // 1. Fetch players from the existing match's subcollection
      final playersSnap =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .doc(match.id)
              .collection('players')
              .get();

      // 2. Create fresh PlayerModel objects (reset all stats)
      final List<PlayerModel> teamAPlayers = [];
      final List<PlayerModel> teamBPlayers = [];

      for (var doc in playersSnap.docs) {
        final data = doc.data();
        final playerId = data['id'] ?? doc.id;

        // Create a clean player object with 0 stats
        final cleanPlayer = PlayerModel(
          id: playerId,
          name: data['name'] ?? 'Unknown',
          role: data['role'] ?? 'all_rounder',
          teamId: data['team_id'] ?? 'A',
          profileImageUrl: data['profile_image_url'],
        );

        if (cleanPlayer.teamId == 'A' ||
            match.teamAPlayers.contains(playerId)) {
          teamAPlayers.add(cleanPlayer);
        } else {
          teamBPlayers.add(cleanPlayer);
        }
      }

      // 3. Create the new match title logic
      String baseTitle = match.title;

      int matchNumber = 1;

      // Regex to find trailing number (e.g., "Match 1" -> "Match", "1")
      final numberRegex = RegExp(r'^(.*?)\s+(\d+)$');
      final matchResult = numberRegex.firstMatch(baseTitle);

      if (matchResult != null) {
        baseTitle = (matchResult.group(1) ?? baseTitle).trim();
        matchNumber = int.parse(matchResult.group(2) ?? '1') + 1;
      }

      final newMatchId = await createMatch(
        title: '$baseTitle $matchNumber',
        createdBy: currentUserId,
        totalOvers: match.totalOvers,
        teamAName: match.teamAName,
        teamBName: match.teamBName,
        groundName: match.groundName,
        teamAPlayers: teamAPlayers,
        teamBPlayers: teamBPlayers,
        scorerIds: match.scorerIds,
        tossWonBy: tossWonBy,
        tossDecision: tossDecision,
        teamACaptainId: match.teamACaptainId,
        teamAViceCaptainId: match.teamAViceCaptainId,
        teamBCaptainId: match.teamBCaptainId,
        teamBViceCaptainId: match.teamBViceCaptainId,
        customRulesEnabled: match.customRulesEnabled,
        lastPlayerCanPlay: match.lastPlayerCanPlay,
        maxBattingOvers: match.maxBattingOvers,
        maxBowlingOvers: match.maxBowlingOvers,
        tournamentId: match.tournamentId,
        round: match.round,
      );

      // 4. Refresh lists
      loadCompletedMatches(refresh: true);
      loadMyMatches(currentUserId, refresh: true);

      _isLoading.value = false;
      return newMatchId;
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Rematch failed: $e');
      return null;
    }
  }

  Future<PlayerStatsModel?> getPlayerStats(String uid) async {
    try {
      final doc =
          await _firestore
              .collection(AppConstants.playerStatsCollection)
              .doc(uid)
              .get();
      if (doc.exists) {
        return PlayerStatsModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching player stats: $e');
      return null;
    }
  }

  // ─── Clean Up ──────────────────────────────────────
  void clearSelectedMatch() {
    _selectedMatchSub?.cancel();
    _playersSub?.cancel();
    _selectedMatch.value = null;
    _players.clear();
  }

  // ─── Data Migration: Repair All Match Results ───────────────────────
  Future<void> repairAllCompletedMatchResults() async {
    try {
      _isLoading.value = true;
      _error.value = null;

      final snapshot =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('status', isEqualTo: AppConstants.matchCompleted)
              .get();

      if (snapshot.docs.isEmpty) {
        UIUtils.showInfo('No completed matches found to repair.');
        return;
      }

      int fixedCount = 0;
      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final match = MatchModel.fromFirestore(doc);
        final recalculated = match.recalculateResult();

        bool needsUpdate = false;
        Map<String, dynamic> updateData = {};

        // 1. Check Result & Winner
        if (match.result != recalculated['result'] ||
            match.winnerId != recalculated['winner_id']) {
          updateData['result'] = recalculated['result'];
          updateData['winner_id'] = recalculated['winner_id'];
          needsUpdate = true;
        }

        // 2. Check Man of the Match (Must be from winning team)
        final winningTeam = recalculated['winning_team']; // 'A' or 'B'
        if (winningTeam != null) {
          bool needsMOMRepair = false;

          if (match.manOfMatch == null) {
            // Missing MOM
            needsMOMRepair = true;
          } else {
            // Check if existing MOM is from correct team
            final momId = match.manOfMatch!;
            final momInCorrectTeam =
                (winningTeam == 'A'
                    ? match.teamAPlayers.contains(momId)
                    : match.teamBPlayers.contains(momId));

            if (!momInCorrectTeam) {
              needsMOMRepair = true;
              debugPrint(
                'Repairing MOM for match ${match.id}: MOM was from losing team.',
              );
            }
          }

          if (needsMOMRepair) {
            // FETCH PLAYERS AND RECALCULATE
            final playersSnap = await doc.reference.collection('players').get();

            String? bestPlayerId;
            String? bestPlayerName;
            double bestScore = -1.0;
            Map<String, dynamic>? bestPlayerData;

            for (final pDoc in playersSnap.docs) {
              final data = pDoc.data();
              final teamId = data['team_id'] as String? ?? '';

              // Only consider players from winning team
              if (teamId != winningTeam) continue;

              final name = data['name'] as String? ?? 'Unknown';
              final runs = (data['runs_scored'] ?? 0) as int;
              final ballsFaced = (data['balls_faced'] ?? 0) as int;
              final wickets = (data['wickets_taken'] ?? 0) as int;
              final catches = (data['catches'] ?? 0) as int;
              final maidens = (data['maidens_bowled'] ?? 0) as int;
              final runsConceded = (data['runs_conceded'] ?? 0) as int;
              final oversBowled = (data['overs_bowled'] ?? 0).toDouble();

              // Use same scoring logic as in ScoringController
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
              motmScore += 10;

              if (motmScore > bestScore) {
                bestScore = motmScore;
                bestPlayerId = pDoc.id;
                bestPlayerName = name;
                bestPlayerData = data;
              }
            }

            if (bestPlayerId != null) {
              updateData['man_of_match'] = bestPlayerId;
              updateData['man_of_match_name'] = bestPlayerName;
              updateData['man_of_the_match_map'] = {
                'id': bestPlayerId,
                'name': bestPlayerName,
                'team': winningTeam == 'A' ? match.teamAName : match.teamBName,
                'image': bestPlayerData?['profile_image_url'],
                'runs': bestPlayerData?['runs_scored'] ?? 0,
                'wickets': bestPlayerData?['wickets_taken'] ?? 0,
                'catches': bestPlayerData?['catches'] ?? 0,
              };
              needsUpdate = true;
            }
          }
        }

        if (needsUpdate) {
          batch.update(doc.reference, updateData);
          fixedCount++;
        }
      }

      // FETCH ALL TOURNAMENTS FOR NAMES
      final tournamentsSnap = await _firestore.collection('tournaments').get();
      final tournamentNames = {
        for (var doc in tournamentsSnap.docs)
          doc.id: (doc.data()['name'] as String? ?? 'Tournament')
      };

      // GROUP BY TOURNAMENT FOR TITLES/NUMBERS
      final tournamentGroups = <String, List<DocumentSnapshot>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tId = data['tournament_id'] as String?;
        if (tId != null) {
          tournamentGroups.putIfAbsent(tId, () => []).add(doc);
        }
      }

      // REPAIR EACH TOURNAMENT GROUP
      for (var entry in tournamentGroups.entries) {
        final tId = entry.key;
        final tName = tournamentNames[tId] ?? 'Tournament';
        final tMatches = entry.value;
        
        // Sort by creation date to determine order
        tMatches.sort((a, b) {
          final aDate = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final bDate = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          return (aDate ?? Timestamp.now()).compareTo(bDate ?? Timestamp.now());
        });

        for (int i = 0; i < tMatches.length; i++) {
          final doc = tMatches[i];
          final data = doc.data() as Map<String, dynamic>;
          final currentNumber = data['match_number'] as int?;
          final currentTitle = data['title'] as String?;
          final currentTName = data['tournament_name'] as String?;
          final expectedNumber = i + 1;
          final expectedTitle = 'Match $expectedNumber';

          if (currentNumber != expectedNumber || 
              currentTitle != expectedTitle || 
              currentTName != tName) {
            final docRef = doc.reference;
            await docRef.update({
              'match_number': expectedNumber,
              'title': expectedTitle,
              'tournament_name': tName,
            });
            fixedCount++;
          }
        }
      }

      if (fixedCount > 0) {
        UIUtils.showSuccess('Successfully fixed $fixedCount match titles and results!');
        loadCompletedMatches(refresh: true);
      } else {
        UIUtils.showInfo('All match data is already consistent.');
      }
    } catch (e) {
      _error.value = 'Error repairing match results: $e';
      UIUtils.showError('Failed to repair match results: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _liveMatchesSub?.cancel();
    _myMatchesSub?.cancel();
    _historyMatchesSub?.cancel();
    _selectedMatchSub?.cancel();
    _playersSub?.cancel();
    super.onClose();
  }
}
