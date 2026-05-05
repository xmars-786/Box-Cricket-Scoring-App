import 'match_model.dart';
import 'player_model.dart';

/// Helper model for the Player Profile screen to associate a match with the player's performance.
class PlayerMatchHistoryModel {
  final MatchModel match;
  final PlayerModel performance;

  PlayerMatchHistoryModel({required this.match, required this.performance});

  bool get isWin {
    if (match.winnerId == null) return false;
    final playerTeamId =
        performance.teamId == 'A' ? match.teamAId : match.teamBId;
    return match.winnerId == playerTeamId;
  }
}
