import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:x_cricket/core/theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../utils/ui_utils.dart';
import 'auth_controller.dart';

class RulesController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Existing scoring rules ──────────────────────────
  final RxInt wideRuns = 1.obs;
  final RxInt noBallRuns = 1.obs;
  final RxBool freeHitEnabled = true.obs;

  // ── Custom over rules ───────────────────────────────
  final RxBool customRulesEnabled = false.obs;
  final RxBool lastPlayerCanPlay = true.obs;
  final RxInt maxBattingOvers = 2.obs;
  final RxInt maxBowlingOvers = 3.obs;
  final RxBool isTournamentEnabled = true.obs;
  final RxBool isApkApproved = false.obs;

  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    listenToRules();
    listenToSiteSettings();
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
            lastPlayerCanPlay.value = data['last_player_can_play'] ?? true;
            maxBattingOvers.value =
                data['max_batting_overs'] ?? AppConstants.maxBatsmanOvers;
            maxBowlingOvers.value =
                data['max_bowling_overs'] ?? AppConstants.maxBowlerOvers;
            isTournamentEnabled.value = data['tournament_mode_enabled'] ?? true;
          }
          isLoading.value = false;
        });
  }

  void listenToSiteSettings() {
    _firestore
        .collection(AppConstants.settingsCollection)
        .doc('site_settings')
        .snapshots()
        .listen((doc) async {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            isApkApproved.value = data['apk_approveed'] ?? false;

            final String minVersion = data['min_version'] ?? '1.0.0';
            final String updateUrl = data['update_url'] ?? '';

            await _checkForUpdate(minVersion, updateUrl);
          }
        });
  }

  Future<void> _checkForUpdate(String minVer, String url) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      if (_isVersionLower(currentVersion, minVer)) {
        _showUpdateDialog(url);
      }
    } catch (e) {
      debugPrint('Error checking update: $e');
    }
  }

  bool _isVersionLower(String current, String min) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> minParts = min.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int m = i < minParts.length ? minParts[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showUpdateDialog(String url) {
    if (Get.isDialogOpen ?? false) return;

    final context = Get.context!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B263B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with gradient background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'Update Required',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                Text(
                  'A new version of the app is available with exciting new features and improvements. Please update to continue using the app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                // Action Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      if (url.isNotEmpty) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Update Now',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> updateRules({
    int? wide,
    int? noBall,
    bool? freeHit,
    bool? customEnabled,
    bool? lastPlayerPlay,
    int? maxBatting,
    int? maxBowling,
    bool? tournamentEnabled,
  }) async {
    try {
      final authController = Get.find<AuthController>();
      if (!(authController.currentUser?.isAdmin ?? false)) {
        UIUtils.showError('Permission denied: Admin role required');
        return;
      }

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
            if (tournamentEnabled != null)
              'tournament_mode_enabled': tournamentEnabled,
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
  bool isBatsmanOverLimitReached(int legalBallsFaced) =>
      customRulesEnabled.value &&
      legalBallsFaced >= (maxBattingOvers.value * 6);

  /// Check if a bowler has exceeded their bowling over limit.
  bool isBowlerOverLimitReached(int oversBowled) =>
      customRulesEnabled.value && oversBowled >= maxBowlingOvers.value;
}
