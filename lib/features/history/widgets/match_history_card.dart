import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../../core/models/match_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../match/screens/match_detail_screen.dart';

class MatchHistoryCard extends StatelessWidget {
  final MatchModel match;
  final bool isDark;
  final VoidCallback? onDelete;
  final bool isAdmin;

  const MatchHistoryCard({
    super.key,
    required this.match,
    required this.isDark,
    this.onDelete,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.to(() => MatchDetailScreen(matchId: match.id)),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  match.matchNumber != null
                      ? 'MATCH ${match.matchNumber} • ${match.tournamentName ?? 'Tournament'}'
                      : match.title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildScoreSection(),
                    const SizedBox(height: 16),
                    _buildResultAndInfoBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.01),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          _buildMatchTypeBadge(),
          const SizedBox(width: 8),
          _buildStatusBadge(),
          const Spacer(),
          Text(
            DateFormat('MMM dd, yyyy').format(match.createdAt),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTypeBadge() {
    final isTournament = match.tournamentId != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isTournament ? Colors.amber : AppTheme.primaryGreen)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTournament
                ? Icons.emoji_events_rounded
                : Icons.sports_cricket_rounded,
            size: 10,
            color: isTournament ? Colors.amber : AppTheme.primaryGreen,
          ),
          const SizedBox(width: 4),
          Text(
            isTournament ? 'TOURNAMENT' : 'SINGLE',
            style: GoogleFonts.outfit(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: isTournament ? Colors.amber : AppTheme.primaryGreen,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;
    switch (match.status) {
      case 'live':
        color = const Color(0xFFEF4444);
        label = 'LIVE';
        break;
      case 'completed':
        color = const Color(0xFF10B981);
        label = 'ENDED';
        break;
      default:
        color = const Color(0xFF3B82F6);
        label = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildScoreSection() {
    bool isTeamAWinner = false;
    bool isTeamBWinner = false;

    if (match.winnerId != null && match.winnerId!.isNotEmpty) {
      isTeamAWinner = match.winnerId == match.teamAId;
      isTeamBWinner = match.winnerId == match.teamBId;
    } else if (match.result != null && match.result!.isNotEmpty) {
      final resultLower = match.result!.toLowerCase();
      isTeamAWinner =
          resultLower.contains(match.teamAName.toLowerCase()) &&
          !resultLower.contains('tie');
      isTeamBWinner =
          resultLower.contains(match.teamBName.toLowerCase()) &&
          !resultLower.contains('tie');
    }

    return Column(
      children: [
        _buildTeamRow(
          name: match.teamAName,
          score: match.teamAScore,
          isWinner: isTeamAWinner,
        ),
        const SizedBox(height: 16),
        _buildTeamRow(
          name: match.teamBName,
          score: match.teamBScore,
          isWinner: isTeamBWinner,
        ),
      ],
    );
  }

  Widget _buildTeamRow({
    required String name,
    required MatchScore score,
    required bool isWinner,
  }) {
    return Row(
      children: [
        _buildTeamLogo(name, isWinner),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color:
                  isWinner
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white70 : Colors.black54),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (match.status != 'upcoming')
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.runs}/${score.wickets}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color:
                      isWinner
                          ? AppTheme.primaryGreen
                          : (isDark ? Colors.white : Colors.black87),
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '(${score.oversDisplay})',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          )
        else
          Text(
            'YET TO BAT',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
      ],
    );
  }

  Widget _buildTeamLogo(String name, bool isWinner) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A2A) : Colors.grey.shade50,
        shape: BoxShape.circle,
        border: Border.all(
          color:
              isWinner
                  ? AppTheme.primaryGreen.withOpacity(0.5)
                  : (isDark ? Colors.white10 : Colors.black12),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.outfit(
            color:
                isWinner
                    ? AppTheme.primaryGreen
                    : (isDark ? Colors.white54 : Colors.black54),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildResultAndInfoBar() {
    final hasResult = match.result != null && match.result!.isNotEmpty;
    Color resultColor = isDark ? Colors.white38 : Colors.black38;

    if (hasResult) {
      if (match.result!.toLowerCase().contains('won')) {
        resultColor = AppTheme.primaryGreen;
      } else if (match.result!.toLowerCase().contains('tie')) {
        resultColor = Colors.amber;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasResult)
                  Text(
                    match.result!.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: resultColor,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (match.groundName.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          match.groundName.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (isAdmin)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
