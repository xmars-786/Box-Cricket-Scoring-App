import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a cricket match with all metadata.
class MatchModel {
  final String id;
  final String title;
  final String createdBy; // Admin user ID
  final String status; // 'upcoming', 'live', 'completed'
  final int totalOvers;
  final List<String> teamAPlayers;
  final List<String> teamBPlayers;
  final String teamAName;
  final String teamBName;
  final String groundName;
  final List<String> scorerIds; // 2–4 scorer user IDs
  final String? activeScorerId;
  final String? lastBallId;
  final bool isFreeHit;
  final MatchScore teamAScore;
  final MatchScore teamBScore;
  final String currentInnings; // 'A' or 'B'
  final String? currentBatsmanId;
  final String? currentNonStrikerId;
  final String? currentBowlerId;
  final String tossWonBy; // 'A' or 'B'
  final String tossDecision; // 'bat' or 'bowl'
  final String? teamACaptainId;
  final String? teamAViceCaptainId;
  final String? teamBCaptainId;
  final String? teamBViceCaptainId;
  final String? result;
  final bool customRulesEnabled;
  final bool lastPlayerCanPlay;
  final int? maxBattingOvers;
  final int? maxBowlingOvers;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isInningsBreak;
  final String? manOfMatch; // player ID
  final String? manOfMatchName; // player name for lists


  MatchModel({
    required this.id,
    required this.title,
    required this.createdBy,
    this.status = 'upcoming',
    required this.totalOvers,
    required this.teamAPlayers,
    required this.teamBPlayers,
    this.teamAName = 'Team A',
    this.teamBName = 'Team B',
    this.groundName = '',
    required this.scorerIds,
    this.activeScorerId,
    this.lastBallId,
    this.isFreeHit = false,
    MatchScore? teamAScore,
    MatchScore? teamBScore,
    this.currentInnings = 'A',
    this.currentBatsmanId,
    this.currentNonStrikerId,
    this.currentBowlerId,
    this.tossWonBy = 'A',
    this.tossDecision = 'bat',
    this.teamACaptainId,
    this.teamAViceCaptainId,
    this.teamBCaptainId,
    this.teamBViceCaptainId,
    this.result,
    this.customRulesEnabled = false,
    this.lastPlayerCanPlay = false,
    this.maxBattingOvers,
    this.maxBowlingOvers,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.isInningsBreak = false,
    this.manOfMatch,
    this.manOfMatchName,
  })  : teamAScore = teamAScore ?? MatchScore(),
        teamBScore = teamBScore ?? MatchScore(),
        createdAt = createdAt ?? DateTime.now();

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      title: data['title'] ?? '',
      createdBy: data['created_by'] ?? '',
      status: data['status'] ?? 'upcoming',
      totalOvers: data['total_overs'] ?? 6,
      teamAPlayers: List<String>.from(data['team_a_players'] ?? []),
      teamBPlayers: List<String>.from(data['team_b_players'] ?? []),
      teamAName: data['team_a_name'] ?? 'Team A',
      teamBName: data['team_b_name'] ?? 'Team B',
      groundName: data['ground_name'] ?? '',
      scorerIds: List<String>.from(data['scorer_ids'] ?? []),
      activeScorerId: data['active_scorer_id'],
      lastBallId: data['last_ball_id'],
      isFreeHit: data['is_free_hit'] ?? false,
      teamAScore: MatchScore.fromMap(data['team_a_score'] ?? {}),
      teamBScore: MatchScore.fromMap(data['team_b_score'] ?? {}),
      currentInnings: data['current_innings'] ?? 'A',
      currentBatsmanId: data['current_batsman_id'],
      currentNonStrikerId: data['current_non_striker_id'],
      currentBowlerId: data['current_bowler_id'],
      tossWonBy: data['toss_won_by'] ?? 'A',
      tossDecision: data['toss_decision'] ?? 'bat',
      teamACaptainId: data['team_a_captain_id'],
      teamAViceCaptainId: data['team_a_vice_captain_id'],
      teamBCaptainId: data['team_b_captain_id'],
      teamBViceCaptainId: data['team_b_vice_captain_id'],
      result: data['result'],
      customRulesEnabled: data['custom_rules_enabled'] ?? false,
      lastPlayerCanPlay: data['last_player_can_play'] ?? false,
      maxBattingOvers: data['max_batting_overs'],
      maxBowlingOvers: data['max_bowling_overs'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['started_at'] as Timestamp?)?.toDate(),
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      isInningsBreak: data['is_innings_break'] ?? false,
      manOfMatch: data['man_of_match'],
      manOfMatchName: data['man_of_match_name'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'created_by': createdBy,
      'status': status,
      'total_overs': totalOvers,
      'team_a_players': teamAPlayers,
      'team_b_players': teamBPlayers,
      'team_a_name': teamAName,
      'team_b_name': teamBName,
      'ground_name': groundName,
      'scorer_ids': scorerIds,
      'active_scorer_id': activeScorerId,
      'last_ball_id': lastBallId,
      'is_free_hit': isFreeHit,
      'team_a_score': teamAScore.toMap(),
      'team_b_score': teamBScore.toMap(),
      'current_innings': currentInnings,
      'current_batsman_id': currentBatsmanId,
      'current_non_striker_id': currentNonStrikerId,
      'current_bowler_id': currentBowlerId,
      'toss_won_by': tossWonBy,
      'toss_decision': tossDecision,
      'team_a_captain_id': teamACaptainId,
      'team_a_vice_captain_id': teamAViceCaptainId,
      'team_b_captain_id': teamBCaptainId,
      'team_b_vice_captain_id': teamBViceCaptainId,
      'result': result,
      'custom_rules_enabled': customRulesEnabled,
      'last_player_can_play': lastPlayerCanPlay,
      'max_batting_overs': maxBattingOvers,
      'max_bowling_overs': maxBowlingOvers,
      'created_at': Timestamp.fromDate(createdAt),
      'started_at': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'is_innings_break': isInningsBreak,
      'man_of_match': manOfMatch,
      'man_of_match_name': manOfMatchName,
    };
  }

  MatchModel copyWith({
    String? title,
    String? status,
    int? totalOvers,
    List<String>? teamAPlayers,
    List<String>? teamBPlayers,
    String? teamAName,
    String? teamBName,
    String? groundName,
    List<String>? scorerIds,
    String? activeScorerId,
    String? lastBallId,
    bool? isFreeHit,
    MatchScore? teamAScore,
    MatchScore? teamBScore,
    String? currentInnings,
    String? currentBatsmanId,
    String? currentNonStrikerId,
    String? currentBowlerId,
    String? tossWonBy,
    String? tossDecision,
    String? teamACaptainId,
    String? teamAViceCaptainId,
    String? teamBCaptainId,
    String? teamBViceCaptainId,
    String? result,
    bool? customRulesEnabled,
    bool? lastPlayerCanPlay,
    int? maxBattingOvers,
    int? maxBowlingOvers,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? isInningsBreak,
    String? manOfMatch,
    String? manOfMatchName,

  }) {
    return MatchModel(
      id: id,
      title: title ?? this.title,
      createdBy: createdBy,
      status: status ?? this.status,
      totalOvers: totalOvers ?? this.totalOvers,
      teamAPlayers: teamAPlayers ?? this.teamAPlayers,
      teamBPlayers: teamBPlayers ?? this.teamBPlayers,
      teamAName: teamAName ?? this.teamAName,
      teamBName: teamBName ?? this.teamBName,
      groundName: groundName ?? this.groundName,
      scorerIds: scorerIds ?? this.scorerIds,
      activeScorerId: activeScorerId ?? this.activeScorerId,
      lastBallId: lastBallId ?? this.lastBallId,
      isFreeHit: isFreeHit ?? this.isFreeHit,
      teamAScore: teamAScore ?? this.teamAScore,
      teamBScore: teamBScore ?? this.teamBScore,
      currentInnings: currentInnings ?? this.currentInnings,
      currentBatsmanId: currentBatsmanId ?? this.currentBatsmanId,
      currentNonStrikerId: currentNonStrikerId ?? this.currentNonStrikerId,
      currentBowlerId: currentBowlerId ?? this.currentBowlerId,
      tossWonBy: tossWonBy ?? this.tossWonBy,
      tossDecision: tossDecision ?? this.tossDecision,
      teamACaptainId: teamACaptainId ?? this.teamACaptainId,
      teamAViceCaptainId: teamAViceCaptainId ?? this.teamAViceCaptainId,
      teamBCaptainId: teamBCaptainId ?? this.teamBCaptainId,
      teamBViceCaptainId: teamBViceCaptainId ?? this.teamBViceCaptainId,
      result: result ?? this.result,
      customRulesEnabled: customRulesEnabled ?? this.customRulesEnabled,
      lastPlayerCanPlay: lastPlayerCanPlay ?? this.lastPlayerCanPlay,
      maxBattingOvers: maxBattingOvers ?? this.maxBattingOvers,
      maxBowlingOvers: maxBowlingOvers ?? this.maxBowlingOvers,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      isInningsBreak: isInningsBreak ?? this.isInningsBreak,
      manOfMatch: manOfMatch ?? this.manOfMatch,
      manOfMatchName: manOfMatchName ?? this.manOfMatchName,
    );
  }

  /// Get current innings score
  MatchScore get currentScore {
    return currentInnings == 'A' ? teamAScore : teamBScore;
  }

  /// Get batting team name
  String get battingTeamName =>
      currentInnings == 'A' ? teamAName : teamBName;

  /// Get bowling team name
  String get bowlingTeamName =>
      currentInnings == 'A' ? teamBName : teamAName;

  bool get isLive => status == 'live';
  bool get isCompleted => status == 'completed';
  bool get isUpcoming => status == 'upcoming';

  /// The team that batted first in the match
  String get initialBattingTeam =>
      tossWonBy == 'A'
          ? (tossDecision == 'bat' ? 'A' : 'B')
          : (tossDecision == 'bat' ? 'B' : 'A');

  /// Whether the match is currently in the second innings (Regular)
  bool get isSecondInnings {
    return currentInnings != initialBattingTeam;
  }

  /// The target score for the chasing team (runs + 1)
  int get targetScore {
    if (!isSecondInnings) return 0;
    final firstInningsScore = currentInnings == 'A' ? teamBScore : teamAScore;
    return firstInningsScore.runs + 1;
  }
}

/// Score data for a team in a match.
class MatchScore {
  final int runs;
  final int wickets;
  final int overs;
  final int balls;
  final int extras;
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;

  MatchScore({
    this.runs = 0,
    this.wickets = 0,
    this.overs = 0,
    this.balls = 0,
    this.extras = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
  });

  factory MatchScore.fromMap(Map<String, dynamic> map) {
    return MatchScore(
      runs: map['runs'] ?? 0,
      wickets: map['wickets'] ?? 0,
      overs: map['overs'] ?? 0,
      balls: map['balls'] ?? 0,
      extras: map['extras'] ?? 0,
      wides: map['wides'] ?? 0,
      noBalls: map['no_balls'] ?? 0,
      byes: map['byes'] ?? 0,
      legByes: map['leg_byes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'runs': runs,
      'wickets': wickets,
      'overs': overs,
      'balls': balls,
      'extras': extras,
      'wides': wides,
      'no_balls': noBalls,
      'byes': byes,
      'leg_byes': legByes,
    };
  }

  MatchScore copyWith({
    int? runs,
    int? wickets,
    int? overs,
    int? balls,
    int? extras,
    int? wides,
    int? noBalls,
    int? byes,
    int? legByes,
  }) {
    return MatchScore(
      runs: runs ?? this.runs,
      wickets: wickets ?? this.wickets,
      overs: overs ?? this.overs,
      balls: balls ?? this.balls,
      extras: extras ?? this.extras,
      wides: wides ?? this.wides,
      noBalls: noBalls ?? this.noBalls,
      byes: byes ?? this.byes,
      legByes: legByes ?? this.legByes,
    );
  }

  /// Formatted overs display (e.g., "3.4")
  String get oversDisplay => '$overs.$balls';

  /// Calculate run rate
  double get runRate {
    final totalBalls = (overs * 6) + balls;
    if (totalBalls == 0) return 0.0;
    return (runs * 6) / totalBalls;
  }

  /// Required run rate calculation
  double requiredRunRate(int targetRuns, int totalOvers) {
    final remainingRuns = targetRuns - runs;
    final totalBalls = totalOvers * 6;
    final ballsBowled = (overs * 6) + balls;
    final remainingBalls = totalBalls - ballsBowled;
    if (remainingBalls <= 0) return 0.0;
    return (remainingRuns * 6) / remainingBalls;
  }
}
