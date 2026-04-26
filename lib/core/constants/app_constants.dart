/// Application-wide constants for Box Cricket Scoring App.
class AppConstants {
  AppConstants._();

  // ─── Match Rules ────────────────────────────────────────
  /// Maximum overs each batsman can play
  static const int maxBatsmanOvers = 2;

  /// Maximum overs each bowler can bowl
  static const int maxBowlerOvers = 3;

  /// Number of balls per over
  static const int ballsPerOver = 6;

  /// Minimum number of scorers per match
  static const int minScorers = 2;

  /// Maximum number of scorers per match
  static const int maxScorers = 4;

  // ─── Firestore Collections ──────────────────────────────
  static const String matchesCollection = 'matches';
  static const String usersCollection = 'users';
  static const String ballLogsCollection = 'ball_logs';
  static const String playerStatsCollection = 'player_stats';
  static const String settingsCollection = 'app_settings';
  static const String rulesDoc = 'rules';

  // ─── User Roles ─────────────────────────────────────────
  static const String roleAdmin = 'admin';
  static const String rolePlayer = 'player';

  // ─── Match Status ───────────────────────────────────────
  static const String matchUpcoming = 'upcoming';
  static const String matchLive = 'live';
  static const String matchCompleted = 'completed';

  // ─── Ball Types ─────────────────────────────────────────
  static const String ballNormal = 'normal';
  static const String ballWide = 'wide';
  static const String ballNoBall = 'no_ball';
  static const String ballWicket = 'wicket';
  static const String ballBye = 'bye';
  static const String ballLegBye = 'leg_bye';

  // ─── Dismissal Types ────────────────────────────────────
  static const String dismissalBowled = 'bowled';
  static const String dismissalCaught = 'caught';
  static const String dismissalRunOut = 'run_out';
  static const String dismissalStumped = 'stumped';
  static const String dismissalLBW = 'lbw';
  static const String dismissalHitWicket = 'hit_wicket';

  // ─── App Metadata ───────────────────────────────────────
  static const String appName = 'X Cricket';
  static const String developedBy = 'DEVELOPED BY XMARS';
  static const String appVersion = 'v1.0.0';
}
