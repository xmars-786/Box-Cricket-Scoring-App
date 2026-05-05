import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/tournament_model.dart';
import '../models/match_model.dart';
import '../models/player_model.dart';
import '../models/tournament_player_stats.dart';
import '../constants/app_constants.dart';
import '../utils/ui_utils.dart';

class TournamentController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final RxList<TournamentModel> _tournaments = <TournamentModel>[].obs;
  final Rxn<TournamentModel> _selectedTournament = Rxn<TournamentModel>();
  final RxList<MatchModel> _tournamentMatches = <MatchModel>[].obs;
  final RxList<TournamentPlayerStats> leaderboard =
      <TournamentPlayerStats>[].obs;
  final RxBool _isLoading = false.obs;
  final RxnString _error = RxnString();

  StreamSubscription? _tournamentsSub;
  StreamSubscription? _selectedTournamentSub;
  StreamSubscription? _matchesSub;

  @override
  void onInit() {
    super.onInit();
    listenToTournaments();
  }

  // ─── Getters ─────────────────────────────────────────
  List<TournamentModel> get tournaments => _tournaments;
  TournamentModel? get selectedTournament => _selectedTournament.value;
  List<MatchModel> get tournamentMatches => _tournamentMatches;
  bool get isLoading => _isLoading.value;
  String? get error => _error.value;

  // Rx getters for reactive listeners
  Rxn<TournamentModel> get selectedTournamentRx => _selectedTournament;
  RxList<MatchModel> get tournamentMatchesRx => _tournamentMatches;

  int get totalMatches => _tournamentMatches.length;
  int get completedMatchesCount =>
      _tournamentMatches.where((m) => m.isCompleted).length;
  int get pendingMatchesCount =>
      _tournamentMatches.where((m) => !m.isCompleted).length;

  MatchModel? get nextMatchToPlay {
    // Sort matches by matchNumber or createdAt to ensure sequential order
    final sortedMatches = [..._tournamentMatches];
    sortedMatches.sort((a, b) {
      if (a.matchNumber != null && b.matchNumber != null) {
        return a.matchNumber!.compareTo(b.matchNumber!);
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    // Find the first match that is NOT completed
    try {
      return sortedMatches.firstWhere((m) => !m.isCompleted);
    } catch (_) {
      return null;
    }
  }

  bool canCreateMatchInTournament(TournamentModel? tournament) {
    if (tournament == null) return false;

    // 1. Check Tournament Status
    final allowedStatuses = ['upcoming', 'ongoing', 'live'];
    if (!allowedStatuses.contains(tournament.status.toLowerCase())) {
      return false;
    }

    // 2. Check for Live Matches
    final hasLive = _tournamentMatches.any((m) => m.isLive);
    if (hasLive) {
      return false;
    }

    return true;
  }

  bool get canCreateNewMatch {
    // Legacy support or general check
    return !_tournamentMatches.any((m) => m.isLive);
  }

  bool canStartMatch(MatchModel match) {
    // 1. Prevent parallel matches (only one live match allowed)
    if (_tournamentMatches.any((m) => m.isLive)) {
      return false;
    }

    // 2. Enforce sequential order based on matchNumber
    final sorted = [..._tournamentMatches];
    sorted.sort((a, b) => (a.matchNumber ?? 0).compareTo(b.matchNumber ?? 0));

    final index = sorted.indexWhere((m) => m.id == match.id);
    if (index > 0) {
      // Allow if previous match is completed
      return sorted[index - 1].isCompleted;
    }
    
    // First match is always allowed if nothing is live
    return true;
  }

  // ─── Listen to All Tournaments ──────────────────────
  void listenToTournaments() {
    _tournamentsSub?.cancel();
    _tournamentsSub = _firestore
        .collection(AppConstants.tournamentsCollection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _tournaments.value =
                snapshot.docs
                    .map((doc) => TournamentModel.fromFirestore(doc))
                    .toList();
          },
          onError: (e) {
            _error.value = 'Error loading tournaments: $e';
          },
        );
  }

  // ─── Listen to Single Tournament ────────────────────
  void listenToTournament(String tournamentId) {
    _selectedTournamentSub?.cancel();
    _selectedTournamentSub = _firestore
        .collection(AppConstants.tournamentsCollection)
        .doc(tournamentId)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _selectedTournament.value = TournamentModel.fromFirestore(doc);
          }
        });

    _matchesSub?.cancel();
    _matchesSub = _firestore
        .collection(AppConstants.matchesCollection)
        .where('tournament_id', isEqualTo: tournamentId)
        .snapshots()
        .listen((snapshot) {
          final matches =
              snapshot.docs
                  .map((doc) => MatchModel.fromFirestore(doc))
                  .toList();
          
          // Sort matches by matchNumber or createdAt to ensure sequential order
          matches.sort((a, b) {
            if (a.matchNumber != null && b.matchNumber != null) {
              return a.matchNumber!.compareTo(b.matchNumber!);
            }
            return a.createdAt.compareTo(b.createdAt);
          });

          _tournamentMatches.value = matches;
          fetchLeaderboard(tournamentId);
        });
  }

  Future<void> fetchLeaderboard(String tournamentId) async {
    _isLoading.value = true;
    try {
      final matches = _tournamentMatches.where((m) => m.isCompleted).toList();
      if (matches.isEmpty) {
        leaderboard.clear();
        return;
      }

      final statsMap = <String, TournamentPlayerStats>{};

      // Parallelize fetching player snapshots for all matches to improve performance
      final snapshots = await Future.wait(
        matches.map((match) => 
          _firestore
            .collection(AppConstants.matchesCollection)
            .doc(match.id)
            .collection('players')
            .get()
            .then((snap) => {'match': match, 'snap': snap})
        )
      );

      final tournament = _selectedTournament.value;

      for (var entry in snapshots) {
        final match = entry['match'] as MatchModel;
        final playersSnapshot = entry['snap'] as QuerySnapshot;
        
        if (playersSnapshot.docs.isEmpty) continue;

        for (var doc in playersSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final matchPlayer = PlayerModel.fromMap(data);
          final teamName =
              matchPlayer.teamId == 'A' ? match.teamAName : match.teamBName;

          // Only include players from teams currently in the tournament
          if (tournament != null && !tournament.teamNames.contains(teamName)) {
            continue;
          }

          if (!statsMap.containsKey(matchPlayer.id)) {
            statsMap[matchPlayer.id] = TournamentPlayerStats(
              playerId: matchPlayer.id,
              name: matchPlayer.name,
              teamName: teamName,
            );
          }
          statsMap[matchPlayer.id]!.aggregate(matchPlayer);
        }
      }

      final statsList = statsMap.values.toList();
      // Default sort by runs
      statsList.sort((a, b) => b.runs.compareTo(a.runs));
      leaderboard.assignAll(statsList);
    } catch (e) {
      print('Error fetching leaderboard: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  // ─── Create Tournament ──────────────────────────────
  Future<String?> createTournament({
    required String name,
    required String createdBy,
    required List<String> teamIds,
    required List<String> teamNames,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    int defaultOvers = 10,
    int ballsPerOver = 6,
    bool customRulesEnabled = false,
    bool lastPlayerCanPlay = false,
    int? maxBattingOvers,
    int? maxBowlingOvers,
  }) async {
    try {
      _isLoading.value = true;
      final id = _uuid.v4();
      final tournament = TournamentModel(
        id: id,
        name: name,
        createdBy: createdBy,
        teamIds: teamIds,
        teamNames: teamNames,
        type: type,
        startDate: startDate,
        endDate: endDate,
        status: _determineInitialStatus(startDate, endDate),
        defaultOvers: defaultOvers,
        ballsPerOver: ballsPerOver,
        customRulesEnabled: customRulesEnabled,
        lastPlayerCanPlay: lastPlayerCanPlay,
        maxBattingOvers: maxBattingOvers,
        maxBowlingOvers: maxBowlingOvers,
      );

      print("DEBUG: Creating Tournament - lastPlayerCanPlay: $lastPlayerCanPlay");

      await _firestore
          .collection(AppConstants.tournamentsCollection)
          .doc(id)
          .set(tournament.toFirestore());

      _isLoading.value = false;
      return id;
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error creating tournament: $e');
      return null;
    }
  }

  // ─── Fixture Management (Manual) ────────────────────
  bool hasLiveMatch(String tournamentId) {
    return _tournamentMatches.any((m) => m.status == 'live');
  }

  String _determineInitialStatus(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (now.isBefore(start)) return 'upcoming';
    if (now.isAfter(end)) return 'completed';
    return 'ongoing';
  }

  // ─── Delete Tournament ──────────────────────────────
  Future<void> deleteTournament(String tournamentId) async {
    try {
      _isLoading.value = true;
      // Note: In a real app, you might want to delete associated matches too
      await _firestore
          .collection(AppConstants.tournamentsCollection)
          .doc(tournamentId)
          .delete();
      _isLoading.value = false;
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error deleting tournament: $e');
    }
  }

  // ─── Update Tournament Status ───────────────────────
  Future<void> updateTournamentStatus(
    String tournamentId,
    String newStatus,
  ) async {
    try {
      _isLoading.value = true;
      final updates = <String, dynamic>{'status': newStatus};

      if (newStatus == 'completed') {
        updates['completed_at'] = Timestamp.now();
      } else if (newStatus == 'live' || newStatus == 'ongoing') {
        updates['started_at'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection(AppConstants.tournamentsCollection)
          .doc(tournamentId)
          .update(updates);

      _isLoading.value = false;
      UIUtils.showSuccess('Tournament status updated to ${newStatus.toUpperCase()}');
    } catch (e) {
      _isLoading.value = false;
      UIUtils.showError('Error updating status: $e');
    }
  }

  @override
  void onClose() {
    _tournamentsSub?.cancel();
    _selectedTournamentSub?.cancel();
    _matchesSub?.cancel();
    super.onClose();
  }
}
