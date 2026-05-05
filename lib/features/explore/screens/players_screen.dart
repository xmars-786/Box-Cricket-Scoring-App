import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../../../core/controllers/leaderboard_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/player_stats_model.dart';
import '../../../core/models/user_model.dart';
import './player_profile_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final LeaderboardController controller = Get.put(LeaderboardController());
  final ScrollController _scrollController = ScrollController();

  static const Color premiumDark = Color(0xFF070B14);
  static const Color surfaceDark = Color(0xFF1B263B);
  static const Color neonCyan = Color(0xFF00F2FF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFE2E8F0);
  static const Color bronze = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        controller.changeType(
          _tabController.index == 0 ? 'Batting' : 'Bowling',
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppTheme.primaryDark : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? surfaceDark : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          _buildBackgroundLayer(isDark),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernHeader(isDark, textColor, subTextColor),

              // Type Switcher (Batting/Bowling)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: _buildTypeSwitcher(isDark),
                ),
              ),

              // Stats Quick View
              SliverToBoxAdapter(
                child: Obx(
                  () => _buildImpactBar(surfaceColor, textColor, subTextColor),
                ),
              ),

              // Unified Player List
              Obx(() {
                if (controller.isLoading.value) {
                  return SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: isDark ? neonCyan : Colors.blue,
                      ),
                    ),
                  );
                }

                if (controller.playersList.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(subTextColor),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildPlayerListItem(
                        controller.playersList[index],
                        index + 1,
                        isDark,
                        surfaceColor,
                        textColor,
                        subTextColor,
                      );
                    }, childCount: controller.playersList.length),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayer(bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDark
                    ? [
                      const Color(0xFF0F172A),
                      premiumDark,
                      const Color(0xFF020617),
                    ]
                    : [
                      const Color(0xFFF1F5F9),
                      const Color(0xFFF8FAFC),
                      const Color(0xFFE2E8F0),
                    ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: neonCyan.withOpacity(isDark ? 0.03 : 0.08),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(bool isDark, Color textColor, Color subTextColor) {
    return SliverAppBar(
      expandedHeight: 100,
      collapsedHeight: 70,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      stretch: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: textColor,
              size: 18,
            ),
            onPressed: () => Get.back(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leaderboard',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: textColor,
                fontSize: 18,
              ),
            ),
            Text(
              'REAL-TIME PLAYER RANKINGS',
              style: GoogleFonts.inter(
                color: subTextColor,
                fontSize: 6,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSwitcher(bool isDark) {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [neonCyan, Color(0xFF00B4D8)]),
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
        labelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [Tab(text: 'BATTING'), Tab(text: 'BOWLING')],
      ),
    );
  }

  Widget _buildImpactBar(
    Color surfaceColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildImpactCard(
            'TOTAL MATCHES',
            controller.totalMatchesCount.value.toString(),
            Icons.sports_cricket_rounded,
            gold,
            surfaceColor,
            textColor,
            subTextColor,
          ),
          _buildImpactCard(
            'TOTAL RUNS',
            controller.totalRuns.value.toString(),
            Icons.bolt_rounded,
            neonCyan,
            surfaceColor,
            textColor,
            subTextColor,
          ),
          _buildImpactCard(
            'TOTAL WKTS',
            controller.totalWickets.value.toString(),
            Icons.adjust_rounded,
            accentPurple,
            surfaceColor,
            textColor,
            subTextColor,
          ),
          _buildImpactCard(
            'TOP PLAYER',
            controller.playersList.isNotEmpty
                ? controller.playersList[0].user.name.split(' ')[0]
                : 'N/A',
            Icons.star_rounded,
            silver,
            surfaceColor,
            textColor,
            subTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerListItem(
    PlayerWithStats p,
    int rank,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color subTextColor,
  ) {
    Color rankColor = isDark ? Colors.white24 : const Color(0xFF94A3B8);
    if (rank == 1)
      rankColor = gold;
    else if (rank == 2)
      rankColor = silver;
    else if (rank == 3)
      rankColor = bronze;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              rank <= 3
                  ? rankColor.withOpacity(0.2)
                  : textColor.withOpacity(0.03),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.to(() => PlayerProfileScreen(
                playerId: p.user.uid,
                initialUser: p.user,
                initialStats: p.stats,
              )),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: rankColor,
                      fontSize: rank <= 3 ? 16 : 14,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: textColor.withOpacity(0.05),
                  backgroundImage:
                      p.user.profileImageUrl != null
                          ? NetworkImage(p.user.profileImageUrl!)
                          : null,
                  child:
                      p.user.profileImageUrl == null
                          ? Text(
                            p.user.name.isNotEmpty ? p.user.name[0] : '?',
                            style: TextStyle(color: rankColor),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.user.name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        p.user.role.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: subTextColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_getStatValue(p.stats)}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color:
                            rank <= 3
                                ? rankColor
                                : (isDark ? neonCyan : const Color(0xFF0891B2)),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      controller.selectedType.value == 'Batting'
                          ? 'RUNS'
                          : 'WKTS',
                      style: GoogleFonts.inter(
                        color: subTextColor.withOpacity(0.5),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textColor.withOpacity(0.1),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_rounded,
            size: 40,
            color: subTextColor.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'No Data Available',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  int _getStatValue(PlayerStatsModel stats) {
    final cat = controller.selectedCategory.value;
    final isBatting = controller.selectedType.value == 'Batting';

    if (isBatting) {
      if (cat == 'Single Match') return stats.singleRuns;
      if (cat == 'Tournament' &&
          controller.selectedTournamentId.value == null) {
        return stats.tournamentRuns;
      }
      return stats.runs;
    } else {
      if (cat == 'Single Match') return stats.singleWickets;
      if (cat == 'Tournament' &&
          controller.selectedTournamentId.value == null) {
        return stats.tournamentWickets;
      }
      return stats.wickets;
    }
  }
}
