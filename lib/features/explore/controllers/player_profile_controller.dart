import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/models/match_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/models/player_model.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/models/player_match_history_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/player_stats_model.dart';
import '../../../core/models/user_model.dart';

class PlayerProfileController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String playerId;

  PlayerProfileController({required this.playerId});

  final RxList<PlayerMatchHistoryModel> allHistory =
      <PlayerMatchHistoryModel>[].obs;
  final RxList<PlayerMatchHistoryModel> singleMatches =
      <PlayerMatchHistoryModel>[].obs;
  final RxMap<String, List<PlayerMatchHistoryModel>> tournamentMatches =
      <String, List<PlayerMatchHistoryModel>>{}.obs;
  final RxMap<String, TournamentModel> tournamentDetails =
      <String, TournamentModel>{}.obs;

  // Advanced Analytics
  final RxDouble impactScore = 0.0.obs;
  final RxDouble boundaryPercentage = 0.0.obs;
  final RxList<PlayerMatchHistoryModel> recentForm =
      <PlayerMatchHistoryModel>[].obs;
  final RxList<Map<String, dynamic>> achievements =
      <Map<String, dynamic>>[].obs;

  final RxMap<String, dynamic> innings1Stats = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> innings2Stats = <String, dynamic>{}.obs;

  final Rxn<PlayerStatsModel> aggregatedStats = Rxn<PlayerStatsModel>();
  final Rxn<AppUser> user = Rxn<AppUser>();
  final RxBool isLoading = true.obs;
  final RxBool isUserLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCache();
    fetchUser();
    fetchPlayerHistory();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString('cache_stats_$playerId');
      final userJson = prefs.getString('cache_user_$playerId');

      if (statsJson != null) {
        aggregatedStats.value = PlayerStatsModel.fromMap(
          playerId,
          json.decode(statsJson),
        );
      }
      if (userJson != null) {
        user.value = AppUser.fromMap(json.decode(userJson));
      }
    } catch (e) {
      print('Error loading cache: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (aggregatedStats.value != null) {
        await prefs.setString(
          'cache_stats_$playerId',
          json.encode(aggregatedStats.value!.toMap()),
        );
      }
      if (user.value != null) {
        await prefs.setString(
          'cache_user_$playerId',
          json.encode(user.value!.toMap()),
        );
      }
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  Future<void> fetchUser() async {
    isUserLoading.value = true;
    try {
      final doc =
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(playerId)
              .get();
      if (doc.exists) {
        user.value = AppUser.fromFirestore(doc);
        _saveCache();
      }
    } catch (e) {
      print('Error fetching user: $e');
    } finally {
      isUserLoading.value = false;
    }
  }

  Future<void> prefetch() async {
    // Call this before navigating to screen for instant load
    await Future.wait([fetchUser(), fetchPlayerHistory()]);
  }

  Future<void> onRefresh() async {
    await fetchPlayerHistory();
  }

  Future<void> fetchPlayerHistory() async {
    isLoading.value = true;
    try {
      // 1. Fetch matches where player participated
      final queryA =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('team_a_players', arrayContains: playerId)
              .where('status', isEqualTo: AppConstants.matchCompleted)
              .get();

      final queryB =
          await _firestore
              .collection(AppConstants.matchesCollection)
              .where('team_b_players', arrayContains: playerId)
              .where('status', isEqualTo: AppConstants.matchCompleted)
              .get();

      List<MatchModel> matches = [
        ...queryA.docs.map((doc) => MatchModel.fromFirestore(doc)),
        ...queryB.docs.map((doc) => MatchModel.fromFirestore(doc)),
      ];

      // Sort by completed date descending
      matches.sort(
        (a, b) => (b.completedAt ?? DateTime.now()).compareTo(
          a.completedAt ?? DateTime.now(),
        ),
      );

      // Parallel processing for maximum speed
      List<PlayerMatchHistoryModel> history = [];
      Set<String> tIds = {};

      final playerDataResults = await Future.wait(
        matches.map((match) async {
          final playerDoc =
              await _firestore
                  .collection(AppConstants.matchesCollection)
                  .doc(match.id)
                  .collection('players')
                  .doc(playerId)
                  .get();
          return {'match': match, 'doc': playerDoc};
        }),
      );

      // Collect ball logs in parallel ONLY for matches that need them
      final List<Map<String, dynamic>> matchesNeedingLogs =
          playerDataResults
              .where((res) {
                final doc = res['doc'] as DocumentSnapshot;
                if (!doc.exists) return false;
                final data = doc.data() as Map<String, dynamic>;
                final int ballsBowled =
                    int.tryParse(data['balls_bowled']?.toString() ?? '0') ?? 0;
                int mDots =
                    int.tryParse(data['dot_balls']?.toString() ?? '0') ?? 0;
                int mWides =
                    int.tryParse(data['wides_bowled']?.toString() ?? '0') ?? 0;
                int mNoBalls =
                    int.tryParse(data['no_balls_bowled']?.toString() ?? '0') ??
                    0;
                return ballsBowled > 0 &&
                    mDots == 0 &&
                    mWides == 0 &&
                    mNoBalls == 0;
              })
              .map((res) => res)
              .toList();

      final Map<String, QuerySnapshot> ballLogsMap = {};
      if (matchesNeedingLogs.isNotEmpty) {
        final logsResults = await Future.wait(
          matchesNeedingLogs.map((res) {
            final match = res['match'] as MatchModel;
            return _firestore
                .collection(AppConstants.matchesCollection)
                .doc(match.id)
                .collection(AppConstants.ballLogsCollection)
                .where('bowler_id', isEqualTo: playerId)
                .get();
          }),
        );
        for (int i = 0; i < matchesNeedingLogs.length; i++) {
          ballLogsMap[(matchesNeedingLogs[i]['match'] as MatchModel).id] =
              logsResults[i];
        }
      }

      // Aggregation variables
      int totalMatches = 0;
      int batInns = 0;
      int bowlInns = 0;
      int totalRuns = 0;
      int totalWkts = 0;
      int totalBallsFaced = 0;
      int totalBallsBowled = 0;
      int totalRunsConceded = 0;
      int fours = 0;
      int sixes = 0;
      int notOuts = 0;
      int highestScore = 0;
      int thirty = 0;
      int fifty = 0;
      int hundred = 0;
      int ducks = 0;
      int maidens = 0;
      int wideBalls = 0;
      int noBalls = 0;
      int dotBalls = 0;
      int threeW = 0;
      int fiveW = 0;
      String bb = "0/0";
      int wins = 0;
      int losses = 0;
      int motm = 0;

      for (var res in playerDataResults) {
        final match = res['match'] as MatchModel;
        final playerDoc = res['doc'] as DocumentSnapshot;

        if (playerDoc.exists) {
          final data = playerDoc.data() as Map<String, dynamic>;
          final p = PlayerModel.fromMap(data);
          history.add(PlayerMatchHistoryModel(match: match, performance: p));
          if (match.tournamentId != null) tIds.add(match.tournamentId!);

          totalMatches++;

          // Win/Loss logic
          if (match.winnerId != null && match.winnerId!.isNotEmpty) {
            final String? playerActualTeamId =
                (p.teamId == 'A') ? match.teamAId : match.teamBId;
            if (match.winnerId == playerActualTeamId) {
              wins++;
            } else if (match.winnerId != 'tied' &&
                match.winnerId != 'no_result') {
              losses++;
            }
          }

          if (match.manOfMatch == playerId) motm++;

          // Batting
          if (p.ballsFaced > 0 || p.runsScored > 0) batInns++;
          totalRuns += p.runsScored;
          totalBallsFaced += p.ballsFaced;
          fours += p.fours;
          sixes += p.sixes;
          if (p.runsScored > highestScore) highestScore = p.runsScored;
          if (p.runsScored >= 100)
            hundred++;
          else if (p.runsScored >= 50)
            fifty++;
          else if (p.runsScored >= 30)
            thirty++;
          if (p.runsScored == 0 && p.isOut) ducks++;
          if (p.ballsFaced > 0 && !p.isOut) notOuts++;

          // Bowling
          if (p.ballsBowled > 0) bowlInns++;
          totalWkts += p.wicketsTaken;
          totalBallsBowled += p.ballsBowled;
          totalRunsConceded += p.runsConceded;

          int matchDots =
              int.tryParse(data['dot_balls']?.toString() ?? '0') ?? 0;
          int matchWides = p.widesBowled;
          int matchNoBalls = p.noBallsBowled;
          int matchMaidens = p.maidens;

          if (ballLogsMap.containsKey(match.id)) {
            final logsSnap = ballLogsMap[match.id]!;
            Map<int, int> overRunsMap = {};
            for (var logDoc in logsSnap.docs) {
              final lData = logDoc.data() as Map<String, dynamic>;
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

              if (isLegal && lRuns == 0) matchDots++;
              if (bType == 'wide') matchWides++;
              if (bType == 'no_ball') matchNoBalls++;

              int bowlerConceded = lRuns;
              if (bType == 'wide' || bType == 'no_ball')
                bowlerConceded += (lExtras > 0 ? lExtras : 1);
              overRunsMap[lOver] = (overRunsMap[lOver] ?? 0) + bowlerConceded;
            }
            matchMaidens = overRunsMap.values.where((runs) => runs == 0).length;
          }

          maidens += matchMaidens;
          wideBalls += matchWides;
          noBalls += matchNoBalls;
          dotBalls += matchDots;

          if (p.wicketsTaken >= 5)
            fiveW++;
          else if (p.wicketsTaken >= 3)
            threeW++;

          if (bb == "0/0") {
            bb = "${p.wicketsTaken}/${p.runsConceded}";
          } else {
            final parts = bb.split('/');
            final oldW = int.parse(parts[0]);
            final oldR = int.parse(parts[1]);
            if (p.wicketsTaken > oldW ||
                (p.wicketsTaken == oldW && p.runsConceded < oldR)) {
              bb = "${p.wicketsTaken}/${p.runsConceded}";
            }
          }
        }
      }

      // Final formatted overs
      double formattedOvers =
          (totalBallsBowled ~/ 6) + (totalBallsBowled % 6) / 10.0;

      aggregatedStats.value = PlayerStatsModel(
        uid: playerId,
        matches: totalMatches,
        battingInnings: batInns,
        runs: totalRuns,
        wickets: totalWkts,
        highestScore: highestScore,
        notOuts: notOuts,
        ballsFaced: totalBallsFaced,
        thirties: thirty,
        fifties: fifty,
        hundreds: hundred,
        fours: fours,
        sixes: sixes,
        ducks: ducks,
        wins: wins,
        losses: losses,
        bowlingInnings: bowlInns,
        overs: formattedOvers,
        maidens: maidens,
        runsConceded: totalRunsConceded,
        bestBowling: bb,
        threeWkts: threeW,
        fiveWkts: fiveW,
        wideBalls: wideBalls,
        noBalls: noBalls,
        dotBalls: dotBalls,
        manOfMatchAwards: motm,
      );

      // 3. Parallel Fetch Tournament Details
      if (tIds.isNotEmpty) {
        final tResults = await Future.wait(
          tIds.map(
            (tId) =>
                _firestore
                    .collection(AppConstants.tournamentsCollection)
                    .doc(tId)
                    .get(),
          ),
        );
        for (var tDoc in tResults) {
          if (tDoc.exists) {
            final tId = tDoc.id;
            tournamentDetails[tId] = TournamentModel.fromFirestore(tDoc);
          }
        }
      }

      // 4. Group data
      allHistory.assignAll(history);
      singleMatches.assignAll(
        history.where((h) => h.match.tournamentId == null).toList(),
      );
      recentForm.assignAll(history.take(5).toList());

      Map<String, List<PlayerMatchHistoryModel>> grouped = {};
      for (var h in history.where((h) => h.match.tournamentId != null)) {
        final tId = h.match.tournamentId!;
        if (!grouped.containsKey(tId)) grouped[tId] = [];
        grouped[tId]!.add(h);
      }
      tournamentMatches.assignAll(grouped);

      // 5. Calculate Advanced Stats
      _calculateAdvancedStats(history);
      _calculateAchievements(history);

      // 6. Save to cache
      _saveCache();
    } catch (e) {
      print('Error fetching player history: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _calculateAchievements(List<PlayerMatchHistoryModel> history) {
    List<Map<String, dynamic>> list = [];

    int totalRuns = 0;
    int totalWkts = 0;
    int matches = history.length;
    int fours = 0;
    int sixes = 0;

    for (var h in history) {
      totalRuns += h.performance.runsScored;
      totalWkts += h.performance.wicketsTaken;
      fours += h.performance.fours;
      sixes += h.performance.sixes;
    }

    if (totalRuns >= 500)
      list.add({
        'title': '500 Club',
        'icon': Icons.stars,
        'color': Colors.amber,
      });
    if (totalRuns >= 100)
      list.add({
        'title': 'Centurion',
        'icon': Icons.workspace_premium,
        'color': Colors.orange,
      });
    if (totalWkts >= 50)
      list.add({
        'title': 'Wicket Wizard',
        'icon': Icons.bolt,
        'color': Colors.blue,
      });
    if (matches >= 20)
      list.add({
        'title': 'Veteran',
        'icon': Icons.shield,
        'color': Colors.purple,
      });
    if (fours + sixes >= 50)
      list.add({
        'title': 'Boundary King',
        'icon': Icons.flash_on,
        'color': Colors.red,
      });
    if (history.any((h) => h.performance.runsScored >= 50))
      list.add({
        'title': 'Record Breaker',
        'icon': Icons.emoji_events,
        'color': Colors.green,
      });

    achievements.assignAll(list);
  }

  void _calculateAdvancedStats(List<PlayerMatchHistoryModel> history) {
    if (history.isEmpty) return;

    double totalImpact = 0;
    int totalBalls = 0;
    int totalBoundaries = 0;

    Map<String, dynamic> i1 = {'runs': 0, 'wkts': 0, 'matches': 0};
    Map<String, dynamic> i2 = {'runs': 0, 'wkts': 0, 'matches': 0};

    for (var h in history) {
      final p = h.performance;
      final m = h.match;

      // Impact Score Logic (Simplified example)
      // (Runs * 1) + (Wickets * 20) + (SR/10) - (Econ * 2)
      double matchImpact = (p.runsScored * 1.0) + (p.wicketsTaken * 25.0);
      if (p.ballsFaced > 0) matchImpact += (p.strikeRate / 20.0);
      if (p.ballsBowled > 0) matchImpact -= (p.economyRate * 2.0);
      totalImpact += matchImpact;

      totalBalls += p.ballsFaced;
      totalBoundaries += (p.fours + p.sixes);

      // Innings Split
      // If player's team is initialBattingTeam, they batted in Innings 1
      if (m.initialBattingTeam == p.teamId) {
        i1['runs'] += p.runsScored;
        i1['wkts'] += p.wicketsTaken;
        i1['matches'] += 1;
      } else {
        i2['runs'] += p.runsScored;
        i2['wkts'] += p.wicketsTaken;
        i2['matches'] += 1;
      }
    }

    impactScore.value = history.length > 0 ? totalImpact / history.length : 0;
    boundaryPercentage.value =
        totalBalls > 0
            ? (totalBoundaries * 4.0 / totalBalls) * 100
            : 0; // Rough estimate
    // Correct boundary % is (runs from boundaries / total runs) or (boundary balls / total balls)
    // Let's use boundary balls / total balls faced for better accuracy of "Boundary Hitting"
    boundaryPercentage.value =
        totalBalls > 0 ? (totalBoundaries / totalBalls) * 100 : 0;

    innings1Stats.assignAll(i1);
    innings2Stats.assignAll(i2);
  }
}
