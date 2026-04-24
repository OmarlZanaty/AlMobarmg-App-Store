import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../theme.dart';

enum SecurityBadgeSize { compact, large }

class SecurityBadge extends StatelessWidget {
  const SecurityBadge({
    super.key,
    required this.score,
    required this.aiHint,
    this.size = SecurityBadgeSize.compact,
  });

  final int score;
  final String aiHint;
  final SecurityBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final isLarge = size == SecurityBadgeSize.large;
    final color = scoreColor(score);
    final radius = isLarge ? 52.0 : 30.0;
    final lineWidth = isLarge ? 10.0 : 6.0;

    return Tooltip(
      message: aiHint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.08),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, spreadRadius: 1)],
            ),
            padding: const EdgeInsets.all(4),
            child: CircularPercentIndicator(
              radius: radius,
              lineWidth: lineWidth,
              percent: score.clamp(0, 100) / 100,
              animation: true,
              animationDuration: 900,
              progressColor: color,
              backgroundColor: color.withOpacity(0.12),
              center: Text(
                '$score',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isLarge ? 28 : 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            scoreLabel(score),
            style: GoogleFonts.plusJakartaSans(
              fontSize: isLarge ? 14 : 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
