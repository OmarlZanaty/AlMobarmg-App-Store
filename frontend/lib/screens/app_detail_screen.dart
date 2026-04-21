import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
            onPressed: () => Share.share('http://34.242.156.156/apps/$appId/security-report'),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed loading app: $e')),
        data: (app) {
          final screenshots = List<String>.from(app['screenshots'] ?? const []);
          final permissions = List<String>.from(app['permissions'] ?? const []);
          final platforms = List<String>.from(app['platforms'] ?? const []);
          final score = (app['security_score'] ?? 0) as int;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: screenshots.isEmpty ? 1 : screenshots.length,
                  itemBuilder: (_, index) {
                    final url = screenshots.isEmpty ? app['hero_image_url'] ?? '' : screenshots[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(imageUrl: app['icon_url'] ?? '', width: 72, height: 72),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(app['name'] ?? '-', style: Theme.of(context).textTheme.headlineSmall),
                      Text(app['developer_name'] ?? '-'),
                    ]),
                  ),
                  SecurityBadge(
                    score: score,
                    aiHint: app['security_summary'] ?? 'Security scan completed',
                    size: SecurityBadgeSize.large,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Risk level: ${_riskLabel(score)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(app['security_summary'] ?? 'AI security summary unavailable'),
              const SizedBox(height: 16),
              const Text('Available Platforms', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: platforms
                    .map((platform) => FilledButton(
                          onPressed: () => ref.read(installServiceProvider).installApp(
                                context: context,
                                app: app,
                                platform: platform,
                              ),
                          child: Text(_buttonLabel(platform)),
                        ))
                    .toList(),
              ),
              TextButton(
                onPressed: () => context.push('/apps/$appId/security-report'),
                child: const Text('View Full Security Report'),
              ),
              const SizedBox(height: 12),
              Text(app['description'] ?? ''),
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
              const SizedBox(height: 12),
              const Text('Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
              ...permissions.map((p) => ListTile(leading: const Icon(Icons.lock_outline), title: Text(p))),
              const Divider(),
              const ListTile(title: Text('Reviews'), subtitle: Text('Coming soon')),
            ],
          );
        },
      ),
    );
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

  String _riskLabel(int score) {
    if (score >= 85) return 'SAFE';
    if (score >= 65) return 'LOW RISK';
    if (score >= 45) return 'CAUTION';
    if (score >= 25) return 'RISKY';
    return 'DANGEROUS';
  }
}
