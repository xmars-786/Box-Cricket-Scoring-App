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
import '../../match/widgets/match_card_widget.dart';
import '../../scoring/screens/scoring_screen.dart';
import '../../../core/constants/app_constants.dart';

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
  final ScrollController _myMatchesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _myMatchesScrollController.addListener(_onHistoryScroll);
  }

  void _onHistoryScroll() {
    if (_myMatchesScrollController.position.pixels >=
        _myMatchesScrollController.position.maxScrollExtent - 200) {
      matchController.loadCompletedMatches();
    }
  }

  void _loadData() {
    matchController.listenToLiveMatches();
    matchController.loadCompletedMatches(refresh: true);
    if (authController.userId != null) {
      matchController.loadMyMatches(authController.userId!, refresh: true);
    }
  }

  @override
  void dispose() {
    _myMatchesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Obx(
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
                    _buildMatchHistory(isDark),
                    _buildExplore(isDark),
                    _buildProfileTab(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B263B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 64,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            indicatorColor: AppTheme.primaryGreen.withOpacity(0.1),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _buildNavDestination(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Home',
                isSelected: _currentIndex == 0,
              ),
              _buildNavDestination(
                icon: Icons.history_rounded,
                activeIcon: Icons.history_edu_rounded,
                label: 'History',
                isSelected: _currentIndex == 1,
              ),
              _buildNavDestination(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Explore',
                isSelected: _currentIndex == 2,
              ),
              _buildNavDestination(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: _currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton:
          _currentIndex <= 1 &&
                  (authController.currentUser?.isAdmin ?? false) &&
                  matchController.liveMatches.isEmpty
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
    return RefreshIndicator(
      onRefresh: () async {
        matchController.listenToLiveMatches();
        await matchController.loadCompletedMatches(refresh: true);
      },
      color: AppTheme.wicketRed,
      child: CustomScrollView(
        physics:
            matchController.liveMatches.isEmpty
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
        slivers: [
          // App bar with gradient
          SliverAppBar(
            expandedHeight: 160,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isDark
                            ? [const Color(0xFF0D1B2A), const Color(0xFF1B263B)]
                            : [AppTheme.primaryGreen, const Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.sports_cricket_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  AppConstants.appName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Spacer(),
                                _buildHeaderAction(
                                  icon:
                                      themeController.isDarkMode
                                          ? Icons.light_mode_rounded
                                          : Icons.dark_mode_rounded,
                                  onPressed: themeController.toggleTheme,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'WELCOME BACK',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white.withOpacity(0.6),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Obx(
                                        () => Text(
                                          authController.currentUser?.name ??
                                              'Player',
                                          style: GoogleFonts.outfit(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildLiveStatusIndicator(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Live Matches List
          Obx(() {
            if (matchController.liveMatches.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(
                  isDark,
                  Icons.sensors_off_rounded,
                  'No live matches at the moment',
                  'Check back later or create a new match to go live!',
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
      ),
    );
  }

  // ─── Live Match Card ────────────────────────────────
  Widget _buildLiveMatchCard(MatchModel match, bool isDark) {
    final isAdmin = authController.currentUser?.isAdmin ?? false;
    final isScorer = match.scorerIds.contains(authController.userId) || isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MatchCardWidget(
        match: match,
        isDark: isDark,
        isAdmin: isAdmin,
        isScorer: isScorer,
        onDelete: () => _confirmDelete(match),
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

  Widget _buildMatchHistory(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        await matchController.loadCompletedMatches(refresh: true);
      },
      color: AppTheme.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _myMatchesScrollController,
        slivers: [
          SliverAppBar(
            title: Text(
              'Match History',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            floating: true,
            automaticallyImplyLeading: false,
          ),
          Obx(() {
            if (matchController.isHistoryLoading &&
                matchController.completedMatches.isEmpty) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (matchController.completedMatches.isEmpty) {
              return SliverFillRemaining(
                child: _buildEmptyState(
                  isDark,
                  Icons.history_rounded,
                  'No match history',
                  'Completed matches will appear here!',
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index < matchController.completedMatches.length) {
                  final match = matchController.completedMatches[index];
                  return _buildMatchListItem(match, isDark);
                } else {
                  if (matchController.hasMoreHistory) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const SizedBox(height: 80);
                }
              }, childCount: matchController.completedMatches.length + 1),
            );
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMatchListItem(MatchModel match, bool isDark) {
    final isAdmin = authController.currentUser?.isAdmin ?? false;
    final isScorer = match.scorerIds.contains(authController.userId) || isAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MatchCardWidget(
        match: match,
        isDark: isDark,
        isAdmin: isAdmin,
        isScorer: isScorer,
        onDelete: () => _confirmDelete(match),
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
                Obx(() {
                  final hasLiveMatch = matchController.liveMatches.isNotEmpty;
                  if (authController.currentUser?.isAdmin == true &&
                      !hasLiveMatch) {
                    return Column(
                      children: [
                        _buildQuickAction(
                          isDark,
                          Icons.add_circle_outline,
                          'Create Match',
                          'Set up a new cricket match',
                          AppTheme.primaryGreen,
                          () => Get.toNamed(AppRoutes.createMatch),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  if (hasLiveMatch &&
                      authController.currentUser?.isAdmin == true) {
                    return Column(
                      children: [
                        _buildQuickAction(
                          isDark,
                          Icons.sensors,
                          'Match Live',
                          'A match is currently in progress',
                          AppTheme.wicketRed.withOpacity(0.7),
                          () => setState(
                            () => _currentIndex = 0,
                          ), // Switch to Dashboard tab
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),
                _buildQuickAction(
                  isDark,
                  Icons.history,
                  'Match History',
                  'View past match results',
                  AppTheme.accentPurple,
                  () => Get.toNamed(AppRoutes.matchHistory),
                ),
                const SizedBox(height: 12),
                if (authController.currentUser?.isAdmin == true) ...[
                  _buildQuickAction(
                    isDark,
                    Icons.group_work_outlined,
                    'Team Management',
                    'Create and manage your teams',
                    const Color(0xFF2196F3),
                    () => Get.toNamed(AppRoutes.teams),
                  ),
                  const SizedBox(height: 12),
                ],
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
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          floating: true,
          pinned: true,
          centerTitle: false,
          automaticallyImplyLeading: false,
          backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
          actions: [
            IconButton(
              onPressed: () => authController.signOut(),
              icon: const Icon(Icons.logout_rounded, color: AppTheme.wicketRed),
              tooltip: 'Sign Out',
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Obx(() {
            final user = authController.currentUser;
            if (user == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Compact Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryGreen,
                          AppTheme.primaryGreen.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.white,
                                foregroundImage:
                                    user.profileImageUrl != null &&
                                            user.profileImageUrl!.isNotEmpty
                                        ? NetworkImage(user.profileImageUrl!)
                                        : null,
                                child: Text(
                                  user.name.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    user.phone.isNotEmpty
                                        ? user.phone
                                        : user.email,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user.role.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Compact Stats Row
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildProfileStat(
                                'Matches',
                                user.matchesPlayed.toString(),
                              ),
                              _buildStatDivider(),
                              _buildProfileStat(
                                'Runs',
                                user.totalRuns.toString(),
                              ),
                              _buildStatDivider(),
                              _buildProfileStat(
                                'Wickets',
                                user.totalWickets.toString(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settings Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'ACCOUNT SETTINGS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark
                                  ? Colors.white30
                                  : Colors.black.withOpacity(0.3),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (user.isAdmin) ...[
                    _buildSettingItem(
                      isDark,
                      Icons.admin_panel_settings_rounded,
                      'Admin Dashboard',
                      onTap: () => Get.toNamed(AppRoutes.admin),
                    ),
                    const SizedBox(height: 8),
                  ],

                  _buildSettingItem(
                    isDark,
                    Icons.dark_mode_rounded,
                    'Dark Mode',
                    trailing: Switch(
                      value: themeController.isDarkMode,
                      onChanged: (_) => themeController.toggleTheme(),
                      activeColor: AppTheme.primaryGreen,
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    '${AppConstants.developedBy} ${AppConstants.appVersion}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white10 : Colors.black12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: Colors.white24);
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

  Widget _buildNavDestination({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    return NavigationDestination(
      icon: Icon(icon, size: 24, color: Colors.grey),
      selectedIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(activeIcon, size: 24, color: AppTheme.primaryGreen),
      ),
      label: label,
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildLiveStatusIndicator() {
    return Obx(() {
      final isLive = matchController.liveMatches.isNotEmpty;
      if (!isLive) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    });
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
