import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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
            onPressed: () => Share.share('http://54.195.111.168/apps/$appId/security-report'),
            icon: const Icon(Icons.share),
          )
        ],
      ),
      body: app.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load report: $e')),
        data: (data) {
          final score = (data['security_score'] ?? 0) as int;
          final vt = data['virus_total'] ?? {'flagged_engines': 0, 'total_engines': 0};
          final findings = List<String>.from(data['mobsf_findings'] ?? const []);
          final permissions = List<String>.from(data['permissions'] ?? const []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: SecurityBadge(
                  score: score,
                  aiHint: data['security_summary'] ?? 'AI summary unavailable',
                  size: SecurityBadgeSize.large,
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('Risk level: ${_riskLabel(score)}')),
              const SizedBox(height: 12),
              Text(data['security_summary'] ?? 'No AI summary available.'),
              const SizedBox(height: 12),
              const Text('Permissions breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
              ...permissions.map((permission) => ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(permission),
                    subtitle: Text(_permissionExplanation(permission)),
                  )),
              const Divider(),
              ListTile(
                title: const Text('VirusTotal result'),
                subtitle: Text('${vt['flagged_engines']} of ${vt['total_engines']} engines flagged this app.'),
              ),
              const Divider(),
              const Text('MobSF findings summary', style: TextStyle(fontWeight: FontWeight.bold)),
              ...findings.map((f) => ListTile(leading: const Icon(Icons.report), title: Text(f))),
            ],
          );
        },
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

  String _permissionExplanation(String permission) {
    final p = permission.toLowerCase();
    if (p.contains('camera')) return 'App can access your camera';
    if (p.contains('location')) return 'App can track your location';
    if (p.contains('contacts')) return 'App can read your contacts';
    if (p.contains('microphone')) return 'App can record audio';
    if (p.contains('storage')) return 'App can read/write your files';
    return 'Permission requested by the app.';
  }
}
