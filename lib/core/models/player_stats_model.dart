import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive model for overall player statistics.
class PlayerStatsModel {
  final String uid;

  // Overall Stats
  final int matches;
  final int battingInnings;
  final int runs;
  final int wickets;
  final int highestScore;

  // Single Match Stats
  final int singleMatches;
  final int singleBattingInnings;
  final int singleRuns;
  final int singleWickets;
  final int singleHighestScore;

  // Tournament Stats
  final int tournamentMatches;
  final int tournamentBattingInnings;
  final int tournamentRuns;
  final int tournamentWickets;
  final int tournamentHighestScore;

  // Batting Stats Details (Overall)
  final int notOuts;
  final int ballsFaced;
  final int thirties;
  final int fifties;
  final int hundreds;
  final int fours;
  final int sixes;
  final int ducks;
  final int wins;
  final int losses;

  // Bowling Stats Details (Overall)
  final int bowlingInnings;
  final double overs;
  final int maidens;
  final int runsConceded;
  final String bestBowling;
  final int threeWkts;
  final int fiveWkts;
  final int wideBalls;
  final int noBalls;
  final int dotBalls;
  final int manOfMatchAwards;

  PlayerStatsModel({
    required this.uid,
    this.matches = 0,
    this.battingInnings = 0,
    this.runs = 0,
    this.wickets = 0,
    this.highestScore = 0,
    this.singleMatches = 0,
    this.singleBattingInnings = 0,
    this.singleRuns = 0,
    this.singleWickets = 0,
    this.singleHighestScore = 0,
    this.tournamentMatches = 0,
    this.tournamentBattingInnings = 0,
    this.tournamentRuns = 0,
    this.tournamentWickets = 0,
    this.tournamentHighestScore = 0,
    this.notOuts = 0,
    this.ballsFaced = 0,
    this.thirties = 0,
    this.fifties = 0,
    this.hundreds = 0,
    this.fours = 0,
    this.sixes = 0,
    this.ducks = 0,
    this.wins = 0,
    this.losses = 0,
    this.bowlingInnings = 0,
    this.overs = 0.0,
    this.maidens = 0,
    this.runsConceded = 0,
    this.bestBowling = '0/0',
    this.threeWkts = 0,
    this.fiveWkts = 0,
    this.wideBalls = 0,
    this.noBalls = 0,
    this.dotBalls = 0,
    this.manOfMatchAwards = 0,
  });

  // Calculated Getters (Overall)
  double get battingAverage {
    final dismissals = battingInnings - notOuts;
    if (dismissals <= 0) return runs.toDouble();
    return runs / dismissals;
  }

  double get battingStrikeRate {
    if (ballsFaced <= 0) return 0.0;
    return (runs * 100) / ballsFaced;
  }

  double get economy {
    if (overs <= 0) return 0.0;
    int wholeOvers = overs.toInt();
    int extraBalls = ((overs - wholeOvers) * 10).round();
    int totalBalls = (wholeOvers * 6) + extraBalls;
    if (totalBalls == 0) return 0.0;
    return (runsConceded * 6) / totalBalls;
  }

  double get bowlingSR {
    if (wickets <= 0) return 0.0;
    int wholeOvers = overs.toInt();
    int extraBalls = ((overs - wholeOvers) * 10).round();
    int totalBalls = (wholeOvers * 6) + extraBalls;
    return totalBalls / wickets;
  }

  double get bowlingAvg {
    if (wickets <= 0) return runsConceded.toDouble();
    return runsConceded / wickets;
  }

  // Helper getters for UI
  double get singleBattingAverage =>
      singleBattingInnings > 0 ? singleRuns / singleBattingInnings : 0.0;
  double get tournamentBattingAverage =>
      tournamentBattingInnings > 0
          ? tournamentRuns / tournamentBattingInnings
          : 0.0;

  factory PlayerStatsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PlayerStatsModel(
      uid: doc.id,
      matches: (data['matches'] as num?)?.toInt() ?? 0,
      battingInnings: (data['batting_innings'] as num?)?.toInt() ?? 0,
      runs: (data['runs'] as num?)?.toInt() ?? 0,
      wickets: (data['wickets'] as num?)?.toInt() ?? 0,
      highestScore: (data['highest_score'] as num?)?.toInt() ?? 0,
      singleMatches: (data['single_matches'] as num?)?.toInt() ?? 0,
      singleBattingInnings: (data['single_batting_innings'] as num?)?.toInt() ?? 0,
      singleRuns: (data['single_runs'] as num?)?.toInt() ?? 0,
      singleWickets: (data['single_wickets'] as num?)?.toInt() ?? 0,
      singleHighestScore: (data['single_highest_score'] as num?)?.toInt() ?? 0,
      tournamentMatches: (data['tournament_matches'] as num?)?.toInt() ?? 0,
      tournamentBattingInnings: (data['tournament_batting_innings'] as num?)?.toInt() ?? 0,
      tournamentRuns: (data['tournament_runs'] as num?)?.toInt() ?? 0,
      tournamentWickets: (data['tournament_wickets'] as num?)?.toInt() ?? 0,
      tournamentHighestScore: (data['tournament_highest_score'] as num?)?.toInt() ?? 0,
      notOuts: (data['not_outs'] as num?)?.toInt() ?? 0,
      ballsFaced: (data['balls_faced'] as num?)?.toInt() ?? 0,
      thirties: (data['thirties'] as num?)?.toInt() ?? 0,
      fifties: (data['fifties'] as num?)?.toInt() ?? 0,
      hundreds: (data['hundreds'] as num?)?.toInt() ?? 0,
      fours: (data['fours'] as num?)?.toInt() ?? 0,
      sixes: (data['sixes'] as num?)?.toInt() ?? 0,
      ducks: (data['ducks'] as num?)?.toInt() ?? 0,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      losses: (data['losses'] as num?)?.toInt() ?? 0,
      bowlingInnings: (data['bowling_innings'] as num?)?.toInt() ?? 0,
      overs: (data['overs'] ?? 0.0).toDouble(),
      maidens: (data['maidens'] as num?)?.toInt() ?? 0,
      runsConceded: (data['runs_conceded'] as num?)?.toInt() ?? 0,
      bestBowling: data['best_bowling'] ?? '0/0',
      threeWkts: (data['three_wkts'] as num?)?.toInt() ?? 0,
      fiveWkts: (data['five_wkts'] as num?)?.toInt() ?? 0,
      wideBalls: (data['wide_balls'] as num?)?.toInt() ?? 0,
      noBalls: (data['no_balls'] as num?)?.toInt() ?? 0,
      dotBalls: (data['dot_balls'] as num?)?.toInt() ?? 0,
      manOfMatchAwards: (data['man_of_match_awards'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matches': matches,
      'batting_innings': battingInnings,
      'runs': runs,
      'wickets': wickets,
      'highest_score': highestScore,
      'single_matches': singleMatches,
      'single_batting_innings': singleBattingInnings,
      'single_runs': singleRuns,
      'single_wickets': singleWickets,
      'single_highest_score': singleHighestScore,
      'tournament_matches': tournamentMatches,
      'tournament_batting_innings': tournamentBattingInnings,
      'tournament_runs': tournamentRuns,
      'tournament_wickets': tournamentWickets,
      'tournament_highest_score': tournamentHighestScore,
      'not_outs': notOuts,
      'balls_faced': ballsFaced,
      'thirties': thirties,
      'fifties': fifties,
      'hundreds': hundreds,
      'fours': fours,
      'sixes': sixes,
      'ducks': ducks,
      'wins': wins,
      'losses': losses,
      'bowling_innings': bowlingInnings,
      'overs': overs,
      'maidens': maidens,
      'runs_conceded': runsConceded,
      'best_bowling': bestBowling,
      'three_wkts': threeWkts,
      'five_wkts': fiveWkts,
      'wide_balls': wideBalls,
      'no_balls': noBalls,
      'dot_balls': dotBalls,
      'man_of_match_awards': manOfMatchAwards,
    };
  }

  factory PlayerStatsModel.fromMap(String uid, Map<String, dynamic> data) {
    return PlayerStatsModel(
      uid: uid,
      matches: (data['matches'] as num?)?.toInt() ?? 0,
      battingInnings: (data['batting_innings'] as num?)?.toInt() ?? 0,
      runs: (data['runs'] as num?)?.toInt() ?? 0,
      wickets: (data['wickets'] as num?)?.toInt() ?? 0,
      highestScore: (data['highest_score'] as num?)?.toInt() ?? 0,
      singleMatches: (data['single_matches'] as num?)?.toInt() ?? 0,
      singleBattingInnings: (data['single_batting_innings'] as num?)?.toInt() ?? 0,
      singleRuns: (data['single_runs'] as num?)?.toInt() ?? 0,
      singleWickets: (data['single_wickets'] as num?)?.toInt() ?? 0,
      singleHighestScore: (data['single_highest_score'] as num?)?.toInt() ?? 0,
      tournamentMatches: (data['tournament_matches'] as num?)?.toInt() ?? 0,
      tournamentBattingInnings: (data['tournament_batting_innings'] as num?)?.toInt() ?? 0,
      tournamentRuns: (data['tournament_runs'] as num?)?.toInt() ?? 0,
      tournamentWickets: (data['tournament_wickets'] as num?)?.toInt() ?? 0,
      tournamentHighestScore: (data['tournament_highest_score'] as num?)?.toInt() ?? 0,
      notOuts: (data['not_outs'] as num?)?.toInt() ?? 0,
      ballsFaced: (data['balls_faced'] as num?)?.toInt() ?? 0,
      thirties: (data['thirties'] as num?)?.toInt() ?? 0,
      fifties: (data['fifties'] as num?)?.toInt() ?? 0,
      hundreds: (data['hundreds'] as num?)?.toInt() ?? 0,
      fours: (data['fours'] as num?)?.toInt() ?? 0,
      sixes: (data['sixes'] as num?)?.toInt() ?? 0,
      ducks: (data['ducks'] as num?)?.toInt() ?? 0,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      losses: (data['losses'] as num?)?.toInt() ?? 0,
      bowlingInnings: (data['bowling_innings'] as num?)?.toInt() ?? 0,
      overs: (data['overs'] ?? 0.0).toDouble(),
      maidens: (data['maidens'] as num?)?.toInt() ?? 0,
      runsConceded: (data['runs_conceded'] as num?)?.toInt() ?? 0,
      bestBowling: data['best_bowling'] ?? '0/0',
      threeWkts: (data['three_wkts'] as num?)?.toInt() ?? 0,
      fiveWkts: (data['five_wkts'] as num?)?.toInt() ?? 0,
      wideBalls: (data['wide_balls'] as num?)?.toInt() ?? 0,
      noBalls: (data['no_balls'] as num?)?.toInt() ?? 0,
      dotBalls: (data['dot_balls'] as num?)?.toInt() ?? 0,
      manOfMatchAwards: (data['man_of_match_awards'] as num?)?.toInt() ?? 0,
    );
  }
}
