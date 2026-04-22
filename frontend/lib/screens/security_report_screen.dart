import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../widgets/security_badge.dart';
import 'app_detail_screen.dart';

class SecurityReportScreen extends ConsumerWidget {
  const SecurityReportScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appDetailProvider(appId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Report'),
        actions: [
          IconButton(
            onPressed: () => Share.share('${AppConstants.storePublicUrl}/apps/$appId/security-report'),
            icon: const Icon(Icons.share),
          )
        ],
      ),
      body: app.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load report: $e')),
        data: (data) {
          final appData = Map<String, dynamic>.from(data['app'] as Map? ?? const {});
          final report = data['latest_security_report'] is Map
              ? Map<String, dynamic>.from(data['latest_security_report'] as Map)
              : null;

          if (report == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ListTile(
                  leading: Icon(Icons.pending_actions),
                  title: Text('Security scan not yet completed'),
                  subtitle: Text('Please check back later for the latest scan results.'),
                ),
                SizedBox(height: 12),
                Text('For full technical report, contact the developer.'),
              ],
            );
          }

          final score = (report['score'] ?? appData['security_score'] ?? 0) as int;
          final aiSummary = report['ai_summary'] as String? ?? 'No AI summary available';
          final riskLevel = report['risk_level'] as String? ?? 'unknown';
          final scannedAt = report['scanned_at']?.toString() ?? 'Unknown';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: SecurityBadge(
                  score: score,
                  aiHint: aiSummary,
                  size: SecurityBadgeSize.large,
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('Risk level: ${riskLevel.toUpperCase()}')),
              const SizedBox(height: 8),
              Center(child: Text('Scanned at: $scannedAt')),
              const SizedBox(height: 12),
              Text(aiSummary),
              const Divider(height: 24),
              const ListTile(
                title: Text('Permissions breakdown'),
                subtitle: Text('Full permission details available after scan'),
              ),
              const Divider(),
              const ListTile(
                title: Text('VirusTotal result'),
                subtitle: Text('VirusTotal results available in developer dashboard'),
              ),
              const Divider(),
              const ListTile(
                title: Text('Technical report'),
                subtitle: Text('For full technical report, contact the developer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
