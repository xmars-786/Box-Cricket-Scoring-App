import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/controllers/tournament_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/models/tournament_model.dart';

class TournamentListScreen extends StatelessWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tournamentController = Get.find<TournamentController>();
    final authController = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tournaments',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (authController.currentUser?.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => Get.toNamed(AppRoutes.createTournament),
            ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (tournamentController.tournaments.isEmpty) {
            return _buildEmptyState(isDark);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tournamentController.tournaments.length,
            itemBuilder: (context, index) {
              final tournament = tournamentController.tournaments[index];
              return _buildTournamentCard(context, tournament, isDark);
            },
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No tournaments yet',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a tournament to organize matches!',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(
    BuildContext context,
    TournamentModel tournament,
    bool isDark,
  ) {
    final status = tournament.status;
    final color = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B263B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap:
              () => Get.toNamed(
                AppRoutes.tournamentDetail,
                arguments: tournament.id,
              ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left accent bar with gradient
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color,
                        color.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusBadge(status),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tournament.type.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tournament.name,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color:
                                isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                size: 12,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${tournament.teamIds.length} Teams Competing',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOURNAMENT WINDOW',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${DateFormat('MMM dd').format(tournament.startDate)} — ${DateFormat('MMM dd, yyyy').format(tournament.endDate)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return AppTheme.primaryGreen;
      case 'ongoing':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      case 'closed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'live':
        color = AppTheme.primaryGreen;
        icon = Icons.sensors_rounded;
        break;
      case 'ongoing':
        color = Colors.orange;
        icon = Icons.play_arrow_rounded;
        break;
      case 'completed':
        color = Colors.grey;
        icon = Icons.check_circle_rounded;
        break;
      case 'closed':
        color = Colors.red;
        icon = Icons.block_rounded;
        break;
      default:
        color = Colors.blue;
        icon = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
