class PartnershipModel {
  final String batterAId;
  final String batterBId;
  final String batterAName;
  final String batterBName;
  final int batterARuns;
  final int batterABalls;
  final int batterBRuns;
  final int batterBBalls;
  final int totalRuns;
  final int totalBalls;
  final int extras;
  final int wicketNumber;
  final bool isOngoing;

  PartnershipModel({
    required this.batterAId,
    required this.batterBId,
    required this.batterAName,
    required this.batterBName,
    this.batterARuns = 0,
    this.batterABalls = 0,
    this.batterBRuns = 0,
    this.batterBBalls = 0,
    this.totalRuns = 0,
    this.totalBalls = 0,
    this.extras = 0,
    this.wicketNumber = 1,
    this.isOngoing = true,
  });

  factory PartnershipModel.fromMap(Map<String, dynamic> map) {
    return PartnershipModel(
      batterAId: map['batter_a_id'] ?? '',
      batterBId: map['batter_b_id'] ?? '',
      batterAName: map['batter_a_name'] ?? '',
      batterBName: map['batter_b_name'] ?? '',
      batterARuns: map['batter_a_runs'] ?? 0,
      batterABalls: map['batter_a_balls'] ?? 0,
      batterBRuns: map['batter_b_runs'] ?? 0,
      batterBBalls: map['batter_b_balls'] ?? 0,
      totalRuns: map['total_runs'] ?? 0,
      totalBalls: map['total_balls'] ?? 0,
      extras: map['extras'] ?? 0,
      wicketNumber: map['wicket_number'] ?? 1,
      isOngoing: map['is_ongoing'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batter_a_id': batterAId,
      'batter_b_id': batterBId,
      'batter_a_name': batterAName,
      'batter_b_name': batterBName,
      'batter_a_runs': batterARuns,
      'batter_a_balls': batterABalls,
      'batter_b_runs': batterBRuns,
      'batter_b_balls': batterBBalls,
      'total_runs': totalRuns,
      'total_balls': totalBalls,
      'extras': extras,
      'wicket_number': wicketNumber,
      'is_ongoing': isOngoing,
    };
  }

  PartnershipModel copyWith({
    String? batterAId,
    String? batterBId,
    String? batterAName,
    String? batterBName,
    int? batterARuns,
    int? batterABalls,
    int? batterBRuns,
    int? batterBBalls,
    int? totalRuns,
    int? totalBalls,
    int? extras,
    int? wicketNumber,
    bool? isOngoing,
  }) {
    return PartnershipModel(
      batterAId: batterAId ?? this.batterAId,
      batterBId: batterBId ?? this.batterBId,
      batterAName: batterAName ?? this.batterAName,
      batterBName: batterBName ?? this.batterBName,
      batterARuns: batterARuns ?? this.batterARuns,
      batterABalls: batterABalls ?? this.batterABalls,
      batterBRuns: batterBRuns ?? this.batterBRuns,
      batterBBalls: batterBBalls ?? this.batterBBalls,
      totalRuns: totalRuns ?? this.totalRuns,
      totalBalls: totalBalls ?? this.totalBalls,
      extras: extras ?? this.extras,
      wicketNumber: wicketNumber ?? this.wicketNumber,
      isOngoing: isOngoing ?? this.isOngoing,
    );
  }
}
