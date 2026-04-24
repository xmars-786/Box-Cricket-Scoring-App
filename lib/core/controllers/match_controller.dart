import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/match_model.dart';
import '../models/player_model.dart';
import '../constants/app_constants.dart';
import '../utils/ui_utils.dart';

class MatchController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final RxList<MatchModel> _liveMatches = <MatchModel>[].obs;
  final RxList<MatchModel> _myMatches = <MatchModel>[].obs;
  final RxList<MatchModel> _completedMatches = <MatchModel>[].obs;
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

  // ─── Load User's Matches ───────────────────────────
  Future<void> loadMyMatches(String userId) async {
    try {
      _isLoading.value = true;

      final createdQuery =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('created_by', isEqualTo: userId)
              .get();

      final matches =
          createdQuery.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .toList();

      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _myMatches.value = matches;

      _isLoading.value = false;
      _error.value = null;
    } catch (e) {
      _error.value = 'Error loading matches: $e';
      _isLoading.value = false;
    }
  }

  // ─── Load Match History ─────────────────────────────
  Future<void> loadCompletedMatches() async {
    try {
      _isLoading.value = true;

      final snapshot =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('status', isEqualTo: AppConstants.matchCompleted)
              .get();

      final matches =
          snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
      matches.sort((a, b) {
        final dateA = a.completedAt ?? a.createdAt;
        final dateB = b.completedAt ?? b.createdAt;
        return dateB.compareTo(dateA);
      });
      _completedMatches.value = matches;

      _isLoading.value = false;
    } catch (e) {
      _error.value = 'Error loading match history: $e';
      _isLoading.value = false;
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
        customRulesEnabled: customRulesEnabled,
        lastPlayerCanPlay: lastPlayerCanPlay,
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

      _isLoading.value = false;
      // UIUtils.showSuccess('Match deleted successfully');
      return true;
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error deleting match: $e');
      return false;
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
