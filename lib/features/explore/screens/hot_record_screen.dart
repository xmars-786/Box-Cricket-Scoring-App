import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/controllers/auth_controller.dart';
import '../controllers/player_profile_controller.dart';
import '../../../core/models/player_stats_model.dart';

class HotRecordScreen extends StatelessWidget {
  const HotRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final AuthController authController = Get.find<AuthController>();

    final String userId = authController.userId ?? '';
    if (!Get.isRegistered<PlayerProfileController>(tag: 'home_profile')) {
      Get.put(PlayerProfileController(playerId: userId), tag: 'home_profile');
    }

    final profileCtrl = Get.find<PlayerProfileController>(tag: 'home_profile');

    return Scaffold(
      backgroundColor: isDark ? AppTheme.primaryDark : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Obx(() {
          final isLoading = profileCtrl.isLoading.value;
          final stats = profileCtrl.aggregatedStats.value;

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, isDark),
              SliverToBoxAdapter(
                child:
                    isLoading
                        ? const Padding(
                          padding: EdgeInsets.only(top: 100),
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : stats == null || stats.matches == 0
                        ? _buildEmptyState(isDark)
                        : _buildRecordsList(stats, isDark),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.primaryGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'HOT RECORDS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8C00), Color(0xFFFF4500)],
                ),
              ),
            ),
            const Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.2,
                child: Icon(Icons.whatshot, size: 200, color: Colors.white),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'PERSONAL ACHIEVEMENTS',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList(PlayerStatsModel stats, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('BATTING MILESTONES', Icons.bolt, Colors.orange),
          const SizedBox(height: 16),
          _buildRecordCard(
            'Highest Score',
            stats.highestScore.toString(),
            'Best individual runs in a match',
            Icons.star_rounded,
            Colors.amber,
            isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallRecordCard(
                  'Fifties',
                  stats.fifties.toString(),
                  Icons.sports_cricket,
                  Colors.blue,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallRecordCard(
                  'Centuries',
                  stats.hundreds.toString(),
                  Icons.workspace_premium,
                  Colors.purple,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'BOWLING EXCELLENCE',
            Icons.auto_awesome,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildRecordCard(
            'Best Bowling',
            stats.bestBowling,
            'Most wickets for least runs in a match',
            Icons.gps_fixed_rounded,
            Colors.redAccent,
            isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallRecordCard(
                  '3 Wickets',
                  stats.threeWkts.toString(),
                  Icons.looks_3,
                  Colors.teal,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallRecordCard(
                  '5 Wickets',
                  stats.fiveWkts.toString(),
                  Icons.looks_5,
                  Colors.indigo,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'CAREER IMPACT',
            Icons.emoji_events,
            Colors.amber,
          ),
          const SizedBox(height: 16),
          _buildRecordCard(
            'Match Wins',
            stats.wins.toString(),
            'Total matches where you were in winning team',
            Icons.military_tech_rounded,
            Colors.green,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildRecordCard(
            'Outstanding Performance',
            stats.thirties.toString(),
            'Matches with 30+ runs impact',
            Icons.trending_up_rounded,
            AppTheme.primaryGreen,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallRecordCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 100, left: 40, right: 40),
      child: Column(
        children: [
          const Opacity(
            opacity: 0.5,
            child: Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Records Yet',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play more matches and perform your best to unlock hot records!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
