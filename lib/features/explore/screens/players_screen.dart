import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../../../core/controllers/leaderboard_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/player_stats_model.dart';
import '../../../core/models/user_model.dart';
import './player_profile_screen.dart';
import '../../../core/widgets/modern_app_bar.dart';

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
    final Color subTextColor =
        isDark ? Colors.white38 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          _buildBackgroundLayer(isDark),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              ModernSliverAppBar(
                title: 'Leaderboard',
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: gold.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: gold,
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SEASON',
                              style: GoogleFonts.inter(
                                color: gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

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

              // Top 3 Podium
              SliverToBoxAdapter(
                child: Obx(() {
                  if (controller.isLoading.value ||
                      controller.playersList.length < 3) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 10),
                    child: _buildTop3Podium(isDark, surfaceColor, textColor),
                  );
                }),
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
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
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
      width: 150,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: subTextColor,
              letterSpacing: 0.5,
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
    bool isTop3 = rank <= 3;
    if (rank == 1) {
      rankColor = gold;
    } else if (rank == 2) {
      rankColor = silver;
    } else if (rank == 3) {
      rankColor = bronze;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isTop3 ? rankColor.withOpacity(0.3) : textColor.withOpacity(0.05),
          width: isTop3 ? 1.5 : 1.0,
        ),
        boxShadow:
            isTop3
                ? [
                  BoxShadow(
                    color: rankColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              () => Get.to(
                () => PlayerProfileScreen(
                  playerId: p.user.uid,
                  initialUser: p.user,
                  initialStats: p.stats,
                ),
              ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: isTop3 ? rankColor : subTextColor.withOpacity(0.5),
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        isTop3
                            ? LinearGradient(
                              colors: [rankColor, rankColor.withOpacity(0.2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                            : null,
                    color: isTop3 ? null : textColor.withOpacity(0.05),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: surfaceColor,
                    backgroundImage:
                        p.user.profileImageUrl != null
                            ? NetworkImage(p.user.profileImageUrl!)
                            : null,
                    child:
                        p.user.profileImageUrl == null
                            ? Text(
                              p.user.name.isNotEmpty
                                  ? p.user.name[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.outfit(
                                color: isTop3 ? rankColor : textColor,
                                fontWeight: FontWeight.bold,
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
                      Text(
                        p.user.name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.user.role.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: subTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_getStatValue(p.stats)}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color:
                            isTop3
                                ? rankColor
                                : (isDark ? neonCyan : const Color(0xFF0891B2)),
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      controller.selectedType.value == 'Batting'
                          ? 'RUNS'
                          : 'WKTS',
                      style: GoogleFonts.inter(
                        color:
                            isTop3
                                ? rankColor.withOpacity(0.8)
                                : subTextColor.withOpacity(0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: subTextColor.withOpacity(0.3),
                  size: 14,
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

  Widget _buildTop3Podium(bool isDark, Color surfaceColor, Color textColor) {
    final top3 = controller.playersList.take(3).toList();
    if (top3.length < 3) return const SizedBox.shrink();

    final rank2 = top3[1];
    final rank1 = top3[0];
    final rank3 = top3[2];

    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPodiumStep(
            rank2,
            2,
            80,
            silver,
            isDark,
            surfaceColor,
            textColor,
          ),
          const SizedBox(width: 8),
          _buildPodiumStep(
            rank1,
            1,
            120,
            gold,
            isDark,
            surfaceColor,
            textColor,
          ),
          const SizedBox(width: 8),
          _buildPodiumStep(
            rank3,
            3,
            60,
            bronze,
            isDark,
            surfaceColor,
            textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(
    PlayerWithStats player,
    int rank,
    double pedestalHeight,
    Color rankColor,
    bool isDark,
    Color surfaceColor,
    Color textColor,
  ) {
    final bool isRank1 = rank == 1;
    final String statValue = _getStatValue(player.stats).toString();
    final String statLabel =
        controller.selectedType.value == 'Batting' ? 'Runs' : 'Wkts';

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Avatar
          Container(
            padding: EdgeInsets.all(isRank1 ? 4 : 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  rankColor.withOpacity(0.9),
                  rankColor.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: rankColor.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: isRank1 ? 32 : 24,
              backgroundColor: surfaceColor,
              child: Text(
                player.user.name.isNotEmpty
                    ? player.user.name.substring(0, 1).toUpperCase()
                    : '?',
                style: GoogleFonts.outfit(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: isRank1 ? 24 : 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            player.user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: textColor,
              fontWeight: isRank1 ? FontWeight.w800 : FontWeight.w600,
              fontSize: isRank1 ? 14 : 12,
            ),
          ),
          const SizedBox(height: 4),
          // Stat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statValue,
                  style: GoogleFonts.inter(
                    color: rankColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  statLabel,
                  style: GoogleFonts.inter(
                    color: rankColor.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Pedestal Block
          Container(
            height: pedestalHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rankColor.withOpacity(0.25),
                  rankColor.withOpacity(0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top border highlight indicator
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: rankColor.withOpacity(0.8),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: rankColor.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                // Rank Text inside Pedestal
                Positioned(
                  top: isRank1 ? 24 : 16,
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.outfit(
                      color: rankColor.withOpacity(isDark ? 0.3 : 0.6),
                      fontSize: isRank1 ? 38 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
