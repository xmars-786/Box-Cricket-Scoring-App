import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../models/player_stats_model.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../models/player_model.dart';
import '../constants/app_constants.dart';

class LeaderboardController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selection States
  final RxString selectedCategory =
      'All'.obs; // All, Single Match, Tournament, Match Wise
  final RxString selectedType = 'Batting'.obs; // Batting, Bowling

  final RxnString selectedTournamentId = RxnString();
  final RxnString selectedMatchId = RxnString();

  // Data Lists
  final RxList<PlayerWithStats> playersList = <PlayerWithStats>[].obs;
  final RxList<TournamentModel> tournaments = <TournamentModel>[].obs;
  final RxList<MatchModel> completedMatches = <MatchModel>[].obs;

  // Global Totals for Stat Strip
  final RxInt totalRuns = 0.obs;
  final RxInt totalWickets = 0.obs;
  final RxInt totalMatchesCount = 0.obs;

  final RxBool isLoading = false.obs;

  StreamSubscription? _statsSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();

    // ROOT FIX: Listen to stats collection for real-time auto-updates after matches
    _statsSubscription = _firestore
        .collection(AppConstants.playerStatsCollection)
        .snapshots()
        .listen((_) {
          if (selectedCategory.value != 'Match Wise' &&
              selectedCategory.value != 'Tournament') {
            _fetchGlobalLeaderboard(); // Silent update
          }
        });

    // Listen to filter changes and refetch
    ever(selectedCategory, (_) => fetchLeaderboard());
    ever(selectedTournamentId, (_) => fetchLeaderboard());
    ever(selectedMatchId, (_) => fetchLeaderboard());

    // Listener for unique matches count
    _firestore
        .collection(AppConstants.matchesCollection)
        .where('status', isEqualTo: AppConstants.matchCompleted)
        .snapshots()
        .listen((snap) {
          completedMatches.assignAll(
            snap.docs.map((doc) => MatchModel.fromFirestore(doc)).toList(),
          );
          totalMatchesCount.value = snap.docs.length;
        });
  }

  @override
  void onClose() {
    _statsSubscription?.cancel();
    super.onClose();
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      // Fetch tournaments for the dropdown
      final tourneySnap =
          await _firestore
              .collection(AppConstants.tournamentsCollection)
              .orderBy('created_at', descending: true)
              .get();
      tournaments.assignAll(
        tourneySnap.docs
            .map((doc) => TournamentModel.fromFirestore(doc))
            .toList(),
      );

      // Fetch matches for the dropdown
      final matchSnap =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('status', isEqualTo: AppConstants.matchCompleted)
              .limit(30)
              .get();
      
      final matches = matchSnap.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
      matches.sort((a, b) => (b.completedAt ?? DateTime.now()).compareTo(a.completedAt ?? DateTime.now()));
      
      completedMatches.assignAll(matches);

      await fetchLeaderboard();
    } catch (e) {
      print('Error fetching initial leaderboard data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchLeaderboard() async {
    isLoading.value = true;
    try {
      if (selectedCategory.value == 'Match Wise' &&
          selectedMatchId.value != null) {
        await _fetchMatchWiseLeaderboard(selectedMatchId.value!);
      } else if (selectedCategory.value == 'Tournament' &&
          selectedTournamentId.value != null) {
        await _fetchTournamentSpecificLeaderboard(selectedTournamentId.value!);
      } else {
        await _fetchGlobalLeaderboard();
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchGlobalLeaderboard() async {
    try {
      final matchSnap =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('status', isEqualTo: AppConstants.matchCompleted)
              .get();

      final matches =
          matchSnap.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
      print("Matches Found: ${matches.length}");

      final results = await _aggregateFromMatches(matches);
      _sortAndAssign(results);
    } catch (e) {
      print('Error in _fetchGlobalLeaderboard: $e');
    }
  }

  Future<void> _fetchTournamentSpecificLeaderboard(String tournamentId) async {
    try {
      final matchesSnap =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('tournament_id', isEqualTo: tournamentId)
              .where('status', isEqualTo: AppConstants.matchCompleted)
              .get();

      final matches =
          matchesSnap.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
      print("Tournament Matches Found: ${matches.length}");

      final results = await _aggregateFromMatches(matches);
      _sortAndAssign(results);
    } catch (e) {
      print('Error in _fetchTournamentSpecificLeaderboard: $e');
    }
  }

  Future<List<PlayerWithStats>> _aggregateFromMatches(
    List<MatchModel> matches,
  ) async {
    final Map<String, PlayerStatsModel> statsMap = {};
    final Set<String> userIds = {};

    print("Optimizing aggregation from ${matches.length} matches...");

    // Parallel match processing for maximum speed
    await Future.wait(
      matches.map((match) async {
        try {
          final playersSnap =
              await _firestore
                  .collection(AppConstants.matchesCollection)
                  .doc(match.id)
                  .collection('players')
                  .get();

          if (playersSnap.docs.isEmpty) return;

          // Optimization: Fetch ALL ball logs for this match ONCE if stats recovery is needed
          Map<String, List<Map<String, dynamic>>> groupedLogs = {};
          bool anyMissingStats = playersSnap.docs.any((doc) {
            final data = doc.data();
            final int balls =
                int.tryParse(data['balls_bowled']?.toString() ?? '0') ?? 0;
            // Only fetch logs if scorecard is missing advanced metrics
            return balls > 0 &&
                (data['dot_balls'] == null || data['wides_bowled'] == null);
          });

          if (anyMissingStats) {
            final logsSnap =
                await _firestore
                    .collection(AppConstants.matchesCollection)
                    .doc(match.id)
                    .collection(AppConstants.ballLogsCollection)
                    .get();

            for (var lDoc in logsSnap.docs) {
              final lData = lDoc.data();
              final String? bId = lData['bowler_id'];
              if (bId != null) {
                groupedLogs.putIfAbsent(bId, () => []).add(lData);
              }
            }
          }

          for (var doc in playersSnap.docs) {
            final data = doc.data();
            final String pid = doc.id;
            final String teamId = (data['team_id'] ?? 'A').toString();

            // Robust parsing
            final int runs =
                int.tryParse(data['runs_scored']?.toString() ?? '0') ?? 0;
            final int balls =
                int.tryParse(data['balls_faced']?.toString() ?? '0') ?? 0;
            final int wickets =
                int.tryParse(data['wickets_taken']?.toString() ?? '0') ?? 0;
            final int fours =
                int.tryParse(data['fours']?.toString() ?? '0') ?? 0;
            final int sixes =
                int.tryParse(data['sixes']?.toString() ?? '0') ?? 0;
            final bool isOut = data['is_out'] == true;
            final int ballsBowled =
                int.tryParse(data['balls_bowled']?.toString() ?? '0') ?? 0;
            final int runsConceded =
                int.tryParse(data['runs_conceded']?.toString() ?? '0') ?? 0;
            final int maidens =
                int.tryParse(data['maidens']?.toString() ?? '0') ?? 0;

            // Historical Data Fallback (Optimized from groupedLogs)
            int mDots = int.tryParse(data['dot_balls']?.toString() ?? '0') ?? 0;
            int mWides =
                int.tryParse(data['wides_bowled']?.toString() ?? '0') ?? 0;
            int mNoBalls =
                int.tryParse(data['no_balls_bowled']?.toString() ?? '0') ?? 0;
            int mMaidens = maidens;

            if (ballsBowled > 0 && groupedLogs.containsKey(pid)) {
              int recDots = 0, recWides = 0, recNoBalls = 0;
              Map<int, int> overRunsMap = {};

              for (var lData in groupedLogs[pid]!) {
                final String bType = lData['ball_type'] ?? 'normal';
                final int lRuns =
                    int.tryParse(lData['runs']?.toString() ?? '0') ?? 0;
                final int lExtras =
                    int.tryParse(lData['extra_runs']?.toString() ?? '0') ?? 0;
                final int lOver =
                    int.tryParse(lData['over_number']?.toString() ?? '0') ?? 0;
                final bool isLegal =
                    bType == 'normal' ||
                    bType == 'bye' ||
                    bType == 'leg_bye' ||
                    bType == 'wicket';

                if (isLegal && lRuns == 0) recDots++;
                if (bType == 'wide') recWides++;
                if (bType == 'no_ball') recNoBalls++;

                int conceded = lRuns;
                if (bType == 'wide' || bType == 'no_ball')
                  conceded += (lExtras > 0 ? lExtras : 1);
                overRunsMap[lOver] = (overRunsMap[lOver] ?? 0) + conceded;
              }

              if (mDots == 0) mDots = recDots;
              if (mWides == 0) mWides = recWides;
              if (mNoBalls == 0) mNoBalls = recNoBalls;
              if (mMaidens == 0)
                mMaidens = overRunsMap.values.where((r) => r == 0).length;
            }

            // Update shared state (Thread-safe in Dart async model)
            userIds.add(pid);
            final current =
                statsMap[pid] ?? PlayerStatsModel(uid: pid, highestScore: 0);

            // Career Match Logic
            int newWins = current.wins;
            int newLosses = current.losses;
            if (match.winnerId != null && match.winnerId!.isNotEmpty) {
              final String? playerTeamId =
                  (teamId == 'A') ? match.teamAId : match.teamBId;
              if (match.winnerId == playerTeamId)
                newWins++;
              else if (match.winnerId != 'tied' &&
                  match.winnerId != 'no_result')
                newLosses++;
            }

            // Accurate Overs Conversion
            int cWhole = current.overs.toInt();
            int cExtra = ((current.overs - cWhole) * 10).round();
            int tBalls = (cWhole * 6) + cExtra + ballsBowled;
            double formattedOvers = (tBalls ~/ 6) + (tBalls % 6) / 10.0;

            statsMap[pid] = PlayerStatsModel(
              uid: pid,
              matches: current.matches + 1,
              battingInnings:
                  current.battingInnings + ((balls > 0 || runs > 0) ? 1 : 0),
              runs: current.runs + runs,
              wickets: current.wickets + wickets,
              fours: current.fours + fours,
              sixes: current.sixes + sixes,
              ballsFaced: current.ballsFaced + balls,
              notOuts: current.notOuts + ((balls > 0 && !isOut) ? 1 : 0),
              highestScore:
                  runs > current.highestScore ? runs : current.highestScore,
              thirties: current.thirties + (runs >= 30 && runs < 50 ? 1 : 0),
              fifties: current.fifties + (runs >= 50 && runs < 100 ? 1 : 0),
              hundreds: current.hundreds + (runs >= 100 ? 1 : 0),
              ducks: current.ducks + (runs == 0 && isOut ? 1 : 0),
              wins: newWins,
              losses: newLosses,
              manOfMatchAwards:
                  current.manOfMatchAwards + (match.manOfMatch == pid ? 1 : 0),
              bowlingInnings:
                  current.bowlingInnings + (ballsBowled > 0 ? 1 : 0),
              overs: formattedOvers,
              runsConceded: current.runsConceded + runsConceded,
              maidens: current.maidens + mMaidens,
              threeWkts:
                  current.threeWkts + (wickets >= 3 && wickets < 5 ? 1 : 0),
              fiveWkts: current.fiveWkts + (wickets >= 5 ? 1 : 0),
              bestBowling: _calculateBestBowling(
                current.bestBowling,
                wickets,
                runsConceded,
              ),
              wideBalls: current.wideBalls + mWides,
              noBalls: current.noBalls + mNoBalls,
              dotBalls: current.dotBalls + mDots,
            );
          }
        } catch (e) {
          print("Error processing match ${match.id}: $e");
        }
      }),
    );

    if (userIds.isEmpty) return [];

    try {
      final usersList = await _fetchUsersByIds(userIds.toList());
      final userMap = {for (var u in usersList) u.uid: u};
      return userIds.map((id) {
        final user =
            userMap[id] ??
            AppUser(
              uid: id,
              name: 'Unknown',
              email: '',
              phone: '',
              role: 'player',
            );
        return PlayerWithStats(user: user, stats: statsMap[id]!);
      }).toList();
    } catch (e) {
      print("User fetch error: $e");
      return [];
    }
  }

  String _calculateBestBowling(String currentBB, int wickets, int runs) {
    if (currentBB == '0/0') return "$wickets/$runs";
    final parts = currentBB.split('/');
    final oldW = int.parse(parts[0]);
    final oldR = int.parse(parts[1]);
    if (wickets > oldW || (wickets == oldW && runs < oldR))
      return "$wickets/$runs";
    return currentBB;
  }

  Future<void> _fetchMatchWiseLeaderboard(String matchId) async {
    final playersSnap =
        await _firestore
            .collection(AppConstants.matchesCollection)
            .doc(matchId)
            .collection('players')
            .get();

    if (playersSnap.docs.isEmpty) {
      playersList.clear();
      return;
    }

    final List<String> userIds = playersSnap.docs.map((doc) => doc.id).toList();
    final usersList = await _fetchUsersByIds(userIds);
    final userMap = {for (var u in usersList) u.uid: u};

    final List<PlayerWithStats> results =
        playersSnap.docs.map((doc) {
          final playerModel = PlayerModel.fromMap(doc.data());
          final user =
              userMap[playerModel.id] ??
              AppUser(
                uid: playerModel.id,
                name: playerModel.name,
                email: '',
                phone: '',
                role: 'player',
              );

          final stats = PlayerStatsModel(
            uid: playerModel.id,
            runs: playerModel.runsScored,
            wickets: playerModel.wicketsTaken,
            matches: 1,
            battingInnings:
                (playerModel.ballsFaced > 0 || playerModel.runsScored > 0)
                    ? 1
                    : 0,
            highestScore: playerModel.runsScored,
            ballsFaced: playerModel.ballsFaced,
            runsConceded: playerModel.runsConceded,
            overs: playerModel.ballsBowled / 6.0,
          );
          return PlayerWithStats(user: user, stats: stats);
        }).toList();

    _sortAndAssign(results);
  }

  Future<List<AppUser>> _fetchUsersByIds(List<String> ids) async {
    List<AppUser> allUsers = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final usersSnap =
          await _firestore
              .collection(AppConstants.usersCollection)
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      allUsers.addAll(usersSnap.docs.map((doc) => AppUser.fromFirestore(doc)));
    }
    return allUsers;
  }

  void _sortAndAssign(List<PlayerWithStats> list) {
    final isBatting = selectedType.value == 'Batting';
    final category = selectedCategory.value;

    list.sort((a, b) {
      if (isBatting) {
        int aRuns = _getRuns(a.stats, category);
        int bRuns = _getRuns(b.stats, category);

        if (bRuns != aRuns) return bRuns.compareTo(aRuns);

        // Tie-breaker 1: Strike Rate (simplified as runs/balls)
        double aSR = a.stats.ballsFaced > 0 ? (aRuns / a.stats.ballsFaced) : 0;
        double bSR = b.stats.ballsFaced > 0 ? (bRuns / b.stats.ballsFaced) : 0;
        return bSR.compareTo(aSR);
      } else {
        int aWkts = _getWickets(a.stats, category);
        int bWkts = _getWickets(b.stats, category);

        if (bWkts != aWkts) return bWkts.compareTo(aWkts);

        // Tie-breaker 1: Economy (lower is better)
        double aEco =
            a.stats.overs > 0 ? (a.stats.runsConceded / a.stats.overs) : 999;
        double bEco =
            b.stats.overs > 0 ? (b.stats.runsConceded / b.stats.overs) : 999;
        return aEco.compareTo(bEco);
      }
    });

    playersList.assignAll(list);
    _calculateGlobalTotals(list);
  }

  void _calculateGlobalTotals(List<PlayerWithStats> list) {
    int runs = 0;
    int wkts = 0;
    final cat = selectedCategory.value;

    for (var p in list) {
      runs += _getRuns(p.stats, cat);
      wkts += _getWickets(p.stats, cat);
    }
    totalRuns.value = runs;
    totalWickets.value = wkts;
  }

  int _getRuns(PlayerStatsModel stats, String category) {
    if (category == 'Single Match') return stats.singleRuns;
    if (category == 'Tournament' && selectedTournamentId.value == null)
      return stats.tournamentRuns;
    return stats.runs;
  }

  int _getWickets(PlayerStatsModel stats, String category) {
    if (category == 'Single Match') return stats.singleWickets;
    if (category == 'Tournament' && selectedTournamentId.value == null)
      return stats.tournamentWickets;
    return stats.wickets;
  }

  void changeType(String type) {
    if (selectedType.value == type) return;
    selectedType.value = type;

    if (playersList.isNotEmpty) {
      // Local optimization: Just re-sort the existing data instead of a full DB fetch
      _sortAndAssign(List.from(playersList));
    } else {
      fetchLeaderboard();
    }
  }
}

class PlayerWithStats {
  final AppUser user;
  final PlayerStatsModel stats;
  PlayerWithStats({required this.user, required this.stats});
}
