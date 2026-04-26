import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/player_stats_model.dart';
import './players_screen.dart';

class PlayerProfileScreen extends StatelessWidget {
  final PlayerWithStats playerWithStats;

  const PlayerProfileScreen({super.key, required this.playerWithStats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = playerWithStats.user;
    final stats = playerWithStats.stats;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDark ? AppTheme.primaryDark : const Color(0xFFF8FAFC),
        body: SafeArea(
          top: false, // Allow SliverAppBar to go behind status bar
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: AppTheme.primaryGreen,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Gradient Background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primaryGreen.withOpacity(0.8),
                                AppTheme.primaryGreen,
                              ],
                            ),
                          ),
                        ),
                        // Player Info Overlay
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Hero(
                              tag: 'player_avatar_${user.uid}',
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 47,
                                  backgroundColor: Colors.white,
                                  foregroundImage:
                                      user.profileImageUrl != null &&
                                              user.profileImageUrl!.isNotEmpty
                                          ? NetworkImage(user.profileImageUrl!)
                                          : null,
                                  child: Text(
                                    user.name.substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.name,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user.role.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  bottom: TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 4,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.7),
                    labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    tabs: const [Tab(text: 'BATTING'), Tab(text: 'BOWLING')],
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _buildBattingStats(stats, isDark),
                _buildBowlingStats(stats, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBattingStats(PlayerStatsModel stats, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Overall Performance', isDark),
          // const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard('Mat', stats.matches.toString(), isDark),
              _buildStatCard('Inns', stats.battingInnings.toString(), isDark),
              _buildStatCard('NO', stats.notOuts.toString(), isDark),
              _buildStatCard(
                'Runs',
                stats.runs.toString(),
                isDark,
                isHighlight: true,
              ),
              _buildStatCard('HS', stats.highestScore.toString(), isDark),
              _buildStatCard(
                'Avg',
                stats.battingAverage.toStringAsFixed(2),
                isDark,
              ),
              _buildStatCard(
                'SR',
                stats.battingStrikeRate.toStringAsFixed(2),
                isDark,
              ),
              _buildStatCard('30s', stats.thirties.toString(), isDark),
              _buildStatCard('50s', stats.fifties.toString(), isDark),
              _buildStatCard('100s', stats.hundreds.toString(), isDark),
              _buildStatCard('4s', stats.fours.toString(), isDark),
              _buildStatCard('6s', stats.sixes.toString(), isDark),
              _buildStatCard('Ducks', stats.ducks.toString(), isDark),
              _buildStatCard(
                'Won',
                stats.wins.toString(),
                isDark,
                color: Colors.green,
              ),
              _buildStatCard(
                'Loss',
                stats.losses.toString(),
                isDark,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBowlingStats(PlayerStatsModel stats, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Overall Bowling', isDark),
          // const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard('Mat', stats.matches.toString(), isDark),
              _buildStatCard('Inns', stats.bowlingInnings.toString(), isDark),
              _buildStatCard('Overs', stats.overs.toStringAsFixed(1), isDark),
              _buildStatCard('Maidens', stats.maidens.toString(), isDark),
              _buildStatCard('Runs', stats.runsConceded.toString(), isDark),
              _buildStatCard(
                'Wkts',
                stats.wickets.toString(),
                isDark,
                isHighlight: true,
              ),
              _buildStatCard('BB', stats.bestBowling, isDark),
              _buildStatCard('3w', stats.threeWkts.toString(), isDark),
              _buildStatCard('5w', stats.fiveWkts.toString(), isDark),
              _buildStatCard('Eco', stats.economy.toStringAsFixed(2), isDark),
              _buildStatCard('SR', stats.bowlingSR.toStringAsFixed(2), isDark),
              _buildStatCard(
                'Avg',
                stats.bowlingAvg.toStringAsFixed(2),
                isDark,
              ),
              _buildStatCard('WD', stats.wideBalls.toString(), isDark),
              _buildStatCard('NB', stats.noBalls.toString(), isDark),
              _buildStatCard('Dots', stats.dotBalls.toString(), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isHighlight
                  ? AppTheme.primaryGreen.withOpacity(0.5)
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
          width: isHighlight ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color:
                  color ??
                  (isHighlight
                      ? AppTheme.primaryGreen
                      : (isDark ? Colors.white : Colors.black87)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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
}
