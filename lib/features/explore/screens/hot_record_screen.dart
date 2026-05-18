import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/controllers/auth_controller.dart';
import '../controllers/player_profile_controller.dart';
import '../../../core/models/player_stats_model.dart';
import '../../../core/widgets/modern_app_bar.dart';

class HotRecordScreen extends StatefulWidget {
  const HotRecordScreen({super.key});

  @override
  State<HotRecordScreen> createState() => _HotRecordScreenState();
}

class _HotRecordScreenState extends State<HotRecordScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final collapsed = _scrollController.offset > (160 - kToolbarHeight - 20);
      if (collapsed != _isCollapsed) {
        setState(() {
          _isCollapsed = collapsed;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      body: Obx(() {
        final isLoading = profileCtrl.isLoading.value;
        final stats = profileCtrl.aggregatedStats.value;

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            ModernSliverAppBar(
              title: 'HOT RECORDS',
              expandedHeight: 160,
              pinned: true,
              titleColor:
                  _isCollapsed
                      ? (isDark ? Colors.white : AppTheme.primaryDark)
                      : Colors.white,
              iconColor:
                  _isCollapsed
                      ? (isDark ? Colors.white : AppTheme.primaryDark)
                      : Colors.white,
              flexibleSpace: FlexibleSpaceBar(
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
                                    const Color(0xFF1A1A2E),
                                    const Color(0xFFE94560),
                                    const Color(0xFFFF8C00),
                                  ]
                                  : [
                                    const Color(0xFFFF5F6D),
                                    const Color(0xFFFF4500),
                                    const Color(0xFFFFC371),
                                  ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.1),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: Opacity(
                        opacity: 0.1,
                        child: Icon(
                          Icons.whatshot_rounded,
                          size: 120,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 50),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              'HALL OF FAME',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your Career Achievements',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    );
  }

  Widget _buildRecordsList(PlayerStatsModel stats, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCareerSummary(stats, isDark),
          const SizedBox(height: 32),
          _buildMilestoneTracker(stats, isDark),
          const SizedBox(height: 32),
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

  Widget _buildCareerSummary(PlayerStatsModel stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'AVG',
                stats.battingAverage.toStringAsFixed(1),
                Icons.analytics_outlined,
                Colors.blue,
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                'S/R',
                stats.battingStrikeRate.toStringAsFixed(1),
                Icons.speed_rounded,
                Colors.orange,
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                'ECON',
                stats.economy.toStringAsFixed(1),
                Icons.query_stats_rounded,
                Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniImpact(
                'Matches',
                stats.matches.toString(),
                Icons.sports_cricket_outlined,
              ),
              const Spacer(),
              _buildMiniImpact(
                'Total Runs',
                stats.runs.toString(),
                Icons.trending_up_rounded,
              ),
              const Spacer(),
              _buildMiniImpact(
                'Total Wkts',
                stats.wickets.toString(),
                Icons.track_changes_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.6)),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.1));
  }

  Widget _buildMiniImpact(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMilestoneTracker(PlayerStatsModel stats, bool isDark) {
    // Logic for next milestone
    final nextRunMilestone = ((stats.runs / 100).floor() + 1) * 100;
    final runProgress = (stats.runs % 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'ROAD TO GLORY',
          Icons.auto_graph_rounded,
          Colors.purple,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.purple.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Next Milestone: $nextRunMilestone Runs',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(runProgress * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      color: Colors.purple,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: runProgress,
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.purple,
                  ),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Only ${nextRunMilestone - stats.runs} runs away from your next big record!',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
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
