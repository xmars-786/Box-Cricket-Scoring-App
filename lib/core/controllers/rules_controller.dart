import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants/app_constants.dart';
import '../utils/ui_utils.dart';

class RulesController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Existing scoring rules ──────────────────────────
  final RxInt wideRuns = 1.obs;
  final RxInt noBallRuns = 1.obs;
  final RxBool freeHitEnabled = true.obs;

  // ── Custom over rules ───────────────────────────────
  final RxBool customRulesEnabled = false.obs;
  final RxBool lastPlayerCanPlay = false.obs;
  final RxInt maxBattingOvers = 2.obs;
  final RxInt maxBowlingOvers = 3.obs;

  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    listenToRules();
  }

  void listenToRules() {
    _firestore
        .collection(AppConstants.settingsCollection)
        .doc(AppConstants.rulesDoc)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        wideRuns.value = data['wide_runs'] ?? 1;
        noBallRuns.value = data['no_ball_runs'] ?? 1;
        freeHitEnabled.value = data['no_ball_free_hit'] ?? true;
        customRulesEnabled.value = data['custom_rules_enabled'] ?? false;
        lastPlayerCanPlay.value = data['last_player_can_play'] ?? false;
        maxBattingOvers.value =
            data['max_batting_overs'] ?? AppConstants.maxBatsmanOvers;
        maxBowlingOvers.value =
            data['max_bowling_overs'] ?? AppConstants.maxBowlerOvers;
      }
      isLoading.value = false;
    });
  }

  Future<void> updateRules({
    int? wide,
    int? noBall,
    bool? freeHit,
    bool? customEnabled,
    bool? lastPlayerPlay,
    int? maxBatting,
    int? maxBowling,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.settingsCollection)
          .doc(AppConstants.rulesDoc)
          .set({
        if (wide != null) 'wide_runs': wide,
        if (noBall != null) 'no_ball_runs': noBall,
        if (freeHit != null) 'no_ball_free_hit': freeHit,
        if (customEnabled != null) 'custom_rules_enabled': customEnabled,
        if (lastPlayerPlay != null) 'last_player_can_play': lastPlayerPlay,
        if (maxBatting != null) 'max_batting_overs': maxBatting,
        if (maxBowling != null) 'max_bowling_overs': maxBowling,
      }, SetOptions(merge: true));
      // UIUtils.showSuccess('Rules updated successfully!');
    } catch (e) {
      UIUtils.showError('Failed to update rules: $e');
    }
  }

  /// Returns effective total overs for a match.
  /// If custom rules are enabled, uses a high number (since innings ends based on player quotas)
  /// else uses the per-match value.
  int effectiveOvers(int perMatchOvers, {int teamSize = 11}) =>
      customRulesEnabled.value
          ? teamSize * maxBattingOvers.value
          : perMatchOvers;

  /// Check if a batsman has exceeded their batting over limit.
  bool isBatsmanOverLimitReached(int ballsFaced) =>
      customRulesEnabled.value && ballsFaced >= (maxBattingOvers.value * 6);

  /// Check if a bowler has exceeded their bowling over limit.
  bool isBowlerOverLimitReached(int oversBowled) =>
      customRulesEnabled.value && oversBowled >= maxBowlingOvers.value;
}
