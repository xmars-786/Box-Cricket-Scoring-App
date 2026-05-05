import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a player in a match with batting and bowling stats.
class PlayerModel {
  final String id;
  final String name;
  final String role; // 'batsman', 'bowler', 'all_rounder'
  final String teamId; // 'A' or 'B'
  final String? profileImageUrl; // Player uploaded profile image

  // Batting stats
  final int runsScored;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final bool isOut;
  final String? dismissalType;
  final String? dismissedBy;
  final double oversPlayed; // Track batsman overs (max 2)

  // Bowling stats
  final int oversBowled;
  final int ballsBowled; // Balls in current over
  final int runsConceded;
  final int wicketsTaken;
  final int widesBowled;
  final int noBallsBowled;
  final int maidens;
  final int catches;
  final int legalBallsFaced; // Track legal balls for quota (excludes Wides and No Balls)

  PlayerModel({
    required this.id,
    required this.name,
    this.role = 'all_rounder',
    this.teamId = 'A',
    this.profileImageUrl,
    this.runsScored = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissalType,
    this.dismissedBy,
    this.oversPlayed = 0,
    this.oversBowled = 0,
    this.ballsBowled = 0,
    this.runsConceded = 0,
    this.wicketsTaken = 0,
    this.widesBowled = 0,
    this.noBallsBowled = 0,
    this.maidens = 0,
    this.catches = 0,
    this.legalBallsFaced = 0,
  });

  factory PlayerModel.fromMap(Map<String, dynamic> map) {
    return PlayerModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'all_rounder',
      teamId: map['team_id'] ?? 'A',
      profileImageUrl: map['profile_image_url'],
      runsScored: (map['runs_scored'] as num?)?.toInt() ?? 0,
      ballsFaced: (map['balls_faced'] as num?)?.toInt() ?? 0,
      fours: (map['fours'] as num?)?.toInt() ?? 0,
      sixes: (map['sixes'] as num?)?.toInt() ?? 0,
      isOut: map['is_out'] ?? false,
      dismissalType: map['dismissal_type'],
      dismissedBy: map['dismissed_by'],
      oversPlayed: (map['overs_played'] ?? 0).toDouble(),
      oversBowled: (map['overs_bowled'] as num?)?.toInt() ?? 0,
      ballsBowled: (map['balls_bowled'] as num?)?.toInt() ?? 0,
      runsConceded: (map['runs_conceded'] as num?)?.toInt() ?? 0,
      wicketsTaken: (map['wickets_taken'] as num?)?.toInt() ?? 0,
      widesBowled: (map['wides_bowled'] as num?)?.toInt() ?? 0,
      noBallsBowled: (map['no_balls_bowled'] as num?)?.toInt() ?? 0,
      maidens: (map['maidens'] as num?)?.toInt() ?? 0,
      catches: (map['catches'] as num?)?.toInt() ?? 0,
      legalBallsFaced: (map['legal_balls_faced'] as num?)?.toInt() ?? 0,
    );
  }

  factory PlayerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerModel(
      id: doc.id,
      name: data['name'] ?? data['displayName'] ?? '',
      role: data['role'] ?? 'all_rounder',
      teamId: data['team_id'] ?? 'A',
      profileImageUrl: data['profile_image_url'] ?? data['photoURL'],
      runsScored: (data['runs_scored'] as num?)?.toInt() ?? 0,
      ballsFaced: (data['balls_faced'] as num?)?.toInt() ?? 0,
      fours: (data['fours'] as num?)?.toInt() ?? 0,
      sixes: (data['sixes'] as num?)?.toInt() ?? 0,
      isOut: data['is_out'] ?? false,
      dismissalType: data['dismissal_type'],
      dismissedBy: data['dismissed_by'],
      oversPlayed: (data['overs_played'] ?? 0).toDouble(),
      oversBowled: (data['overs_bowled'] as num?)?.toInt() ?? 0,
      ballsBowled: (data['balls_bowled'] as num?)?.toInt() ?? 0,
      runsConceded: (data['runs_conceded'] as num?)?.toInt() ?? 0,
      wicketsTaken: (data['wickets_taken'] as num?)?.toInt() ?? 0,
      widesBowled: (data['wides_bowled'] as num?)?.toInt() ?? 0,
      noBallsBowled: (data['no_balls_bowled'] as num?)?.toInt() ?? 0,
      maidens: (data['maidens'] as num?)?.toInt() ?? 0,
      catches: (data['catches'] as num?)?.toInt() ?? 0,
      legalBallsFaced: (data['legal_balls_faced'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'team_id': teamId,
      'profile_image_url': profileImageUrl,
      'runs_scored': runsScored,
      'balls_faced': ballsFaced,
      'fours': fours,
      'sixes': sixes,
      'is_out': isOut,
      'dismissal_type': dismissalType,
      'dismissed_by': dismissedBy,
      'overs_played': oversPlayed,
      'overs_bowled': oversBowled,
      'balls_bowled': ballsBowled,
      'runs_conceded': runsConceded,
      'wickets_taken': wicketsTaken,
      'wides_bowled': widesBowled,
      'no_balls_bowled': noBallsBowled,
      'maidens': maidens,
      'catches': catches,
      'legal_balls_faced': legalBallsFaced,
    };
  }

  PlayerModel copyWith({
    String? name,
    String? role,
    String? teamId,
    String? profileImageUrl,
    int? runsScored,
    int? ballsFaced,
    int? fours,
    int? sixes,
    bool? isOut,
    String? dismissalType,
    String? dismissedBy,
    double? oversPlayed,
    int? oversBowled,
    int? ballsBowled,
    int? runsConceded,
    int? wicketsTaken,
    int? widesBowled,
    int? noBallsBowled,
    int? maidens,
    int? catches,
    int? legalBallsFaced,
  }) {
    return PlayerModel(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      teamId: teamId ?? this.teamId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      runsScored: runsScored ?? this.runsScored,
      ballsFaced: ballsFaced ?? this.ballsFaced,
      fours: fours ?? this.fours,
      sixes: sixes ?? this.sixes,
      isOut: isOut ?? this.isOut,
      dismissalType: dismissalType ?? this.dismissalType,
      dismissedBy: dismissedBy ?? this.dismissedBy,
      oversPlayed: oversPlayed ?? this.oversPlayed,
      oversBowled: oversBowled ?? this.oversBowled,
      ballsBowled: ballsBowled ?? this.ballsBowled,
      runsConceded: runsConceded ?? this.runsConceded,
      wicketsTaken: wicketsTaken ?? this.wicketsTaken,
      widesBowled: widesBowled ?? this.widesBowled,
      noBallsBowled: noBallsBowled ?? this.noBallsBowled,
      maidens: maidens ?? this.maidens,
      catches: catches ?? this.catches,
      legalBallsFaced: legalBallsFaced ?? this.legalBallsFaced,
    );
  }

  /// Batting strike rate
  double get strikeRate {
    if (ballsFaced == 0) return 0.0;
    return (runsScored * 100) / ballsFaced;
  }

  /// Bowling economy rate
  double get economyRate {
    if (ballsBowled == 0) return 0.0;
    return (runsConceded * 6) / ballsBowled;
  }

  /// Bowling figures display string
  String get bowlingFigures => '$wicketsTaken/$runsConceded';

  /// Overs bowled display
  String get oversBowledDisplay {
    final wholeOvers = ballsBowled ~/ 6;
    final extraBalls = ballsBowled % 6;
    return '$wholeOvers.$extraBalls';
  }

  /// Total batting overs played in balls (effectively just balls faced)
  int get totalBattingBalls => ballsFaced;

  /// Check if batsman can still bat based on ball limit
  bool canBatWithLimit(int maxBalls) => !isOut && ballsFaced < maxBalls;

  /// Check if bowler can still bowl based on over limit
  bool canBowl(int maxOvers) => ballsBowled < (maxOvers * 6);

  /// Total balls bowled
  int get totalBowlingBalls => ballsBowled;

  /// Calculate MOTM score for this player
  double calculateMOTMScore(String winningTeamId) {
    // Man of the Match MUST be from the winning team
    if (winningTeamId.isNotEmpty && teamId != winningTeamId) {
      return -1.0; // Ineligible
    }

    double score = (runsScored * 1.0) +
        (wicketsTaken * 20.0) +
        (catches * 10.0) +
        (maidens * 15.0);

    // Economy Bonus
    final totalBalls = ballsBowled;
    if (totalBalls >= 6) {
      double overs = (totalBalls ~/ 6) + (totalBalls % 6) / 6.0;
      double econ = runsConceded / overs;
      if (econ < 6.0) score += 10;
    }

    // Strike Rate Bonus
    if (ballsFaced >= 10) {
      if (strikeRate > 150.0) score += 10;
    }

    // Winning Team Bonus
    if (winningTeamId.isNotEmpty && teamId == winningTeamId) {
      score += 10;
    }

    return score;
  }
}
