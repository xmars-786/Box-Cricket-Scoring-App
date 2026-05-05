import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;
    final highlightColor = isDark ? const Color(0xFF334155) : Colors.grey[50]!;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      itemCount: 4,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Column(
              children: [
                // Header Shimmer
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Score Row Shimmer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTeamShimmer(),
                          Container(width: 40, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                          _buildTeamShimmer(),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Info Bar Shimmer
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamShimmer() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(height: 12),
        Container(
          width: 60,
          height: 12,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 10,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
        ),
      ],
    );
  }
}
