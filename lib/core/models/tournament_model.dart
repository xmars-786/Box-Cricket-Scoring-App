import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentType { league, knockout, final_ }

class TournamentModel {
  final String id;
  final String name;
  final String createdBy;
  final List<String> teamIds;
  final List<String> teamNames;
  final String status; // 'upcoming', 'live', 'ongoing', 'completed', 'closed'
  final String type; // 'league', 'knockout'
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? winnerTeamId;
  final bool isScheduleGenerated;
  final int defaultOvers;
  final int ballsPerOver;
  final bool customRulesEnabled;
  final bool lastPlayerCanPlay;
  final int? maxBattingOvers;
  final int? maxBowlingOvers;

  TournamentModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.teamIds,
    required this.teamNames,
    required this.startDate,
    required this.endDate,
    this.status = 'upcoming',
    this.type = 'league',
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.winnerTeamId,
    this.isScheduleGenerated = false,
    this.defaultOvers = 10,
    this.ballsPerOver = 6,
    this.customRulesEnabled = false,
    this.lastPlayerCanPlay = false,
    this.maxBattingOvers,
    this.maxBowlingOvers,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TournamentModel(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['created_by'] ?? '',
      teamIds: List<String>.from(data['team_ids'] ?? []),
      teamNames: List<String>.from(data['team_names'] ?? []),
      status: data['status'] ?? 'upcoming',
      type: data['type'] ?? 'league',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['start_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
      startedAt: (data['started_at'] as Timestamp?)?.toDate(),
      completedAt: (data['completed_at'] as Timestamp?)?.toDate(),
      winnerTeamId: data['winner_team_id'],
      isScheduleGenerated: data['is_schedule_generated'] ?? false,
      defaultOvers: data['default_overs'] ?? 10,
      ballsPerOver: data['balls_per_over'] ?? 6,
      customRulesEnabled: data['custom_rules_enabled'] ?? false,
      lastPlayerCanPlay: data['last_player_can_play'] ?? false,
      maxBattingOvers: data['max_batting_overs'],
      maxBowlingOvers: data['max_bowling_overs'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'created_by': createdBy,
      'team_ids': teamIds,
      'team_names': teamNames,
      'status': status,
      'type': type,
      'created_at': Timestamp.fromDate(createdAt),
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'started_at': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completed_at':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'winner_team_id': winnerTeamId,
      'is_schedule_generated': isScheduleGenerated,
      'default_overs': defaultOvers,
      'balls_per_over': ballsPerOver,
      'custom_rules_enabled': customRulesEnabled,
      'last_player_can_play': lastPlayerCanPlay,
      'max_batting_overs': maxBattingOvers,
      'max_bowling_overs': maxBowlingOvers,
    };
  }

  TournamentModel copyWith({
    String? name,
    String? status,
    String? type,
    List<String>? teamIds,
    List<String>? teamNames,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? startedAt,
    DateTime? completedAt,
    String? winnerTeamId,
    bool? isScheduleGenerated,
    int? defaultOvers,
    int? ballsPerOver,
    bool? customRulesEnabled,
    bool? lastPlayerCanPlay,
    int? maxBattingOvers,
    int? maxBowlingOvers,
  }) {
    return TournamentModel(
      id: id,
      name: name ?? this.name,
      createdBy: createdBy,
      teamIds: teamIds ?? this.teamIds,
      teamNames: teamNames ?? this.teamNames,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      winnerTeamId: winnerTeamId ?? this.winnerTeamId,
      isScheduleGenerated: isScheduleGenerated ?? this.isScheduleGenerated,
      defaultOvers: defaultOvers ?? this.defaultOvers,
      ballsPerOver: ballsPerOver ?? this.ballsPerOver,
      customRulesEnabled: customRulesEnabled ?? this.customRulesEnabled,
      lastPlayerCanPlay: lastPlayerCanPlay ?? this.lastPlayerCanPlay,
      maxBattingOvers: maxBattingOvers ?? this.maxBattingOvers,
      maxBowlingOvers: maxBowlingOvers ?? this.maxBowlingOvers,
    );
  }

  String? get winnerName {
    if (winnerTeamId == null) return null;
    final index = teamIds.indexOf(winnerTeamId!);
    if (index != -1 && index < teamNames.length) {
      return teamNames[index];
    }
    return null;
  }
}
