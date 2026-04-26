import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/models/match_model.dart';
import '../../../core/theme/app_theme.dart';
import '../screens/match_detail_screen.dart';
import '../utils/match_dialogs.dart';
import '../../scoring/screens/scoring_screen.dart';

/// A unified match card widget used across Home, History, and My Matches.
class MatchCardWidget extends StatelessWidget {
  final MatchModel match;
  final bool isDark;
  final bool isAdmin;
  final bool isScorer;
  final VoidCallback? onDelete;

  const MatchCardWidget({
    super.key,
    required this.match,
    required this.isDark,
    this.isAdmin = false,
    this.isScorer = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (match.isCompleted) {
      return _buildCompletedCard(context);
    } else if (match.isLive) {
      return _buildLiveCard(context);
    } else {
      return _buildUpcomingCard(context);
    }
  }

  // ─── Completed Match Card ──────────────────────────────────────────
  Widget _buildCompletedCard(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final dateStr =
        match.completedAt != null
            ? dateFormat.format(match.completedAt!)
            : 'Unknown date';

    final matchController = Get.find<MatchController>();

    return _buildBaseCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge('completed'),
              if (isAdmin) _buildOptionsMenu(),
            ],
          ),
          const Divider(height: 24),
          _buildScoreSummary(),
          if (match.result != null) ...[
            const SizedBox(height: 12),
            _buildResultBanner(),
          ],
          const Divider(height: 24),
          _buildMOTMRow(),
          Obx(() {
            final latestMatch =
                matchController.completedMatches.isNotEmpty
                    ? matchController.completedMatches.first
                    : null;
            final isLatest = latestMatch?.id == match.id;

            if (isAdmin && isLatest && matchController.liveMatches.isEmpty) {
              return Column(
                children: [
                  const SizedBox(height: 16),
                  _buildRematchButton(context),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildRematchButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => MatchDialogs.showRematchDialog(context, match),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryGreen, Color(0xFF00BFA5)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'REMATCH',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Live Match Card ──────────────────────────────────────────────
  Widget _buildLiveCard(BuildContext context) {
    return _buildBaseCard(
      context,
      isLive: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            match.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Row(
                    //   children: [
                    //     Icon(
                    //       Icons.location_on_rounded,
                    //       size: 12,
                    //       color: isDark ? Colors.white38 : Colors.grey[500],
                    //     ),
                    //     const SizedBox(width: 4),
                    //     Text(
                    //       match.groundName,
                    //       style: GoogleFonts.inter(
                    //         fontSize: 12,
                    //         color: isDark ? Colors.white38 : Colors.grey[500],
                    //         fontWeight: FontWeight.w500,
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
              _buildStatusBadge('live'),
              if (isAdmin) _buildOptionsMenu(),
            ],
          ),
          const SizedBox(height: 20),
          _buildLiveScoreSummary(),
          const SizedBox(height: 20),
          _buildLiveStats(),
          _buildChaseInfo(context),
          if (isScorer) ...[const SizedBox(height: 16), _buildAddScoreButton()],
        ],
      ),
    );
  }

  Widget _buildLiveScoreSummary() {
    final isTeamABatting = match.currentInnings == 'A';
    final isTeamBBatting = match.currentInnings == 'B';

    return Row(
      children: [
        Expanded(
          child: _buildLiveTeamScore(
            match.teamAName,
            match.teamAScore,
            isTeamABatting,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'VS',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white24 : Colors.black12,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: _buildLiveTeamScore(
            match.teamBName,
            match.teamBScore,
            isTeamBBatting,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTeamScore(String name, MatchScore score, bool isBatting) {
    return Column(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            color:
                isBatting
                    ? AppTheme.primaryGreen
                    : (isDark ? Colors.white54 : Colors.grey[600]),
            fontWeight: isBatting ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isBatting
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '${score.runs}/${score.wickets}',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color:
                      isBatting
                          ? AppTheme.primaryGreen
                          : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              Text(
                '${score.oversDisplay} OV',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      isBatting
                          ? AppTheme.primaryGreen.withOpacity(0.7)
                          : (isDark ? Colors.white24 : Colors.black12),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatPill(
          'CRR',
          match.currentScore.runRate.toStringAsFixed(2),
          isDark,
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(width: 12),
        _buildStatPill(
          'TARGET',
          match.isSecondInnings ? '${match.targetScore}' : '-',
          isDark,
          color: AppTheme.vibrantOrange,
        ),
      ],
    );
  }

  Widget _buildStatPill(
    String label,
    String value,
    bool isDark, {
    Color? color,
  }) {
    final effectiveColor = color ?? (isDark ? Colors.white : Colors.black87);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: effectiveColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: effectiveColor.withOpacity(0.6),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaseInfo(BuildContext context) {
    if (!match.isSecondInnings || !match.isLive) return const SizedBox.shrink();

    final target = match.targetScore;
    final currentScore = match.currentScore;

    final runsNeeded = target - currentScore.runs;
    final totalBalls = (match.totalOvers * 6);
    final ballsBowled = (currentScore.overs * 6 + currentScore.balls);
    final ballsRemaining = totalBalls - ballsBowled;

    if (runsNeeded <= 0) return const SizedBox.shrink();
    if (ballsRemaining <= 0 && runsNeeded > 0) return const SizedBox.shrink();

    double rrr = 0;
    if (ballsRemaining > 0) {
      rrr = (runsNeeded / ballsRemaining) * 6;
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: AppTheme.primaryGreen,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${match.battingTeamName.toUpperCase()} NEED $runsNeeded RUNS',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.black.withOpacity(0.02),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChaseStat(
                  'BALLS LEFT',
                  '$ballsRemaining',
                  AppTheme.primaryGreen,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                ),
                _buildChaseStat(
                  'REQ. RUN RATE',
                  rrr.toStringAsFixed(2),
                  AppTheme.vibrantOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaseStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.grey[500],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─── Upcoming Match Card ──────────────────────────────────────────
  Widget _buildUpcomingCard(BuildContext context) {
    return _buildBaseCard(
      context,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      match.groundName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge('upcoming'),
              if (isAdmin) _buildOptionsMenu(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTeamName(match.teamAName)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'VS',
                  style: GoogleFonts.outfit(color: Colors.grey),
                ),
              ),
              Expanded(child: _buildTeamName(match.teamBName)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helper Parts ──────────────────────────────────────────────────

  Widget _buildBaseCard(
    BuildContext context, {
    required Widget child,
    bool isLive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.to(() => MatchDetailScreen(matchId: match.id)),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isLive
                        ? AppTheme.primaryGreen.withOpacity(0.3)
                        : (isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFF1F5F9)),
                width: isLive ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      isLive
                          ? AppTheme.primaryGreen.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSummary() {
    final isTeamABatting = match.currentInnings == 'A';
    final isTeamBBatting = match.currentInnings == 'B';

    return Row(
      children: [
        Expanded(
          child: _buildTeamScoreDetail(
            match.teamAName,
            match.teamAScore,
            isTeamABatting && match.isLive,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'vs',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
          ),
        ),
        Expanded(
          child: _buildTeamScoreDetail(
            match.teamBName,
            match.teamBScore,
            isTeamBBatting && match.isLive,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamScoreDetail(String name, MatchScore score, bool isBatting) {
    return Column(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isBatting ? AppTheme.primaryGreen : Colors.grey,
            fontWeight: isBatting ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${score.runs}/${score.wickets}',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isBatting ? AppTheme.primaryGreen : null,
          ),
        ),
        Text(
          '(${score.oversDisplay} ov)',
          style: GoogleFonts.inter(
            fontSize: 11,
            color:
                isBatting
                    ? AppTheme.primaryGreen.withOpacity(0.7)
                    : Colors.grey,
          ),
        ),
        if (isBatting)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'BATTING',
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        match.result!,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildMOTMRow() {
    return Row(
      children: [
        if (match.manOfMatchName != null)
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFAB00),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'MoM: ${match.manOfMatchName}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFAB00),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOptionsMenu() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: isDark ? Colors.white54 : Colors.grey,
      ),
      onSelected: (val) {
        if (val == 'delete' && onDelete != null) {
          onDelete!();
        }
      },
      itemBuilder:
          (ctx) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Delete Match', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
    );
  }

  Widget _buildAddScoreButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.to(() => ScoringScreen(matchId: match.id)),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.vibrantOrange, Color(0xFFFF6D00)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.vibrantOrange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.edit_note, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'ADD SCORE',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'live':
        color = AppTheme.wicketRed;
        text = 'LIVE';
        break;
      case 'completed':
        color = AppTheme.primaryGreen;
        text = 'DONE';
        break;
      default:
        color = AppTheme.vibrantOrange;
        text = 'UPCOMING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTeamName(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
