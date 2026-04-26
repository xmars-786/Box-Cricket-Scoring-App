import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/user_model.dart';
import '../../../core/models/player_stats_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import './player_profile_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDark ? AppTheme.primaryDark : const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          centerTitle: false,
          backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
          title: Text(
            'Player Stats',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          bottom: TabBar(
            isScrollable: false,
            indicatorColor: AppTheme.primaryGreen,
            indicatorWeight: 3,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black45,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            tabs: const [Tab(text: 'BATTING'), Tab(text: 'BOWLING')],
          ),
        ),
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection(AppConstants.usersCollection)
                    .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (userSnapshot.hasError) {
                return Center(child: Text('Error: ${userSnapshot.error}'));
              }

              return StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection(AppConstants.playerStatsCollection)
                        .snapshots(),
                builder: (context, statsSnapshot) {
                  if (statsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final statsMap = {
                    for (var doc in statsSnapshot.data?.docs ?? [])
                      doc.id: PlayerStatsModel.fromFirestore(doc),
                  };

                  final players =
                      (userSnapshot.data?.docs ?? []).map((doc) {
                        final user = AppUser.fromFirestore(doc);
                        final stats =
                            statsMap[user.uid] ??
                            PlayerStatsModel(uid: user.uid);
                        return PlayerWithStats(user: user, stats: stats);
                      }).toList();

                  if (players.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  return TabBarView(
                    children: [
                      _buildBattingTab(players, isDark),
                      _buildBowlingTab(players, isDark),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBattingTab(List<PlayerWithStats> players, bool isDark) {
    final sortedPlayers = List<PlayerWithStats>.from(players)
      ..sort((a, b) => b.stats.runs.compareTo(a.stats.runs));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedPlayers.length,
      itemBuilder: (context, index) {
        final item = sortedPlayers[index];
        return _buildPlayerListItem(item, 'batting', isDark, index + 1);
      },
    );
  }

  Widget _buildBowlingTab(List<PlayerWithStats> players, bool isDark) {
    final sortedPlayers = List<PlayerWithStats>.from(players)
      ..sort((a, b) => b.stats.wickets.compareTo(a.stats.wickets));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedPlayers.length,
      itemBuilder: (context, index) {
        final item = sortedPlayers[index];
        return _buildPlayerListItem(item, 'bowling', isDark, index + 1);
      },
    );
  }

  Widget _buildPlayerListItem(
    PlayerWithStats item,
    String type,
    bool isDark,
    int rank,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Get.to(() => PlayerProfileScreen(playerWithStats: item)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Rank and Avatar
              SizedBox(
                width: 30,
                child: Text(
                  '#$rank',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    color:
                        rank <= 3
                            ? AppTheme.primaryGreen
                            : (isDark ? Colors.white24 : Colors.black12),
                    fontSize: 14,
                  ),
                ),
              ),
              Hero(
                tag: 'player_avatar_${item.user.uid}',
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                  foregroundImage:
                      item.user.profileImageUrl != null &&
                              item.user.profileImageUrl!.isNotEmpty
                          ? NetworkImage(item.user.profileImageUrl!)
                          : null,
                  child: Text(
                    item.user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and Stats Preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.user.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatStrip(item.stats, type, isDark),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatStrip(PlayerStatsModel stats, String type, bool isDark) {
    final color = isDark ? Colors.white60 : Colors.black54;
    final style = GoogleFonts.inter(
      fontSize: 11,
      color: color,
      fontWeight: FontWeight.w500,
    );

    if (type == 'batting') {
      return Row(
        children: [
          _statText('Mat: ${stats.matches}', style),
          _divider(isDark),
          _statText('Runs: ${stats.runs}', style, isBold: true),
          _divider(isDark),
          _statText('Avg: ${stats.battingAverage.toStringAsFixed(2)}', style),
        ],
      );
    } else {
      return Row(
        children: [
          _statText('Mat: ${stats.matches}', style),
          _divider(isDark),
          _statText('Wkts: ${stats.wickets}', style, isBold: true),
          _divider(isDark),
          _statText('Eco: ${stats.economy.toStringAsFixed(2)}', style),
        ],
      );
    }
  }

  Widget _statText(String text, TextStyle style, {bool isBold = false}) {
    return Text(
      text,
      style:
          isBold
              ? style.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              )
              : style,
    );
  }

  Widget _divider(bool isDark) {
    return Container(
      height: 10,
      width: 1,
      color: isDark ? Colors.white10 : Colors.black12,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: isDark ? Colors.white10 : Colors.grey[200],
          ),
          const SizedBox(height: 16),
          Text(
            'No players found',
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerWithStats {
  final AppUser user;
  final PlayerStatsModel stats;
  PlayerWithStats({required this.user, required this.stats});
}
