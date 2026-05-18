import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/theme_controller.dart';
import '../../../core/controllers/connectivity_controller.dart';
import '../../../core/controllers/rules_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/models/match_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../history/widgets/match_history_card.dart';
import '../../match/screens/match_detail_screen.dart';
import '../../match/widgets/match_card_widget.dart';
import '../../match/utils/match_dialogs.dart';
import '../../explore/controllers/player_profile_controller.dart';
import '../widgets/pwa_install_banner.dart';

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
  final RulesController rulesController = Get.find<RulesController>();
  final ScrollController _myMatchesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Initialize profile stats for current user IMMEDIATELY to avoid build-time errors
    final userId = authController.userId;
    if (userId != null) {
      Get.put(PlayerProfileController(playerId: userId), tag: 'home_profile');
    }

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
      extendBody: true,
      body: SafeArea(
        bottom: false,
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
              const PwaInstallBanner(),
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
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1B263B).withOpacity(0.65)
                          : Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.05),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFloatingNavItem(
                      0,
                      Icons.home_outlined,
                      Icons.home_rounded,
                      'Home',
                      isDark,
                    ),
                    _buildFloatingNavItem(
                      1,
                      Icons.history_outlined,
                      Icons.history_rounded,
                      'History',
                      isDark,
                    ),
                    _buildFloatingNavItem(
                      2,
                      Icons.explore_outlined,
                      Icons.explore_rounded,
                      'Explore',
                      isDark,
                    ),
                    _buildFloatingNavItem(
                      3,
                      Icons.person_outline_rounded,
                      Icons.person_rounded,
                      'Profile',
                      isDark,
                    ),
                  ],
                ),
              ),
            ),
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
        final userId = authController.userId;
        if (userId != null &&
            Get.isRegistered<PlayerProfileController>(tag: 'home_profile')) {
          await Get.find<PlayerProfileController>(
            tag: 'home_profile',
          ).onRefresh();
        }
      },
      color: AppTheme.wicketRed,
      child: CustomScrollView(
        physics:
            matchController.liveMatches.isEmpty
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Modern Header
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isDark
                            ? [const Color(0xFF0D1B2A), const Color(0xFF1B263B)]
                            : [
                              const Color(0xFFFFFFFF),
                              const Color(0xFFF1F5F9),
                            ], // Adaptive premium gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Dynamic curves / decorative circles
                    Positioned(
                      top: -60,
                      right: -30,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isDark
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.black.withOpacity(0.03),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.02),
                            width: 20,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.sports_cricket_rounded,
                                      color: AppTheme.primaryGreen,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppConstants.appName.toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF1A1A2E),
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                _buildHeaderAction(
                                  icon:
                                      themeController.isDarkMode
                                          ? Icons.light_mode_rounded
                                          : Icons.dark_mode_rounded,
                                  onPressed: themeController.toggleTheme,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'WELCOME BACK,',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryGreen,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Obx(
                              () => Text(
                                authController.currentUser?.name ?? 'Player',
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1A2E),
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Quick Actions Section
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'QUICK ACTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white54 : Colors.black54,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActions(isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Live Matches Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Obx(() {
                    final liveMatches = matchController.liveMatches;
                    final totalWatchers = liveMatches.fold(
                      0,
                      (sum, m) => sum + m.viewerCount,
                    );
                    return Text(
                      'LIVE MATCHES (${liveMatches.length}) ${totalWatchers > 0 ? "• $totalWatchers WATCHING" : ""}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 1.5,
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
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
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(
                  isDark,
                  Icons.sports_cricket_outlined,
                  'No live matches at the moment',
                  '',
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

  // ─── Quick Actions ──────────────────────────────────
  Widget _buildQuickActions(bool isDark) {
    return SizedBox(
      height: 115,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (authController.currentUser?.isAdmin ?? false)
            _buildQuickActionCard(
              title: 'New Match',
              icon: Icons.add_circle_rounded,
              color: AppTheme.vibrantOrange,
              onTap: () => Get.toNamed(AppRoutes.createMatch),
              isDark: isDark,
            ),
          _buildQuickActionCard(
            title: 'Tournaments',
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFF1C40F),
            onTap: () => Get.toNamed(AppRoutes.tournaments),
            isDark: isDark,
          ),

          _buildQuickActionCard(
            title: 'Leaderboard',
            icon: Icons.leaderboard_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => Get.toNamed(AppRoutes.players),
            isDark: isDark,
          ),

          _buildQuickActionCard(
            title: 'Hot Records',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFE74C3C),
            onTap: () => Get.toNamed(AppRoutes.hotRecord),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B263B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.05 : 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
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
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.primaryDark,
              ),
            ),
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
            automaticallyImplyLeading: false,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color:
                      isDark
                          ? const Color(0xFF0D1B2A).withOpacity(0.8)
                          : Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MatchHistoryCard(
        match: match,
        isDark: isDark,
        isAdmin: isAdmin,
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
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.primaryDark,
            ),
          ),
          pinned: true,
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
          automaticallyImplyLeading: false,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color:
                    isDark
                        ? const Color(0xFF0D1B2A).withOpacity(0.8)
                        : Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          actions: [
            // IconButton(
            //   icon: const Icon(Icons.history),
            //   onPressed: () => Get.toNamed(AppRoutes.matchHistory),
            // ),
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
                // Tournament Access (Role-based)
                Obx(() {
                  if (!rulesController.isTournamentEnabled.value)
                    return const SizedBox.shrink();

                  final isAdmin = authController.currentUser?.isAdmin ?? false;
                  return Column(
                    children: [
                      _buildQuickAction(
                        isDark,
                        Icons.emoji_events_outlined,
                        isAdmin ? 'Tournament Management' : 'Tournaments',
                        isAdmin
                            ? 'Organize leagues and knockouts'
                            : 'Explore active tournaments and rankings',
                        Colors.amber,
                        () => Get.toNamed(AppRoutes.tournaments),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
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
                  _buildQuickAction(
                    isDark,
                    Icons.auto_fix_high_rounded,
                    'Repair Match Results',
                    'Fix incorrect win/loss margins in history',
                    Colors.deepPurple,
                    () => matchController.repairAllCompletedMatchResults(),
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
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ─── Delete Confirmation Dialog ────────────────────────
  Future<void> _confirmDelete(MatchModel match) async {
    final confirm = await MatchDialogs.showDeleteMatchDialog(context);

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
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () {
                  final userId = authController.userId;
                  if (userId != null &&
                      Get.isRegistered<PlayerProfileController>(
                        tag: 'home_profile',
                      )) {
                    final profileCtrl = Get.find<PlayerProfileController>(
                      tag: 'home_profile',
                    );
                    profileCtrl.fetchUser();
                    profileCtrl.onRefresh();

                    Get.snackbar(
                      'Refreshing',
                      'Updating profile data...',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: isDark ? Colors.white12 : Colors.black87,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 2),
                      margin: const EdgeInsets.all(16),
                    );
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                  foregroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 22),
                tooltip: 'Reload Profile',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () {
                  Get.dialog(
                    Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1B263B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black54 : Colors.black12,
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.wicketRed.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.power_settings_new_rounded,
                                color: AppTheme.wicketRed,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Sign Out',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Are you sure you want to log out of your account?',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Get.back(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Get.back();
                                      authController.signOut();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.wicketRed,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Logout',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.wicketRed.withOpacity(0.1),
                  foregroundColor: AppTheme.wicketRed,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.power_settings_new_rounded, size: 22),
                tooltip: 'Sign Out',
              ),
            ),
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap:
                                            () => _showEditNameDialog(
                                              context,
                                              user.name,
                                              isDark,
                                            ),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
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
                          child: Obx(() {
                            // Safety check for initialization
                            if (!Get.isRegistered<PlayerProfileController>(
                              tag: 'home_profile',
                            )) {
                              return const SizedBox(height: 40);
                            }

                            final profileCtrl =
                                Get.find<PlayerProfileController>(
                                  tag: 'home_profile',
                                );

                            final stats = profileCtrl.aggregatedStats.value;
                            final bool isStillLoading =
                                profileCtrl.isLoading.value && stats == null;

                            if (isStillLoading) {
                              return const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildProfileStat(
                                  'Matches',
                                  stats?.matches.toString() ?? '0',
                                ),
                                _buildStatDivider(),
                                _buildProfileStat(
                                  'Runs',
                                  stats?.runs.toString() ?? '0',
                                ),
                                _buildStatDivider(),
                                _buildProfileStat(
                                  'Wickets',
                                  stats?.wickets.toString() ?? '0',
                                ),
                                _buildStatDivider(),
                                _buildHotRecordStat(isDark),
                              ],
                            );
                          }),
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
                    _buildSettingItem(
                      isDark,
                      Icons.emoji_events_rounded,
                      'Tournament Mode',
                      trailing: Obx(
                        () => Switch(
                          value: rulesController.isTournamentEnabled.value,
                          onChanged:
                              (val) => rulesController.updateRules(
                                tournamentEnabled: val,
                              ),
                          activeColor: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  _buildThemeSelector(isDark),

                  const SizedBox(height: 12),

                  // Delete Account
                  Obx(() {
                    if (rulesController.isApkApproved.value) {
                      return const SizedBox.shrink();
                    }

                    return Center(
                      child: TextButton(
                        onPressed: () {
                          Get.dialog(
                            AlertDialog(
                              backgroundColor:
                                  isDark
                                      ? const Color(0xFF1B263B)
                                      : Colors.white,
                              title: Text(
                                'Delete Account',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to delete your account? This action is permanent and all your data will be lost.',
                                style: GoogleFonts.inter(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Get.back();
                                    authController.deleteAccount();
                                  },
                                  child: Text(
                                    'Delete',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.wicketRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          'Delete Account',
                          style: GoogleFonts.inter(
                            color: AppTheme.wicketRed.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 100),
                ],
              ),
            );
          }),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  Widget _buildHotRecordStat(bool isDark) {
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.hotRecord),
      child: Column(
        children: [
          const Icon(Icons.whatshot_rounded, color: Colors.orange, size: 24),
          const SizedBox(height: 2),
          Text(
            'HOT RECORD',
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
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: Colors.white24);
  }

  Widget _buildThemeSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF253750) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 12),
              Text(
                'APPEARANCE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white54 : Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Obx(
              () => Row(
                children: [
                  _buildThemeOption(
                    ThemeMode.system,
                    'System',
                    Icons.settings_suggest_rounded,
                    isDark,
                  ),
                  _buildThemeOption(
                    ThemeMode.light,
                    'Light',
                    Icons.light_mode_rounded,
                    isDark,
                  ),
                  _buildThemeOption(
                    ThemeMode.dark,
                    'Dark',
                    Icons.dark_mode_rounded,
                    isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    ThemeMode mode,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = themeController.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => themeController.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    isSelected
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color:
                      isSelected
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildFloatingNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    bool isDark,
  ) {
    final isSelected = _currentIndex == index;
    final activeColor = AppTheme.primaryGreen;
    final inactiveColor = isDark ? Colors.white54 : Colors.grey[500];

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 3) {
          final userId = authController.userId;
          if (userId != null &&
              Get.isRegistered<PlayerProfileController>(tag: 'home_profile')) {
            Get.find<PlayerProfileController>(tag: 'home_profile').onRefresh();
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder:
                  (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onPressed,
    bool isDark = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          size: 20,
        ),
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
              textAlign: TextAlign.center,
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

  void _showEditNameDialog(
    BuildContext context,
    String currentName,
    bool isDark,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B263B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black54 : Colors.black12,
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Name',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: GoogleFonts.inter(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black12 : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        if (newName.isNotEmpty && newName != currentName) {
                          Get.back();
                          Get.dialog(
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            barrierDismissible: false,
                          );
                          await authController.updateProfile(name: newName);
                          Get.back(); // close loading

                          if (Get.isRegistered<PlayerProfileController>(
                            tag: 'home_profile',
                          )) {
                            Get.find<PlayerProfileController>(
                              tag: 'home_profile',
                            ).fetchUser();
                          }

                          Get.snackbar(
                            'Success',
                            'Name updated successfully',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: AppTheme.primaryGreen,
                            colorText: Colors.white,
                            margin: const EdgeInsets.all(16),
                            borderRadius: 12,
                          );
                        } else {
                          Get.back();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
