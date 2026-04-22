import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../services/api_service.dart';
import '../services/install_service.dart';
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
      appBar: AppBar(
        title: const Text('App Details'),
        actions: [
          IconButton(
            onPressed: () => Share.share('${AppConstants.storePublicUrl}/apps/$appId/security-report'),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (screenshots.isNotEmpty) ...[
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    itemCount: screenshots.length,
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(imageUrl: screenshots[index], fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(imageUrl: appData['icon_url']?.toString() ?? '', width: 72, height: 72),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appData['name']?.toString() ?? '-', style: Theme.of(context).textTheme.headlineSmall),
                        Text(developer['email']?.toString() ?? '-'),
                      ],
                    ),
                  ),
                  _buildSecurityWidget(status: status, score: score, report: report),
                ],
              ),
              const SizedBox(height: 8),
              Text('Status: ${_statusLabel(status)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(report?['ai_summary']?.toString() ?? 'AI security summary unavailable'),
              const SizedBox(height: 16),
              if (status == 'approved') ...[
                const Text('Available Platforms', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: platforms
                      .map(
                        (platform) => FilledButton(
                          onPressed: () async {
                            final payload = _buildInstallPayload(installUrls);
                            final downloadUrl = _downloadUrlForPlatform(platform, installUrls);
                            if (downloadUrl == null || downloadUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('No install URL available for ${platform.toUpperCase()}')),
                              );
                              return;
                            }
                            await ref.read(installServiceProvider).installApp(
                                  context: context,
                                  app: payload,
                                  platform: platform,
                                );
                          },
                          child: Text(_buttonLabel(platform)),
                        ),
                      )
                      .toList(),
                ),
              ] else ...[
                const Text('Installs are available only after approval.'),
              ],
              TextButton(
                onPressed: () => context.push('/apps/$appId/security-report'),
                child: const Text('View Full Security Report'),
              ),
              const SizedBox(height: 12),
              Text(appData['description']?.toString() ?? ''),
              if (screenshots.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Screenshots', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, i) => CachedNetworkImage(imageUrl: screenshots[i]),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: screenshots.length,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
              if (permissions.isEmpty)
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No dangerous permissions reported yet.'),
                )
              else
                ...permissions.map((p) => ListTile(leading: const Icon(Icons.lock_outline), title: Text(p))),
              const Divider(),
              const ListTile(title: Text('Reviews'), subtitle: Text('Coming soon')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSecurityWidget({
    required String status,
    required int score,
    required Map<String, dynamic>? report,
  }) {
    if (status == 'scanning' || status == 'pending') {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(height: 4),
          Text('Scanning...'),
        ],
      );
    }

    if (status == 'review') {
      return const Chip(label: Text('Under Review'));
    }

    if (report == null) {
      return const Chip(label: Text('Score not available'));
    }

    return SecurityBadge(
      score: score,
      aiHint: report['ai_summary']?.toString() ?? 'Security scan completed',
      size: SecurityBadgeSize.large,
    );
  }

  String? _downloadUrlForPlatform(String platform, Map<String, String> installUrls) {
    final key = platform.toLowerCase();
    if (key == 'linux') {
      return installUrls['linux_deb'] ?? installUrls['linux_appimage'] ?? installUrls['linux_rpm'];
    }
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

  String _buttonLabel(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Install Android';
      case 'ios':
      case 'iphone':
        return 'Open on iPhone';
      case 'windows':
        return 'Download Windows';
      case 'mac':
      case 'macos':
        return 'Download Mac';
      default:
        return 'Download Linux';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'scanning':
        return 'Scanning...';
      case 'review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}
