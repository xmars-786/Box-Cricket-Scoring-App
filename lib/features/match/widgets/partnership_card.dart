import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/partnership_model.dart';
import '../../../core/theme/app_theme.dart';

class PartnershipCard extends StatelessWidget {
  final PartnershipModel partnership;
  final bool isDark;

  const PartnershipCard({
    super.key,
    required this.partnership,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE PARTNERSHIP',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${partnership.wicketNumber}${_getOrdinal(partnership.wicketNumber)} Wicket',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildBatterSide(partnership.batterAName, partnership.batterARuns, partnership.batterABalls, false)),
              _buildCentralTotal(),
              Expanded(child: _buildBatterSide(partnership.batterBName, partnership.batterBRuns, partnership.batterBBalls, true)),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressBar(),
        ],
      ),
    );
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildBatterSide(String name, int runs, int balls, bool alignRight) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignRight) ...[
              Text(
                '($balls)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              '$runs',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            if (!alignRight) ...[
              const SizedBox(width: 4),
              Text(
                '($balls)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCentralTotal() {
    return Column(
      children: [
        Text(
          '${partnership.totalRuns}',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryGreen,
          ),
        ),
        Text(
          '${partnership.totalBalls} balls',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    double ratio = 0.5;
    if (partnership.totalRuns > 0) {
      ratio = partnership.batterARuns / (partnership.batterARuns + partnership.batterBRuns + 0.00001);
      // Clamp between 0.1 and 0.9 for visual balance
      if (ratio < 0.1) ratio = 0.1;
      if (ratio > 0.9) ratio = 0.9;
    }

    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 2,
                height: 6,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
