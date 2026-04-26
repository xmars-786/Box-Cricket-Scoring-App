import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/pdf_service.dart';
import '../../../core/utils/ui_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';

import '../../../core/models/match_model.dart';
import '../../../core/models/player_model.dart';
import '../../../core/models/ball_log_model.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/scoring_controller.dart';
import '../../../core/controllers/match_detail_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_utils.dart';
import '../../scoring/screens/scoring_screen.dart';
import '../../scorecard/screens/scorecard_screen.dart';
import '../utils/match_dialogs.dart';
import 'package:lottie/lottie.dart';

/// Match detail screen for viewers — Cricbuzz-style live score view.
class MatchDetailScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final MatchController matchController = Get.find<MatchController>();
  final ScoringController scoringController = Get.find<ScoringController>();
  final AuthController authController = Get.find<AuthController>();
  final MatchDetailController detailController = Get.put(
    MatchDetailController(),
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      matchController.listenToMatch(widget.matchId);
      scoringController.initForMatch(widget.matchId);
      detailController.listenToLatestBall(widget.matchId);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Obx(() {
              final match = matchController.selectedMatch;
              if (match == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final isLive = match.status == AppConstants.matchLive;
              final isCompleted = match.status == AppConstants.matchCompleted;
              final tabLength = isLive ? 4 : 3;

              return DefaultTabController(
                length: tabLength,
                child: NestedScrollView(
                  headerSliverBuilder:
                      (context, innerBoxIsScrolled) => [
                        // Score header
                        SliverAppBar(
                          expandedHeight: 250,
                          pinned: true,
                          backgroundColor:
                              isDark
                                  ? const Color(0xFF111827)
                                  : AppTheme.primaryGreen,
                          flexibleSpace: FlexibleSpaceBar(
                            collapseMode: CollapseMode.none,
                            background: MatchHeaderWidget(
                              match: match,
                              isDark: isDark,
                            ),
                          ),
                          centerTitle: true,
                          title: Text(
                            innerBoxIsScrolled
                                ? '${match.teamAScore.runs}/${match.teamAScore.wickets} vs ${match.teamBScore.runs}/${match.teamBScore.wickets}'
                                : match.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          actions: [
                            if (match.isCompleted)
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () => _shareMatch(match),
                              ),
                            // More menu (Delete match)
                            Obx(() {
                              final isAdmin =
                                  authController.currentUser?.isAdmin ?? false;
                              if (!isAdmin) return const SizedBox.shrink();
                              return PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    final confirm =
                                        await _showDeleteConfirmation(context);
                                    if (confirm == true) {
                                      await matchController.deleteMatch(
                                        match.id,
                                      );
                                      Get.back(); // Go back to Home/Match List after deleting
                                    }
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Delete Match',
                                              style: GoogleFonts.inter(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                              );
                            }),
                          ],
                          bottom: TabsWidget(isLive: isLive, isDark: isDark),
                        ),
                      ],
                  body: TabBarView(
                    children: [
                      if (isLive)
                        _buildLiveTab(
                          match,
                          matchController.players,
                          scoringController,
                          isDark,
                        ),
                      ScorecardScreen(
                        match: match,
                        players: matchController.players,
                      ),
                      _buildSquadsTab(
                        match,
                        matchController.players.values.toList(),
                        isDark,
                      ),
                      _buildInfoTab(match, isDark),
                    ],
                  ),
                ),
              );
            }),
            // Funny & Dynamic Animation Overlay
            Obx(() {
              final anim = detailController.currentAnimation.value;
              if (anim == null) return const SizedBox.shrink();

              Color bgColor;
              String title;
              String emoji;
              List<Color> gradient;

              switch (anim) {
                case 'wicket':
                  bgColor = Colors.redAccent;
                  title = 'OUT!';
                  emoji = '☝️';
                  gradient = [Colors.red.shade900, Colors.redAccent];
                  break;
                case 'six':
                  bgColor = Colors.blueAccent;
                  title = 'MAXIMUM!';
                  emoji = '🚀🔥';
                  gradient = [Colors.blue.shade900, Colors.blueAccent];
                  break;
                case 'four':
                  bgColor = Colors.orangeAccent;
                  title = 'FOUR!';
                  emoji = '🏃‍♂️💨';
                  gradient = [Colors.orange.shade900, Colors.orangeAccent];
                  break;
                case 'wide':
                  bgColor = Colors.purpleAccent;
                  title = 'WIDE!';
                  emoji = '↔️';
                  gradient = [Colors.purple.shade900, Colors.purpleAccent];
                  break;
                case 'no_ball':
                  bgColor = Colors.amberAccent;
                  title = 'NO BALL!';
                  emoji = '🚫';
                  gradient = [Colors.amber.shade900, Colors.amberAccent];
                  break;
                default:
                  bgColor = AppTheme.primaryGreen;
                  title = anim.toUpperCase();
                  emoji = '🏏';
                  gradient = [const Color(0xFF0D1B2A), AppTheme.primaryGreen];
              }

              return Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Container(
                      color: Colors.black.withOpacity(0.7 * value),
                      child: Center(
                        child: Transform.scale(
                          scale: value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Floating Emojis
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeInOutBack,
                                builder: (context, emojiValue, _) {
                                  return Transform.translate(
                                    offset: Offset(0, -20 * emojiValue),
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 80),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              // Main Title with Gradient Background
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: bgColor.withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2,
                                        shadows: [
                                          const Shadow(
                                            color: Colors.black45,
                                            offset: Offset(4, 4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (anim == 'wicket')
                                      Text(
                                        'G O N E !',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white.withOpacity(0.8),
                                          letterSpacing: 8,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Optional Lottie Fallback (if they ever add the files)
                              Opacity(
                                opacity: 0.3,
                                child: Lottie.asset(
                                  'assets/lottie/$anim.json',
                                  width: 150,
                                  height: 150,
                                  repeat: false,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
      // Prominent Floating Action Button for Scoring
      floatingActionButton: Obx(() {
        final match = matchController.selectedMatch;
        if (match == null || !match.isLive) return const SizedBox.shrink();

        final isScorer =
            match.scorerIds.contains(authController.userId) ||
            (authController.currentUser?.isAdmin ?? false);

        if (!isScorer) return const SizedBox.shrink();

        return FloatingActionButton.extended(
          onPressed: () {
            Get.off(() => ScoringScreen(matchId: match.id));
          },
          backgroundColor: AppTheme.vibrantOrange,
          icon: const Icon(Icons.edit_note, color: Colors.white),
          label: Text(
            'Add Scores',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }),
    );
  }

  // ─── Delete Confirmation Dialog ────────────────────────
  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Delete Match',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete this match permanently? This action cannot be undone and will erase all match logs and player stats associated with it.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // ─── Live Tab ──────────────────────────────────────
  Widget _buildLiveTab(
    MatchModel match,
    Map<String, PlayerModel> players,
    ScoringController scoringCont,
    bool isDark,
  ) {
    final batsman =
        match.currentBatsmanId != null ? players[match.currentBatsmanId] : null;
    final nonStriker =
        match.currentNonStrikerId != null
            ? players[match.currentNonStrikerId]
            : null;
    final bowler =
        match.currentBowlerId != null ? players[match.currentBowlerId] : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Chase Bar (2nd innings only) ─────────────────────────────────────
        Builder(
          builder: (context) {
            final initialBattingTeam =
                match.tossWonBy == 'A'
                    ? (match.tossDecision == 'bat' ? 'A' : 'B')
                    : (match.tossDecision == 'bat' ? 'B' : 'A');
            final isSecondInnings = match.currentInnings != initialBattingTeam;

            if (!isSecondInnings) return const SizedBox.shrink();

            final firstScore =
                match.currentInnings == 'A'
                    ? match.teamBScore
                    : match.teamAScore;
            final battingScore = match.currentScore;
            final runsNeeded = (firstScore.runs + 1) - battingScore.runs;
            final ballsRemaining =
                (match.totalOvers * 6) -
                (battingScore.overs * 6 + battingScore.balls);

            if (runsNeeded <= 0 || ballsRemaining <= 0) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A4731), Color(0xFF0D2B1E)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${match.battingTeamName} need${runsNeeded == 1 ? "s" : ""} '
                '$runsNeeded run${runsNeeded == 1 ? "" : "s"} '
                'in $ballsRemaining ball${ballsRemaining == 1 ? "" : "s"}',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            );
          },
        ),
        // ── Win Probability (2nd innings only) ──────────────────────────────
        _buildWinProbabilityBar(match, isDark),

        // Current batsmen
        if (batsman != null || nonStriker != null)
          _buildCurrentBatsmenCard(batsman, nonStriker, isDark, match),

        const SizedBox(height: 12),

        // Current bowler
        if (bowler != null) _buildCurrentBowlerCard(bowler, isDark, match),

        const SizedBox(height: 16),

        // Ball-by-ball (this over)
        _buildThisOverCard(scoringCont.currentOverBalls, isDark),

        const SizedBox(height: 16),

        // Recent overs
        _buildRecentOversCard(match, scoringCont, isDark),

        const SizedBox(height: 16),

        // Partnership info
        if (batsman != null && nonStriker != null)
          _buildPartnershipCard(batsman, nonStriker, isDark),
      ],
    );
  }

  Widget _buildCurrentBatsmenCard(
    PlayerModel? striker,
    PlayerModel? nonStriker,
    bool isDark,
    MatchModel match,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BATTING',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Batsman',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  'R',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  'B',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '4s',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '6s',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  'SR',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          if (striker != null) _buildBatsmanRow(striker, true, match),
          if (nonStriker != null) ...[
            const SizedBox(height: 8),
            _buildBatsmanRow(nonStriker, false, match),
          ],
        ],
      ),
    );
  }

  Widget _buildBatsmanRow(
    PlayerModel player,
    bool isStriker,
    MatchModel match,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (player.id == match.teamACaptainId ||
                  player.id == match.teamBCaptainId) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFFFB800).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'C',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD49A00),
                    ),
                  ),
                ),
              ],
              if (player.id == match.teamAViceCaptainId ||
                  player.id == match.teamBViceCaptainId) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64B5F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF64B5F6).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'VC',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                ),
              ],
              if (isStriker)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '*',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${player.runsScored}',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${player.ballsFaced}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${player.fours}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${player.sixes}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            player.strikeRate.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentBowlerCard(
    PlayerModel bowler,
    bool isDark,
    MatchModel match,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BOWLING',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentPurple,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Bowler',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 35,
                child: Text(
                  'O',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 35,
                child: Text(
                  'R',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  'W',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              SizedBox(
                width: 45,
                child: Text(
                  'Econ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        bowler.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (bowler.id == match.teamACaptainId ||
                        bowler.id == match.teamBCaptainId) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFFB800).withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          'C',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD49A00),
                          ),
                        ),
                      ),
                    ],
                    if (bowler.id == match.teamAViceCaptainId ||
                        bowler.id == match.teamBViceCaptainId) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64B5F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF64B5F6).withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          'VC',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1976D2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 35,
                child: Text(
                  bowler.oversBowledDisplay,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
              SizedBox(
                width: 35,
                child: Text(
                  '${bowler.runsConceded}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text(
                  '${bowler.wicketsTaken}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color:
                        bowler.wicketsTaken > 0 ? AppTheme.primaryGreen : null,
                  ),
                ),
              ),
              SizedBox(
                width: 45,
                child: Text(
                  bowler.economyRate.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThisOverCard(List<BallLog> balls, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS OVER',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.vibrantOrange,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                balls.isEmpty
                    ? [
                      Text(
                        'No deliveries yet',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ]
                    : balls.map((ball) => _buildBallChip(ball)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBallChip(BallLog ball) {
    Color bgColor;
    Color textColor;

    if (ball.isWicket) {
      bgColor = AppTheme.wicketRed;
      textColor = Colors.white;
    } else if (ball.ballType == 'wide') {
      bgColor = AppTheme.wideColor;
      textColor = Colors.white;
    } else if (ball.ballType == 'no_ball') {
      bgColor = AppTheme.noBallColor;
      textColor = Colors.white;
    } else if (ball.ballType == 'bye' || ball.ballType == 'leg_bye') {
      bgColor = Colors.blueGrey;
      textColor = Colors.white;
    } else if (ball.isSix || ball.runs == 6) {
      bgColor = AppTheme.sixGold;
      textColor = Colors.black;
    } else if (ball.isFour || ball.runs == 4) {
      bgColor = AppTheme.fourYellow;
      textColor = Colors.black;
    } else if (ball.runs == 0) {
      bgColor = Colors.grey.withOpacity(0.2);
      textColor = Colors.grey;
    } else {
      bgColor = AppTheme.primaryGreen.withOpacity(0.15);
      textColor = AppTheme.primaryGreen;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              ball.displayText,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOversCard(
    MatchModel match,
    ScoringController scoringCont,
    bool isDark,
  ) {
    final currentInningsBalls = scoringCont.getBallsForInnings(
      match.currentInnings,
    );

    // Group balls by over
    final overs = <int, List<BallLog>>{};
    for (final ball in currentInningsBalls) {
      overs.putIfAbsent(ball.overNumber, () => []).add(ball);
    }

    final sortedOvers = overs.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT OVERS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentBlue,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedOvers.take(10).map((overNum) {
            final balls = overs[overNum]!;
            final overRuns = balls.fold<int>(0, (sum, b) => sum + b.totalRuns);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: Text(
                      'Ov ${overNum + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            balls
                                .map(
                                  (b) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _buildMiniBallChip(b),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$overRuns runs',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (sortedOvers.isEmpty)
            Text(
              'No overs bowled yet',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniBallChip(BallLog ball) {
    Color bgColor;
    Color textColor;

    if (ball.isWicket) {
      bgColor = AppTheme.wicketRed;
      textColor = Colors.white;
    } else if (ball.ballType == 'wide') {
      bgColor = AppTheme.wideColor;
      textColor = Colors.white;
    } else if (ball.ballType == 'no_ball') {
      bgColor = AppTheme.noBallColor;
      textColor = Colors.white;
    } else if (ball.ballType == 'bye' || ball.ballType == 'leg_bye') {
      bgColor = Colors.blueGrey;
      textColor = Colors.white;
    } else if (ball.isSix || ball.runs == 6) {
      bgColor = AppTheme.sixGold;
      textColor = Colors.black;
    } else if (ball.isFour || ball.runs == 4) {
      bgColor = AppTheme.fourYellow;
      textColor = Colors.black;
    } else if (ball.runs == 0) {
      bgColor = Colors.grey.withOpacity(0.2);
      textColor = Colors.grey;
    } else {
      bgColor = AppTheme.primaryGreen.withOpacity(0.15);
      textColor = AppTheme.primaryGreen;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Text(
              ball.displayText,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnershipCard(
    PlayerModel striker,
    PlayerModel nonStriker,
    bool isDark,
  ) {
    final partnershipRuns = striker.runsScored + nonStriker.runsScored;
    final partnershipBalls = striker.ballsFaced + nonStriker.ballsFaced;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARTNERSHIP',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    '$partnershipRuns',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Runs',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 40,
                color:
                    isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
              ),
              Column(
                children: [
                  Text(
                    '$partnershipBalls',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Balls',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Squads Tab ───────────────────────────────────
  Widget _buildSquadsTab(
    MatchModel match,
    List<PlayerModel> allPlayers,
    bool isDark,
  ) {
    final teamAPlayers =
        allPlayers.where((p) => match.teamAPlayers.contains(p.id)).toList();
    final teamBPlayers =
        allPlayers.where((p) => match.teamBPlayers.contains(p.id)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildPlayerList(
                      match.teamAName,
                      teamAPlayers,
                      isDark,
                      match.teamACaptainId,
                      match.teamAViceCaptainId,
                    ),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildPlayerList(
                      match.teamBName,
                      teamBPlayers,
                      isDark,
                      match.teamBCaptainId,
                      match.teamBViceCaptainId,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPlayerList(
              match.teamAName,
              teamAPlayers,
              isDark,
              match.teamACaptainId,
              match.teamAViceCaptainId,
            ),
            const SizedBox(height: 24),
            _buildPlayerList(
              match.teamBName,
              teamBPlayers,
              isDark,
              match.teamBCaptainId,
              match.teamBViceCaptainId,
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildPlayerList(
    String teamName,
    List<PlayerModel> players,
    bool isDark,
    String? captainId,
    String? viceCaptainId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0.5),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'SQUAD LIST',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '${players.length} PLAYERS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection(AppConstants.usersCollection)
                      .doc(player.id)
                      .get(),
              builder: (context, snapshot) {
                String? imageUrl = player.profileImageUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    imageUrl =
                        data['profile_image'] ??
                        data['profile_image_url'] ??
                        imageUrl;
                  }
                }

                final isCaptain = player.id == captainId;
                final isViceCaptain = player.id == viceCaptainId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {}, // For ripple effect
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.primaryGreen,
                                    AppTheme.primaryGreen.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    isDark
                                        ? const Color(0xFF111827)
                                        : Colors.white,
                                backgroundImage:
                                    imageUrl != null && imageUrl.isNotEmpty
                                        ? NetworkImage(imageUrl)
                                        : null,
                                child:
                                    imageUrl == null || imageUrl.isEmpty
                                        ? Text(
                                          player.name.isNotEmpty
                                              ? player.name
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '?',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryGreen,
                                            fontSize: 18,
                                          ),
                                        )
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          player.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCaptain) ...[
                                        const SizedBox(width: 8),
                                        _buildBadge(
                                          'C',
                                          const Color(0xFFFFB800),
                                        ),
                                      ],
                                      if (isViceCaptain) ...[
                                        const SizedBox(width: 8),
                                        _buildBadge(
                                          'VC',
                                          const Color(0xFF3B82F6),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildStatChip(
                                        Icons.bolt_rounded,
                                        '${player.runsScored} Runs',
                                        Colors.amber,
                                        isDark,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatChip(
                                        Icons.sports_cricket_rounded,
                                        '${player.wicketsTaken} Wkts',
                                        AppTheme.primaryGreen,
                                        isDark,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  // ─── Info Tab ──────────────────────────────────────
  Widget _buildInfoTab(MatchModel match, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernInfoRow(
                'Match Title',
                match.title,
                Icons.emoji_events_outlined,
                isDark,
              ),
              _buildDivider(isDark),
              FutureBuilder<String>(
                future: authController.getUserName(match.createdBy),
                builder: (context, snapshot) {
                  return _buildModernInfoRow(
                    'Created By',
                    snapshot.data ?? 'Loading...',
                    Icons.person_outline,
                    isDark,
                  );
                },
              ),
              _buildDivider(isDark),
              _buildModernInfoRow(
                'Status',
                match.status.toUpperCase(),
                Icons.info_outline,
                isDark,
              ),
              _buildDivider(isDark),
              _buildModernInfoRow(
                'Total Overs',
                '${match.totalOvers} Overs',
                Icons.sports_cricket_outlined,
                isDark,
              ),
              _buildDivider(isDark),
              _buildModernInfoRow(
                'Toss',
                '${match.tossWonBy == 'A' ? match.teamAName : match.teamBName} won the toss and elected to ${match.tossDecision}',
                Icons.monetization_on_outlined,
                isDark,
              ),
              if (match.customRulesEnabled || match.lastPlayerCanPlay) ...[
                _buildDivider(isDark),
                _buildModernInfoRow(
                  'Custom Rules',
                  '${match.customRulesEnabled ? "• Single Batsman Mode: ON\n" : ""}'
                      '${match.lastPlayerCanPlay ? "• Last Man Standing: ON\n" : ""}'
                      '${match.maxBattingOvers != null ? "• Max Batting: ${match.maxBattingOvers} overs/batsman\n" : ""}'
                      '${match.maxBowlingOvers != null ? "• Max Bowling: ${match.maxBowlingOvers} overs/bowler" : ""}',
                  Icons.rule_folder_outlined,
                  isDark,
                ),
              ],
              if (match.result != null) ...[
                _buildDivider(isDark),
                _buildModernInfoRow(
                  'Result',
                  match.result!,
                  Icons.flag_outlined,
                  isDark,
                ),
              ],
            ],
          ),
        ),
        if (match.isCompleted) ...[
          const SizedBox(height: 24),
          _buildRematchButton(match, isDark),
        ],
      ],
    );
  }

  Widget _buildRematchButton(MatchModel match, bool isDark) {
    // Only show for admins
    final isAdmin = authController.currentUser?.isAdmin ?? false;
    if (!isAdmin) return const SizedBox.shrink();

    // Only show on the latest completed match and if no live match exists
    final latestMatch =
        matchController.completedMatches.isNotEmpty
            ? matchController.completedMatches.first
            : null;
    final isLatest = latestMatch?.id == match.id;
    if (!isLatest || matchController.liveMatches.isNotEmpty)
      return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => MatchDialogs.showRematchDialog(context, match),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryGreen, Color(0xFF00BFA5)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'CONTINUE WITH THESE TEAMS',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateWinProbability(MatchModel match) {
    final score = match.currentScore;
    final initialBattingTeam =
        match.tossWonBy == 'A'
            ? (match.tossDecision == 'bat' ? 'A' : 'B')
            : (match.tossDecision == 'bat' ? 'B' : 'A');
    final isSecondInnings = match.currentInnings != initialBattingTeam;

    if (!isSecondInnings) return 50;

    final firstInningsScore =
        match.currentInnings == 'A' ? match.teamBScore : match.teamAScore;
    final target = firstInningsScore.runs + 1;
    final requiredRuns = target - score.runs;

    final totalBalls = match.totalOvers * 6;
    final ballsPlayed = (score.overs * 6) + score.balls;
    final ballsRemaining = totalBalls - ballsPlayed;

    // Base conditions
    if (ballsPlayed == 0) return 50;
    if (requiredRuns <= 0) return 100;
    if (ballsRemaining <= 0) return 0;

    // Run Rates
    final crr = (score.runs / ballsPlayed) * 6;
    final rrr = (requiredRuns / ballsRemaining) * 6;

    // Probability Logic (User requested formula: (CRR/RRR)*50 + 50)
    double winPct;
    if (rrr == 0) {
      winPct = 100;
    } else {
      winPct = (crr / rrr) * 50 + 50;
    }

    // Wicket Adjustment (Optional but requested)
    final battingTeamId = match.currentInnings;
    final teamSize =
        battingTeamId == 'A'
            ? match.teamAPlayers.length
            : match.teamBPlayers.length;
    final wicketsRemaining = (teamSize - 1) - score.wickets;
    winPct += (wicketsRemaining * 2);

    return winPct.clamp(0, 100).toInt();
  }

  Widget _buildWinProbabilityBar(MatchModel match, bool isDark) {
    final initialBattingTeam =
        match.tossWonBy == 'A'
            ? (match.tossDecision == 'bat' ? 'A' : 'B')
            : (match.tossDecision == 'bat' ? 'B' : 'A');
    final isSecondInnings = match.currentInnings != initialBattingTeam;

    if (!isSecondInnings || match.status != AppConstants.matchLive) {
      return const SizedBox.shrink();
    }

    final winPct = _calculateWinProbability(match);
    final oppPct = 100 - winPct;

    final battingTeamName =
        match.currentInnings == 'A' ? match.teamAName : match.teamBName;
    final bowlingTeamName =
        match.currentInnings == 'A' ? match.teamBName : match.teamAName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'WIN PROBABILITY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  battingTeamName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                '$winPct%',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'vs',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ),
              Text(
                '$oppPct%',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
              Expanded(
                child: Text(
                  bowlingTeamName.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              return ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  height: 8,
                  width: double.infinity,
                  color:
                      isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeInOutExpo,
                        width: availableWidth * (winPct / 100),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.redAccent.withOpacity(0.8),
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
    );
  }

  void _shareMatch(MatchModel match) async {
    try {
      UIUtils.showLoading('Generating Scorecard PDF...');
      await PdfService.generateAndShareMatchPdf(match, matchController.players);
      if (Get.isDialogOpen ?? false) Get.back(); // Hide loading
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(); // Hide loading
      UIUtils.showError('Failed to generate PDF: $e');
    }
  }
}

Widget _buildDivider(bool isDark) {
  return Divider(
    height: 1,
    thickness: 1,
    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
    indent: 16,
    endIndent: 16,
  );
}

Widget _buildModernInfoRow(
  String label,
  String value,
  IconData icon,
  bool isDark,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppTheme.primaryGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Match Header Widgets ────────────────────────────

class MatchHeaderWidget extends StatelessWidget {
  final MatchModel match;
  final bool isDark;

  const MatchHeaderWidget({
    super.key,
    required this.match,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient:
            isDark
                ? const LinearGradient(
                  colors: [Color(0xFF111827), Color(0xFF1F2937)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
                : const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF00BFA5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Score Card Container
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF374151).withOpacity(0.5)
                          : Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Team A
                        Expanded(
                          child: TeamScoreWidget(
                            name: match.teamAName,
                            score: match.teamAScore,
                            isBatting: match.currentInnings == 'A',
                            isDark: isDark,
                          ),
                        ),

                        // VS divider
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'VS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // Team B
                        Expanded(
                          child: TeamScoreWidget(
                            name: match.teamBName,
                            score: match.teamBScore,
                            isBatting: match.currentInnings == 'B',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    if (match.result != null || match.isLive)
                      const SizedBox(height: 8),

                    // Status / Result / CRR
                    if (match.result != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.vibrantOrange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          match.result!,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else if (match.isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CRR: ${match.currentScore.runRate.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            if (match.isSecondInnings) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                height: 12,
                                width: 1,
                                color: Colors.white54,
                              ),
                              Text(
                                'RRR: ${match.currentScore.requiredRunRate(match.targetScore, match.totalOvers).toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                height: 12,
                                width: 1,
                                color: Colors.white54,
                              ),
                              Text(
                                'Target: ${match.targetScore}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
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
}

class TeamScoreWidget extends StatelessWidget {
  final String name;
  final MatchScore score;
  final bool isBatting;
  final bool isDark;

  const TeamScoreWidget({
    super.key,
    required this.name,
    required this.score,
    required this.isBatting,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${score.runs}',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 2),
              child: Text(
                '/${score.wickets}',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.white70,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '(${score.oversDisplay} ov)',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white60),
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: isBatting ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class TabsWidget extends StatelessWidget implements PreferredSizeWidget {
  final bool isLive;
  final bool isDark;

  const TabsWidget({super.key, required this.isLive, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        indicatorColor: AppTheme.primaryGreen,
        indicatorWeight: 3,
        labelColor: AppTheme.primaryGreen,
        unselectedLabelColor: isDark ? Colors.grey : Colors.grey.shade600,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: [
          if (isLive) const Tab(text: 'Live'),
          const Tab(text: 'Scoreboard'),
          const Tab(text: 'Squads'),
          const Tab(text: 'Info'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
