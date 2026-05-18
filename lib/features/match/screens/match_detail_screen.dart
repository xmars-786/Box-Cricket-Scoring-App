import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:x_cricket/core/routes/app_routes.dart';
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
import '../utils/match_dialogs.dart';
import '../../match/widgets/motm_award_card.dart';
import '../../match/widgets/partnership_card.dart';
import '../../scoring/screens/scoring_screen.dart';
import '../../scorecard/screens/scorecard_screen.dart';
import '../../explore/screens/player_profile_screen.dart';
import 'package:lottie/lottie.dart';
import '../../../core/widgets/modern_app_bar.dart';
import '../widgets/match_event_animation_overlay.dart';

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

  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  List<String> _teamABowlingSequence = [];
  List<String> _teamBBowlingSequence = [];
  bool _isFetchingBowlingOrder = false;

  // Added for Overs Tab
  String? _selectedOversInnings;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      matchController.listenToMatch(widget.matchId);
      scoringController.initForMatch(widget.matchId);
      detailController.listenToLatestBall(widget.matchId);
      matchController.incrementViewerCount(
        widget.matchId,
        userId: authController.userId,
        userName: authController.currentUser?.name,
      );

      // Fetch bowling order for old data
      final match = matchController.selectedMatch;
      if (match != null) {
        _selectedOversInnings = match.initialBattingTeam;
        if (match.teamABowlingOrder.isEmpty ||
            match.teamBBowlingOrder.isEmpty) {
          _fetchBowlingOrderFromLogs();
        }
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final collapsed = _scrollController.offset > (265 - kToolbarHeight - 20);
      if (collapsed != _isCollapsed) {
        setState(() {
          _isCollapsed = collapsed;
        });
      }
    }
  }

  Future<void> _fetchBowlingOrderFromLogs() async {
    if (_isFetchingBowlingOrder) return;
    _isFetchingBowlingOrder = true;

    try {
      final logsSnap =
          await FirebaseFirestore.instance
              .collection('matches')
              .doc(widget.matchId)
              .collection('ball_logs')
              .orderBy('timestamp', descending: false)
              .get();

      final Set<String> teamASeq = {};
      final Set<String> teamBSeq = {};

      for (var doc in logsSnap.docs) {
        final data = doc.data();
        final bowlerId = data['bowler_id'] as String?;
        final innings = data['innings'] as String?;

        if (bowlerId != null && innings != null) {
          if (innings == 'A') {
            teamBSeq.add(bowlerId);
          } else {
            teamASeq.add(bowlerId);
          }
        }
      }

      if (mounted) {
        setState(() {
          _teamABowlingSequence = teamASeq.toList();
          _teamBBowlingSequence = teamBSeq.toList();
          _isFetchingBowlingOrder = false;
        });
      }
    } catch (e) {
      _isFetchingBowlingOrder = false;
    }
  }

  @override
  void dispose() {
    matchController.decrementViewerCount(
      widget.matchId,
      userId: authController.userId,
    );
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Obx(() {
            final match = matchController.selectedMatch;
            if (match == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final isLive = match.status == AppConstants.matchLive;
            final isCompleted = match.status == AppConstants.matchCompleted;
            final tabLength = isLive ? 5 : 4;

            return DefaultTabController(
              length: tabLength,
              child: NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  final adaptiveColor =
                      _isCollapsed
                          ? (isDark ? Colors.white : AppTheme.primaryDark)
                          : Colors.white;

                  return [
                    // Score header
                    ModernSliverAppBar(
                      titleColor: adaptiveColor,
                      iconColor: adaptiveColor,
                      leading: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: adaptiveColor,
                          size: 20,
                        ),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Get.offAllNamed(AppRoutes.home);
                          }
                        },
                      ),
                      expandedHeight: 265,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.none,
                        background: MatchHeaderWidget(
                          match: match,
                          isDark: isDark,
                        ),
                      ),
                      title:
                          _isCollapsed
                              ? '${match.teamAScore.runs}/${match.teamAScore.wickets} vs ${match.teamBScore.runs}/${match.teamBScore.wickets}'
                              : match.title,
                      actions: [
                        if (match.isCompleted)
                          IconButton(
                            icon: Icon(Icons.share, color: adaptiveColor),
                            onPressed: () => _shareMatch(match),
                          ),
                        // More menu (Delete match)
                        Obx(() {
                          final isAdmin =
                              authController.currentUser?.isAdmin ?? false;
                          if (!isAdmin) return const SizedBox.shrink();
                          return PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: adaptiveColor),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirm = await _showDeleteConfirmation(
                                  context,
                                );
                                if (confirm == true) {
                                  await matchController.deleteMatch(match.id);
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
                  ];
                },
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
                    _buildOversTab(match, isDark),
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
          // Premium Match Event Animations
          MatchEventAnimationOverlay(),
        ],
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
            Get.to(() => ScoringScreen(matchId: match.id));
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
    return MatchDialogs.showDeleteMatchDialog(context);
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
        if (match.activePartnership != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PartnershipCard(
              partnership: match.activePartnership!,
              isDark: isDark,
            ),
          ),

        // Yet to bat section
        _buildYetToBatLive(match, players, isDark),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildYetToBatLive(
    MatchModel match,
    Map<String, PlayerModel> players,
    bool isDark,
  ) {
    final battingTeamIds =
        match.currentInnings == 'A' ? match.teamAPlayers : match.teamBPlayers;

    final yetToBat =
        battingTeamIds.map((id) => players[id]).whereType<PlayerModel>().where((
          p,
        ) {
          final hasBatted = p.ballsFaced > 0 || p.isOut;
          if (hasBatted) return false;
          // Check if currently at crease
          return p.id != match.currentBatsmanId &&
              p.id != match.currentNonStrikerId;
        }).toList();

    if (yetToBat.isEmpty) return const SizedBox.shrink();

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
            'YET TO BAT',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                yetToBat
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Text(
                          p.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
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

  // ─── Overs Tab ─────────────────────────────────────
  Widget _buildOversTab(MatchModel match, bool isDark) {
    return Obx(() {
      final allBalls = scoringController.ballLogs;
      final players = matchController.players;

      // Determine initial batting team
      final team1Innings = match.initialBattingTeam;
      final team2Innings = team1Innings == 'A' ? 'B' : 'A';

      final selectedInnings = _selectedOversInnings ?? team1Innings;
      final inningsBalls =
          allBalls.where((b) => b.innings == selectedInnings).toList();

      // Sort balls by timestamp to calculate cumulative scores
      final sortedBalls = List<BallLog>.from(inningsBalls)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Calculate scores at end of each over
      final Map<int, String> overScores = {};
      int runsCount = 0;
      int wicketsCount = 0;
      for (var ball in sortedBalls) {
        runsCount += ball.totalRuns;
        if (ball.isWicket) wicketsCount++;
        overScores[ball.overNumber] = "$runsCount-$wicketsCount";
      }

      // Group by over
      final Map<int, List<BallLog>> oversMap = {};
      for (var ball in inningsBalls) {
        oversMap.putIfAbsent(ball.overNumber, () => []).add(ball);
      }

      final sortedOverNumbers =
          oversMap.keys.toList()..sort((a, b) => b.compareTo(a));

      return Column(
        children: [
          _buildOversInningsToggle(match, isDark),
          Expanded(
            child:
                sortedOverNumbers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 64,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No overs recorded yet',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: sortedOverNumbers.length,
                      separatorBuilder:
                          (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final overNum = sortedOverNumbers[index];
                        final balls = oversMap[overNum]!;
                        final score = overScores[overNum] ?? "0-0";
                        return _buildOverDetailCard(
                          overNum,
                          balls,
                          score,
                          players,
                          isDark,
                        );
                      },
                    ),
          ),
        ],
      );
    });
  }

  Widget _buildOversInningsToggle(MatchModel match, bool isDark) {
    final team1Innings = match.initialBattingTeam;
    final team2Innings = team1Innings == 'A' ? 'B' : 'A';

    final team1Name = team1Innings == 'A' ? match.teamAName : match.teamBName;
    final team2Name = team2Innings == 'A' ? match.teamAName : match.teamBName;

    final selectedInnings = _selectedOversInnings ?? team1Innings;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF111827) : Colors.grey[50],
      child: Row(
        children: [
          Expanded(
            child: _buildInningsButton(
              team1Name,
              "1st Innings",
              selectedInnings == team1Innings,
              () => setState(() => _selectedOversInnings = team1Innings),
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInningsButton(
              team2Name,
              "2nd Innings",
              selectedInnings == team2Innings,
              () => setState(() => _selectedOversInnings = team2Innings),
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsButton(
    String teamName,
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark
                      ? AppTheme.primaryGreen.withOpacity(0.2)
                      : AppTheme.primaryGreen.withOpacity(0.05))
                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color:
                isSelected
                    ? AppTheme.primaryGreen
                    : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color:
                      isSelected
                          ? AppTheme.primaryGreen
                          : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color:
                    isSelected
                        ? AppTheme.primaryGreen.withOpacity(0.8)
                        : (isDark ? Colors.white38 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverDetailCard(
    int overNum,
    List<BallLog> balls,
    String score,
    Map<String, PlayerModel> players,
    bool isDark,
  ) {
    // Calculate over runs
    final overRuns = balls.fold<int>(0, (sum, b) => sum + b.totalRuns);

    // Get bowler and unique strikers (only those who faced a ball)
    final bowlerId = balls.isNotEmpty ? balls.first.bowlerId : null;
    final bowlerName =
        bowlerId != null ? (players[bowlerId]?.name ?? "Bowler") : "Bowler";

    final Set<String> strikerIds = balls.map((b) => b.batsmanId).toSet();
    final batsmenNames = strikerIds
        .map((id) => players[id]?.name ?? "Batsman")
        .join(" & ");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: isDark ? const Color(0xFF111827) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Over Number & Score
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ov ${overNum + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  score,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Middle: Players & Ball Chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$bowlerName to $batsmenNames',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      balls.map((b) => _buildOverBallChip(b, isDark)).toList(),
                ),
              ],
            ),
          ),

          // Right: Over Runs
          SizedBox(
            width: 40,
            child: Text(
              '$overRuns',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverBallChip(BallLog ball, bool isDark) {
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
        child: Text(
          ball.displayText,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSquadsTab(
    MatchModel match,
    List<PlayerModel> allPlayers,
    bool isDark,
  ) {
    final teamAPlayers =
        allPlayers.where((p) => match.teamAPlayers.contains(p.id)).toList();
    final teamBPlayers =
        allPlayers.where((p) => match.teamBPlayers.contains(p.id)).toList();

    // Get Participation Order from Match Data
    List<String> getBattingSequence(String teamId) {
      final List<String> order =
          teamId == 'A' ? match.teamABattingOrder : match.teamBBattingOrder;
      if (order.isNotEmpty) return order;

      final Set<String> sequence = {};
      final partnerships =
          teamId == 'A' ? match.teamAPartnerships : match.teamBPartnerships;
      for (var p in partnerships) {
        sequence.add(p.batterAId);
        sequence.add(p.batterBId);
      }
      return sequence.toList();
    }

    final teamASeq = getBattingSequence('A');
    final teamBSeq = getBattingSequence('B');

    // Sort squads: played players first, maintaining chronological order
    teamAPlayers.sort((a, b) {
      final aPlayed = a.ballsFaced > 0 || a.isOut || a.ballsBowled > 0;
      final bPlayed = b.ballsFaced > 0 || b.isOut || b.ballsBowled > 0;
      if (aPlayed && !bPlayed) return -1;
      if (!aPlayed && bPlayed) return 1;

      // Participation order check
      final idxA = teamASeq.indexOf(a.id);
      final idxB = teamASeq.indexOf(b.id);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;

      // Bowling order check
      final bSeq =
          match.teamABowlingOrder.isNotEmpty
              ? match.teamABowlingOrder
              : _teamABowlingSequence;
      final bIdxA = bSeq.indexOf(a.id);
      final bIdxB = bSeq.indexOf(b.id);
      if (bIdxA != -1 && bIdxB != -1) return bIdxA.compareTo(bIdxB);

      return match.teamAPlayers
          .indexOf(a.id)
          .compareTo(match.teamAPlayers.indexOf(b.id));
    });

    teamBPlayers.sort((a, b) {
      final aPlayed = a.ballsFaced > 0 || a.isOut || a.ballsBowled > 0;
      final bPlayed = b.ballsFaced > 0 || b.isOut || b.ballsBowled > 0;
      if (aPlayed && !bPlayed) return -1;
      if (!aPlayed && bPlayed) return 1;

      final idxA = teamBSeq.indexOf(a.id);
      final idxB = teamBSeq.indexOf(b.id);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;

      // Bowling order check
      final bSeq =
          match.teamBBowlingOrder.isNotEmpty
              ? match.teamBBowlingOrder
              : _teamBBowlingSequence;
      final bIdxA = bSeq.indexOf(a.id);
      final bIdxB = bSeq.indexOf(b.id);
      if (bIdxA != -1 && bIdxB != -1) return bIdxA.compareTo(bIdxB);

      return match.teamBPlayers
          .indexOf(a.id)
          .compareTo(match.teamBPlayers.indexOf(b.id));
    });

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                      onTap: () {
                        Get.to(() => PlayerProfileScreen(playerId: player.id));
                      },
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                'Venue',
                match.groundName.isNotEmpty
                    ? match.groundName
                    : 'Not Specified',
                Icons.location_on_outlined,
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
              if (match.startedAt != null) ...[
                _buildDivider(isDark),
                StreamBuilder<int>(
                  stream:
                      match.status == AppConstants.matchLive
                          ? Stream.periodic(
                            const Duration(seconds: 30),
                            (x) => x,
                          )
                          : null,
                  builder: (context, snapshot) {
                    return _buildModernInfoRow(
                      match.status == AppConstants.matchCompleted
                          ? 'Match Duration'
                          : 'Time Elapsed',
                      _getMatchDuration(match),
                      Icons.timer_outlined,
                      isDark,
                    );
                  },
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

  String _getMatchDuration(MatchModel match) {
    if (match.startedAt == null) return 'Match not started yet';

    final end = match.completedAt ?? DateTime.now();
    final diff = end.difference(match.startedAt!);

    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return '${diff.inMinutes}m';
    }
  }

  void _showViewersList(
    BuildContext context,
    String matchId,
    bool isDark,
  ) async {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MATCH VIEWERS',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: matchController.getMatchViewersStream(
                matchId,
                onlyOnline: false,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final viewers = snapshot.data ?? [];
                if (viewers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        'No viewer data available',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: Get.height * 0.4),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: viewers.length,
                    separatorBuilder:
                        (context, index) => Divider(
                          color:
                              isDark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.1),
                        ),
                    itemBuilder: (context, index) {
                      final viewer = viewers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGreen.withOpacity(
                            0.1,
                          ),
                          child: Text(
                            (viewer['name'] as String? ?? 'A')[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          viewer['name'] ?? 'Anonymous',
                          style: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          viewer['viewed_at'] != null
                              ? DateFormat('dd MMM, hh:mm a').format(
                                (viewer['viewed_at'] as Timestamp).toDate(),
                              )
                              : '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
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
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
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
                    if (match.result != null) ...[
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
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ), // Extra space at bottom of header content
                    ] else if (match.isLive) ...[
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
                color: Colors.white,
                fontWeight: FontWeight.w700,
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
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
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
          const Tab(text: 'Overs'),
          const Tab(text: 'Squads'),
          const Tab(text: 'Info'),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}
