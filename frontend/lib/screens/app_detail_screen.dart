import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../services/install_service.dart';
import '../theme.dart';
import '../widgets/security_badge.dart';
import 'home_screen.dart';

final installServiceProvider = Provider<InstallService>((_) => InstallService());
final appDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, appId) {
  return ref.read(apiServiceProvider).getApp(appId);
});

class AppDetailScreen extends ConsumerWidget {
  const AppDetailScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(appDetailProvider(appId));
    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed loading app: $e')),
        data: (data) {
          final appData = Map<String, dynamic>.from(data['app'] as Map? ?? const {});
          final report = data['latest_security_report'] is Map
              ? Map<String, dynamic>.from(data['latest_security_report'] as Map)
              : null;
          final developer = Map<String, dynamic>.from(data['developer'] as Map? ?? const {});
          final installUrls = Map<String, String>.from(data['install_urls'] as Map? ?? const {});
          final screenshots = List<String>.from(appData['screenshots'] ?? const []);
          final platforms = List<String>.from(appData['supported_platforms'] ?? const []);
          final permissions = List<String>.from(report?['dangerous_permissions'] ?? const []);
          final status = (appData['status'] ?? '').toString().toLowerCase();
          final score = (report?['score'] ?? appData['security_score'] ?? 0) as int;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  appData: appData,
                  developer: developer,
                  score: score,
                  onShare: () => Share.share('${AppConstants.storePublicUrl}/apps/$appId/security-report'),
                  onBack: () => context.pop(),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A1A237E), blurRadius: 24, offset: Offset(0, -6)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border(left: BorderSide(color: kCyan, width: 4)),
                            ),
                            child: Text(
                              report?['ai_summary']?.toString() ?? 'AI security summary unavailable.',
                              style: GoogleFonts.spaceGrotesk(height: 1.5, color: const Color(0xFF364152)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (status == 'approved') ...[
                            Text('Install by Platform',
                                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kNavyDeep)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: platforms.map((p) => _platformButton(context, ref, p, installUrls)).toList(),
                            ),
                          ] else
                            Text(
                              'Installs are available after approval.',
                              style: GoogleFonts.spaceGrotesk(color: const Color(0xFF6B7280)),
                            ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.push('/apps/$appId/security-report'),
                            child: Text('View Full Security Report',
                                style: GoogleFonts.plusJakartaSans(color: kCyanDark, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          Text('Description',
                              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kNavyDeep)),
                          const SizedBox(height: 8),
                          Text(appData['description']?.toString() ?? '-', style: GoogleFonts.spaceGrotesk(height: 1.45)),
                          if (screenshots.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Screenshots',
                                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kNavyDeep)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: screenshots.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(imageUrl: screenshots[i], width: 190, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text('Dangerous Permissions',
                              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kNavyDeep)),
                          const SizedBox(height: 8),
                          permissions.isEmpty
                              ? Text('No dangerous permissions reported.', style: GoogleFonts.spaceGrotesk())
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: permissions
                                      .map(
                                        (p) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: kDangerRed.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(100),
                                            border: Border.all(color: kDangerRed.withOpacity(0.35)),
                                          ),
                                          child: Text(p,
                                              style: GoogleFonts.spaceGrotesk(
                                                  color: kDangerRed, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                      )
                                      .toList(),
                                ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _platformButton(
    BuildContext context,
    WidgetRef ref,
    String platform,
    Map<String, String> installUrls,
  ) {
    final config = _platformConfig(platform);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [config.color, config.color.withOpacity(0.75)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final payload = _buildInstallPayload(installUrls);
            final downloadUrl = _downloadUrlForPlatform(platform, installUrls);
            if (downloadUrl == null || downloadUrl.isEmpty) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('No install URL available for ${platform.toUpperCase()}')));
              return;
            }
            await ref.read(installServiceProvider).installApp(context: context, app: payload, platform: platform);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(config.icon, color: Colors.white, size: 16), const SizedBox(width: 6), Text(config.label, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700))],
            ),
          ),
        ),
      ),
    );
  }

  ({Color color, IconData icon, String label}) _platformConfig(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return (color: kSafeGreen, icon: Icons.android_rounded, label: 'Install Android');
      case 'ios':
      case 'iphone':
        return (color: kNavyMid, icon: Icons.phone_iphone_rounded, label: 'Open iPhone');
      case 'windows':
        return (color: kCyanDark, icon: Icons.window_rounded, label: 'Download Windows');
      case 'mac':
      case 'macos':
        return (color: kNavyDeep, icon: Icons.laptop_mac_rounded, label: 'Download Mac');
      default:
        return (color: kCautionAmb, icon: Icons.computer_rounded, label: 'Download Linux');
    }
  }

  String? _downloadUrlForPlatform(String platform, Map<String, String> installUrls) {
    final key = platform.toLowerCase();
    if (key == 'linux') return installUrls['linux_deb'] ?? installUrls['linux_appimage'] ?? installUrls['linux_rpm'];
    return installUrls[key];
  }

  Map<String, dynamic> _buildInstallPayload(Map<String, String> installUrls) {
    return {
      'android_download_url': installUrls['android'],
      'ios_pwa_url': installUrls['ios'],
      'windows_download_url': installUrls['windows'],
      'mac_download_url': installUrls['mac'],
      'linux_download_url': installUrls['linux_deb'] ?? installUrls['linux_appimage'] ?? installUrls['linux_rpm'],
    };
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.appData,
    required this.developer,
    required this.score,
    required this.onShare,
    required this.onBack,
  });

  final Map<String, dynamic> appData;
  final Map<String, dynamic> developer;
  final int score;
  final VoidCallback onShare;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 42),
      decoration: const BoxDecoration(gradient: kBrandGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _heroAction(icon: Icons.arrow_back_rounded, onTap: onBack),
              const Spacer(),
              _heroAction(icon: Icons.share_rounded, onTap: onShare),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.65)),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: appData['icon_url']?.toString() ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.apps_rounded, color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appData['name']?.toString() ?? '-', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(developer['email']?.toString() ?? '-', style: GoogleFonts.spaceGrotesk(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    SecurityBadge(score: score, aiHint: 'Security score', size: SecurityBadgeSize.compact),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Security score based on static and behavioral analysis.',
                        style: GoogleFonts.spaceGrotesk(color: Colors.white.withOpacity(0.92), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: scoreColor(score).withOpacity(0.16), borderRadius: BorderRadius.circular(100), border: Border.all(color: Colors.white.withOpacity(0.4))),
              child: Text(scoreLabel(score), style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroAction({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Ink(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(100)),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
