import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive model for overall player statistics.
class PlayerStatsModel {
  final String uid;
  
  // Batting Stats
  final int matches;
  final int battingInnings;
  final int notOuts;
  final int runs;
  final int ballsFaced;
  final int highestScore;
  final int thirties;
  final int fifties;
  final int hundreds;
  final int fours;
  final int sixes;
  final int ducks;
  final int wins;
  final int losses;

  // Bowling Stats
  final int bowlingInnings;
  final double overs;
  final int maidens;
  final int runsConceded;
  final int wickets;
  final String bestBowling;
  final int threeWkts;
  final int fiveWkts;
  final int wideBalls;
  final int noBalls;
  final int dotBalls;

  PlayerStatsModel({
    required this.uid,
    this.matches = 0,
    this.battingInnings = 0,
    this.notOuts = 0,
    this.runs = 0,
    this.ballsFaced = 0,
    this.highestScore = 0,
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
    this.wickets = 0,
    this.bestBowling = '0/0',
    this.threeWkts = 0,
    this.fiveWkts = 0,
    this.wideBalls = 0,
    this.noBalls = 0,
    this.dotBalls = 0,
  });

  // Calculated Getters
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
    // Convert overs (e.g. 2.3) to balls to be precise
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

  factory PlayerStatsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PlayerStatsModel(
      uid: doc.id,
      matches: data['matches'] ?? 0,
      battingInnings: data['batting_innings'] ?? 0,
      notOuts: data['not_outs'] ?? 0,
      runs: data['runs'] ?? 0,
      ballsFaced: data['balls_faced'] ?? 0,
      highestScore: data['highest_score'] ?? 0,
      thirties: data['thirties'] ?? 0,
      fifties: data['fifties'] ?? 0,
      hundreds: data['hundreds'] ?? 0,
      fours: data['fours'] ?? 0,
      sixes: data['sixes'] ?? 0,
      ducks: data['ducks'] ?? 0,
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
      bowlingInnings: data['bowling_innings'] ?? 0,
      overs: (data['overs'] ?? 0.0).toDouble(),
      maidens: data['maidens'] ?? 0,
      runsConceded: data['runs_conceded'] ?? 0,
      wickets: data['wickets'] ?? 0,
      bestBowling: data['best_bowling'] ?? '0/0',
      threeWkts: data['three_wkts'] ?? 0,
      fiveWkts: data['five_wkts'] ?? 0,
      wideBalls: data['wide_balls'] ?? 0,
      noBalls: data['no_balls'] ?? 0,
      dotBalls: data['dot_balls'] ?? 0,
    );
  }
}
