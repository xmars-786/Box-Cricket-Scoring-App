import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/match_model.dart';
import '../models/player_model.dart';
import '../models/user_model.dart';
import '../controllers/auth_controller.dart';
import '../constants/app_constants.dart';
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

  static const int _pageSize = 10;

  final Rxn<MatchModel> _selectedMatch = Rxn<MatchModel>();
  final RxMap<String, PlayerModel> _players = <String, PlayerModel>{}.obs;
  final RxBool _isLoading = false.obs;
  final RxnString _error = RxnString();

  StreamSubscription? _liveMatchesSub;
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
  bool get isLoading => _isLoading.value;
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
      _myMatches.clear();
    }

    if (!_hasMoreMyMatches.value || _isLoading.value) return;

    try {
      Future.microtask(() => _isLoading.value = true);

      var query = _firestore
          .collection(AppConstants.matchesCollection)
          .where('created_by', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(_pageSize);

      if (_lastMyMatchDoc != null) {
        query = query.startAfterDocument(_lastMyMatchDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < _pageSize) {
        _hasMoreMyMatches.value = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastMyMatchDoc = snapshot.docs.last;
        final newMatches =
            snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
        _myMatches.addAll(newMatches);
      }

      _isLoading.value = false;
      _error.value = null;
    } catch (e) {
      _error.value = 'Error loading matches: $e';
      _isLoading.value = false;
      print('Pagination error: $e');
    }
  }

  // ─── Load Match History with Pagination ─────────────
  Future<void> loadCompletedMatches({bool refresh = false}) async {
    if (refresh) {
      _lastHistoryDoc = null;
      _hasMoreHistory.value = true;
      _completedMatches.clear();
    }

    if (!_hasMoreHistory.value || _isLoading.value) return;

    try {
      Future.microtask(() => _isLoading.value = true);

      var query = _firestore
          .collection(AppConstants.matchesCollection)
          .where('status', isEqualTo: AppConstants.matchCompleted)
          .orderBy('created_at', descending: true)
          .limit(_pageSize);

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
        _completedMatches.addAll(newMatches);
      }

      _isLoading.value = false;
    } catch (e) {
      _error.value = 'Error loading match history: $e';
      _isLoading.value = false;
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
  }) async {
    try {
      _isLoading.value = true;
      _error.value = null;

      _error.value = null;

      final matchId = _uuid.v4();

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
        maxBattingOvers: maxBattingOvers,
        maxBowlingOvers: maxBowlingOvers,
        createdAt: DateTime.now(),
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
  }

  // ─── End Match ─────────────────────────────────────
  Future<void> endMatch(String matchId, String result) async {
    await _firestore
        .collection(AppConstants.matchesCollection)
        .doc(matchId)
        .update({
          'status': AppConstants.matchCompleted,
          'completed_at': Timestamp.now(),
          'result': result,
        });
  }

  // ─── Delete Match ──────────────────────────────────
  Future<bool> deleteMatch(String matchId) async {
    try {
      _isLoading.value = true;

      // Use a batch for faster deletion
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      void _commitIfFull() async {
        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      // Delete players subcollection
      final playersQuery =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .collection('players')
              .get();
      for (final doc in playersQuery.docs) {
        batch.delete(doc.reference);
        operationCount++;
        _commitIfFull();
      }

      // Delete ball logs subcollection
      final ballLogsQuery =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .doc(matchId)
              .collection(AppConstants.ballLogsCollection)
              .get();
      for (final doc in ballLogsQuery.docs) {
        batch.delete(doc.reference);
        operationCount++;
        _commitIfFull();
      }

      // Delete main document
      batch.delete(
        _firestore.collection(AppConstants.matchesCollection).doc(matchId),
      );

      await batch.commit();

      // Remove from local lists immediately to update UI
      _myMatches.removeWhere((m) => m.id == matchId);
      _completedMatches.removeWhere((m) => m.id == matchId);
      _liveMatches.removeWhere((m) => m.id == matchId);

      _isLoading.value = false;
      // UIUtils.showSuccess('Match deleted successfully');
      return true;
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error deleting match: $e');
      return false;
    }
  }

  // ─── Rematch ──────────────────────────────────────
  Future<String?> performRematch({
    required MatchModel match,
    required String tossWonBy,
    required String tossDecision,
    required String currentUserId,
  }) async {
    try {
      _isLoading.value = true;

      // 1. Fetch players from the existing match's subcollection
      final playersSnap = await _firestore
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

        if (cleanPlayer.teamId == 'A' || match.teamAPlayers.contains(playerId)) {
          teamAPlayers.add(cleanPlayer);
        } else {
          teamBPlayers.add(cleanPlayer);
        }
      }

      // 3. Create the new match
      final newMatchId = await createMatch(
        title: '${match.title} (Rematch)',
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

  // ─── Clean Up ──────────────────────────────────────
  void clearSelectedMatch() {
    _selectedMatchSub?.cancel();
    _playersSub?.cancel();
    _selectedMatch.value = null;
    _players.clear();
  }

  @override
  void onClose() {
    _liveMatchesSub?.cancel();
    _selectedMatchSub?.cancel();
    _playersSub?.cancel();
    super.onClose();
  }
}
