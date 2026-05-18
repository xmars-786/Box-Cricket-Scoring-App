import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import 'partnership_model.dart';

/// Represents a cricket match with all metadata.
class MatchModel {
  final String id;
  final String title;
  final String createdBy; // Admin user ID
  final String status; // 'upcoming', 'live', 'completed'
  final int totalOvers;
  final int ballsPerOver;
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
  final String? tournamentId;
  final String? tournamentName;
  final String? round;
  final String? teamAId;
  final String? teamBId;
  final String? winnerId;
  final String? manOfMatch;
  final String? manOfMatchName;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isInningsBreak;
  final int? matchNumber; // For tournament scheduling order
  final bool isKnockoutPlaceholder; // If true, teams are not yet decided
  final String? nextMatchId; // ID of the match the winner advances to
  final PartnershipModel? activePartnership;
  final List<PartnershipModel> teamAPartnerships;
  final List<PartnershipModel> teamBPartnerships;
  final List<String> teamABattingOrder;
  final List<String> teamBBattingOrder;
  final List<String> teamABowlingOrder;
  final List<String> teamBBowlingOrder;
  final Map<String, dynamic>? manOfTheMatchMap;
  final int viewerCount; // Live watchers
  final int totalViews; // Cumulative views
  MatchModel({
    required this.id,
    required this.title,
    required this.createdBy,
    this.status = 'upcoming',
    required this.totalOvers,
    this.ballsPerOver = 6,
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
    this.tournamentId,
    this.tournamentName,
    this.round,
    this.teamAId,
    this.teamBId,
    this.winnerId,
    this.manOfMatch,
    this.manOfMatchName,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.isInningsBreak = false,
    this.matchNumber,
    this.isKnockoutPlaceholder = false,
    this.nextMatchId,
    this.activePartnership,
    List<PartnershipModel>? teamAPartnerships,
    List<PartnershipModel>? teamBPartnerships,
    List<String>? teamABattingOrder,
    List<String>? teamBBattingOrder,
    List<String>? teamABowlingOrder,
    List<String>? teamBBowlingOrder,
    this.manOfTheMatchMap,
    this.viewerCount = 0,
    this.totalViews = 0,
  }) : teamAScore = teamAScore ?? MatchScore(),
       teamBScore = teamBScore ?? MatchScore(),
       teamAPartnerships = teamAPartnerships ?? [],
       teamBPartnerships = teamBPartnerships ?? [],
       teamABattingOrder = teamABattingOrder ?? [],
       teamBBattingOrder = teamBBattingOrder ?? [],
       teamABowlingOrder = teamABowlingOrder ?? [],
       teamBBowlingOrder = teamBBowlingOrder ?? [],
       createdAt = createdAt ?? DateTime.now();

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      title: data['title'] ?? '',
      createdBy: data['created_by'] ?? '',
      status: data['status'] ?? 'upcoming',
      totalOvers: (data['total_overs'] as num?)?.toInt() ?? 0,
      ballsPerOver: (data['balls_per_over'] as num?)?.toInt() ?? 6,
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
      tournamentId: data['tournament_id'],
      tournamentName: data['tournament_name'],
      round: data['round'],
      teamAId: data['team_a_id'],
      teamBId: data['team_b_id'],
      winnerId: data['winner_id'],
      manOfMatch: data['man_of_match'],
      manOfMatchName: data['man_of_match_name'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['started_at'] as Timestamp?)?.toDate(),
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      isInningsBreak: data['is_innings_break'] ?? false,
      matchNumber: data['match_number'],
      isKnockoutPlaceholder: data['is_knockout_placeholder'] ?? false,
      nextMatchId: data['next_match_id'],
      activePartnership:
          data['active_partnership'] != null
              ? PartnershipModel.fromMap(data['active_partnership'])
              : null,
      teamAPartnerships:
          (data['team_a_partnerships'] as List? ?? [])
              .map((e) => PartnershipModel.fromMap(e))
              .toList(),
      teamBPartnerships:
          (data['team_b_partnerships'] as List? ?? [])
              .map((e) => PartnershipModel.fromMap(e))
              .toList(),
      teamABattingOrder: List<String>.from(data['team_a_batting_order'] ?? []),
      teamBBattingOrder: List<String>.from(data['team_b_batting_order'] ?? []),
      teamABowlingOrder: List<String>.from(data['team_a_bowling_order'] ?? []),
      teamBBowlingOrder: List<String>.from(data['team_b_bowling_order'] ?? []),
      manOfTheMatchMap: data['man_of_the_match_map'],
      viewerCount: (data['viewer_count'] as num?)?.toInt() ?? 0,
      totalViews: (data['total_views'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'created_by': createdBy,
      'status': status,
      'total_overs': totalOvers,
      'balls_per_over': ballsPerOver,
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
      'tournament_id': tournamentId,
      'tournament_name': tournamentName,
      'round': round,
      'team_a_id': teamAId,
      'team_b_id': teamBId,
      'winner_id': winnerId,
      'man_of_match': manOfMatch,
      'man_of_match_name': manOfMatchName,
      'created_at': Timestamp.fromDate(createdAt),
      'started_at': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completed_at':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'is_innings_break': isInningsBreak,
      'match_number': matchNumber,
      'is_knockout_placeholder': isKnockoutPlaceholder,
      'next_match_id': nextMatchId,
      'active_partnership': activePartnership?.toMap(),
      'team_a_partnerships': teamAPartnerships.map((e) => e.toMap()).toList(),
      'team_b_partnerships': teamBPartnerships.map((e) => e.toMap()).toList(),
      'team_a_batting_order': teamABattingOrder,
      'team_b_batting_order': teamBBattingOrder,
      'team_a_bowling_order': teamABowlingOrder,
      'team_b_bowling_order': teamBBowlingOrder,
      'man_of_the_match_map': manOfTheMatchMap,
      'viewer_count': viewerCount,
      'total_views': totalViews,
    };
  }

  MatchModel copyWith({
    String? title,
    String? status,
    int? totalOvers,
    int? ballsPerOver,
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
    String? tournamentId,
    String? tournamentName,
    String? round,
    String? teamAId,
    String? teamBId,
    String? winnerId,
    String? manOfMatch,
    String? manOfMatchName,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? isInningsBreak,
    bool? isKnockoutPlaceholder,
    String? nextMatchId,
    List<PartnershipModel>? teamAPartnerships,
    List<PartnershipModel>? teamBPartnerships,
    List<String>? teamABattingOrder,
    List<String>? teamBBattingOrder,
    List<String>? teamABowlingOrder,
    List<String>? teamBBowlingOrder,
    Map<String, dynamic>? manOfTheMatchMap,
    int? viewerCount,
    int? totalViews,
  }) {
    return MatchModel(
      id: id,
      title: title ?? this.title,
      createdBy: createdBy,
      status: status ?? this.status,
      totalOvers: totalOvers ?? this.totalOvers,
      ballsPerOver: ballsPerOver ?? this.ballsPerOver,
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
      tournamentId: tournamentId ?? this.tournamentId,
      tournamentName: tournamentName ?? this.tournamentName,
      round: round ?? this.round,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      winnerId: winnerId ?? this.winnerId,
      manOfMatch: manOfMatch ?? this.manOfMatch,
      manOfMatchName: manOfMatchName ?? this.manOfMatchName,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      isInningsBreak: isInningsBreak ?? this.isInningsBreak,
      matchNumber: matchNumber ?? this.matchNumber,
      isKnockoutPlaceholder:
          isKnockoutPlaceholder ?? this.isKnockoutPlaceholder,
      nextMatchId: nextMatchId ?? this.nextMatchId,
      activePartnership: activePartnership ?? this.activePartnership,
      teamAPartnerships: teamAPartnerships ?? this.teamAPartnerships,
      teamBPartnerships: teamBPartnerships ?? this.teamBPartnerships,
      teamABattingOrder: teamABattingOrder ?? this.teamABattingOrder,
      teamBBattingOrder: teamBBattingOrder ?? this.teamBBattingOrder,
      teamABowlingOrder: teamABowlingOrder ?? this.teamABowlingOrder,
      teamBBowlingOrder: teamBBowlingOrder ?? this.teamBBowlingOrder,
      manOfTheMatchMap: manOfTheMatchMap ?? this.manOfTheMatchMap,
      viewerCount: viewerCount ?? this.viewerCount,
      totalViews: totalViews ?? this.totalViews,
    );
  }

  /// Get current innings score
  MatchScore get currentScore =>
      currentInnings == 'A' ? teamAScore : teamBScore;

  /// Get batting team name
  String get battingTeamName => currentInnings == 'A' ? teamAName : teamBName;

  /// Get bowling team name
  String get bowlingTeamName => currentInnings == 'A' ? teamBName : teamAName;

  bool get isLive => status == AppConstants.matchLive;
  bool get isCompleted => status == AppConstants.matchCompleted;
  bool get isUpcoming => status == AppConstants.matchUpcoming;

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

  /// Recalculates the match result and winner ID based on current scores and batting order.
  /// Useful for data migration and ensuring historical accuracy.
  Map<String, String?> recalculateResult() {
    if (status != AppConstants.matchCompleted) {
      return {'result': result, 'winner_id': winnerId};
    }

    final initialTeam = initialBattingTeam; // Team 1 (Defending)
    final chasingTeamId = initialTeam == 'A' ? 'B' : 'A'; // Team 2 (Chasing)

    final score1 = initialTeam == 'A' ? teamAScore.runs : teamBScore.runs;
    final score2 = initialTeam == 'A' ? teamBScore.runs : teamAScore.runs;

    final name1 = initialTeam == 'A' ? teamAName : teamBName;
    final name2 = initialTeam == 'A' ? teamBName : teamAName;

    final id1 = initialTeam == 'A' ? teamAId : teamBId;
    final id2 = initialTeam == 'A' ? teamBId : teamAId;

    String? resultText;
    String? finalWinnerId;
    String? winningTeam; // 'A' or 'B'

    if (score2 > score1) {
      // Chasing team won
      final wicketsLost = initialTeam == 'A' ? teamBScore.wickets : teamAScore.wickets;
      final chasingTeamSize =
          initialTeam == 'A' ? teamBPlayers.length : teamAPlayers.length;

      int remainingWickets = (chasingTeamSize - 1) - wicketsLost;
      if (lastPlayerCanPlay) {
        remainingWickets = chasingTeamSize - wicketsLost;
      }
      if (remainingWickets < 0) remainingWickets = 0;

      resultText = '$name2 won by $remainingWickets wickets';
      finalWinnerId = id2;
      winningTeam = chasingTeamId;
    } else if (score1 > score2) {
      // Defending team won
      resultText = '$name1 won by ${score1 - score2} runs';
      finalWinnerId = id1;
      winningTeam = initialTeam;
    } else {
      resultText = 'Match Tied';
      finalWinnerId = null;
      winningTeam = null;
    }

    return {
      'result': resultText,
      'winner_id': finalWinnerId,
      'winning_team': winningTeam,
    };
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
      runs: (map['runs'] as num?)?.toInt() ?? 0,
      wickets: (map['wickets'] as num?)?.toInt() ?? 0,
      overs: (map['overs'] as num?)?.toInt() ?? 0,
      balls: (map['balls'] as num?)?.toInt() ?? 0,
      extras: (map['extras'] as num?)?.toInt() ?? 0,
      wides: (map['wides'] as num?)?.toInt() ?? 0,
      noBalls: (map['no_balls'] as num?)?.toInt() ?? 0,
      byes: (map['byes'] as num?)?.toInt() ?? 0,
      legByes: (map['leg_byes'] as num?)?.toInt() ?? 0,
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

  /// Total balls bowled
  int get totalBalls => (overs * 6) + balls;

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
