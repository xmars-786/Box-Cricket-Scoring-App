import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class MOTMAwardCard extends StatelessWidget {
  final String playerName;
  final String? teamName;
  final String? playerImageUrl;
  final int runs;
  final int wickets;
  final int catches;
  final VoidCallback? onTap;
  final bool canEdit;

  const MOTMAwardCard({
    super.key,
    required this.playerName,
    this.teamName,
    this.playerImageUrl,
    required this.runs,
    required this.wickets,
    required this.catches,
    this.onTap,
    this.canEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [const Color(0xFFFF8F00), const Color(0xFFFF6F00)]
              : [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8F00).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Decorative Background elements
              Positioned(
                right: -30,
                bottom: -30,
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 200,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header Label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'MAN OF THE MATCH',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Player Avatar with Trophy Badge
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.orange[100],
                              backgroundImage: playerImageUrl != null && playerImageUrl!.isNotEmpty
                                  ? NetworkImage(playerImageUrl!)
                                  : null,
                              child: playerImageUrl == null || playerImageUrl!.isEmpty
                                  ? Text(
                                      playerName.isNotEmpty ? playerName[0].toUpperCase() : 'P',
                                      style: GoogleFonts.outfit(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFF8F00),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Color(0xFFFFD700),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Name and Team
                    Text(
                      playerName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (teamName != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          teamName!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Performance Stats
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(runs.toString(), 'RUNS'),
                          _buildStatDivider(),
                          _buildStatItem(wickets.toString(), 'WKTS'),
                          _buildStatDivider(),
                          _buildStatItem(catches.toString(), 'CTCH'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              if (canEdit)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }
}
