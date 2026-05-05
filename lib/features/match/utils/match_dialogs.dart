import 'package:x_cricket/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../../../core/models/match_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/controllers/match_controller.dart';
import '../../../core/controllers/auth_controller.dart';
import '../../../core/controllers/scoring_controller.dart';
import '../../../core/utils/ui_utils.dart';
import '../../scoring/screens/scoring_screen.dart';

class MatchDialogs {
  MatchDialogs._();

  static void showRematchDialog(BuildContext context, MatchModel match) {
    String tossWonBy = 'A';
    String tossDecision = 'bat';

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B263B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rematch Toss',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new match with same teams and rules.',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Who won the toss?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTossChoice(
                          match.teamAName,
                          'A',
                          tossWonBy == 'A',
                          () => setModalState(() => tossWonBy = 'A'),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTossChoice(
                          match.teamBName,
                          'B',
                          tossWonBy == 'B',
                          () => setModalState(() => tossWonBy = 'B'),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Winner elected to?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTossChoice(
                          'BAT',
                          'bat',
                          tossDecision == 'bat',
                          () => setModalState(() => tossDecision = 'bat'),
                          isDark,
                          icon: Icons.sports_cricket,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTossChoice(
                          'BOWL',
                          'bowl',
                          tossDecision == 'bowl',
                          () => setModalState(() => tossDecision = 'bowl'),
                          isDark,
                          icon: Icons.sports_baseball,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed:
                          () => _executeRematch(match, tossWonBy, tossDecision),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'START REMATCH',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  static Widget _buildTossChoice(
    String label,
    String value,
    bool isSelected,
    VoidCallback onTap,
    bool isDark, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryGreen.withOpacity(0.1)
                  : (isDark
                      ? const Color(0xFF253750)
                      : const Color(0xFFF0F2F5)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryGreen : Colors.grey,
                size: 18,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color:
                    isSelected
                        ? AppTheme.primaryGreen
                        : (isDark ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _executeRematch(
    MatchModel match,
    String tossWonBy,
    String tossDecision,
  ) async {
    try {
      Get.back(); // Close bottom sheet

      final matchController = Get.find<MatchController>();
      final authController = Get.find<AuthController>();

      UIUtils.showLoading('Setting up rematch...');

      final newMatchId = await matchController.performRematch(
        match: match,
        tossWonBy: tossWonBy,
        tossDecision: tossDecision,
        currentUserId: authController.userId!,
      );

      Get.back(); // Hide loading

      if (newMatchId != null) {
        // Navigate to new scoring screen and remove old one from stack
        Get.offNamed(
          AppRoutes.scoring,
          arguments: newMatchId,
          preventDuplicates: false,
        );
        UIUtils.showSuccess('Rematch started!');
      }
    } catch (e) {
      Get.back(); // Hide loading
      UIUtils.showError('Failed to start rematch: $e');
    }
  }

  static Future<bool?> showDeleteMatchDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Match',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to delete this match permanently? This action cannot be undone and will erase all match logs and player stats associated with it.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
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
  }
}
