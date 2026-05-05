import 'package:x_cricket/core/models/player_model.dart';

class TournamentPlayerStats {
  final String playerId;
  final String name;
  final String teamName;
  int matches = 0;
  int runs = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  int wickets = 0;
  int runsConceded = 0;
  int ballsBowled = 0;
  int highestScore = 0;
  int bestWickets = 0;
  int bestRunsConceded = 999;
  int catches = 0;

  TournamentPlayerStats({
    required this.playerId,
    required this.name,
    required this.teamName,
  });

  double get strikeRate => ballsFaced == 0 ? 0.0 : (runs * 100) / ballsFaced;
  double get economy => ballsBowled == 0 ? 0.0 : (runsConceded * 6) / ballsBowled;
  String get bestBowling => bestWickets == 0 ? '-' : '$bestWickets/$bestRunsConceded';
  
  String get oversBowledDisplay {
    final wholeOvers = ballsBowled ~/ 6;
    final extraBalls = ballsBowled % 6;
    return '$wholeOvers.$extraBalls';
  }

  void aggregate(PlayerModel matchPlayer) {
    matches++;
    runs += matchPlayer.runsScored;
    ballsFaced += matchPlayer.ballsFaced;
    fours += matchPlayer.fours;
    sixes += matchPlayer.sixes;
    catches += matchPlayer.catches;
    
    if (matchPlayer.runsScored > highestScore) {
      highestScore = matchPlayer.runsScored;
    }

    if (matchPlayer.ballsBowled > 0) {
      wickets += matchPlayer.wicketsTaken;
      runsConceded += matchPlayer.runsConceded;
      ballsBowled += matchPlayer.ballsBowled;

      // Best Bowling: prioritize wickets, then fewer runs
      if (matchPlayer.wicketsTaken > bestWickets) {
        bestWickets = matchPlayer.wicketsTaken;
        bestRunsConceded = matchPlayer.runsConceded;
      } else if (matchPlayer.wicketsTaken == bestWickets && matchPlayer.wicketsTaken > 0) {
        if (matchPlayer.runsConceded < bestRunsConceded) {
          bestRunsConceded = matchPlayer.runsConceded;
        }
      }
    }
  }
}
