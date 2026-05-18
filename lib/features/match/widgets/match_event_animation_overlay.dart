import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/controllers/match_detail_controller.dart';
import '../../../core/theme/app_theme.dart';

class MatchEventAnimationOverlay extends StatelessWidget {
  final MatchDetailController controller = Get.find<MatchDetailController>();

  MatchEventAnimationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final type = controller.currentAnimation.value;
      if (type == null) return const SizedBox.shrink();

      return _buildAnimationBody(type);
    });
  }

  Widget _buildAnimationBody(String type) {
    Color primaryColor;
    String mainText;
    String subText;
    IconData icon;

    switch (type) {
      case 'six':
        primaryColor = const Color(0xFFFFD700); // Gold
        mainText = 'MASSIVE SIX!';
        subText = 'OUT OF THE PARK';
        icon = Icons.star_rounded;
        break;
      case 'four':
        primaryColor = AppTheme.primaryGreen;
        mainText = 'FANTASTIC FOUR!';
        subText = 'CRACKING BOUNDARY';
        icon = Icons.flash_on_rounded;
        break;
      case 'wicket':
        primaryColor = AppTheme.wicketRed;
        mainText = 'OUT!';
        subText = 'CRITICAL BREAKTHROUGH';
        icon = Icons.gavel_rounded;
        break;
      case 'wide':
        primaryColor = Colors.lightBlueAccent;
        mainText = 'WIDE BALL';
        subText = 'EXTRA RUN ADDED';
        icon = Icons.swap_horiz_rounded;
        break;
      case 'no_ball':
        primaryColor = Colors.orangeAccent;
        mainText = 'NO BALL!';
        subText = 'FREE HIT COMING?';
        icon = Icons.warning_amber_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Background Flash
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Container(
              color: primaryColor.withOpacity(0.1 * value),
            );
          },
        ),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withOpacity(0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E), // Dark background for contrast
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: primaryColor,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      mainText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: primaryColor,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
