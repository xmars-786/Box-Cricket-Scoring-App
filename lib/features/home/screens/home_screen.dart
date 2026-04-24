import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/theme_controller.dart';
import '../../../core/controllers/connectivity_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/models/match_model.dart';
import '../../match/screens/match_detail_screen.dart';
import '../../scoring/screens/scoring_screen.dart';

/// Home screen with live matches, my matches, and navigation using GetX.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final AuthController authController = Get.find<AuthController>();
  final MatchController matchController = Get.find<MatchController>();
  final ThemeController themeController = Get.find<ThemeController>();
  final ConnectivityController connectivityController =
      Get.find<ConnectivityController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    matchController.listenToLiveMatches();
    if (authController.isAuthenticated) {
      matchController.loadMyMatches(authController.userId);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Obx(
        () => Column(
          children: [
            // Offline banner
            if (!connectivityController.isOnline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: AppTheme.vibrantOrange,
                child: Text(
                  '📡 You\'re offline. Data will sync when connected.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildDashboard(isDark),
                  _buildMyMatches(isDark),
                  _buildExplore(isDark),
                  _buildProfileTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_cricket_outlined),
            selectedIcon: Icon(Icons.sports_cricket),
            label: 'My Matches',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton:
          _currentIndex <= 1
              ? FloatingActionButton.extended(
                onPressed: () => Get.toNamed(AppRoutes.createMatch),
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: Text(
                  'New Match',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              )
              : null,
    );
  }

  // ─── Dashboard Tab ──────────────────────────────────
  Widget _buildDashboard(bool isDark) {
    return CustomScrollView(
      slivers: [
        // App bar with gradient
        SliverAppBar(
          expandedHeight: 140,
          floating: true,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_cricket,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Box Cricket',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          // Theme toggle
                          Obx(
                            () => IconButton(
                              icon: Icon(
                                themeController.isDarkMode
                                    ? Icons.light_mode
                                    : Icons.dark_mode,
                                color: Colors.white,
                              ),
                              onPressed: themeController.toggleTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Obx(
                        () => Text(
                          'Welcome, ${authController.currentUser?.name ?? 'Player'} 👋',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Live Matches Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.wicketRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE MATCHES',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.wicketRed,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.wicketRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Live Matches List
        Obx(() {
          if (matchController.liveMatches.isEmpty) {
            return SliverToBoxAdapter(
              child: _buildEmptyState(
                isDark,
                Icons.sports_cricket,
                'No live matches',
                'Create a new match to get started!',
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildLiveMatchCard(
                matchController.liveMatches[index],
                isDark,
              ),
              childCount: matchController.liveMatches.length,
            ),
          );
        }),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ─── Live Match Card ────────────────────────────────
  Widget _buildLiveMatchCard(MatchModel match, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMatch(match),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B263B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
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
                // Match title & live badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.wicketRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.wicketRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.wicketRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Score display
                Row(
                  children: [
                    Expanded(
                      child: _buildTeamScore(
                        match.teamAName,
                        match.teamAScore,
                        match.currentInnings == 'A',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF253750)
                                : const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'vs',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildTeamScore(
                        match.teamBName,
                        match.teamBScore,
                        match.currentInnings == 'B',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                // Run rate
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CRR: ${match.currentScore.runRate.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Overs: ${match.currentScore.oversDisplay}/${match.totalOvers}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  ],
                ),

                // --- Quick Actions ---
                Builder(
                  builder: (context) {
                    final isAdmin =
                        authController.currentUser?.isAdmin ?? false;
                    final isScorer =
                        match.scorerIds.contains(authController.userId) ||
                        isAdmin;

                    if (!isScorer && !isAdmin) return const SizedBox.shrink();

                    return Column(
                      children: [
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Match',
                                onPressed: () => _confirmDelete(match),
                              ),
                            if (isScorer && match.isLive)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        () => Get.to(
                                          () =>
                                              ScoringScreen(matchId: match.id),
                                        ),
                                    icon: const Icon(Icons.edit_note, size: 18),
                                    label: const Text('Add Score'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.vibrantOrange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamScore(String teamName, MatchScore score, bool isBatting) {
    return Column(
      children: [
        Text(
          teamName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isBatting ? AppTheme.primaryGreen : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${score.runs}/${score.wickets}',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isBatting ? AppTheme.primaryGreen : null,
          ),
        ),
        Text(
          '(${score.oversDisplay})',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // ─── My Matches Tab ─────────────────────────────────
  Widget _buildMyMatches(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(
            'My Matches',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          floating: true,
          automaticallyImplyLeading: false,
        ),
        Obx(() {
          if (matchController.isLoading) {
            return const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (matchController.myMatches.isEmpty) {
            return SliverFillRemaining(
              child: _buildEmptyState(
                isDark,
                Icons.sports_cricket_outlined,
                'No matches yet',
                'Create your first match!',
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final match = matchController.myMatches[index];
              return _buildMatchListItem(match, isDark);
            }, childCount: matchController.myMatches.length),
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildMatchListItem(MatchModel match, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMatch(match),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B263B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getStatusColor(match.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.sports_cricket,
                        color: _getStatusColor(match.status),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${match.teamAName} vs ${match.teamBName}  •  ${match.totalOvers} overs',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(match.status),
                  ],
                ),

                // --- Quick Actions ---
                Builder(
                  builder: (context) {
                    final isAdmin =
                        authController.currentUser?.isAdmin ?? false;
                    final isScorer =
                        match.scorerIds.contains(authController.userId) ||
                        isAdmin;

                    if ((!isScorer || !match.isLive) && !isAdmin)
                      return const SizedBox.shrink();

                    return Column(
                      children: [
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isAdmin)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Match',
                                onPressed: () => _confirmDelete(match),
                              ),
                            if (isScorer && match.isLive)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        () => Get.to(
                                          () =>
                                              ScoringScreen(matchId: match.id),
                                        ),
                                    icon: const Icon(Icons.edit_note, size: 18),
                                    label: const Text('Add Score'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.vibrantOrange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Explore Tab ────────────────────────────────────
  Widget _buildExplore(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(
            'Explore',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          floating: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Get.toNamed(AppRoutes.matchHistory),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (authController.currentUser?.isAdmin == true) ...[
                  _buildQuickAction(
                    isDark,
                    Icons.add_circle_outline,
                    'Create Match',
                    'Set up a new box cricket match',
                    AppTheme.primaryGreen,
                    () => Get.toNamed(AppRoutes.createMatch),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildQuickAction(
                  isDark,
                  Icons.history,
                  'Match History',
                  'View past match results',
                  AppTheme.accentPurple,
                  () => Get.toNamed(AppRoutes.matchHistory),
                ),
                const SizedBox(height: 12),
                _buildQuickAction(
                  isDark,
                  Icons.group_work_outlined,
                  'Team Management',
                  'Create and manage your teams',
                  const Color(0xFF2196F3),
                  () => Get.toNamed(AppRoutes.teams),
                ),
                const SizedBox(height: 12),
                _buildQuickAction(
                  isDark,
                  Icons.leaderboard_outlined,
                  'Player Stats',
                  'Track player performance',
                  AppTheme.vibrantOrange,
                  () => Get.toNamed(AppRoutes.players),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Delete Confirmation Dialog ────────────────────────
  Future<void> _confirmDelete(MatchModel match) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Delete Match',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete this match permanently? This action cannot be undone and will erase all match logs and player stats associated with it.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await matchController.deleteMatch(match.id);
    }
  }

  Widget _buildQuickAction(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Profile Tab ────────────────────────────────────
  Widget _buildProfileTab(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(
            'Profile',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          floating: true,
          automaticallyImplyLeading: false,
        ),
        SliverToBoxAdapter(
          child: Obx(
            () => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              backgroundImage:
                                  authController.currentUser?.profileImageUrl !=
                                          null
                                      ? NetworkImage(
                                        authController
                                            .currentUser!
                                            .profileImageUrl!,
                                      )
                                      : null,
                              child:
                                  authController.currentUser?.profileImageUrl ==
                                          null
                                      ? Text(
                                        (authController.currentUser?.name ??
                                                'U')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authController.currentUser?.name ?? 'User',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    authController.currentUser?.phone ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (authController.currentUser?.role ??
                                              'player')
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (authController.currentUser?.isAdmin == true) ...[
                    _buildSettingItem(
                      isDark,
                      Icons.admin_panel_settings,
                      'Admin Dashboard',
                      onTap: () => Get.toNamed(AppRoutes.admin),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Settings options
                  _buildSettingItem(
                    isDark,
                    Icons.dark_mode,
                    'Dark Mode',
                    trailing: Obx(
                      () => Switch(
                        value: themeController.isDarkMode,
                        onChanged: (_) => themeController.toggleTheme(),
                        activeColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Sign out button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => authController.signOut(),
                      icon: const Icon(Icons.logout, color: AppTheme.wicketRed),
                      label: Text(
                        'Sign Out',
                        style: GoogleFonts.inter(
                          color: AppTheme.wicketRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.wicketRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Developed By XMARS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.withOpacity(0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    bool isDark,
    IconData icon,
    String title, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 22),
        title: Text(
          title,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────
  Widget _buildEmptyState(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'live':
        color = AppTheme.wicketRed;
        text = 'LIVE';
        break;
      case 'completed':
        color = AppTheme.primaryGreen;
        text = 'DONE';
        break;
      default:
        color = AppTheme.vibrantOrange;
        text = 'UPCOMING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'live':
        return AppTheme.wicketRed;
      case 'completed':
        return AppTheme.primaryGreen;
      default:
        return AppTheme.vibrantOrange;
    }
  }

  void _openMatch(MatchModel match) {
    // Tapping the card always goes to the spectator/details view.
    // Authorized users can access the ScoringScreen via the 'Add Score' button on the card.
    Get.to(() => MatchDetailScreen(matchId: match.id));
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
