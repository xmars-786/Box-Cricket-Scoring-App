import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../core/controllers/tournament_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/models/match_model.dart';
import '../../../core/models/tournament_player_stats.dart';
import '../../match/widgets/match_card_widget.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../core/services/tournament_pdf_service.dart';
import '../../../core/controllers/team_controller.dart';
import '../../../core/models/team_model.dart';
import '../../../core/models/user_model.dart';
import '../../explore/screens/player_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamStanding {
  final String teamId;
  final String teamName;
  int matches = 0;
  int wins = 0;
  int losses = 0;
  int runs = 0;
  int wickets = 0;
  int points = 0;

  TeamStanding(this.teamId, this.teamName);
}

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({super.key});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final tournamentController = Get.find<TournamentController>();
  final authController = Get.find<AuthController>();
  final matchController = Get.find<MatchController>();
  final teamController = Get.find<TeamController>();

  late String tournamentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    tournamentId = Get.arguments as String;
    tournamentController.listenToTournament(tournamentId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TeamStanding> _calculateStandings(
    TournamentModel tournament,
    List<MatchModel> matches,
  ) {
    final standingsMap = <String, TeamStanding>{};

    for (int i = 0; i < tournament.teamIds.length; i++) {
      standingsMap[tournament.teamIds[i]] = TeamStanding(
        tournament.teamIds[i],
        tournament.teamNames[i],
      );
    }

    for (var match in matches.where((m) => m.isCompleted)) {
      String? teamAId = match.teamAId;
      String? teamBId = match.teamBId;

      if (teamAId == null) {
        final idx = tournament.teamNames.indexOf(match.teamAName);
        if (idx != -1) teamAId = tournament.teamIds[idx];
      }
      if (teamBId == null) {
        final idx = tournament.teamNames.indexOf(match.teamBName);
        if (idx != -1) teamBId = tournament.teamIds[idx];
      }

      final teamA = standingsMap[teamAId];
      final teamB = standingsMap[teamBId];

      if (teamA != null && teamB != null) {
        teamA.matches++;
        teamB.matches++;
        teamA.runs += match.teamAScore.runs;
        teamB.runs += match.teamBScore.runs;
        teamA.wickets += match.teamAScore.wickets;
        teamB.wickets += match.teamBScore.wickets;

        if (match.winnerId == teamAId) {
          teamA.wins++;
          teamA.points += 2;
          teamB.losses++;
        } else if (match.winnerId == teamBId) {
          teamB.wins++;
          teamB.points += 2;
          teamA.losses++;
        } else {
          final resultLower = match.result?.toLowerCase() ?? '';
          if (resultLower.contains(match.teamAName.toLowerCase())) {
            teamA.wins++;
            teamA.points += 2;
            teamB.losses++;
          } else if (resultLower.contains(match.teamBName.toLowerCase())) {
            teamB.wins++;
            teamB.points += 2;
            teamA.losses++;
          } else {
            teamA.points += 1;
            teamB.points += 1;
          }
        }
      }
    }

    final standings = standingsMap.values.toList();
    standings.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      return b.wins.compareTo(a.wins);
    });

    return standings;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final tournament = tournamentController.selectedTournament;
      final matches = tournamentController.tournamentMatches;
      final leaderboard = tournamentController.leaderboard;

      if (tournament == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      // Safety check for leaderboard
      if (leaderboard == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final standings = _calculateStandings(tournament, matches);
      final totalRuns = standings.fold<int>(0, (sum, s) => sum + s.runs);
      final totalWickets = standings.fold<int>(0, (sum, s) => sum + s.wickets);

      return Scaffold(
        backgroundColor:
            isDark ? AppTheme.primaryDark : const Color(0xFFF1F5F9),
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppTheme.primaryGreen,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title:
                        innerBoxIsScrolled
                            ? Text(
                              tournament.name.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            )
                            : null,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors:
                                  isDark
                                      ? [
                                        const Color(0xFF1E293B),
                                        const Color(0xFF0F172A),
                                      ]
                                      : [
                                        const Color(0xFF00B894),
                                        const Color(0xFF00A8FF),
                                      ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -50,
                          top: -20,
                          child: Opacity(
                            opacity: 0.1,
                            child: Icon(
                              Icons.sports_cricket,
                              size: 250,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      tournament.type.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  _buildTournamentStatusBadge(
                                    tournament.status,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tournament.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${UIUtils.formatDate(tournament.startDate)} - ${UIUtils.formatDate(tournament.endDate)}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  _buildTopStat(
                                    'TEAMS',
                                    tournament.teamIds.length.toString(),
                                  ),
                                  _buildStatDivider(),
                                  _buildTopStat(
                                    'MATCHES',
                                    matches.length.toString(),
                                  ),
                                  _buildStatDivider(),
                                  _buildTopStat('RUNS', totalRuns.toString()),
                                  _buildStatDivider(),
                                  _buildTopStat('WKT', totalWickets.toString()),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (tournament.status == 'completed')
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        onPressed: () => _exportTournamentAsPdf(tournament),
                        tooltip: 'Export PDF Report',
                      ),
                    if (authController.currentUser?.isAdmin ?? false) ...[
                      IconButton(
                        icon: const Icon(Icons.settings_suggest_outlined),
                        onPressed:
                            () => _showStatusChangeSheet(context, tournament),
                        tooltip: 'Change Status',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(tournament),
                      ),
                    ],
                  ],
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.primaryDark : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: AppTheme.primaryGreen,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppTheme.primaryGreen,
                        indicatorWeight: 3,
                        indicatorPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        labelStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        tabs: const [
                          Tab(text: 'OVERVIEW'),
                          Tab(text: 'LEADERBOARD'),
                          Tab(text: 'MATCHES'),
                          Tab(text: 'TEAMS'),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isDark, standings, totalRuns, totalWickets),
                _buildLeaderboardTab(isDark, leaderboard),
                _buildMatchesTab(isDark),
                _buildTeamsTab(isDark, tournament),
              ],
            ),
          ),
        ),
        floatingActionButton:
            (authController.currentUser?.isAdmin ?? false) &&
                    tournamentController.canCreateMatchInTournament(tournament)
                ? FloatingActionButton.extended(
                  onPressed:
                      () => Get.toNamed(
                        AppRoutes.createMatch,
                        arguments: {"tournamentId": tournament.id},
                      ),
                  backgroundColor: AppTheme.primaryGreen,
                  elevation: 4,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    "NEW MATCH",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                )
                : null,
      );
    });
  }

  Widget _buildTopStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildOverviewTab(
    bool isDark,
    List<TeamStanding> standings,
    int totalRuns,
    int totalWickets,
  ) {
    final tournament = tournamentController.selectedTournament;
    final isClosedOrCompleted =
        tournament?.status == 'completed' || tournament?.status == 'closed';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isClosedOrCompleted) _buildStatusBanner(isDark, tournament!.status),
        if (!(authController.currentUser?.isAdmin ?? false))
          _buildViewOnlyBanner(isDark),
        _buildAwardsSection(isDark),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'POINTS TABLE',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            if (standings.isNotEmpty)
              Text(
                'Top 4 advance',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              _buildTableHeader(isDark),
              ...standings.asMap().entries.map((entry) {
                return _buildTableRow(
                  entry.key + 1,
                  entry.value,
                  isDark,
                  standings.length,
                );
              }),
              if (standings.isEmpty) _buildEmptyState('No stats available yet'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAwardsSection(bool isDark) {
    final leaderboard = tournamentController.leaderboard;
    if (leaderboard.isEmpty) {
      if (tournamentController.isLoading) {
        return _buildAwardsLoadingState(isDark);
      }
      return const SizedBox.shrink();
    }

    final potList = [...leaderboard];
    potList.sort((a, b) {
      final pointsA = a.runs + (a.wickets * 20) + (a.catches * 10);
      final pointsB = b.runs + (b.wickets * 20) + (b.catches * 10);
      return pointsB.compareTo(pointsA);
    });

    final bestBatsman = leaderboard.first;
    final bestBowler = [...leaderboard];
    bestBowler.sort((a, b) => b.wickets.compareTo(a.wickets));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOURNAMENT AWARDS',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildAwardCard(
                'Player of Tournament',
                potList.first.name,
                potList.first.teamName,
                Icons.emoji_events,
                const Color(0xFFFFD700),
                isDark,
              ),
              const SizedBox(width: 16),
              _buildAwardCard(
                'Best Batsman',
                bestBatsman.name,
                bestBatsman.teamName,
                Icons.sports_cricket,
                const Color(0xFF00B894),
                isDark,
              ),
              const SizedBox(width: 16),
              _buildAwardCard(
                'Best Bowler',
                bestBowler.first.name,
                bestBowler.first.teamName,
                Icons.bolt,
                const Color(0xFF00A8FF),
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAwardsLoadingState(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 150,
          height: 16,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              3,
              (index) => Container(
                width: 140,
                height: 160,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200,
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAwardCard(
    String title,
    String name,
    String team,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            team,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: _tableHeaderText('#')),
          Expanded(child: _tableHeaderText('TEAM')),
          SizedBox(width: 30, child: _tableHeaderText('P')),
          SizedBox(width: 30, child: _tableHeaderText('W')),
          SizedBox(width: 40, child: _tableHeaderText('PTS')),
        ],
      ),
    );
  }

  Widget _tableHeaderText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTableRow(int rank, TeamStanding team, bool isDark, int total) {
    final isTop4 = rank <= 4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border:
            rank == total
                ? null
                : Border(
                  bottom: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.03)
                            : const Color(0xFFF1F5F9),
                  ),
                ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              rank.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: isTop4 ? AppTheme.primaryGreen : Colors.grey[400],
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (isTop4)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    team.teamName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              team.matches.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              team.wins.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              team.points.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(
    bool isDark,
    List<TournamentPlayerStats> leaderboard,
  ) {
    if (leaderboard.isEmpty) {
      return _buildEmptyState('No player statistics yet');
    }

    final topScorers = leaderboard.take(3).toList();
    final topWicketTakers = [...leaderboard];
    topWicketTakers.sort((a, b) => b.wickets.compareTo(a.wickets));
    final topBowlers = topWicketTakers.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('TOP RUN SCORERS', Icons.trending_up),
        const SizedBox(height: 12),
        ...topScorers.asMap().entries.map(
          (entry) =>
              _buildPlayerRankCard(entry.key + 1, entry.value, 'runs', isDark),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('TOP WICKET TAKERS', Icons.bolt),
        const SizedBox(height: 12),
        ...topBowlers.asMap().entries.map(
          (entry) => _buildPlayerRankCard(
            entry.key + 1,
            entry.value,
            'wickets',
            isDark,
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader('ALL PLAYER STATS', Icons.list),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children:
                leaderboard
                    .map((stats) => _buildPlayerListRow(stats, isDark))
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerRankCard(
    int rank,
    TournamentPlayerStats stats,
    String type,
    bool isDark,
  ) {
    final color =
        rank == 1
            ? const Color(0xFFFFD700)
            : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    final value =
        type == 'runs' ? '${stats.runs} Runs' : '${stats.wickets} Wkts';
    final subValue =
        type == 'runs'
            ? 'SR: ${stats.strikeRate.toStringAsFixed(1)}'
            : 'Eco: ${stats.economy.toStringAsFixed(1)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildRankBadge(rank),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  stats.teamName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGreen,
                ),
              ),
              Text(
                subValue,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    final color =
        rank == 1
            ? const Color(0xFFFFD700)
            : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '#$rank',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            color: color,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerListRow(TournamentPlayerStats stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                isDark
                    ? Colors.white.withOpacity(0.03)
                    : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                Text(
                  stats.teamName,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          _statsColumn('M', stats.matches.toString()),
          _statsColumn('R', stats.runs.toString()),
          _statsColumn('W', stats.wickets.toString()),
          _statsColumn('HS', stats.highestScore.toString()),
        ],
      ),
    );
  }

  Widget _statsColumn(String label, String value) {
    return Container(
      width: 40,
      margin: const EdgeInsets.only(left: 8),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesTab(bool isDark) {
    return Obx(() {
      final matches = tournamentController.tournamentMatches;
      final isAdmin = authController.currentUser?.isAdmin ?? false;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTournamentDashboard(isDark),
          const SizedBox(height: 24),

          if (matches.isEmpty)
            _buildEmptyState('No matches scheduled yet')
          else ...[
            _buildSectionHeader(
              'MATCH SCHEDULE & FLOW',
              Icons.account_tree_outlined,
            ),
            const SizedBox(height: 16),
            ...List.generate(matches.length, (index) {
              final match = matches[index];
              final canStart = tournamentController.canStartMatch(match);
              final isLive = match.isLive;
              final isCompleted = match.isCompleted;

              return Column(
                children: [
                  Row(
                    children: [
                      // Timeline Indicator
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color:
                                  isCompleted
                                      ? AppTheme.primaryGreen
                                      : (isLive
                                          ? Colors.blue
                                          : Colors.grey.withOpacity(0.2)),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child:
                                  isCompleted
                                      ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                      : Text(
                                        '${index + 1}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isLive
                                                  ? Colors.white
                                                  : Colors.grey,
                                        ),
                                      ),
                            ),
                          ),
                          if (index < matches.length - 1)
                            Container(
                              width: 2,
                              height: 40,
                              color:
                                  isCompleted
                                      ? AppTheme.primaryGreen.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.1),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Match Card
                      Expanded(
                        child: Column(
                          children: [
                            MatchCardWidget(
                              match: match,
                              isDark: isDark,
                              isAdmin: isAdmin,
                              showTournamentName: false,
                              onDelete:
                                  () => matchController.deleteMatch(match.id),
                            ),
                            if (canStart && !isLive && !isCompleted && isAdmin)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildNextMatchAction(match, isDark),
                              ),
                            if (!canStart && !isLive && !isCompleted)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildLockedMatchInfo(isDark),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ],
      );
    });
  }

  Widget _buildNextMatchAction(MatchModel match, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.play_circle_fill,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'THIS IS THE NEXT MATCH',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          TextButton(
            onPressed:
                () => Get.toNamed(
                  AppRoutes.createMatch,
                  arguments: {
                    'matchId': match.id,
                    'tournamentId': tournamentId,
                  },
                ),
            child: Text(
              'START NOW',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedMatchInfo(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            'Complete previous matches to unlock',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentDashboard(bool isDark) {
    final total = tournamentController.totalMatches;
    final completed = tournamentController.completedMatchesCount;
    final pending = tournamentController.pendingMatchesCount;
    final nextMatch = tournamentController.nextMatchToPlay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('TOURNAMENT DASHBOARD', Icons.dashboard_rounded),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFE2E8F0),
            ),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tournamentController.selectedTournament?.defaultOvers ?? 0} Overs Tournament',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDashboardStat('TOTAL', total.toString(), Colors.blue),
                  _buildDashboardStat(
                    'COMPLETED',
                    completed.toString(),
                    AppTheme.primaryGreen,
                  ),
                  _buildDashboardStat(
                    'PENDING',
                    pending.toString(),
                    AppTheme.vibrantOrange,
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildTournamentRulesSummary(
                isDark,
                tournamentController.selectedTournament,
              ),
              if (total > 0) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOURNAMENT PROGRESS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : completed / total,
                              backgroundColor:
                                  isDark ? Colors.white10 : Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryGreen,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${((total == 0 ? 0 : completed / total) * 100).toInt()}%',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Continue Next Match Button
        if (nextMatch != null &&
            nextMatch.status == 'upcoming' &&
            tournamentController.selectedTournament?.status != 'completed' &&
            tournamentController.selectedTournament?.status != 'closed' &&
            (authController.currentUser?.isAdmin ?? false)) ...[
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Get.toNamed(
                  AppRoutes.createMatch,
                  arguments: {
                    'tournamentId': tournamentController.selectedTournament?.id,
                    'existingMatchId': nextMatch.id,
                  },
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryGreen, Color(0xFF00BFA5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'CONTINUE TO NEXT MATCH',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Create New Match Button (if allowed)
        if (tournamentController.canCreateMatchInTournament(
              tournamentController.selectedTournament,
            ) &&
            (authController.currentUser?.isAdmin ?? false)) ...[
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Get.toNamed(
                  AppRoutes.createMatch,
                  arguments: {
                    'tournamentId': tournamentController.selectedTournament?.id,
                  },
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'CREATE NEW MATCH',
                      style: GoogleFonts.outfit(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (nextMatch != null) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('NEXT MATCH TO PLAY', Icons.play_circle_filled),
          const SizedBox(height: 12),
          MatchCardWidget(
            match: nextMatch,
            isDark: isDark,
            isAdmin: authController.currentUser?.isAdmin ?? false,
          ),
        ],
      ],
    );
  }

  Widget _buildDashboardStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamsTab(bool isDark, TournamentModel tournament) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tournament.teamNames.length,
      itemBuilder: (context, index) {
        final teamName = tournament.teamNames[index];
        final teamId = tournament.teamIds[index];
        final isWinner = tournament.winnerTeamId == teamId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isWinner
                      ? Colors.amber.withOpacity(0.3)
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFE2E8F0)),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: (isWinner ? Colors.amber : AppTheme.primaryGreen)
                  .withOpacity(0.1),
              child: Icon(
                isWinner ? Icons.emoji_events : Icons.group,
                color: isWinner ? Colors.amber : AppTheme.primaryGreen,
              ),
            ),
            title: Text(
              teamName,
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Tournament Participant',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
            trailing:
                isWinner
                    ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'WINNER',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                        ),
                      ),
                    )
                    : const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
            onTap:
                () => _showTeamPlayersSheet(context, teamId, teamName, isDark),
          ),
        );
      },
    );
  }

  void _showTeamPlayersSheet(
    BuildContext context,
    String teamId,
    String teamName,
    bool isDark,
  ) async {
    // Find the master team template
    final team = teamController.teams.firstWhereOrNull((t) => t.id == teamId);

    // Fallback: Get players from matches if team template is deleted
    final Set<String> playerIds = {};
    if (team != null) {
      playerIds.addAll(team.playerIds);
    }

    // Also collect from leaderboard (players who have actually played)
    // This helps if the team template was deleted or modified
    final playedPlayers = tournamentController.leaderboard
        .where((p) => p.teamName == teamName)
        .map((p) => p.playerId);
    playerIds.addAll(playedPlayers);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.group_rounded,
                        color: AppTheme.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamName.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'SQUAD LIST',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child:
                    playerIds.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                team == null
                                    ? 'No match data or squad found'
                                    : 'No players listed in this team',
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                        : FutureBuilder<QuerySnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .where(
                                    FieldPath.documentId,
                                    whereIn:
                                        playerIds.length > 30
                                            ? playerIds.take(30).toList()
                                            : playerIds.toList(),
                                  )
                                  .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryGreen,
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'No players listed in this team',
                                  style: GoogleFonts.inter(color: Colors.grey),
                                ),
                              );
                            }

                            final players =
                                snapshot.data!.docs
                                    .map((doc) => AppUser.fromFirestore(doc))
                                    .toList();

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: players.length,
                              itemBuilder: (context, index) {
                                final player = players[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? Colors.white.withOpacity(0.03)
                                            : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? Colors.white.withOpacity(0.05)
                                              : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppTheme.primaryGreen
                                          .withOpacity(0.1),
                                      backgroundImage:
                                          (player.profileImageUrl != null &&
                                                  player
                                                      .profileImageUrl!
                                                      .isNotEmpty)
                                              ? NetworkImage(
                                                player.profileImageUrl!,
                                              )
                                              : null,
                                      child:
                                          (player.profileImageUrl == null ||
                                                  player
                                                      .profileImageUrl!
                                                      .isEmpty)
                                              ? Text(
                                                player.name[0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: AppTheme.primaryGreen,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                              : null,
                                    ),
                                    title: Text(
                                      player.name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Text(
                                      (player.role.contains('_')
                                              ? player.role.replaceAll('_', ' ')
                                              : player.role)
                                          .toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppTheme.primaryGreen,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Get.to(
                                        () => PlayerProfileScreen(
                                          playerId: player.uid,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
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

  Widget _buildTournamentStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'live':
      case 'ongoing':
        color = Colors.blue;
        icon = Icons.sensors_rounded;
        break;
      case 'completed':
        color = AppTheme.primaryGreen;
        icon = Icons.check_circle_rounded;
        break;
      case 'upcoming':
        color = Colors.grey;
        icon = Icons.schedule_rounded;
        break;
      case 'closed':
        color = Colors.red;
        icon = Icons.block_rounded;
        break;
      default:
        color = Colors.grey;
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isDark, String status) {
    final isClosed = status == 'closed';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: (isClosed ? Colors.red : AppTheme.primaryGreen).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isClosed ? Colors.red : AppTheme.primaryGreen).withOpacity(
            0.2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isClosed ? Icons.lock_rounded : Icons.emoji_events_rounded,
            color: isClosed ? Colors.red : AppTheme.primaryGreen,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClosed ? 'TOURNAMENT CLOSED' : 'TOURNAMENT COMPLETED',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isClosed ? Colors.red : AppTheme.primaryGreen,
                  ),
                ),
                Text(
                  isClosed
                      ? 'This tournament has been manually closed by admin.'
                      : 'All matches have been finished. Congratulations to the winners!',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusChangeSheet(
    BuildContext context,
    TournamentModel tournament,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Tournament Status',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the current state of ${tournament.name}',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _statusOption(
              context,
              'upcoming',
              'Upcoming',
              Icons.schedule_rounded,
              Colors.blue,
              tournament,
            ),
            _statusOption(
              context,
              'live',
              'Live',
              Icons.sensors_rounded,
              AppTheme.primaryGreen,
              tournament,
            ),
            _statusOption(
              context,
              'ongoing',
              'Ongoing',
              Icons.play_arrow_rounded,
              Colors.orange,
              tournament,
            ),
            _statusOption(
              context,
              'completed',
              'Completed',
              Icons.check_circle_rounded,
              Colors.grey,
              tournament,
            ),
            _statusOption(
              context,
              'closed',
              'Closed',
              Icons.block_rounded,
              Colors.red,
              tournament,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statusOption(
    BuildContext context,
    String status,
    String label,
    IconData icon,
    Color color,
    TournamentModel tournament,
  ) {
    final isSelected = tournament.status == status;
    return InkWell(
      onTap: () {
        Get.back();
        tournamentController.updateTournamentStatus(tournament.id, status);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : null,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://assets10.lottiefiles.com/packages/lf20_m6cu9nrv.json',
            width: 150,
            height: 150,
            errorBuilder:
                (_, __, ___) => Icon(
                  Icons.sports_cricket_outlined,
                  size: 64,
                  color: Colors.grey.withOpacity(0.2),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentRulesSummary(
    bool isDark,
    TournamentModel? tournament,
  ) {
    if (tournament == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildRuleIconStat(
          Icons.timer_outlined,
          '${tournament.defaultOvers} OVERS',
          'Per Innings',
          isDark,
        ),
        _buildRuleIconStat(
          Icons.sports_cricket_outlined,
          '${tournament.ballsPerOver} BALLS',
          'Per Over',
          isDark,
        ),
        if (tournament.customRulesEnabled)
          _buildRuleIconStat(
            Icons.rule_folder_outlined,
            'CUSTOM',
            'Limits On',
            isDark,
          ),
      ],
    );
  }

  Widget _buildRuleIconStat(
    IconData icon,
    String label,
    String subLabel,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryGreen.withOpacity(0.7)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              subLabel,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDelete(TournamentModel tournament) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Tournament'),
        content: const Text(
          'This will remove the tournament linking. Matches will remain as individual records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await tournamentController.deleteTournament(tournament.id);
      Get.back();
    }
  }

  Future<void> _exportTournamentAsPdf(TournamentModel tournament) async {
    try {
      UIUtils.showLoading('Generating PDF...');

      await TournamentPdfService.generateAndShareTournamentReport(
        tournament: tournament,
        matches: tournamentController.tournamentMatches,
        leaderboard: tournamentController.leaderboard,
      );

      Get.back(); // Close loading
    } catch (e) {
      Get.back(); // Close loading
      UIUtils.showError('Failed to generate PDF: $e');
    }
  }

  Widget _buildViewOnlyBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: isDark ? Colors.white54 : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            'VIEW ONLY MODE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white54 : Colors.blue,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this.child);
  final Widget child;
  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
