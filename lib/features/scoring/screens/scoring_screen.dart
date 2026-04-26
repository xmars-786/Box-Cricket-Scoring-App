import 'package:x_cricket/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../../../core/models/match_model.dart';
import '../../../core/models/player_model.dart';
import '../../../core/models/ball_log_model.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/scoring_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/rules_controller.dart';
import '../../../core/utils/ui_utils.dart';
import '../../match/utils/match_dialogs.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Scoring screen for scorers to record ball-by-ball updates.
/// Features run buttons, wicket, extras, undo, and auto strike change.
class ScoringScreen extends StatefulWidget {
  final String matchId;

  const ScoringScreen({super.key, required this.matchId});

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  final MatchController matchController = Get.find<MatchController>();
  final ScoringController scoringController = Get.find<ScoringController>();
  final AuthController authController = Get.find<AuthController>();
  final RulesController rulesController = Get.find<RulesController>();

  bool _isProcessingAction = false;

  Future<void> _safeRecordBall(
    MatchModel match,
    PlayerModel batsman,
    PlayerModel bowler,
    int runs,
    String ballType,
    ScoringController scoringProv, {
    bool isWicket = false,
    String? dismissalType,
    String? dismissedPlayerId,
    String? fielderId,
  }) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    await scoringProv.recordBall(
      match: match,
      batsman: batsman,
      bowler: bowler,
      runs: runs,
      ballType: ballType,
      isWicket: isWicket,
      dismissalType: dismissalType,
      dismissedPlayerId: dismissedPlayerId,
      fielderId: fielderId,
    );

    if (mounted) {
      setState(() => _isProcessingAction = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      matchController.listenToMatch(widget.matchId);
      scoringController.initForMatch(widget.matchId);
    });
  }

  Widget _buildSummaryItem(
    bool isDark,
    String name,
    String score,
    String overs,
  ) {
    return Column(
      children: [
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          '($overs)',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Get.back();
            } else {
              Get.offAllNamed(AppRoutes.home);
            }
          },
        ),
        title: Text(
          'Live Scoring',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final match = matchController.selectedMatch;
          if (match == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (match.isCompleted) {
            return _buildMatchCompletedView(match, isDark);
          }

          if (match.isUpcoming) {
            return _buildStartMatchView(match, matchController, isDark);
          }

          return _buildScoringView(
            match,
            matchController.players,
            scoringController,
            isDark,
          );
        }),
      ),
    );
  }

  // --- Player Selection Helpers ---
  void _openStrikerSelection(
    MatchModel match,
    Map<String, PlayerModel> players,
    bool isDark,
  ) {
    final maxBatBalls =
        match.customRulesEnabled ? (match.maxBattingOvers ?? 2) * 6 : 999;
    final battingTeamPlayers =
        players.values.where((p) {
          final isCorrectTeam =
              p.teamId == match.currentInnings ||
              (p.teamId == '' &&
                  ((match.currentInnings == 'A' &&
                          match.teamAPlayers.contains(p.id)) ||
                      (match.currentInnings == 'B' &&
                          match.teamBPlayers.contains(p.id))));
          return isCorrectTeam && !p.isOut && p.canBatWithLimit(maxBatBalls);
        }).toList();

    _showSearchablePlayerPicker(
      label: 'Striker',
      icon: Icons.sports_cricket,
      color: AppTheme.primaryGreen,
      players:
          battingTeamPlayers
              .where((p) => p.id != match.currentNonStrikerId)
              .toList(),
      selectedId: match.currentBatsmanId,
      onChanged: (id) {
        if (id != null) scoringController.selectBatsman(match.id, id, true);
      },
      isDark: isDark,
      subtitleBuilder:
          (p) => Text(
            'Runs: ${p.runsScored} (${p.ballsFaced}) SR: ${p.strikeRate.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
    );
  }

  void _openNonStrikerSelection(
    MatchModel match,
    Map<String, PlayerModel> players,
    bool isDark,
  ) {
    final maxBatBalls =
        match.customRulesEnabled ? (match.maxBattingOvers ?? 2) * 6 : 999;
    final battingTeamPlayers =
        players.values.where((p) {
          final isCorrectTeam =
              p.teamId == match.currentInnings ||
              (p.teamId == '' &&
                  ((match.currentInnings == 'A' &&
                          match.teamAPlayers.contains(p.id)) ||
                      (match.currentInnings == 'B' &&
                          match.teamBPlayers.contains(p.id))));
          return isCorrectTeam && !p.isOut && p.canBatWithLimit(maxBatBalls);
        }).toList();

    if (!match.customRulesEnabled && battingTeamPlayers.length == 1) return;

    _showSearchablePlayerPicker(
      label: 'Non-Striker',
      icon: Icons.person_outline,
      color: AppTheme.accentBlue,
      players:
          battingTeamPlayers
              .where((p) => p.id != match.currentBatsmanId)
              .toList(),
      selectedId: match.currentNonStrikerId,
      onChanged: (id) {
        if (id != null) scoringController.selectBatsman(match.id, id, false);
      },
      isDark: isDark,
      subtitleBuilder:
          (p) => Text(
            'Runs: ${p.runsScored} (${p.ballsFaced}) SR: ${p.strikeRate.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
    );
  }

  void _openBowlerSelection(
    MatchModel match,
    Map<String, PlayerModel> players,
    bool isDark,
  ) {
    final maxBowlOvers =
        match.customRulesEnabled
            ? (match.maxBowlingOvers ?? 3)
            : AppConstants.maxBowlerOvers;
    final bowlingTeamPlayers =
        players.values.where((p) {
          final isBowlingTeam =
              p.teamId != match.currentInnings ||
              (p.teamId == '' &&
                  ((match.currentInnings == 'A' &&
                          match.teamBPlayers.contains(p.id)) ||
                      (match.currentInnings == 'B' &&
                          match.teamAPlayers.contains(p.id))));
          return isBowlingTeam && p.canBowl(maxBowlOvers);
        }).toList();

    final lastBallIndex = scoringController.ballLogs.lastIndexWhere(
      (b) => b.innings == match.currentInnings,
    );
    final lastBowlerId =
        lastBallIndex != -1
            ? scoringController.ballLogs[lastBallIndex].bowlerId
            : null;

    _showSearchablePlayerPicker(
      label: 'Bowler',
      icon: Icons.gps_fixed,
      color: AppTheme.accentPurple,
      players: bowlingTeamPlayers,
      selectedId: match.currentBowlerId,
      onChanged: (id) {
        if (id != null) scoringController.selectBowler(match.id, id);
      },
      isDark: isDark,
      enabledPredicate: (p) => p.id != lastBowlerId,
      subtitleBuilder:
          (p) => Text(
            p.id == lastBowlerId
                ? 'Player can\'t bowl back-to-back overs.'
                : 'Overs: ${p.oversBowledDisplay} (${p.bowlingFigures})',
            style: TextStyle(
              fontSize: 12,
              color:
                  p.id == lastBowlerId
                      ? Colors.redAccent
                      : (isDark ? Colors.white70 : Colors.grey[600]),
            ),
          ),
    );
  }

  // Start Match View
  Widget _buildStartMatchView(
    MatchModel match,
    MatchController matchProv,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_cricket,
                size: 64,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              match.title,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${match.teamAName} vs ${match.teamBName}\n${match.totalOvers} overs',
              style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => matchProv.startMatch(widget.matchId),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  'Start Match',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchablePlayerPicker({
    required String label,
    required IconData icon,
    required Color color,
    required List<PlayerModel> players,
    required String? selectedId,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    Widget Function(PlayerModel)? subtitleBuilder,
    bool Function(PlayerModel)? enabledPredicate,
  }) {
    String searchQuery = '';

    FocusScope.of(context).unfocus();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setDialogState) {
          final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
          final cardColor =
              isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
          final accentColor = color;

          final filteredPlayers =
              players.where((p) {
                return p.name.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: accentColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select $label',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Available from your team',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (val) => setDialogState(() => searchQuery = val),
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search $label...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child:
                        filteredPlayers.isEmpty
                            ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.person_off_rounded,
                                    size: 48,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No players found',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.only(bottom: 32),
                              itemCount: filteredPlayers.length,
                              separatorBuilder:
                                  (context, index) =>
                                      const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final p = filteredPlayers[i];
                                final isSelected = p.id == selectedId;
                                final isEnabled =
                                    enabledPredicate?.call(p) ?? true;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap:
                                        isEnabled
                                            ? () {
                                              Get.back();
                                              onChanged(p.id);
                                            }
                                            : null,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Opacity(
                                      opacity: isEnabled ? 1.0 : 0.5,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? accentColor.withOpacity(0.1)
                                                  : cardColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color:
                                                isSelected
                                                    ? accentColor
                                                    : (isDark
                                                        ? Colors.white
                                                            .withOpacity(0.05)
                                                        : Colors.black
                                                            .withOpacity(0.05)),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor:
                                                  isSelected
                                                      ? accentColor
                                                      : accentColor.withOpacity(
                                                        0.1,
                                                      ),
                                              child: Text(
                                                p.name.isNotEmpty
                                                    ? p.name[0].toUpperCase()
                                                    : 'P',
                                                style: GoogleFonts.outfit(
                                                  color:
                                                      isSelected
                                                          ? Colors.white
                                                          : accentColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    p.name,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  if (subtitleBuilder != null)
                                                    subtitleBuilder(p),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: accentColor,
                                              )
                                            else if (!isEnabled)
                                              const Icon(
                                                Icons.block_flipped,
                                                color: Colors.grey,
                                                size: 20,
                                              )
                                            else
                                              Icon(
                                                Icons
                                                    .add_circle_outline_rounded,
                                                color: Colors.grey[400],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  // Main Scoring View
  Widget _buildScoringView(
    MatchModel match,
    Map<String, PlayerModel> players,
    ScoringController scoringProv,
    bool isDark,
  ) {
    try {
      final actualBatsman = _getPlayerById(players, match.currentBatsmanId);
      final actualNonStriker = _getPlayerById(
        players,
        match.currentNonStrikerId,
      );
      final actualBowler = _getPlayerById(players, match.currentBowlerId);

      final battingTeamId = match.currentInnings;
      final teamSize =
          battingTeamId == 'A'
              ? match.teamAPlayers.length
              : match.teamBPlayers.length;
      final isLastPlayerStanding =
          match.lastPlayerCanPlay &&
          teamSize > 0 &&
          match.currentScore.wickets >= teamSize - 1;

      final batsman =
          actualBatsman ?? PlayerModel(id: '', name: 'Select Striker');
      final nonStriker =
          actualNonStriker ??
          (match.customRulesEnabled || isLastPlayerStanding
              ? null
              : PlayerModel(id: '', name: 'Select Non-Striker'));
      final bowler = actualBowler ?? PlayerModel(id: '', name: 'Select Bowler');

      final isScorer =
          match.scorerIds.contains(authController.userId) ||
          (authController.currentUser?.isAdmin ?? false);

      final needsStriker = actualBatsman == null;
      final needsNonStriker =
          actualNonStriker == null &&
          !match.customRulesEnabled &&
          !isLastPlayerStanding;
      final needsBowler = actualBowler == null;

      final bgColor = isDark ? AppTheme.primaryDark : const Color(0xFFF8FAFC);

      return SafeArea(
        child: Column(
          children: [
            _buildScoreSummary(match, isDark),

            // Condition Indicators Bar
            if (match.isFreeHit || match.groundName.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    bottom: BorderSide(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (match.isFreeHit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.wicketRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.wicketRed.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flash_on_rounded,
                              color: AppTheme.wicketRed,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'FREE HIT',
                              style: GoogleFonts.inter(
                                color: AppTheme.wicketRed,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (match.groundName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: isDark ? Colors.white30 : Colors.black26,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            match.groundName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            _buildCurrentPlayersBar(match, batsman, nonStriker, bowler, isDark),

            Expanded(
              child: Container(
                color: bgColor,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      if (match.isInningsBreak)
                        _buildInningsBreakView(match, scoringProv, isDark)
                      else ...[
                        _buildThisOverStrip(scoringProv, match, isDark),

                        // Special In-View CTA for Inning Start (Chase)
                        if (isScorer && needsStriker && needsBowler)
                          _buildRunChaseStartCard(match, isDark),

                        // View Only Mode Banner
                        if (!isScorer) _buildViewOnlyBanner(isDark),

                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Scoring Controls / CTAs
            if (isScorer &&
                !match.isInningsBreak &&
                match.status == AppConstants.matchLive)
              _buildBottomControlsArea(
                match,
                players,
                scoringProv,
                batsman,
                bowler,
                needsStriker,
                needsNonStriker,
                needsBowler,
                isDark,
              ),
          ],
        ),
      );
    } catch (e, stack) {
      return _buildCrashView(e, stack);
    }
  }

  Widget _buildRunChaseStartCard(MatchModel match, bool isDark) {
    if (!match.isSecondInnings ||
        match.currentScore.overs > 0 ||
        match.currentScore.balls > 0) {
      return const SizedBox.shrink();
    }

    final target = match.targetScore;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sports_cricket_rounded,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'CHASE TIME',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryGreen,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              children: [
                const TextSpan(text: 'Target to Win: '),
                TextSpan(
                  text: '$target Runs',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select your openers and a bowler to begin the final innings',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildViewOnlyBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B263B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.accentBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.remove_red_eye_rounded,
                color: AppTheme.accentBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viewer Mode',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Recording is restricted to scorers.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlsArea(
    MatchModel match,
    Map<String, PlayerModel> players,
    ScoringController scoringProv,
    PlayerModel batsman,
    PlayerModel bowler,
    bool needsStriker,
    bool needsNonStriker,
    bool needsBowler,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needsStriker)
            _buildMissingPlayerCta(
              'Select Striker',
              Icons.sports_cricket,
              AppTheme.primaryGreen,
              () => _openStrikerSelection(match, players, isDark),
            )
          else if (needsNonStriker)
            _buildMissingPlayerCta(
              'Select Non-Striker',
              Icons.person_outline,
              AppTheme.accentBlue,
              () => _openNonStrikerSelection(match, players, isDark),
            )
          else if (needsBowler)
            _buildMissingPlayerCta(
              'Choose Bowler',
              Icons.gps_fixed,
              AppTheme.accentPurple,
              () => _openBowlerSelection(match, players, isDark),
            )
          else
            _buildScoringButtons(match, batsman, bowler, scoringProv, isDark),
        ],
      ),
    );
  }

  Widget _buildCrashView(dynamic e, dynamic stack) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'SCORING ENGINE ERROR',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                '$e\n\n$stack',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsBreakView(
    MatchModel match,
    ScoringController scoringProv,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty,
              size: 64,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Innings is Completed',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting to start the next innings',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: 250,
            child: ElevatedButton.icon(
              onPressed: () => scoringProv.startNextInnings(match),
              icon: const Icon(Icons.play_circle_filled, color: Colors.white),
              label: Text(
                'Start New Innings',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCompletedView(MatchModel match, bool isDark) {
    return SizedBox.expand(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF00E676)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C853).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Match Completed',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (match.customRulesEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    'SINGLE BATSMAN MODE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  match.result ?? 'Match Ended',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (match.manOfMatchName != null) ...[
                Text(
                  'PLAYER OF THE MATCH',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  match.manOfMatchName!,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 48),
              ],
              if ((authController.currentUser?.isAdmin ?? false) &&
                  matchController.liveMatches.isEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRematchTossDialog(match),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: Text(
                      'Continue With These Teams',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: Text(
                    'Go Back Home',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFF1B263B) : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingPlayerCta(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(isDark ? 0.2 : 0.1),
                  color.withOpacity(isDark ? 0.1 : 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Action Required',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, color: color, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Avatar Helper ─────────────────────────────────
  PlayerModel? _getPlayerById(
    Map<String, PlayerModel> players,
    String? playerId,
  ) {
    if (playerId == null ||
        playerId.isEmpty ||
        !players.containsKey(playerId)) {
      return null;
    }
    return players[playerId];
  }

  Widget _buildAvatar(
    String name,
    double radius, {
    bool isSelected = false,
    Color? color,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isSelected ? (color ?? AppTheme.primaryGreen) : Colors.grey[300],
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildScoreSummary(MatchModel match, bool isDark) {
    final score = match.currentScore;
    final initialBattingTeam =
        match.tossWonBy == 'A'
            ? (match.tossDecision == 'bat' ? 'A' : 'B')
            : (match.tossDecision == 'bat' ? 'B' : 'A');
    final isSecondInnings = match.currentInnings != initialBattingTeam;

    int? target;
    int? runsNeeded;
    int? ballsRemaining;
    double? rrr;

    if (isSecondInnings) {
      final firstInningsScore =
          match.currentInnings == 'A' ? match.teamBScore : match.teamAScore;
      target = firstInningsScore.runs + 1;
      runsNeeded = (target - score.runs).clamp(0, target);
      final totalBalls = match.totalOvers * 6;
      final ballsBowled = (score.overs * 6) + score.balls;
      ballsRemaining = (totalBalls - ballsBowled).clamp(0, totalBalls);
      rrr = ballsRemaining > 0 ? (runsNeeded * 6) / ballsRemaining : 0.0;
    }

    final primaryGradient =
        isDark
            ? const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
            : const LinearGradient(
              colors: [Color(0xFF00C853), Color(0xFF009624)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            );

    return Container(
      decoration: BoxDecoration(
        gradient: primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD600),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              match.battingTeamName.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${score.runs}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            ' / ${score.wickets}',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'OVERS',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            score.oversDisplay,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' / ${match.totalOvers}',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.15)),
            child: Row(
              children: [
                _buildStatItem('CRR', score.runRate.toStringAsFixed(2)),
                if (isSecondInnings && rrr != null) ...[
                  const SizedBox(width: 20),
                  _buildStatItem(
                    'RRR',
                    rrr.toStringAsFixed(2),
                    valueColor:
                        rrr > score.runRate
                            ? const Color(0xFFFFD600)
                            : const Color(0xFF00E676),
                  ),
                ],
              ],
            ),
          ),
          if (isSecondInnings && runsNeeded != null && ballsRemaining != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color:
                  isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
              child: Text(
                '${match.battingTeamName} needs $runsNeeded runs in $ballsRemaining balls',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPlayersBar(
    MatchModel match,
    PlayerModel batsman,
    PlayerModel? nonStriker,
    PlayerModel bowler,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color:
                isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildBatsmanCard(match, batsman, true, isDark),
                if (nonStriker != null && !match.customRulesEnabled) ...[
                  const SizedBox(height: 6),
                  _buildBatsmanCard(match, nonStriker, false, isDark),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 4, child: _buildBowlerCard(match, bowler, isDark)),
        ],
      ),
    );
  }

  Widget _buildBatsmanCard(
    MatchModel match,
    PlayerModel player,
    bool isStriker,
    bool isDark,
  ) {
    final canReplace = player.ballsFaced == 0;
    final accentColor = AppTheme.primaryGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            canReplace
                ? () {
                  if (isStriker) {
                    _openStrikerSelection(
                      match,
                      matchController.players,
                      isDark,
                    );
                  } else {
                    _openNonStrikerSelection(
                      match,
                      matchController.players,
                      isDark,
                    );
                  }
                }
                : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color:
                isStriker
                    ? accentColor.withOpacity(isDark ? 0.15 : 0.08)
                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isStriker
                      ? accentColor.withOpacity(0.4)
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05)),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              if (isStriker) ...[
                const Icon(
                  Icons.sports_cricket,
                  size: 14,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight:
                            isStriker ? FontWeight.w800 : FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (canReplace)
                      Text(
                        'TAP TO REPLACE',
                        style: GoogleFonts.inter(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: accentColor.withOpacity(0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${player.runsScored}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${player.ballsFaced} balls',
                    style: GoogleFonts.inter(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBowlerCard(MatchModel match, PlayerModel player, bool isDark) {
    final canReplace = player.oversBowledDisplay == '0.0';
    final accentColor = AppTheme.accentPurple;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            canReplace
                ? () =>
                    _openBowlerSelection(match, matchController.players, isDark)
                : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gps_fixed, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      player.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${player.oversBowledDisplay} - ${player.bowlingFigures}',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              if (canReplace)
                Text(
                  'CHANGE',
                  style: GoogleFonts.inter(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    color: accentColor.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThisOverStrip(
    ScoringController scoringProv,
    MatchModel match,
    bool isDark,
  ) {
    final allBalls =
        scoringProv.ballLogs
            .where((b) => b.innings == match.currentInnings)
            .toList();

    if (allBalls.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF9FAFB),
        child: Text(
          'THIS OVER: —',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
        ),
      );
    }

    final Map<int, List<BallLog>> overMap = {};
    for (final ball in allBalls) {
      overMap.putIfAbsent(ball.overNumber, () => []).add(ball);
    }

    final sortedOverKeys =
        overMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final visibleOvers = sortedOverKeys.toList();

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF9FAFB),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: visibleOvers.length,
        separatorBuilder:
            (context, index) => Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
        itemBuilder: (context, index) {
          final isCurrentOver = index == 0;
          final overNum = visibleOvers[index];
          final overBalls = overMap[overNum]!;

          final overRuns = overBalls.fold<int>(0, (sum, b) {
            int r = b.runs + (b.extraRuns ?? 0);
            return sum + r;
          });

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentOver ? 'THIS OVER' : 'OVER ${overNum + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color:
                              isCurrentOver
                                  ? AppTheme.primaryGreen
                                  : Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '$overRuns runs',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isCurrentOver
                                  ? AppTheme.primaryGreen
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          overBalls.map((ball) {
                            return Container(
                              margin: const EdgeInsets.only(right: 4),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: _getBallColor(ball),
                                shape: BoxShape.circle,
                                border:
                                    isCurrentOver && ball == overBalls.last
                                        ? Border.all(
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                          width: 1.5,
                                        )
                                        : null,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: Text(
                                      ball.displayText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _getBallTextColor(ball),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoringButtons(
    MatchModel match,
    PlayerModel batsman,
    PlayerModel bowler,
    ScoringController scoringProv,
    bool isDark,
  ) {
    if (scoringProv.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          scoringProv.error!,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final keypadHeight = (screenHeight * 0.35).clamp(240.0, 280.0);

    return Container(
      height: keypadHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.primaryDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column 1
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGridBtn(
                  '0',
                  () => _safeRecordBall(
                    match,
                    batsman,
                    bowler,
                    0,
                    'normal',
                    scoringProv,
                  ),
                  isDark: isDark,
                  fontSize: 18,
                ),
                _buildGridBtn(
                  '3',
                  () => _safeRecordBall(
                    match,
                    batsman,
                    bowler,
                    3,
                    'normal',
                    scoringProv,
                  ),
                  isDark: isDark,
                  fontSize: 18,
                ),
                _buildGridBtn(
                  'WD',
                  () => _showExtraBottomSheet(
                    'wide',
                    match,
                    batsman,
                    bowler,
                    scoringProv,
                    isDark,
                  ),
                  textColor: AppTheme.wideColor,
                  fontWeight: FontWeight.bold,
                  isDark: isDark,
                  fontSize: 16,
                ),
              ],
            ),
          ),
          // Column 2
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGridBtn(
                  '1',
                  () => _safeRecordBall(
                    match,
                    batsman,
                    bowler,
                    1,
                    'normal',
                    scoringProv,
                  ),
                  isDark: isDark,
                  fontSize: 18,
                ),
                _buildGridBtn(
                  '4',
                  () => _safeRecordBall(
                    match,
                    batsman,
                    bowler,
                    4,
                    'normal',
                    scoringProv,
                  ),
                  subtitle: 'Four',
                  textColor: AppTheme.fourYellow,
                  isDark: isDark,
                  fontSize: 18,
                ),
                _buildGridBtn(
                  'NB',
                  () => _showExtraBottomSheet(
                    'no_ball',
                    match,
                    batsman,
                    bowler,
                    scoringProv,
                    isDark,
                  ),
                  textColor: AppTheme.noBallColor,
                  fontWeight: FontWeight.bold,
                  isDark: isDark,
                  fontSize: 16,
                ),
              ],
            ),
          ),
          // Column 3
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGridBtn(
                  '2',
                  () => _safeRecordBall(
                    match,
                    batsman,
                    bowler,
                    2,
                    'normal',
                    scoringProv,
                  ),
                  isDark: isDark,
                  fontSize: 18,
                ),
                _buildGridBtn(
                  '6',
                  () => _safeRecordBall(
                    match,
                    batsman,
                    bowler,
                    6,
                    'normal',
                    scoringProv,
                  ),
                  subtitle: 'Six',
                  textColor: AppTheme.sixGold,
                  isDark: isDark,
                  fontSize: 18,
                ),
                _buildGridBtn(
                  'BYE',
                  () => _showExtraBottomSheet(
                    'bye',
                    match,
                    batsman,
                    bowler,
                    scoringProv,
                    isDark,
                  ),
                  textColor: AppTheme.accentBlue,
                  isDark: isDark,
                  fontSize: 14,
                ),
              ],
            ),
          ),
          // Column 4
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGridBtn(
                  'UNDO',
                  () => _undoLastBall(matchController, scoringProv),
                  textColor: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  flex: 3,
                  isDark: isDark,
                  isEnabled:
                      scoringProv.ballLogs.isNotEmpty &&
                      scoringProv.ballLogs.last.innings == match.currentInnings,
                  fontSize: 14,
                ),
                _buildGridBtn(
                  'OUT',
                  () => _showWicketDialog(
                    match,
                    batsman,
                    bowler,
                    scoringProv,
                    isDark,
                  ),
                  textColor: AppTheme.wicketRed,
                  fontWeight: FontWeight.bold,
                  flex: 3,
                  isDark: isDark,
                  fontSize: 16,
                ),
                _buildGridBtn(
                  'LB',
                  () => _showExtraBottomSheet(
                    'leg_bye',
                    match,
                    batsman,
                    bowler,
                    scoringProv,
                    isDark,
                  ),
                  textColor: AppTheme.legByeColor,
                  fontWeight: FontWeight.bold,
                  flex: 3,
                  isDark: isDark,
                  fontSize: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBtn(
    String label,
    VoidCallback onTap, {
    String? subtitle,
    Color? textColor,
    FontWeight? fontWeight,
    int flex = 4,
    required bool isDark,
    bool isEnabled = true,
    double? fontSize,
  }) {
    final effectiveTextColor =
        (!isEnabled || _isProcessingAction)
            ? Colors.grey
            : (textColor ?? (isDark ? Colors.white : Colors.black87));

    Color? bgColor;
    if (isEnabled && !_isProcessingAction) {
      if (label == 'WD')
        bgColor = AppTheme.wideColor.withOpacity(0.08);
      else if (label == 'NB')
        bgColor = AppTheme.noBallColor.withOpacity(0.08);
      else if (label == 'OUT')
        bgColor = AppTheme.wicketRed.withOpacity(0.08);
      else if (label == 'UNDO')
        bgColor = AppTheme.primaryGreen.withOpacity(0.08);
      else if (label == '4')
        bgColor = AppTheme.fourYellow.withOpacity(0.08);
      else if (label == '6')
        bgColor = AppTheme.sixGold.withOpacity(0.08);
    }

    return Expanded(
      flex: flex,
      child: _ClickableGridButton(
        label: label,
        subtitle: subtitle,
        onTap: isEnabled && !_isProcessingAction ? onTap : () {},
        textColor: effectiveTextColor,
        fontWeight: fontWeight,
        isDark: isDark,
        bgColor: bgColor,
        isEnabled: isEnabled && !_isProcessingAction,
        fontSize: fontSize,
      ),
    );
  }

  Widget _buildLimitReachedView(String title, String message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.vibrantOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.vibrantOrange.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.vibrantOrange,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.vibrantOrange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExtraBottomSheet(
    String type,
    MatchModel match,
    PlayerModel batsman,
    PlayerModel bowler,
    ScoringController scoringProv,
    bool isDark,
  ) {
    String title = '';
    if (type == 'wide')
      title = 'Wide ball (WD)';
    else if (type == 'no_ball')
      title = 'No ball (NB)';
    else if (type == 'bye')
      title = 'Bye runs';
    else if (type == 'leg_bye')
      title = 'Leg bye runs';

    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(8, (index) {
                    int runs = index;
                    String label =
                        type == 'wide'
                            ? 'WD + $runs'
                            : type == 'no_ball'
                            ? 'NB + $runs'
                            : '$runs';
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _safeRecordBall(
                          match,
                          batsman,
                          bowler,
                          runs,
                          type,
                          scoringProv,
                        );
                      },
                      child: Container(
                        width: 70,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primaryGreen),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRunsBottomSheet(
    MatchModel match,
    PlayerModel batsman,
    PlayerModel bowler,
    ScoringController scoringProv,
    bool isDark,
  ) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'More runs',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children:
                      [5, 7, 8].map((runs) {
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _safeRecordBall(
                              match,
                              batsman,
                              bowler,
                              runs,
                              'normal',
                              scoringProv,
                            );
                          },
                          child: Container(
                            width: 70,
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primaryGreen),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$runs',
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _undoLastBall(MatchController matchProv, ScoringController scoringProv) {
    if (matchProv.selectedMatch == null || _isProcessingAction) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Undo Last Ball?',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This will permanently remove the last recorded delivery. This action cannot be reversed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            if (_isProcessingAction) return;

                            setState(() => _isProcessingAction = true);
                            try {
                              await scoringProv.undoLastBall(
                                matchProv.selectedMatch!,
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isProcessingAction = false);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Confirm Undo',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showWicketDialog(
    MatchModel match,
    PlayerModel batsman,
    PlayerModel bowler,
    ScoringController scoringProv,
    bool isDark,
  ) {
    String dismissalType = AppConstants.dismissalBowled;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setDialogState) {
          final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
          final cardColor =
              isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
          final primaryRed = const Color(0xFFFF4D4D);

          final dismissalOptions = [
            {
              'type': AppConstants.dismissalBowled,
              'icon': Icons.sports_cricket,
              'label': 'Bowled',
            },
            {
              'type': AppConstants.dismissalCaught,
              'icon': Icons.back_hand_rounded,
              'label': 'Caught',
            },
            {
              'type': AppConstants.dismissalRunOut,
              'icon': Icons.directions_run_rounded,
              'label': 'Run Out',
            },
            {
              'type': AppConstants.dismissalStumped,
              'icon': Icons.pan_tool_rounded,
              'label': 'Stumped',
            },
            {
              'type': AppConstants.dismissalLBW,
              'icon': Icons.front_hand_rounded,
              'label': 'LBW',
            },
            {
              'type': AppConstants.dismissalHitWicket,
              'icon': Icons.gavel_rounded,
              'label': 'Hit Wicket',
            },
          ];

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryRed.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: primaryRed,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wicket!',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Select the type of dismissal',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: Icon(Icons.close, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: dismissalOptions.length,
                    itemBuilder: (context, index) {
                      final opt = dismissalOptions[index];
                      final isSelected = dismissalType == opt['type'];
                      final optionType = opt['type'] as String;

                      return GestureDetector(
                        onTap:
                            () => setDialogState(
                              () => dismissalType = optionType,
                            ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryRed : cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isSelected ? primaryRed : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: primaryRed.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                opt['icon'] as IconData,
                                color: isSelected ? Colors.white : Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                opt['label'] as String,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        if (dismissalType == AppConstants.dismissalCaught ||
                            dismissalType == AppConstants.dismissalRunOut ||
                            dismissalType == AppConstants.dismissalStumped) {
                          _showFielderSelectionSheet(
                            match,
                            batsman,
                            bowler,
                            scoringProv,
                            isDark,
                            dismissalType,
                          );
                        } else {
                          _safeRecordBall(
                            match,
                            batsman,
                            bowler,
                            0,
                            'normal',
                            scoringProv,
                            isWicket: true,
                            dismissalType: dismissalType,
                            dismissedPlayerId: batsman.id,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'CONFIRM WICKET',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  void _showFielderSelectionSheet(
    MatchModel match,
    PlayerModel batsman,
    PlayerModel bowler,
    ScoringController scoringProv,
    bool isDark,
    String baseDismissalType,
  ) {
    final fieldingTeamPlayers =
        matchController.players.values.where((p) {
          return p.teamId == (match.currentInnings == 'A' ? 'B' : 'A') ||
              (p.teamId == '' &&
                  ((match.currentInnings == 'A' &&
                          match.teamBPlayers.contains(p.id)) ||
                      (match.currentInnings == 'B' &&
                          match.teamAPlayers.contains(p.id))));
        }).toList();

    FocusScope.of(context).unfocus();

    String searchQuery = '';

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setDialogState) {
          final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
          final cardColor =
              isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
          final primaryGreen = const Color(0xFF00C853);

          final filteredPlayers =
              fieldingTeamPlayers.where((p) {
                return p.name.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Fielder',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            baseDismissalType.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${fieldingTeamPlayers.length} Players',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (val) => setDialogState(() => searchQuery = val),
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search player...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child:
                        filteredPlayers.isEmpty
                            ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.person_search_rounded,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No player found',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.only(bottom: 32),
                              itemCount: filteredPlayers.length,
                              separatorBuilder:
                                  (context, index) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final p = filteredPlayers[i];
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Get.back();
                                      _safeRecordBall(
                                        match,
                                        batsman,
                                        bowler,
                                        0,
                                        'normal',
                                        scoringProv,
                                        isWicket: true,
                                        dismissalType:
                                            '$baseDismissalType (${p.name})',
                                        dismissedPlayerId: batsman.id,
                                        fielderId: p.id,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? Colors.white.withOpacity(
                                                    0.05,
                                                  )
                                                  : Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: primaryGreen
                                                .withOpacity(0.1),
                                            child: Text(
                                              p.name.isNotEmpty
                                                  ? p.name[0].toUpperCase()
                                                  : 'P',
                                              style: GoogleFonts.outfit(
                                                color: primaryGreen,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.name,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  'Fielder',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: Colors.grey[400],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Color _getBallColor(BallLog ball) {
    if (ball.isWicket) return AppTheme.wicketRed;
    if (ball.ballType == 'wide') return AppTheme.wideColor;
    if (ball.ballType == 'no_ball') return AppTheme.noBallColor;
    if (ball.ballType == 'bye' || ball.ballType == 'leg_bye')
      return Colors.blueGrey;
    if (ball.runs == 6) return AppTheme.sixGold;
    if (ball.runs == 4) return AppTheme.fourYellow;
    if (ball.runs == 0) return Colors.grey.withOpacity(0.2);
    return AppTheme.primaryGreen.withOpacity(0.15);
  }

  Color _getBallTextColor(BallLog ball) {
    if (ball.isWicket ||
        ball.ballType == 'wide' ||
        ball.ballType == 'no_ball' ||
        ball.ballType == 'bye' ||
        ball.ballType == 'leg_bye') {
      return Colors.white;
    }
    if (ball.runs == 6 || ball.runs == 4) return Colors.black;
    if (ball.runs == 0) return Colors.grey;
    return AppTheme.primaryGreen;
  }

  void _showRematchTossDialog(MatchModel match) {
    String tossWonBy = 'A';
    String tossDecision = 'bat';

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B263B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rematch Toss',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new match with same teams and rules.',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Who won the toss?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTossChoice(
                          match.teamAName,
                          'A',
                          tossWonBy == 'A',
                          () => setModalState(() => tossWonBy = 'A'),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTossChoice(
                          match.teamBName,
                          'B',
                          tossWonBy == 'B',
                          () => setModalState(() => tossWonBy = 'B'),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Winner elected to?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTossChoice(
                          'BAT',
                          'bat',
                          tossDecision == 'bat',
                          () => setModalState(() => tossDecision = 'bat'),
                          isDark,
                          icon: Icons.sports_cricket,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTossChoice(
                          'BOWL',
                          'bowl',
                          tossDecision == 'bowl',
                          () => setModalState(() => tossDecision = 'bowl'),
                          isDark,
                          icon: Icons.sports_baseball,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          () => _startRematch(match, tossWonBy, tossDecision),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'START REMATCH',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildTossChoice(
    String label,
    String value,
    bool isSelected,
    VoidCallback onTap,
    bool isDark, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryGreen.withOpacity(0.1)
                  : (isDark
                      ? const Color(0xFF253750)
                      : const Color(0xFFF0F2F5)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryGreen : Colors.grey,
                size: 18,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color:
                    isSelected
                        ? AppTheme.primaryGreen
                        : (isDark ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRematch(
    MatchModel match,
    String tossWonBy,
    String tossDecision,
  ) async {
    try {
      Get.back();

      UIUtils.showLoading('Setting up rematch...');

      final newMatchId = await matchController.performRematch(
        match: match,
        tossWonBy: tossWonBy,
        tossDecision: tossDecision,
        currentUserId: authController.userId!,
      );

      Get.back();

      if (newMatchId != null) {
        Get.off(
          () => ScoringScreen(matchId: newMatchId),
          preventDuplicates: false,
        );
        UIUtils.showSuccess('Rematch started!');
      }
    } catch (e) {
      Get.back();
      UIUtils.showError('Failed to start rematch: $e');
    }
  }
}

/// Helper widget for the scoring buttons with click animation
class _ClickableGridButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color textColor;
  final FontWeight? fontWeight;
  final bool isDark;
  final Color? bgColor;
  final bool isEnabled;
  final double? fontSize;

  const _ClickableGridButton({
    required this.label,
    this.subtitle,
    required this.onTap,
    required this.textColor,
    this.fontWeight,
    required this.isDark,
    this.bgColor,
    required this.isEnabled,
    this.fontSize,
  });

  @override
  State<_ClickableGridButton> createState() => _ClickableGridButtonState();
}

class _ClickableGridButtonState extends State<_ClickableGridButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isEnabled) _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.isEnabled) _controller.reverse();
  }

  void _handleTapCancel() {
    if (widget.isEnabled) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: widget.bgColor ?? Colors.transparent,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: widget.fontSize ?? 20,
                  fontWeight: widget.fontWeight ?? FontWeight.w700,
                  color: widget.textColor,
                ),
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: widget.textColor.withOpacity(0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
