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
    );

    if (mounted) {
      setState(() => _isProcessingAction = false);
    }
  }

  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      matchController.listenToMatch(widget.matchId);
      scoringController.initForMatch(widget.matchId);

      // Listen for completion to show dialog
      ever(matchController.selectedMatchRx, (MatchModel? match) {
        if (match != null &&
            match.status == AppConstants.matchCompleted &&
            !_dialogShown &&
            mounted) {
          _dialogShown = true;
          _showMatchCompletionDialog(match);
        }
      });
    });
  }

  void _showMatchCompletionDialog(MatchModel match) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      barrierDismissible: false,
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF00E676)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MATCH COMPLETED',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      match.result ?? 'Match Ended',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: isDark ? Colors.white10 : Colors.black12,
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSummaryItem(
                          isDark,
                          match.teamAName,
                          '${match.teamAScore.runs}/${match.teamAScore.wickets}',
                          match.teamAScore.oversDisplay,
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        _buildSummaryItem(
                          isDark,
                          match.teamBName,
                          '${match.teamBScore.runs}/${match.teamBScore.wickets}',
                          match.teamBScore.oversDisplay,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.offAllNamed('/home');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'BACK TO HOME',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      body: Obx(() {
        final match = matchController.selectedMatch;
        if (match == null) {
          return const Center(child: CircularProgressIndicator());
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
    );
  }

  // --- Player Selection Helpers ---
  void _openStrikerSelection(
    MatchModel match,
    Map<String, PlayerModel> players,
    bool isDark,
  ) {
    final maxBatBalls =
        match.customRulesEnabled
            ? rulesController.maxBattingOvers.value * 6
            : 999;
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
        match.customRulesEnabled
            ? rulesController.maxBattingOvers.value * 6
            : 999;
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
            ? rulesController.maxBowlingOvers.value
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
    final searchCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            final filteredPlayers =
                players
                    .where((p) => p.name.toLowerCase().contains(query))
                    .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
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
                          Icon(icon, color: color, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Select $label',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus:
                            false, // Prevents keyboard from immediately opening
                        decoration: InputDecoration(
                          hintText: 'Search for $label...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor:
                              isDark
                                  ? const Color(0xFF1B263B)
                                  : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged:
                            (v) => setInner(() => query = v.toLowerCase()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredPlayers.length,
                        itemBuilder: (ctx, i) {
                          final player = filteredPlayers[i];
                          final isSelected = selectedId == player.id;
                          final isEnabled =
                              enabledPredicate?.call(player) ?? true;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              enabled: isEnabled,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              tileColor:
                                  isSelected ? color.withOpacity(0.08) : null,
                              leading: Opacity(
                                opacity: isEnabled ? 1.0 : 0.5,
                                child: _buildAvatar(
                                  player.name,
                                  20,
                                  isSelected: isSelected,
                                  color: color,
                                ),
                              ),
                              title: Text(
                                player.name,
                                style: GoogleFonts.inter(
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  color:
                                      isSelected
                                          ? color
                                          : (isEnabled ? null : Colors.grey),
                                ),
                              ),
                              subtitle:
                                  subtitleBuilder != null
                                      ? subtitleBuilder(player)
                                      : (player.role != 'player'
                                          ? Text(
                                            player.role.replaceAll('_', ' '),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          )
                                          : null),
                              trailing:
                                  isSelected
                                      ? Icon(Icons.check_circle, color: color)
                                      : null,
                              onTap: () {
                                onChanged(player.id);
                                Navigator.pop(context);
                              },
                            ),
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
      },
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

      final batsman =
          actualBatsman ?? PlayerModel(id: '', name: 'Select Striker');
      final nonStriker =
          actualNonStriker ??
          (match.customRulesEnabled
              ? null
              : PlayerModel(id: '', name: 'Select Non-Striker'));
      final bowler = actualBowler ?? PlayerModel(id: '', name: 'Select Bowler');

      final isScorer =
          match.scorerIds.contains(authController.userId) ||
          (authController.currentUser?.isAdmin ?? false);

      final needsStriker = actualBatsman == null;
      final needsNonStriker =
          actualNonStriker == null && !match.customRulesEnabled;
      final needsBowler = actualBowler == null;

      return Column(
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
          _buildThisOverStrip(scoringProv, match, isDark),

          if (match.isInningsBreak)
            _buildInningsBreakView(match, scoringProv, isDark)
          else ...[
            // ── Innings Break Banner (Second Innings) ─────────────
            if (isScorer && needsStriker && needsBowler)
              Builder(
                builder: (context) {
                  final initialBattingTeam =
                      match.tossWonBy == 'A'
                          ? (match.tossDecision == 'bat' ? 'A' : 'B')
                          : (match.tossDecision == 'bat' ? 'B' : 'A');
                  final isSecondInnings =
                      match.currentInnings != initialBattingTeam;
                  if (!isSecondInnings) return const SizedBox.shrink();

                  final firstScore =
                      match.currentInnings == 'A'
                          ? match.teamBScore
                          : match.teamAScore;
                  final target = firstScore.runs + 1;

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

            const Spacer(),

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
              _buildScoringButtons(match, batsman, bowler, scoringProv, isDark),
          ],

          const SizedBox(height: 16),
        ],
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

    // ── Chase info (2nd innings only) ────────────────────────────────
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

    // Sort over keys descending (latest over first), take last 3
    final sortedOverKeys =
        overMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final visibleOvers = sortedOverKeys.take(3).toList();

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF9FAFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visibleOvers.asMap().entries.map((entry) {
            final isCurrentOver = entry.key == 0;
            final overNum = entry.value;
            final overBalls = overMap[overNum]!;

            // Calculate total legal runs for this over
            final overRuns = overBalls.fold<int>(0, (sum, b) {
              int r = b.runs + (b.extraRuns ?? 0);
              return sum + r;
            });

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
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
                                            color: Colors.white,
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
          }),
          if (visibleOvers.length > 1)
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
        ],
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
                _buildGridBtn(
                  '5, 7',
                  () => _showRunsBottomSheet(
                    match,
                    batsman,
                    bowler,
                    scoringProv,
                    isDark,
                  ),
                  flex: 3,
                  isDark: isDark,
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
                  textColor: Colors.red,
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

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
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
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
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
        );
      },
    );
  }

  void _undoLastBall(MatchController matchProv, ScoringController scoringProv) {
    if (matchProv.selectedMatch == null) return;
    showDialog(
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  scoringProv.undoLastBall(matchProv.selectedMatch!);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Undo'),
              ),
            ],
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
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final dialogBg =
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF0E5);
              final textColor = isDark ? Colors.white : Colors.black87;

              return Dialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wicket!',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dismissal type:',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
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

                              // Format text to remove underscores and use Title Case
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

                              return InkWell(
                                onTap:
                                    () => setDialogState(
                                      () => dismissalType = type,
                                    ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 110,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? const Color(0xFFFFCCD5)
                                            : (isDark
                                                ? const Color(0xFF2D3748)
                                                : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? Colors.transparent
                                              : (isDark
                                                  ? Colors.grey[800]!
                                                  : Colors.grey[300]!),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.black87,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        displayText,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isSelected
                                                  ? Colors.black87
                                                  : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00C853),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (dismissalType ==
                                      AppConstants.dismissalCaught ||
                                  dismissalType ==
                                      AppConstants.dismissalRunOut ||
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Confirm',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
}
