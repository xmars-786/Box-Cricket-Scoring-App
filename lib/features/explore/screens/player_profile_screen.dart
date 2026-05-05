import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'dart:ui';
import '../../../core/controllers/leaderboard_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/player_match_history_model.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/player_stats_model.dart';
import '../controllers/player_profile_controller.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final AppUser? initialUser;
  final PlayerStatsModel? initialStats;

  const PlayerProfileScreen({
    super.key,
    required this.playerId,
    this.initialUser,
    this.initialStats,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen>
    with TickerProviderStateMixin {
  late PlayerProfileController _profileController;
  final RxString _selectedStatType = 'Batting'.obs;

  static const Color premiumDark = AppTheme.primaryDark;
  static const Color surfaceDark = Color(0xFF1B263B);
  static const Color neonCyan = Color(0xFF00F2FF);
  static const Color gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _profileController = Get.put(
      PlayerProfileController(playerId: widget.playerId),
      tag: widget.playerId,
    );

    if (widget.initialUser != null) {
      _profileController.user.value = widget.initialUser;
      _profileController.isUserLoading.value = false;
    }
    if (widget.initialStats != null) {
      _profileController.aggregatedStats.value = widget.initialStats;
    }
  }

  @override
  void dispose() {
    Get.delete<PlayerProfileController>(tag: widget.playerId);
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
      body: Obx(() {
        if (_profileController.isLoading.value &&
            _profileController.aggregatedStats.value == null) {
          return _buildSkeletonLoader(isDark, backgroundColor, surfaceColor);
        }

        return RefreshIndicator(
          color: neonCyan,
          onRefresh: () => _profileController.onRefresh(),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernAppBar(isDark, backgroundColor, textColor),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 8),
                  child: Center(child: _buildSubTabSwitcher(isDark)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: _buildStatsGrid(surfaceColor, textColor, subTextColor),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildModernAppBar(
    bool isDark,
    Color backgroundColor,
    Color textColor,
  ) {
    return Obx(() {
      final user = _profileController.user.value;

      return SliverAppBar(
        expandedHeight: 220,
        pinned: true,
        backgroundColor: backgroundColor,
        elevation: 0,
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
          background: Stack(
            fit: StackFit.expand,
            children: [
              _buildAppBarGradient(isDark),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                child: _buildProfileHeader(user, textColor),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAppBarGradient(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? [
                    const Color(0xFF1E293B),
                    premiumDark,
                    const Color(0xFF0F172A),
                  ]
                  : [
                    const Color(0xFFE2E8F0),
                    const Color(0xFFF8FAFC),
                    const Color(0xFFCBD5E1),
                  ],
        ),
      ),
      child: Opacity(
        opacity: isDark ? 0.05 : 0.02,
        child: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildProfileHeader(AppUser? user, Color textColor) {
    if (user == null) return const SizedBox.shrink();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: neonCyan.withOpacity(0.2), width: 2),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: textColor.withOpacity(0.05),
            backgroundImage:
                user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
            child:
                user.profileImageUrl == null
                    ? Text(
                      user.name.isNotEmpty ? user.name[0] : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.name,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        Text(
          user.role.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: textColor.withOpacity(0.5),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabSwitcher(bool isDark) {
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            ['Batting', 'Bowling'].map((type) {
              final isSelected = _selectedStatType.value == type;
              return GestureDetector(
                onTap: () => _selectedStatType.value = type,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected
                              ? Colors.black
                              : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildStatsGrid(
    Color surfaceColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Obx(() {
      final stats = _profileController.aggregatedStats.value;
      if (stats == null)
        return const SliverToBoxAdapter(child: SizedBox.shrink());

      final type = _selectedStatType.value;
      List<StatItem> items = [];

      if (type == 'Batting') {
        items = [
          StatItem('Mat', stats.matches.toString()),
          StatItem('Inns', stats.battingInnings.toString()),
          StatItem('NO', stats.notOuts.toString()),
          StatItem('Runs', stats.runs.toString()),
          StatItem(
            'HS',
            '${stats.highestScore}${stats.notOuts > 0 ? "*" : ""}',
          ),
          StatItem('Avg', stats.battingAverage.toStringAsFixed(2)),
          StatItem('SR', stats.battingStrikeRate.toStringAsFixed(2)),
          StatItem('30s', stats.thirties.toString()),
          StatItem('50s', stats.fifties.toString()),
          StatItem('100s', stats.hundreds.toString()),
          StatItem('4s', stats.fours.toString()),
          StatItem('6s', stats.sixes.toString()),
          StatItem('Ducks', stats.ducks.toString()),
          StatItem('Won', stats.wins.toString()),
          StatItem('Loss', stats.losses.toString()),
        ];
      } else {
        items = [
          StatItem('Mat', stats.matches.toString()),
          StatItem('Inns', stats.bowlingInnings.toString()),
          StatItem('Overs', stats.overs.toStringAsFixed(1)),
          StatItem('Maidens', stats.maidens.toString()),
          StatItem('Runs', stats.runsConceded.toString()),
          StatItem('Wkts', stats.wickets.toString()),
          StatItem('BB', stats.bestBowling),
          StatItem('3 Wkts', stats.threeWkts.toString()),
          StatItem('5 Wkts', stats.fiveWkts.toString()),
          StatItem('Eco', stats.economy.toStringAsFixed(2)),
          StatItem('SR', stats.bowlingSR.toStringAsFixed(2)),
          StatItem('Avg', stats.bowlingAvg.toStringAsFixed(2)),
          StatItem('WD', stats.wideBalls.toString()),
          StatItem('NB', stats.noBalls.toString()),
          StatItem('Dots', stats.dotBalls.toString()),
        ];
      }

      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: textColor.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  items[index].value,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  items[index].label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: subTextColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        }, childCount: items.length),
      );
    });
  }

  Widget _buildSkeletonLoader(
    bool isDark,
    Color backgroundColor,
    Color surfaceColor,
  ) {
    return Container(
      color: backgroundColor,
      child: Center(child: CircularProgressIndicator(color: neonCyan)),
    );
  }
}

class StatItem {
  final String label;
  final String value;
  StatItem(this.label, this.value);
}
