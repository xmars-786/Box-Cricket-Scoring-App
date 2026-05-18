import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../../../core/controllers/scoring_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/models/match_model.dart';
import '../../../core/models/player_model.dart';
import '../../../core/models/partnership_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../match/widgets/motm_award_card.dart';
import '../../explore/screens/player_profile_screen.dart';

/// Full scorecard view with batting and bowling tables.
class ScorecardScreen extends StatefulWidget {
  final MatchModel match;
  final Map<String, PlayerModel> players;

  const ScorecardScreen({
    super.key,
    required this.match,
    required this.players,
  });

  @override
  State<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends State<ScorecardScreen> {
  List<String> _teamABowlingSequence = [];
  List<String> _teamBBowlingSequence = [];
  bool _isFetchingBowlingOrder = false;

  @override
  void initState() {
    super.initState();
    _teamABowlingSequence = List.from(widget.match.teamABowlingOrder);
    _teamBBowlingSequence = List.from(widget.match.teamBBowlingOrder);

    // If order is missing (old data), try to fetch from ball logs
    if (_teamABowlingSequence.isEmpty || _teamBBowlingSequence.isEmpty) {
      _fetchBowlingOrderFromLogs();
    }
  }

  Future<void> _fetchBowlingOrderFromLogs() async {
    if (_isFetchingBowlingOrder) return;
    setState(() => _isFetchingBowlingOrder = true);

    try {
      final logsSnap =
          await FirebaseFirestore.instance
              .collection('matches')
              .doc(widget.match.id)
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
            // If innings is A, B was bowling
            teamBSeq.add(bowlerId);
          } else {
            // If innings is B, A was bowling
            teamASeq.add(bowlerId);
          }
        }
      }

      if (mounted) {
        setState(() {
          if (_teamABowlingSequence.isEmpty)
            _teamABowlingSequence = teamASeq.toList();
          if (_teamBBowlingSequence.isEmpty)
            _teamBBowlingSequence = teamBSeq.toList();
          _isFetchingBowlingOrder = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bowling order: $e');
      if (mounted) setState(() => _isFetchingBowlingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final match = widget.match;
    final players = widget.players;

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

    // Get Participation Order from Match Data
    // Fallback: If the new order lists are empty, try to derive from partnerships (for old matches)
    List<String> getBattingSequence(String teamId) {
      final List<String> order =
          teamId == 'A' ? match.teamABattingOrder : match.teamBBattingOrder;
      if (order.isNotEmpty) return order;

      // Fallback for old matches: scan partnerships
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

    // Sort to show those who have batted first, then those yet to bat
    // Use the actual batting sequence as the primary order key
    bool hasBatted(PlayerModel p, String teamId) {
      // Basic check: did they face a ball or get out?
      if (p.ballsFaced > 0 || p.isOut) return true;

      // Participation check: are they in the recorded batting sequence?
      final seq = teamId == 'A' ? teamASeq : teamBSeq;
      if (seq.contains(p.id)) return true;

      // Live check: are they currently at the crease?
      if (match.status == AppConstants.matchLive &&
          match.currentInnings == teamId) {
        return p.id == match.currentBatsmanId ||
            p.id == match.currentNonStrikerId;
      }
      return false;
    }

    final teamABatted = teamABatsmen.where((p) => hasBatted(p, 'A')).toList();
    final teamADidNotBat =
        teamABatsmen.where((p) => !teamABatted.contains(p)).toList();

    final teamBBatted = teamBBatsmen.where((p) => hasBatted(p, 'B')).toList();
    final teamBDidNotBat =
        teamBBatsmen.where((p) => !teamBBatted.contains(p)).toList();

    // Sort Batted lists
    teamABatted.sort((a, b) {
      final idxA = teamASeq.indexOf(a.id);
      final idxB = teamASeq.indexOf(b.id);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return match.teamAPlayers
          .indexOf(a.id)
          .compareTo(match.teamAPlayers.indexOf(b.id));
    });

    teamBBatted.sort((a, b) {
      final idxA = teamBSeq.indexOf(a.id);
      final idxB = teamBSeq.indexOf(b.id);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return match.teamBPlayers
          .indexOf(a.id)
          .compareTo(match.teamBPlayers.indexOf(b.id));
    });

    final teamABowlers =
        players.values
            .where((p) => p.teamId == 'A' && p.totalBowlingBalls > 0)
            .toList();
    // Sort bowlers by actual participation order, fallback to squad index
    teamABowlers.sort((a, b) {
      final idxA = _teamABowlingSequence.indexOf(a.id);
      final idxB = _teamABowlingSequence.indexOf(b.id);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return match.teamAPlayers
          .indexOf(a.id)
          .compareTo(match.teamAPlayers.indexOf(b.id));
    });

    final teamBBowlers =
        players.values
            .where((p) => p.teamId == 'B' && p.totalBowlingBalls > 0)
            .toList();
    // Sort bowlers by actual participation order
    teamBBowlers.sort((a, b) {
      final idxA = _teamBBowlingSequence.indexOf(a.id);
      final idxB = _teamBBowlingSequence.indexOf(b.id);
      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return match.teamBPlayers
          .indexOf(a.id)
          .compareTo(match.teamBPlayers.indexOf(b.id));
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // ── Result (at the top) ──────────
        if (match.result != null) ...[
          // _buildResultCard(isDark),
          const SizedBox(height: 16),
        ],

        // ── Man of the Match card (only when completed) ──────────
        if (match.isCompleted) ...[
          Builder(
            builder: (context) {
              final motmMap = match.manOfTheMatchMap;
              final motmPlayerId = match.manOfMatch;
              final motmPlayer =
                  motmPlayerId != null ? players[motmPlayerId] : null;

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
                  players.isNotEmpty) {
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

                for (var p in players.values) {
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

              if (displayMOTMName.isEmpty) {
                // Auto-generate for old completed matches that missed the calc
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
                    const SizedBox(height: 16),
                  ],
                );
              }

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
                    onTap: null,
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ],

        // Team A Innings
        _buildInningsHeader(match.teamAName, match.teamAScore, isDark),
        const SizedBox(height: 8),
        _buildBattingTable(teamABatted, isDark),
        _buildDidNotBat(teamADidNotBat, isDark),
        const SizedBox(height: 8),
        _buildExtrasRow(match.teamAScore, isDark),
        const SizedBox(height: 16),
        _buildBowlingTable(teamBBowlers, isDark),
        if (match.teamAPartnerships.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPartnershipsList(match.teamAPartnerships, isDark),
        ],

        const SizedBox(height: 32),

        // Team B Innings
        _buildInningsHeader(match.teamBName, match.teamBScore, isDark),
        const SizedBox(height: 8),
        _buildBattingTable(teamBBatted, isDark),
        _buildDidNotBat(teamBDidNotBat, isDark),
        const SizedBox(height: 8),
        _buildExtrasRow(match.teamBScore, isDark),
        const SizedBox(height: 16),
        _buildBowlingTable(teamABowlers, isDark),
        if (match.teamBPartnerships.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPartnershipsList(match.teamBPartnerships, isDark),
        ],
      ],
    );
  }

  Widget _buildSelectMOTMPlaceholder(MatchModel match, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Center(
        child: Text(
          'Calculating Man of the Match...',
          style: GoogleFonts.inter(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
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
            ? (widget.players[player.dismissedBy!]?.name ?? 'Unknown Bowler')
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
    return InkWell(
      onTap: () {
        Get.to(() => PlayerProfileScreen(playerId: player.id));
      },
      child: Container(
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
                      if (player.id == widget.match.teamACaptainId ||
                          player.id == widget.match.teamBCaptainId) ...[
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
                      if (player.id == widget.match.teamAViceCaptainId ||
                          player.id == widget.match.teamBViceCaptainId) ...[
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
      ),
    );
  }

  Widget _buildDidNotBat(List<PlayerModel> players, bool isDark) {
    if (players.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_off_rounded,
                size: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 6),
              Text(
                'DID NOT BAT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                players
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF253750) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.03),
                          ),
                        ),
                        child: Text(
                          p.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
    return InkWell(
      onTap: () {
        Get.to(() => PlayerProfileScreen(playerId: player.id));
      },
      child: Container(
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
                  if (player.id == widget.match.teamACaptainId ||
                      player.id == widget.match.teamBCaptainId) ...[
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
                  if (player.id == widget.match.teamAViceCaptainId ||
                      player.id == widget.match.teamBViceCaptainId) ...[
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
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.match.result!.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPartnershipsList(
    List<PartnershipModel> partnerships,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF253750) : const Color(0xFFF0F2F5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text('PARTNERSHIPS', style: _headerStyle()),
          ),
          ...partnerships.map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark
                            ? const Color(0xFF253750)
                            : const Color(0xFFF0F2F5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${p.wicketNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.batterBName.toLowerCase().contains('non-striker') ||
                                  p.batterBName.toLowerCase().contains(
                                    'non-sticker',
                                  ) ||
                                  p.batterBName.isEmpty
                              ? p.batterAName
                              : '${p.batterAName} & ${p.batterBName}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          p.batterBName.toLowerCase().contains('non-striker') ||
                                  p.batterBName.toLowerCase().contains(
                                    'non-sticker',
                                  ) ||
                                  p.batterBName.isEmpty
                              ? '${p.batterARuns}(${p.batterABalls})'
                              : '${p.batterARuns}(${p.batterABalls}) & ${p.batterBRuns}(${p.batterBBalls})',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.totalRuns}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      Text(
                        '${p.totalBalls} balls',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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

  void _showMOMSelectionSheet(
    BuildContext context,
    MatchModel match,
    bool isDark,
  ) {
    final matchController = Get.find<MatchController>();
    final scoringController = Get.find<ScoringController>();

    // Identify winning team
    String winningTeamId = '';
    if (match.result != null) {
      if (match.result!.toLowerCase().contains(match.teamAName.toLowerCase())) {
        winningTeamId = 'A';
      } else if (match.result!.toLowerCase().contains(
        match.teamBName.toLowerCase(),
      )) {
        winningTeamId = 'B';
      }
    }

    // Filter players only from winning team (or all if tied)
    final eligiblePlayers =
        matchController.players.values.where((p) {
          if (winningTeamId.isEmpty) return true; // Tie
          return p.teamId == winningTeamId;
        }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              const SizedBox(height: 20),
              Text(
                'Select Man of the Match',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (winningTeamId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Winning Team: ${winningTeamId == 'A' ? match.teamAName : match.teamBName}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: eligiblePlayers.length,
                  itemBuilder: (context, index) {
                    final player = eligiblePlayers[index];
                    return Card(
                      color: isDark ? const Color(0xFF334155) : Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGreen.withOpacity(
                            0.1,
                          ),
                          backgroundImage:
                              (player.profileImageUrl != null &&
                                      player.profileImageUrl!.isNotEmpty)
                                  ? NetworkImage(player.profileImageUrl!)
                                  : null,
                          child:
                              (player.profileImageUrl == null ||
                                      player.profileImageUrl!.isEmpty)
                                  ? Text(
                                    player.name[0],
                                    style: const TextStyle(
                                      color: AppTheme.primaryGreen,
                                    ),
                                  )
                                  : null,
                        ),
                        title: Text(
                          player.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${player.runsScored} Runs • ${player.wicketsTaken} Wkts',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          scoringController.setManualManOfMatch(
                            matchId: match.id,
                            playerId: player.id,
                            playerName: player.name,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
