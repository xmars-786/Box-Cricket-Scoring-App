import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user in the system with role-based access.
class AppUser {
  final String uid;
  final String name;
  final String email; // kept for backward compat, prefer phone
  final String phone;
  final String role; // 'admin', 'player'
  final bool isApproved;
  final bool isPreRegistered; // true = admin created, no Auth account yet
  final String? profileImageUrl;
  final int totalRuns;
  final int totalWickets;
  final int matchesPlayed;
  final int highestScore;
  final DateTime createdAt;
  final DateTime lastLogin;

  AppUser({
    required this.uid,
    required this.name,
    this.email = '',
    this.phone = '',
    this.role = 'player',
    this.isApproved = false,
    this.isPreRegistered = false,
    this.profileImageUrl,
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.matchesPlayed = 0,
    this.highestScore = 0,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) : createdAt = createdAt ?? DateTime.now(),
       lastLogin = lastLogin ?? DateTime.now();

  /// Create from Firestore document snapshot
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role:
          data['role'] == 'super_admin' ? 'admin' : (data['role'] ?? 'player'),
      isApproved: data['is_approved'] ?? false,
      isPreRegistered: data['is_pre_registered'] ?? false,
      profileImageUrl:
          data['profile_image'] ?? data['profile_image_url'], // Support both
      totalRuns: data['total_runs'] ?? 0,
      totalWickets: data['total_wickets'] ?? 0,
      matchesPlayed: data['matches_played'] ?? 0,
      highestScore: data['highest_score'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['last_login'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'is_approved': isApproved,
      'is_pre_registered': isPreRegistered,
      'profile_image': profileImageUrl, // Changed field name
      'total_runs': totalRuns,
      'total_wickets': totalWickets,
      'matches_played': matchesPlayed,
      'highest_score': highestScore,
      'created_at': Timestamp.fromDate(createdAt),
      'last_login': Timestamp.fromDate(lastLogin),
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isApproved,
    bool? isPreRegistered,
    String? profileImageUrl,
    int? totalRuns,
    int? totalWickets,
    int? matchesPlayed,
    int? highestScore,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      isPreRegistered: isPreRegistered ?? this.isPreRegistered,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      totalRuns: totalRuns ?? this.totalRuns,
      totalWickets: totalWickets ?? this.totalWickets,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      highestScore: highestScore ?? this.highestScore,
      createdAt: createdAt,
      lastLogin: lastLogin,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isPlayer => role == 'player';
}
