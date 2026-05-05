import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:x_cricket/core/routes/app_routes.dart';

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
import '../../match/widgets/motm_award_card.dart';
import '../../match/widgets/partnership_card.dart';
import '../../../core/models/partnership_model.dart';
import '../../../core/controllers/tournament_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/last_ball_popup.dart';

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
  final TournamentController tournamentController =
      Get.find<TournamentController>();

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
    String? newIncomingBatsmanId,
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
      newIncomingBatsmanId: newIncomingBatsmanId,
    );

    // Explicitly trigger selection checks after a small delay to ensure Firestore sync
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        final freshMatch = matchController.selectedMatch;
        if (freshMatch != null) {
          _autoOpenSelectionIfNeeded(freshMatch);
        }
      }
    });

    if (mounted) {
      setState(() => _isProcessingAction = false);
    }
  }

  Worker? _matchWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      matchController.listenToMatch(widget.matchId);
      scoringController.initForMatch(widget.matchId);

      // Auto-open player selection safety net with debounce to handle rapid Firestore updates
      _matchWorker = debounce(matchController.selectedMatchRx, (
        MatchModel? match,
      ) {
        if (!mounted) return;
        if (match == null) return;

        // Auto-close selection sheets if match completes or innings break
        if ((match.isCompleted || match.isInningsBreak) &&
            _isSelectionSheetOpen) {
          if (Get.isBottomSheetOpen == true) {
            Get.back();
          }
          _isSelectionSheetOpen = false;
          return;
        }

        if (!match.isLive || match.isInningsBreak || _isSelectionSheetOpen) {
          return;
        }

        // Check if current user is scorer
        final isScorer =
            match.scorerIds.contains(authController.userId) ||
            (authController.currentUser?.isAdmin ?? false);
        if (!isScorer) return;

        // Only trigger if IDs are missing
        if (match.currentBatsmanId == null ||
            match.currentBowlerId == null ||
            (match.currentNonStrikerId == null && !match.customRulesEnabled)) {
          _autoOpenSelectionIfNeeded(match);
        }
      }, time: const Duration(milliseconds: 300));

      // Last Ball Alert Worker
      _lastBallWorker = ever(scoringController.lastBallShown, (bool shown) {
        if (shown && mounted) {
          _showLastBallAlert();
        }
      });
    });
  }

  Worker? _lastBallWorker;

  void _showLastBallAlert() {
    HapticFeedback.heavyImpact();
    Get.dialog(const Center(child: LastBallPopup()), barrierDismissible: false);

    Future.delayed(const Duration(seconds: 3), () {
      if (Get.isDialogOpen == true) {
        Get.back();
      }
    });
  }

  @override
  void dispose() {
    _matchWorker?.dispose();
    _lastBallWorker?.dispose();
    super.dispose();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation(context, isDark);
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              final shouldPop = await _showExitConfirmation(context, isDark);
              if (shouldPop && mounted) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Get.offAllNamed(AppRoutes.home);
                }
              }
            },
          ),
          title: Text(
            'Live Scoring',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          // actions: [
          //   // Undo button
          //   Obx(
          //     () => IconButton(
          //       icon: const Icon(Icons.undo),
          //       tooltip: 'Undo Last Ball',
          //       onPressed:
          //           scoringController.ballLogs.isEmpty
          //               ? null
          //               : () => _undoLastBall(matchController, scoringController),
          //     ),
          //   ),
          // ],
        ),
        body: SafeArea(
          child: Obx(() {
            final match = matchController.selectedMatch;
            if (match == null) {
              return const Center(child: CircularProgressIndicator());
            }

            // Check if match is completed
            if (match.isCompleted) {
              return _buildMatchCompletedView(match, isDark);
            }

            // Check if match needs to start
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
      ),
    );
  }

  Future<bool> _showExitConfirmation(BuildContext context, bool isDark) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                title: Text(
                  'Exit Scoring?',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                content: Text(
                  'Are you sure you want to leave the live scoring screen? The match progress will be saved.',
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'STAY',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.wicketRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'EXIT',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  bool _isSelectionSheetOpen = false;

  Future<void> _autoOpenSelectionIfNeeded(MatchModel match) async {
    // 100% Reliable Lock System
    if (_isSelectionSheetOpen || match.isCompleted || match.isInningsBreak)
      return;

    // Settling delay: wait for database snapshots to stabilize
    await Future.delayed(const Duration(milliseconds: 200));

    // Re-verify state after delay using the latest available data
    final latestMatch = matchController.selectedMatch;
    if (latestMatch == null ||
        latestMatch.id != match.id ||
        latestMatch.isCompleted ||
        latestMatch.isInningsBreak ||
        _isSelectionSheetOpen) {
      return;
    }

    // Immediate lock to prevent race conditions during async player fetch
    _isSelectionSheetOpen = true;

    final currentMatch = latestMatch;

    if (matchController.players.isEmpty) {
      await matchController.fetchPlayers(match.id);
    }

    final players = matchController.players;
    final battingTeamId = currentMatch.currentInnings;
    final teamSize =
        battingTeamId == 'A'
            ? currentMatch.teamAPlayers.length
            : currentMatch.teamBPlayers.length;

    // Smart Detection Logic
    final isLastPlayerStanding =
        currentMatch.lastPlayerCanPlay &&
        teamSize > 0 &&
        currentMatch.currentScore.wickets >= teamSize - 1;

    final needsStriker = currentMatch.currentBatsmanId == null;
    final needsNonStriker =
        currentMatch.currentNonStrikerId == null &&
        !currentMatch.customRulesEnabled &&
        !isLastPlayerStanding &&
        currentMatch.currentScore.wickets < teamSize - 1;
    final needsBowler = currentMatch.currentBowlerId == null;

    if (needsStriker || needsNonStriker || needsBowler) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Central Event Triggers
      if (needsStriker) {
        _openStrikerSelection(currentMatch, players, isDark);
      } else if (needsNonStriker) {
        _openNonStrikerSelection(currentMatch, players, isDark);
      } else if (needsBowler) {
        _openBowlerSelection(currentMatch, players, isDark);
      }
    } else {
      // Release lock if no selection was actually needed
      _isSelectionSheetOpen = false;
    }
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

    // Check Last Man Stands
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

    // Find last bowler to prevent consecutive overs
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
                ? 'Cannot bowl consecutive overs'
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
                onPressed: () async {
                  UIUtils.showLoading('Starting match...');
                  await matchProv.fetchPlayers(widget.matchId);
                  await matchProv.startMatch(widget.matchId);
                  UIUtils.hideLoading();
                },
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
    final searchCtrl = TextEditingController();
    String query = '';

    FocusScope.of(context).unfocus();
    _isSelectionSheetOpen = true;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setInner) {
          final filteredPlayers =
              players
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Select $label',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search for $label...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) => setInner(() => query = v.toLowerCase()),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: Get.height * 0.6),
                  child:
                      filteredPlayers.isEmpty
                          ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (searchCtrl.text.isEmpty) ...[
                                    const CircularProgressIndicator(
                                      color: AppTheme.primaryGreen,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading players...',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: Colors.grey.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No players found matching "$query"',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                            itemCount: filteredPlayers.length,
                            itemBuilder: (ctx, i) {
                              final player = filteredPlayers[i];
                              final isSelected = selectedId == player.id;
                              final isEnabled =
                                  enabledPredicate?.call(player) ?? true;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap:
                                      isEnabled
                                          ? () {
                                            onChanged(player.id);
                                            Get.back();
                                          }
                                          : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? color.withOpacity(0.1)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? color.withOpacity(0.5)
                                                : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Opacity(
                                          opacity: isEnabled ? 1.0 : 0.4,
                                          child: _buildAvatar(
                                            player.name,
                                            24,
                                            isSelected: isSelected,
                                            color: color,
                                            imageUrl: player.profileImageUrl,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                player.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      isSelected
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                  color:
                                                      isSelected
                                                          ? color
                                                          : (isEnabled
                                                              ? (isDark
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black87)
                                                              : Colors.grey),
                                                ),
                                              ),
                                              if (subtitleBuilder != null)
                                                subtitleBuilder(player)
                                              else
                                                Text(
                                                  player.role.replaceAll(
                                                    '_',
                                                    ' ',
                                                  ),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(Icons.check_circle, color: color)
                                        else if (!isEnabled)
                                          const Icon(
                                            Icons.block,
                                            color: Colors.grey,
                                            size: 16,
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
          );
        },
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      backgroundColor: Colors.transparent,
    ).then((_) {
      _isSelectionSheetOpen = false;
    });
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

      return SafeArea(
        child: Column(
          children: [
            _buildScoreSummary(match, isDark),

            if (match.isFreeHit)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Center(
                  child: Text(
                    'FREE HIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

            if (match.groundName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${match.groundName}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),

            _buildCurrentPlayersBar(match, batsman, nonStriker, bowler, isDark),

            // if (match.activePartnership != null)
            //   Padding(
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 16,
            //       vertical: 8,
            //     ),
            //     child: PartnershipCard(
            //       partnership: match.activePartnership!,
            //       isDark: isDark,
            //     ),
            //   ),
            if (match.isInningsBreak)
              _buildInningsBreakView(match, scoringProv, isDark)
            else ...[
              Expanded(child: _buildThisOverStrip(scoringProv, match, isDark)),

              // ── Innings Break Banner (Second Innings) ─────────────
              if (isScorer && needsStriker && needsBowler)
                Builder(
                  builder: (context) {
                    if (!match.isSecondInnings ||
                        match.currentScore.overs > 0 ||
                        match.currentScore.balls > 0)
                      return const SizedBox.shrink();

                    final target = match.targetScore;

                    return Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A4731), Color(0xFF0D2B1E)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryGreen,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.sports_cricket,
                            color: AppTheme.primaryGreen,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'INNINGS BREAK',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${match.battingTeamName} needs $target runs to win',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select new batsmen & bowler to begin 2nd innings',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // const Spacer(), // Removed to allow _buildThisOverStrip to expand
              if (!isScorer)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    child: const ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: AppTheme.accentBlue,
                      ),
                      title: Text('View Only Mode'),
                      subtitle: Text('Only assigned scorers can record balls.'),
                    ),
                  ),
                )
              else if (needsStriker)
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
              else if (isScorer && needsBowler)
                _buildMissingPlayerCta(
                  'Select Bowler for New Over',
                  Icons.gps_fixed,
                  AppTheme.accentPurple,
                  () => _openBowlerSelection(match, players, isDark),
                )
              else if (isScorer)
                _buildScoringButtons(
                  match,
                  batsman,
                  bowler,
                  scoringProv,
                  isDark,
                ),
            ],
          ],
        ),
      );
    } catch (e, stack) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            'CRASH IN SCORING VIEW:\n$e\n\n$stack',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      );
    }
  }

  Widget _buildInningsBreakView(
    MatchModel match,
    ScoringController scoringProv,
    bool isDark,
  ) {
    return Expanded(
      child: Center(
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
      ),
    );
  }

  Widget _buildMatchCompletedView(MatchModel match, bool isDark) {
    return Center(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            // MOTM Section
            Builder(
              builder: (context) {
                final motmMap = match.manOfTheMatchMap;
                final motmPlayerId = match.manOfMatch;
                final motmPlayer =
                    motmPlayerId != null
                        ? matchController.players[motmPlayerId]
                        : null;

                final String motmName =
                    (motmMap?['name']?.toString() ??
                            motmPlayer?.name ??
                            match.manOfMatchName ??
                            "")
                        .trim();
                final String? motmImage =
                    (motmMap?['image']?.toString()) ??
                    motmPlayer?.profileImageUrl;
                final String? motmTeam =
                    (motmMap?['team']?.toString()) ??
                    (motmPlayer?.teamId == 'A'
                        ? match.teamAName
                        : (motmPlayer?.teamId == 'B' ? match.teamBName : null));

                // Direct calculation if name is empty but match is completed
                String displayMOTMName = motmName;
                String? displayMOTMImage = motmImage;
                String? displayMOTMTeam = motmTeam;
                PlayerModel? displayMOTMPlayer = motmPlayer;

                if (displayMOTMName.isEmpty &&
                    match.isCompleted &&
                    matchController.players.isNotEmpty) {
                  String winningTeamId = '';
                  if (match.result != null) {
                    if (match.result!.toLowerCase().contains(
                      match.teamAName.toLowerCase(),
                    )) {
                      winningTeamId = 'A';
                    } else if (match.result!.toLowerCase().contains(
                      match.teamBName.toLowerCase(),
                    )) {
                      winningTeamId = 'B';
                    }
                  }

                  PlayerModel? bestP;
                  double bestS = -1;

                  for (var p in matchController.players.values) {
                    double s = p.calculateMOTMScore(winningTeamId);
                    if (s > bestS) {
                      bestS = s;
                      bestP = p;
                    }
                  }

                  if (bestP != null) {
                    displayMOTMName = bestP.name;
                    displayMOTMImage = bestP.profileImageUrl;
                    displayMOTMTeam =
                        bestP.teamId == 'A' ? match.teamAName : match.teamBName;
                    displayMOTMPlayer = bestP;
                  }
                }

                final isScorer =
                    match.scorerIds.contains(authController.userId) ||
                    (authController.currentUser?.isAdmin ?? false);

                if (displayMOTMName.isNotEmpty) {
                  return Column(
                    children: [
                      MOTMAwardCard(
                        playerName: displayMOTMName,
                        playerImageUrl: displayMOTMImage,
                        teamName: displayMOTMTeam,
                        runs: displayMOTMPlayer?.runsScored ?? 0,
                        wickets: displayMOTMPlayer?.wicketsTaken ?? 0,
                        catches: displayMOTMPlayer?.catches ?? 0,
                        canEdit: false,
                      ),
                      const SizedBox(height: 48),
                    ],
                  );
                } else {
                  if (match.isCompleted && match.result != null) {
                    Future.microtask(() {
                      Get.find<ScoringController>().saveManOfMatch(
                        match.id,
                        match.result!,
                      );
                    });
                  }
                  return Column(
                    children: [
                      _buildSelectMOTMPlaceholder(match, isDark),
                      const SizedBox(height: 48),
                    ],
                  );
                }
              },
            ),
            if (match.tournamentId != null) ...[
              // Tournament Actions
              Obx(() {
                final nextMatch = tournamentController.nextMatchToPlay;
                if (nextMatch != null) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Get.offNamedUntil(
                              AppRoutes.createMatch,
                              (route) => route.isFirst,
                              arguments: {
                                'tournamentId': match.tournamentId,
                                'existingMatchId': nextMatch.id,
                              },
                            );
                          },
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Continue Next Match',
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
                      const SizedBox(height: 12),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Matches Completed',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }
              }),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.offNamedUntil(
                      AppRoutes.tournamentDetail,
                      (route) => route.isFirst,
                      arguments: match.tournamentId,
                    );
                  },
                  icon: const Icon(
                    Icons.dashboard_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                  label: Text(
                    'Go to Tournament',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed:
                      () => Get.toNamed(
                        AppRoutes.matchDetail,
                        arguments: match.id,
                      ),
                  icon: const Icon(Icons.bar_chart_rounded, color: Colors.grey),
                  label: const Text(
                    'View Match Results',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else if ((authController.currentUser?.isAdmin ?? false) &&
                matchController.liveMatches.isEmpty &&
                match.tournamentId == null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      () => MatchDialogs.showRematchDialog(context, match),
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
                onPressed: () => Get.offAllNamed(AppRoutes.home),
                icon: const Icon(Icons.home_rounded, color: Colors.white),
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
    );
  }

  Widget _buildMissingPlayerCta(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          icon: Icon(icon, color: Colors.white),
          label: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
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
    String? imageUrl,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isSelected ? (color ?? AppTheme.primaryGreen) : Colors.grey[300],
      backgroundImage:
          imageUrl != null && imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
      child:
          imageUrl == null || imageUrl.isEmpty
              ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              )
              : null,
    );
  }

  Widget _buildScoreSummary(MatchModel match, bool isDark) {
    final score = match.currentScore;

    // ── Chase info (2nd innings only) ────────────────────────────────
    final initialBattingTeam =
        match.tossWonBy == 'A'
            ? (match.tossDecision == 'bat' ? 'A' : 'B')
            : (match.tossDecision == 'bat' ? 'B' : 'A');
    final isSecondInnings = match.currentInnings != initialBattingTeam;

    int target = 0;
    int runsNeeded = 0;
    int ballsRemaining = 0;
    double rrr = 0.0;

    if (isSecondInnings) {
      final firstInningsScore =
          match.currentInnings == 'A' ? match.teamBScore : match.teamAScore;
      target = firstInningsScore.runs + 1;
      runsNeeded = (target - score.runs).clamp(0, target);
      final totalBalls = match.totalOvers * match.ballsPerOver;
      final ballsBowled = (score.overs * match.ballsPerOver) + score.balls;
      ballsRemaining = (totalBalls - ballsBowled).clamp(0, totalBalls);
      rrr =
          ballsRemaining > 0
              ? (runsNeeded * match.ballsPerOver) / ballsRemaining
              : 0.0;
    }

    return Column(
      children: [
        // ── Main score bar ────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : AppTheme.primaryGreen,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Score
              Column(
                children: [
                  Text(
                    match.battingTeamName,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${score.runs}/${score.wickets}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(height: 40, width: 1, color: Colors.white24),
              // Overs
              Column(
                children: [
                  Text(
                    'OVERS',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final isCustom = match.customRulesEnabled;
                      return Text(
                        isCustom
                            ? score.oversDisplay
                            : '${score.oversDisplay}/${match.totalOvers}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Container(height: 40, width: 1, color: Colors.white24),
              // CRR
              Column(
                children: [
                  Text(
                    'CRR',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    score.runRate.toStringAsFixed(2),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // RRR — only in 2nd innings
              if (isSecondInnings && rrr != null) ...[
                Container(height: 40, width: 1, color: Colors.white24),
                Column(
                  children: [
                    Text(
                      'RRR',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      rrr.toStringAsFixed(2),
                      style: GoogleFonts.outfit(
                        color:
                            rrr > score.runRate
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // ── Chase info bar ─────────────────────────────────────────
        if (isSecondInnings && runsNeeded != null && ballsRemaining != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: isDark ? const Color(0xFF0D1418) : const Color(0xFF1A4731),
            child: Text(
              '${match.battingTeamName} need${runsNeeded == 1 ? 's' : ''} $runsNeeded run${runsNeeded == 1 ? '' : 's'} in $ballsRemaining ball${ballsRemaining == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
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
    bool canReplaceBowler = match.currentScore.balls == 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: isDark ? Colors.black26 : Colors.grey[200],
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildBatsmanRow(match, batsman, true, isDark),
                if (nonStriker != null && !match.customRulesEnabled)
                  _buildBatsmanRow(match, nonStriker, false, isDark),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap:
                  canReplaceBowler
                      ? () => _openBowlerSelection(
                        match,
                        matchController.players,
                        isDark,
                      )
                      : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.gps_fixed,
                      size: 14,
                      color: AppTheme.accentPurple,
                    ),
                    Text(
                      bowler.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentPurple,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${bowler.oversBowledDisplay} - ${bowler.bowlingFigures}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    if (canReplaceBowler)
                      Text(
                        'Replace',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.accentPurple.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.accentPurple.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatsmanRow(
    MatchModel match,
    PlayerModel player,
    bool isStriker,
    bool isDark,
  ) {
    bool canReplace = player.ballsFaced == 0;

    return InkWell(
      onTap:
          canReplace
              ? () {
                if (isStriker) {
                  _openStrikerSelection(match, matchController.players, isDark);
                } else {
                  _openNonStrikerSelection(
                    match,
                    matchController.players,
                    isDark,
                  );
                }
              }
              : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            isStriker
                ? BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                  ),
                )
                : null,
        child: Row(
          children: [
            if (isStriker)
              const Icon(
                Icons.sports_cricket,
                size: 14,
                color: AppTheme.primaryGreen,
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isStriker ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (canReplace)
                    Text(
                      'Replace',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.primaryGreen.withOpacity(0.7),
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.primaryGreen.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${player.runsScored}(${player.ballsFaced})',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isStriker ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThisOverStrip(
    ScoringController scoringProv,
    MatchModel match,
    bool isDark,
  ) {
    // Filter ball logs by current innings
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

    // Build a map: overNumber → list of balls (already sorted ascending from listener)
    final Map<int, List<BallLog>> overMap = {};
    for (final ball in allBalls) {
      overMap.putIfAbsent(ball.overNumber, () => []).add(ball);
    }

    // Sort over keys descending (latest over first)
    final sortedOverKeys =
        overMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final visibleOvers = sortedOverKeys.toList();

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF9FAFB),
      child: ListView.separated(
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

          // Calculate total legal runs for this over
          final overRuns = overBalls.fold<int>(0, (sum, b) {
            int r = b.runs + (b.extraRuns ?? 0);
            return sum + r;
          });

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                // Over label
                SizedBox(
                  width: 68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentOver ? 'THIS OVER' : 'OVER ${overNum + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 9,
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
                          fontSize: 13,
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
                // Balls — oldest first (left to right)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          overBalls.map((ball) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 30,
                              height: 30,
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
                                          width: 2,
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
                                        fontSize: 10,
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

    return Container(
      height: 280, // Fixed height for the grid
      width: double.infinity,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                  isDark: isDark,
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
                  isDark: isDark,
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
                  textColor: AppTheme.byeColor,
                  isDark: isDark,
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
                ),
                // _buildGridBtn(
                //   '5, 7',
                //   () => _showRunsBottomSheet(
                //     match,
                //     batsman,
                //     bowler,
                //     scoringProv,
                //     isDark,
                //   ),
                //   flex: 3,
                //   isDark: isDark,
                // ),
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
                  flex: 3,
                  isDark: isDark,
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
  }) {
    final borderColor =
        isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: _isProcessingAction ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: borderColor, width: 0.5),
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: fontWeight ?? FontWeight.w500,
                  color:
                      _isProcessingAction
                          ? Colors.grey
                          : (textColor ??
                              (isDark ? Colors.white : Colors.black87)),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white : AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select additional runs to record',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                          ),
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        int runs = index;
                        String label =
                            type == 'wide'
                                ? '+$runs'
                                : type == 'no_ball'
                                ? '+$runs'
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
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors:
                                    runs == 0
                                        ? [
                                          Colors.grey.shade400,
                                          Colors.grey.shade600,
                                        ]
                                        : [
                                          AppTheme.primaryGreen,
                                          const Color(0xFF059669),
                                        ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (runs == 0
                                          ? Colors.grey
                                          : AppTheme.primaryGreen)
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (type == 'wide' || type == 'no_ball')
                                  Text(
                                    type == 'wide' ? 'WIDE' : 'N.B',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  children: [
                    Text(
                      'MORE RUNS',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white : AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select the specific runs scored',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          [5, 7, 8].map((runs) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: InkWell(
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
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.primaryGreen,
                                          Color(0xFF059669),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryGreen
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$runs',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _undoLastBall(
    MatchController matchProv,
    ScoringController scoringProv,
  ) async {
    if (matchProv.selectedMatch == null) return;
    if (_isProcessingAction) return;

    final shouldUndo = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Undo Last Ball',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'Are you sure you want to undo the last ball? Only the scorer who added the ball can undo it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Undo'),
              ),
            ],
          ),
    );

    if (shouldUndo == true) {
      setState(() => _isProcessingAction = true);
      try {
        await scoringProv.undoLastBall(matchProv.selectedMatch!);
      } finally {
        if (mounted) {
          setState(() => _isProcessingAction = false);
        }
      }
    }
  }

  void _showWicketDialog(
    MatchModel match,
    PlayerModel batsman,
    PlayerModel bowler,
    ScoringController scoringProv,
    bool isDark,
  ) {
    String dismissalType = AppConstants.dismissalBowled;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final bg =
                  isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
              final cardBg =
                  isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0F5A).withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: -10,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0F5A).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sports_cricket_rounded,
                          color: Color(0xFFFF0F5A),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'WICKET!',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: const Color(0xFFFF0F5A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select dismissal type',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Grid Layout (2 Columns)
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.4,
                        children:
                            [
                              AppConstants.dismissalBowled,
                              AppConstants.dismissalCaught,
                              AppConstants.dismissalRunOut,
                              AppConstants.dismissalStumped,
                              AppConstants.dismissalLBW,
                              AppConstants.dismissalHitWicket,
                            ].map((type) {
                              final isSelected = dismissalType == type;

                              IconData iconData;
                              switch (type) {
                                case AppConstants.dismissalBowled:
                                  iconData = Icons.sports_cricket_rounded;
                                  break;
                                case AppConstants.dismissalCaught:
                                  iconData = Icons.front_hand_rounded;
                                  break;
                                case AppConstants.dismissalRunOut:
                                  iconData = Icons.bolt_rounded;
                                  break;
                                case AppConstants.dismissalStumped:
                                  iconData = Icons.back_hand_rounded;
                                  break;
                                case AppConstants.dismissalLBW:
                                  iconData = Icons.straighten_rounded;
                                  break;
                                case AppConstants.dismissalHitWicket:
                                  iconData = Icons.close_rounded;
                                  break;
                                default:
                                  iconData = Icons.sports_cricket_rounded;
                              }

                              String displayText =
                                  type.toUpperCase() == 'LBW'
                                      ? 'LBW'
                                      : type
                                          .split('_')
                                          .map((word) {
                                            if (word.isEmpty) return word;
                                            return word[0].toUpperCase() +
                                                word.substring(1).toLowerCase();
                                          })
                                          .join(' ');

                              return GestureDetector(
                                onTap:
                                    () => setDialogState(
                                      () => dismissalType = type,
                                    ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    gradient:
                                        isSelected
                                            ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFF0F5A),
                                                Color(0xFFFF4B2B),
                                              ],
                                            )
                                            : null,
                                    color: isSelected ? null : cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? Colors.transparent
                                              : (isDark
                                                  ? Colors.white.withOpacity(
                                                    0.05,
                                                  )
                                                  : Colors.black.withOpacity(
                                                    0.05,
                                                  )),
                                    ),
                                    boxShadow:
                                        isSelected
                                            ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFFF0F5A,
                                                ).withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                            : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        iconData,
                                        size: 16,
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600]),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        displayText,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : (isDark
                                                      ? Colors.grey[300]
                                                      : Colors.grey[800]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                side: BorderSide(
                                  color:
                                      isDark
                                          ? Colors.grey[800]!
                                          : Colors.grey[300]!,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (dismissalType ==
                                    AppConstants.dismissalRunOut) {
                                  _showRunOutFlow(
                                    match,
                                    batsman,
                                    bowler,
                                    scoringProv,
                                    isDark,
                                  );
                                } else if (dismissalType ==
                                        AppConstants.dismissalCaught ||
                                    dismissalType ==
                                        AppConstants.dismissalStumped) {
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
                                backgroundColor: const Color(0xFFFF0F5A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                'Confirm',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
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
              );
            },
          ),
    );
  }

  void _showRunOutFlow(
    MatchModel match,
    PlayerModel striker,
    PlayerModel bowler,
    ScoringController scoringProv,
    bool isDark,
  ) {
    int currentStep = 1;
    PlayerModel? selectedFielder;
    PlayerModel? dismissedBatsman;
    PlayerModel? newBatsman;

    final fieldingTeamPlayers =
        matchController.players.values.where((p) {
          return p.teamId == (match.currentInnings == 'A' ? 'B' : 'A') ||
              (p.teamId == '' &&
                  ((match.currentInnings == 'A' &&
                          match.teamBPlayers.contains(p.id)) ||
                      (match.currentInnings == 'B' &&
                          match.teamAPlayers.contains(p.id))));
        }).toList();

    final currentBatsmen =
        [
          if (match.currentBatsmanId != null)
            matchController.players[match.currentBatsmanId],
          if (match.currentNonStrikerId != null)
            matchController.players[match.currentNonStrikerId],
        ].whereType<PlayerModel>().toList();

    final battingTeamPlayers =
        matchController.players.values.where((p) {
          return p.teamId == match.currentInnings ||
              (p.teamId == '' &&
                  ((match.currentInnings == 'A' &&
                          match.teamAPlayers.contains(p.id)) ||
                      (match.currentInnings == 'B' &&
                          match.teamBPlayers.contains(p.id))));
        }).toList();

    final maxBatBalls =
        match.customRulesEnabled
            ? (match.maxBattingOvers ?? 2) * match.ballsPerOver
            : 999;
    final remainingBatsmen =
        battingTeamPlayers
            .where(
              (p) =>
                  !p.isOut &&
                  p.id != match.currentBatsmanId &&
                  p.id != match.currentNonStrikerId &&
                  p.canBatWithLimit(maxBatBalls),
            )
            .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setStepState) {
              final bg =
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
              final cardBg =
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Header & Progress
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RUN OUT FLOW',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      currentStep == 1
                                          ? 'Select the fielder responsible'
                                          : (currentStep == 2
                                              ? 'Who was dismissed?'
                                              : 'Select incoming batsman'),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Close button
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Step Indicator
                          Row(
                            children:
                                [1, 2, 3].map((s) {
                                  final isCompleted = s < currentStep;
                                  final isActive = s == currentStep;
                                  return Expanded(
                                    child: Container(
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isCompleted
                                                ? AppTheme.primaryGreen
                                                : (isActive
                                                    ? AppTheme.primaryGreen
                                                        .withOpacity(0.5)
                                                    : Colors.grey.withOpacity(
                                                      0.2,
                                                    )),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Step Content
                    Expanded(
                      child: IndexedStack(
                        index: currentStep - 1,
                        children: [
                          // Step 1: Fielders
                          _buildRunOutPlayerList(
                            fieldingTeamPlayers,
                            selectedFielder,
                            isDark,
                            cardBg,
                            (p) {
                              setStepState(() {
                                selectedFielder = p;
                                currentStep = 2;
                              });
                            },
                          ),
                          // Step 2: Dismissed Batsman
                          _buildRunOutPlayerList(
                            currentBatsmen,
                            dismissedBatsman,
                            isDark,
                            cardBg,
                            (p) {
                              setStepState(() {
                                dismissedBatsman = p;

                                if (remainingBatsmen.length == 1) {
                                  // Auto-select last remaining player
                                  newBatsman = remainingBatsmen.first;
                                  Navigator.pop(ctx);
                                  UIUtils.showSuccess(
                                    'Next batsman auto selected: ${newBatsman!.name}',
                                  );
                                  _safeRecordBall(
                                    match,
                                    striker,
                                    bowler,
                                    0,
                                    'normal',
                                    scoringProv,
                                    isWicket: true,
                                    dismissalType:
                                        'Run Out (${selectedFielder?.name})',
                                    dismissedPlayerId: dismissedBatsman?.id,
                                    fielderId: selectedFielder?.id,
                                    newIncomingBatsmanId: newBatsman?.id,
                                  );
                                } else if (remainingBatsmen.isEmpty) {
                                  // No more players available
                                  Navigator.pop(ctx);
                                  _safeRecordBall(
                                    match,
                                    striker,
                                    bowler,
                                    0,
                                    'normal',
                                    scoringProv,
                                    isWicket: true,
                                    dismissalType:
                                        'Run Out (${selectedFielder?.name})',
                                    dismissedPlayerId: dismissedBatsman?.id,
                                    fielderId: selectedFielder?.id,
                                  );
                                } else {
                                  // Multiple players left, show manual selection
                                  currentStep = 3;
                                }
                              });
                            },
                            subtitleBuilder:
                                (p) =>
                                    p.id == match.currentBatsmanId
                                        ? 'Striker'
                                        : 'Non-Striker',
                          ),
                          // Step 3: New Batsman
                          _buildRunOutPlayerList(
                            remainingBatsmen,
                            newBatsman,
                            isDark,
                            cardBg,
                            (p) {
                              setStepState(() {
                                newBatsman = p;
                              });
                              // Auto confirm after 3rd selection
                              Navigator.pop(ctx);
                              _safeRecordBall(
                                match,
                                striker,
                                bowler,
                                0,
                                'normal',
                                scoringProv,
                                isWicket: true,
                                dismissalType:
                                    'Run Out (${selectedFielder?.name})',
                                dismissedPlayerId: dismissedBatsman?.id,
                                fielderId: selectedFielder?.id,
                                newIncomingBatsmanId: newBatsman?.id,
                              );
                              // We don't need to manually select new batsman here because recordBall handles it
                              // But wait, the user asked to select next batsman here.
                              // Actually recordBall will set current_batsman_id to null,
                              // and the screen will naturally show the picker.
                              // But if we want to do it in one flow, we should pass it or call it after.
                            },
                            emptyMessage:
                                match.lastPlayerCanPlay &&
                                        remainingBatsmen.isEmpty
                                    ? 'No more players. Last player continues!'
                                    : 'All out! No more batsmen available.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildRunOutPlayerList(
    List<PlayerModel> players,
    PlayerModel? selected,
    bool isDark,
    Color cardBg,
    Function(PlayerModel) onSelect, {
    String? Function(PlayerModel)? subtitleBuilder,
    String? emptyMessage,
  }) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off_rounded,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No players available',
              style: GoogleFonts.inter(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final isSelected = selected?.id == p.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryGreen : cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color:
                    isSelected
                        ? AppTheme.primaryGreen
                        : (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05)),
              ),
            ),
            child: ListTile(
              onTap: () => onSelect(p),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: CircleAvatar(
                backgroundColor:
                    isSelected
                        ? Colors.white.withOpacity(0.2)
                        : AppTheme.primaryGreen.withOpacity(0.1),
                child: Text(
                  p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                p.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color:
                      isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              subtitle:
                  subtitleBuilder != null
                      ? Text(
                        subtitleBuilder(p)!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isSelected ? Colors.white70 : Colors.grey,
                        ),
                      )
                      : null,
              trailing:
                  isSelected
                      ? const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                      )
                      : Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.grey[700] : Colors.grey[400],
                      ),
            ),
          ),
        );
      },
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  'Select Fielder (${baseDismissalType.toUpperCase()})',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: fieldingTeamPlayers.length,
                    itemBuilder: (ctx, i) {
                      final p = fieldingTeamPlayers[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGreen.withOpacity(
                            0.2,
                          ),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _safeRecordBall(
                            match,
                            batsman,
                            bowler,
                            0,
                            'normal',
                            scoringProv,
                            isWicket: true,
                            dismissalType: '$baseDismissalType (${p.name})',
                            dismissedPlayerId: batsman.id,
                            fielderId: p.id,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
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
      Get.back(); // Close bottom sheet

      UIUtils.showLoading('Setting up rematch...');

      final newMatchId = await matchController.performRematch(
        match: match,
        tossWonBy: tossWonBy,
        tossDecision: tossDecision,
        currentUserId: authController.userId!,
      );

      Get.back(); // Hide loading

      if (newMatchId != null) {
        // Navigate to new scoring screen
        Get.off(() => ScoringScreen(matchId: newMatchId));
        UIUtils.showSuccess('Rematch started!');
      }
    } catch (e) {
      Get.back(); // Hide loading
      UIUtils.showError('Failed to start rematch: $e');
    }
  }

  Widget _buildSelectMOTMPlaceholder(MatchModel match, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.vibrantOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppTheme.vibrantOrange,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Calculating Man of the Match...',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
