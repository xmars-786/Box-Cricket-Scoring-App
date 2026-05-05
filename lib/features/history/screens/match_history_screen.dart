import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'dart:ui';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/match_model.dart';
import '../widgets/match_history_card.dart';
import '../widgets/history_filter_sheet.dart';
import '../widgets/history_skeleton.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final MatchController matchController = Get.find<MatchController>();
  final AuthController authController = Get.find<AuthController>();
  final ScrollController _scrollController = ScrollController();

  String? _status = AppConstants.matchCompleted;
  bool? _isTournament;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      matchController.loadCompletedMatches(refresh: true, status: _status);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      matchController.loadCompletedMatches();
    }
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => HistoryFilterSheet(
            initialStatus: _status,
            initialIsTournament: _isTournament,
            initialStartDate: _startDate,
            initialEndDate: _endDate,
          ),
    );

    if (result != null) {
      setState(() {
        _status = result['status'];
        _isTournament = result['isTournament'];
        _startDate = result['startDate'];
        _endDate = result['endDate'];
      });
      _refreshList();
    }
  }

  void _refreshList() {
    matchController.loadCompletedMatches(
      refresh: true,
      status: _status,
      isTournament: _isTournament,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF070B14) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Premium Background Gradients
          if (isDark) ...[
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryGreen.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => _refreshList(),
              color: AppTheme.primaryGreen,
              displacement: 60,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  _buildPremiumHeader(isDark),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSearchAndFilterRow(isDark),
                        ),
                        const SizedBox(height: 24),
                        _buildScrollableStatsRow(isDark),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  _buildActiveFiltersSliver(isDark),

                  Obx(() {
                    if (matchController.isHistoryLoading &&
                        matchController.completedMatches.isEmpty) {
                      return const SliverToBoxAdapter(child: HistorySkeleton());
                    }

                    if (matchController.error != null &&
                        matchController.completedMatches.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildErrorView(isDark),
                      );
                    }

                    final matches =
                        matchController.completedMatches.where((m) {
                          if (_searchQuery.isEmpty) return true;
                          final query = _searchQuery.toLowerCase();
                          return m.title.toLowerCase().contains(query) ||
                              m.teamAName.toLowerCase().contains(query) ||
                              m.teamBName.toLowerCase().contains(query);
                        }).toList();

                    if (matches.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyView(isDark),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index < matches.length) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: MatchHistoryCard(
                                  match: matches[index],
                                  isDark: isDark,
                                  isAdmin:
                                      authController.currentUser?.isAdmin ??
                                      false,
                                  onDelete:
                                      () => _confirmDelete(matches[index]),
                                ),
                              );
                            } else {
                              return _buildBottomLoader();
                            }
                          },
                          childCount:
                              matches.length +
                              (matchController.hasMoreHistory ? 1 : 0),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(bool isDark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor:
          isDark
              ? const Color(0xFF070B14).withOpacity(0.9)
              : const Color(0xFFF8FAFC).withOpacity(0.9),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onPressed: () => Get.back(),
      ),
      title: Text(
        'Match History',
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
          letterSpacing: 0.5,
        ),
      ),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A2A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search teams or venue...',
                hintStyle: GoogleFonts.outfit(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white54 : Colors.black54,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _showFilterSheet,
          child: Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableStatsRow(bool isDark) {
    final matches = matchController.completedMatches;
    final total = matchController.completedMatches.length;
    final live = matches.where((m) => m.isLive).length;
    final tourney = matches.where((m) => m.tournamentId != null).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            'TOTAL MATCHES',
            '$total',
            Icons.sports_cricket_rounded,
            Colors.blueAccent,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'LIVE NOW',
            '$live',
            Icons.sensors_rounded,
            const Color(0xFFEF4444),
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'TOURNAMENTS',
            '$tourney',
            Icons.emoji_events_rounded,
            Colors.amber,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
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
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersSliver(bool isDark) {
    bool hasFilters =
        _status != AppConstants.matchCompleted ||
        _isTournament != null ||
        _startDate != null;

    if (!hasFilters) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              if (_status != null)
                _buildFilterChip(
                  _status!.toUpperCase(),
                  () => setState(() {
                    _status = null;
                    _refreshList();
                  }),
                  isDark,
                ),
              if (_isTournament != null)
                _buildFilterChip(
                  _isTournament! ? 'TOURNAMENT' : 'SINGLE',
                  () => setState(() {
                    _isTournament = null;
                    _refreshList();
                  }),
                  isDark,
                ),
              if (_startDate != null)
                _buildFilterChip(
                  'DATE FILTER',
                  () => setState(() {
                    _startDate = null;
                    _endDate = null;
                    _refreshList();
                  }),
                  isDark,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onClear, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLoader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A2A) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Matches Found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _status = AppConstants.matchCompleted;
                _isTournament = null;
                _startDate = null;
                _endDate = null;
                _searchController.clear();
                _searchQuery = '';
              });
              matchController.loadCompletedMatches(clearFilters: true);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'RESET FILTERS',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load History',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshList,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('RETRY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(MatchModel match) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Delete Match?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'This will permanently remove this match record and revert its statistics.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'DELETE',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await matchController.deleteMatch(match.id);
    }
  }
}
