import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

enum SecurityBadgeSize { compact, large }

class SecurityBadge extends StatefulWidget {
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
  State<SecurityBadge> createState() => _SecurityBadgeState();
}

class _SecurityBadgeState extends State<SecurityBadge> {
  @override
  Widget build(BuildContext context) {
    final isLarge = widget.size == SecurityBadgeSize.large;
    final radius = isLarge ? 50.0 : 28.0;
    final lineWidth = isLarge ? 10.0 : 6.0;

    return Tooltip(
      message: widget.aiHint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularPercentIndicator(
            radius: radius,
            lineWidth: lineWidth,
            percent: (widget.score.clamp(0, 100) / 100),
            animation: true,
            animationDuration: 900,
            progressColor: _scoreColor(widget.score),
            center: Text(
              '${widget.score}',
              style: TextStyle(
                fontSize: isLarge ? 28 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _riskLabel(widget.score),
            style: TextStyle(
              fontSize: isLarge ? 14 : 11,
              color: _scoreColor(widget.score),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _riskLabel(int score) {
    if (score >= 85) return 'SAFE';
    if (score >= 65) return 'LOW RISK';
    if (score >= 45) return 'CAUTION';
    if (score >= 25) return 'RISKY';
    return 'DANGEROUS';
  }

  Color _scoreColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 65) return Colors.blue;
    if (score >= 45) return Colors.amber.shade700;
    if (score >= 25) return Colors.red;
    return Colors.red.shade900;
  }
}
