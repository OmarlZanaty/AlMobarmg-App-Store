import 'package:flutter/material.dart';

class PlatformChips extends StatelessWidget {
  const PlatformChips({
    super.key,
    required this.platforms,
    this.compact = false,
  });

  final List<String> platforms;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (platforms.isEmpty) {
      return const SizedBox.shrink();
    }

    final normalized = platforms
        .map((p) => _normalize(p))
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: normalized.map((platform) => _chipFor(platform)).toList(),
    );
  }

  Widget _chipFor(String platform) {
    final config = _configFor(platform);
    final bgColor = config.color.withValues(alpha: 0.14);

    if (compact) {
      return Tooltip(
        message: config.label,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(config.icon, size: 16, color: config.color),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 15, color: config.color),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _normalize(String platform) {
    final value = platform.trim().toLowerCase();
    switch (value) {
      case 'ios':
      case 'iphone':
      case 'ipad':
        return 'ios';
      case 'macos':
      case 'mac':
      case 'osx':
        return 'mac';
      default:
        return value;
    }
  }

  _PlatformConfig _configFor(String platform) {
    switch (platform) {
      case 'android':
        return const _PlatformConfig('Android', Icons.android, Color(0xFF43A047));
      case 'ios':
        return const _PlatformConfig('iOS', Icons.phone_iphone_rounded, Color(0xFF9E9E9E));
      case 'windows':
        return const _PlatformConfig('Windows', Icons.window_rounded, Color(0xFF1E88E5));
      case 'mac':
        return const _PlatformConfig('Mac', Icons.laptop_mac_rounded, Color(0xFFB0BEC5));
      case 'linux':
        return const _PlatformConfig('Linux', Icons.terminal_rounded, Color(0xFFFB8C00));
      default:
        return const _PlatformConfig('Other', Icons.devices_rounded, Color(0xFF78909C));
    }
  }
}

class _PlatformConfig {
  const _PlatformConfig(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
