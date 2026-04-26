import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/match_model.dart';
import '../../../core/models/player_model.dart';
import '../../../core/theme/app_theme.dart';

/// Full scorecard view with batting and bowling tables.
class ScorecardScreen extends StatelessWidget {
  final MatchModel match;
  final Map<String, PlayerModel> players;

  const ScorecardScreen({
    super.key,
    required this.match,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get all players for Team A and Team B from the match player lists
    final teamABatsmen =
        match.teamAPlayers
            .map((id) => players[id])
            .whereType<PlayerModel>()
            .toList();

    final teamBBatsmen =
        match.teamBPlayers
            .map((id) => players[id])
            .whereType<PlayerModel>()
            .toList();

    // Sort to show those who have batted first, then those yet to bat
    // Batted = faced balls or is out
    teamABatsmen.sort((a, b) {
      final aBatted = a.ballsFaced > 0 || a.isOut;
      final bBatted = b.ballsFaced > 0 || b.isOut;
      if (aBatted && !bBatted) return -1;
      if (!aBatted && bBatted) return 1;
      return 0;
    });

    teamBBatsmen.sort((a, b) {
      final aBatted = a.ballsFaced > 0 || a.isOut;
      final bBatted = b.ballsFaced > 0 || b.isOut;
      if (aBatted && !bBatted) return -1;
      if (!aBatted && bBatted) return 1;
      return 0;
    });

    final teamABowlers =
        players.values
            .where((p) => p.teamId == 'A' && p.totalBowlingBalls > 0)
            .toList();

    final teamBBowlers =
        players.values
            .where((p) => p.teamId == 'B' && p.totalBowlingBalls > 0)
            .toList();

    final motmPlayerId = match.manOfMatch;
    final motmPlayer = motmPlayerId != null ? players[motmPlayerId] : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ── Man of the Match card (only when completed) ──────────
        if (match.isCompleted && motmPlayer != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFAB00), Color(0xFFFF6D00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFAB00).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAN OF THE MATCH',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        motmPlayer.name,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${motmPlayer.runsScored} runs  •  ${motmPlayer.wicketsTaken} wickets  •  ${motmPlayer.catches} catches',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Team A Innings
        _buildInningsHeader(match.teamAName, match.teamAScore, isDark),
        const SizedBox(height: 8),
        _buildBattingTable(teamABatsmen, isDark),
        const SizedBox(height: 8),
        _buildExtrasRow(match.teamAScore, isDark),
        const SizedBox(height: 16),
        _buildBowlingTable(teamBBowlers, isDark),

        const SizedBox(height: 32),

        // Team B Innings
        _buildInningsHeader(match.teamBName, match.teamBScore, isDark),
        const SizedBox(height: 8),
        _buildBattingTable(teamBBatsmen, isDark),
        const SizedBox(height: 8),
        _buildExtrasRow(match.teamBScore, isDark),
        const SizedBox(height: 16),
        _buildBowlingTable(teamABowlers, isDark),

        const SizedBox(height: 24),

        // Result
        if (match.result != null) _buildResultCard(isDark),
      ],
    );
  }

  String _getDismissalText(PlayerModel player) {
    if (!player.isOut) {
      return player.ballsFaced > 0 ? 'not out' : '';
    }
    if (player.dismissalType == null || player.dismissalType!.isEmpty)
      return 'out';

    final type = player.dismissalType!;
    final bowlerName =
        player.dismissedBy != null && player.dismissedBy!.isNotEmpty
            ? (players[player.dismissedBy!]?.name ?? 'Unknown Bowler')
            : '';

    final typeLower = type.toLowerCase();

    if (typeLower.startsWith('caught')) {
      final fielderMatches = RegExp(r'\((.*?)\)').firstMatch(type);
      final fielderName = fielderMatches?.group(1);
      if (fielderName != null) {
        return bowlerName.isNotEmpty
            ? 'c $fielderName b $bowlerName'
            : 'c $fielderName';
      }
      return bowlerName.isNotEmpty ? 'c ? b $bowlerName' : 'caught';
    } else if (typeLower == 'bowled') {
      return 'b $bowlerName';
    } else if (typeLower == 'lbw') {
      return 'lbw b $bowlerName';
    } else if (typeLower == 'stumped') {
      return 'st b $bowlerName';
    } else if (typeLower == 'run out' || typeLower == 'run_out') {
      return 'run out';
    } else if (typeLower == 'hit wicket' || typeLower == 'hit_wicket') {
      return bowlerName.isNotEmpty ? 'hit wicket b $bowlerName' : 'hit wicket';
    } else {
      return type.replaceAll('_', ' ') +
          (bowlerName.isNotEmpty ? ' b $bowlerName' : '');
    }
  }

  Widget _buildInningsHeader(String teamName, MatchScore score, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teamName.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Innings',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${score.runs}',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ' / ${score.wickets}',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              Text(
                '(${score.oversDisplay} ov)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBattingTable(List<PlayerModel> batsmen, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF253750) : const Color(0xFFF0F2F5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('BATTING', style: _headerStyle()),
                ),
                _headerCell('R', 30),
                _headerCell('B', 30),
                _headerCell('4s', 28),
                _headerCell('6s', 28),
                _headerCell('SR', 44),
              ],
            ),
          ),
          // Rows
          if (batsmen.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Yet to bat',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          else
            ...batsmen.map((batsman) => _buildBattingRow(batsman, isDark)),
        ],
      ),
    );
  }

  Widget _buildBattingRow(PlayerModel player, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF253750) : const Color(0xFFF0F2F5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getDismissalText(player),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color:
                        player.isOut
                            ? AppTheme.wicketRed
                            : AppTheme.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _dataCell('${player.runsScored}', 30, bold: true),
          _dataCell('${player.ballsFaced}', 30),
          _dataCell('${player.fours}', 28),
          _dataCell('${player.sixes}', 28),
          _dataCell(player.strikeRate.toStringAsFixed(1), 44),
        ],
      ),
    );
  }

  Widget _buildExtrasRow(MatchScore score, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Extras: ',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            '${score.extras}',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(wd ${score.wides}, nb ${score.noBalls}, b ${score.byes}, lb ${score.legByes})',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlingTable(List<PlayerModel> bowlers, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF253750) : const Color(0xFFF0F2F5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text('BOWLING', style: _headerStyle()),
                ),
                _headerCell('O', 35),
                _headerCell('R', 35),
                _headerCell('W', 30),
                _headerCell('Wd', 30),
                _headerCell('Econ', 45),
              ],
            ),
          ),
          if (bowlers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No bowling data',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          else
            ...bowlers.map((bowler) => _buildBowlingRow(bowler, isDark)),
        ],
      ),
    );
  }

  Widget _buildBowlingRow(PlayerModel player, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF253750) : const Color(0xFFF0F2F5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
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
              ],
            ),
          ),
          _dataCell(player.oversBowledDisplay, 35),
          _dataCell('${player.runsConceded}', 35, bold: true),
          _dataCell(
            '${player.wicketsTaken}',
            30,
            bold: true,
            color: player.wicketsTaken > 0 ? AppTheme.primaryGreen : null,
          ),
          _dataCell('${player.widesBowled}', 30),
          _dataCell(player.economyRate.toStringAsFixed(1), 45),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF00BFA5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          match.result!,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ─── Table Helpers ────────────────────────────────
  TextStyle _headerStyle() => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: Colors.grey,
  );

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, textAlign: TextAlign.center, style: _headerStyle()),
    );
  }

  Widget _dataCell(
    String text,
    double width, {
    bool bold = false,
    Color? color,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
    );
  }

  Widget _cell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13),
      ),
    );
  }
}
