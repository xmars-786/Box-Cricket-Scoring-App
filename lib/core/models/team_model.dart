import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a master team template.
class TeamModel {
  final String id;
  final String name;
  final List<String> playerIds;
  final String createdBy;
  final DateTime createdAt;

  TeamModel({
    required this.id,
    required this.name,
    required this.playerIds,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TeamModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamModel(
      id: doc.id,
      name: data['name'] ?? '',
      playerIds: List<String>.from(data['player_ids'] ?? []),
      createdBy: data['created_by'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'player_ids': playerIds,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  TeamModel copyWith({
    String? name,
    List<String>? playerIds,
  }) {
    return TeamModel(
      id: id,
      name: name ?? this.name,
      playerIds: playerIds ?? this.playerIds,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
