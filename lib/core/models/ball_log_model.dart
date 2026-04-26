import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single ball delivery in the match.
class BallLog {
  final String id;
  final String matchId;
  final String innings; // 'A' or 'B'
  final int overNumber;
  final int ballNumber;
  final String batsmanId;
  final String? nonStrikerId;
  final String bowlerId;
  final int runs;
  final String ballType; // 'normal', 'wide', 'no_ball', 'wicket'
  final bool isWicket;
  final String? dismissalType;
  final String? dismissedPlayerId;
  final bool isFour;
  final bool isSix;
  final bool isBye;
  final bool isLegBye;
  final int extraRuns;
  final bool isFreeHit;
  final DateTime timestamp;
  final String scoredBy; // Scorer user ID

  BallLog({
    required this.id,
    required this.matchId,
    required this.innings,
    required this.overNumber,
    required this.ballNumber,
    required this.batsmanId,
    this.nonStrikerId,
    required this.bowlerId,
    required this.runs,
    this.ballType = 'normal',
    this.isWicket = false,
    this.dismissalType,
    this.dismissedPlayerId,
    this.isFour = false,
    this.isSix = false,
    this.isBye = false,
    this.isLegBye = false,
    this.extraRuns = 0,
    this.isFreeHit = false,
    DateTime? timestamp,
    this.scoredBy = '',
  }) : timestamp = timestamp ?? DateTime.now();

  factory BallLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BallLog(
      id: doc.id,
      matchId: data['match_id'] ?? '',
      innings: data['innings'] ?? 'A',
      overNumber: data['over_number'] ?? 0,
      ballNumber: data['ball_number'] ?? 0,
      batsmanId: data['batsman_id'] ?? '',
      nonStrikerId: data['non_striker_id'],
      bowlerId: data['bowler_id'] ?? '',
      runs: data['runs'] ?? 0,
      ballType: data['ball_type'] ?? 'normal',
      isWicket: data['is_wicket'] ?? false,
      dismissalType: data['dismissal_type'],
      dismissedPlayerId: data['dismissed_player_id'],
      isFour: data['is_four'] ?? false,
      isSix: data['is_six'] ?? false,
      isBye: data['is_bye'] ?? false,
      isLegBye: data['is_leg_bye'] ?? false,
      extraRuns: data['extra_runs'] ?? 0,
      isFreeHit: data['is_free_hit'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scoredBy: data['scored_by'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'match_id': matchId,
      'innings': innings,
      'over_number': overNumber,
      'ball_number': ballNumber,
      'batsman_id': batsmanId,
      'non_striker_id': nonStrikerId,
      'bowler_id': bowlerId,
      'runs': runs,
      'ball_type': ballType,
      'is_wicket': isWicket,
      'dismissal_type': dismissalType,
      'dismissed_player_id': dismissedPlayerId,
      'is_four': isFour,
      'is_six': isSix,
      'is_bye': isBye,
      'is_leg_bye': isLegBye,
      'extra_runs': extraRuns,
      'is_free_hit': isFreeHit,
      'timestamp': Timestamp.fromDate(timestamp),
      'scored_by': scoredBy,
    };
  }

  /// Display string for the ball (e.g., "4", "W", "Wd+1", "NB+2", "4B", "4LB")
  String get displayText {
    String text = '';
    
    if (isWicket) {
      if (ballType == 'wide') {
        text = runs > 0 ? 'Wd+$runs+W' : 'Wd+W';
      } else if (ballType == 'no_ball') {
        text = runs > 0 ? 'NB+$runs+W' : 'NB+W';
      } else {
        text = runs > 0 ? 'W+$runs' : 'W';
      }
    } else if (ballType == 'wide') {
      text = runs > 0 ? 'Wd+$runs' : 'Wd';
    } else if (ballType == 'no_ball') {
      text = runs > 0 ? 'NB+$runs' : 'NB';
    } else if (ballType == 'bye') {
      text = runs > 0 ? '${runs}B' : 'B';
    } else if (ballType == 'leg_bye') {
      text = runs > 0 ? '${runs}LB' : 'LB';
    } else {
      text = runs.toString();
    }
    
    if (isFreeHit && !isWicket) return '$text(FH)';
    return text;
  }

  /// Total runs from this ball (including extras)
  int get totalRuns => runs + extraRuns;

  bool get isWide => ballType == 'wide';
  bool get isNoBall => ballType == 'no_ball';
  bool get isNormal => ballType == 'normal';
  bool get isExtra => ballType != 'normal' && ballType != 'wicket';
}
