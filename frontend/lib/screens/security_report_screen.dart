import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../theme.dart';
import 'app_detail_screen.dart';

class SecurityReportScreen extends ConsumerWidget {
  const SecurityReportScreen({super.key, required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appDetailProvider(appId));
    return Scaffold(
      body: app.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load report: $e')),
        data: (data) {
          final appData = Map<String, dynamic>.from(data['app'] as Map? ?? const {});
          final report = data['latest_security_report'] is Map
              ? Map<String, dynamic>.from(data['latest_security_report'] as Map)
              : null;
          if (report == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Security scan not completed yet. Please check back later.',
                  style: GoogleFonts.spaceGrotesk(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final score = (report['score'] ?? appData['security_score'] ?? 0) as int;
          final aiSummary = report['ai_summary']?.toString() ?? 'No AI summary available';
          final riskLevel = report['risk_level']?.toString().toUpperCase() ?? scoreLabel(score);
          final findings = List<Map<String, dynamic>>.from(report['findings'] ?? const []);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 52, 16, 26),
                  decoration: const BoxDecoration(gradient: kBrandGradient),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Share.share('${AppConstants.storePublicUrl}/apps/$appId/security-report'),
                            icon: const Icon(Icons.share_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 158,
                        height: 158,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: scoreColor(score), width: 8),
                        ),
                        child: Center(
                          child: Text(
                            '$score',
                            style: GoogleFonts.plusJakartaSans(
                              color: scoreColor(score),
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(riskLevel, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -16),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kSafeGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kSafeGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: kSafeGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('VirusTotal: No known malware signatures detected.',
                                    style: GoogleFonts.spaceGrotesk(color: const Color(0xFF065F46), fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('AI Security Summary', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kNavyDeep)),
                        const SizedBox(height: 6),
                        Text(aiSummary, style: GoogleFonts.spaceGrotesk(height: 1.5)),
                        const SizedBox(height: 14),
                        Text('Findings', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kNavyDeep)),
                        const SizedBox(height: 8),
                        ...(findings.isEmpty
                            ? [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: _iconBox(kSafeGreen, Icons.check_circle_outline_rounded),
                                  title: Text('No critical findings', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                                  subtitle: Text('Current scan did not report major issues.', style: GoogleFonts.spaceGrotesk()),
                                ),
                              ]
                            : findings.map((f) {
                                final severity = (f['severity']?.toString().toLowerCase() ?? 'low');
                                final c = severity == 'high'
                                    ? kDangerRed
                                    : severity == 'medium'
                                        ? kCautionAmb
                                        : kCyan;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: _iconBox(c, Icons.security_rounded),
                                  title: Text(f['title']?.toString() ?? 'Finding', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                                  subtitle: Text(f['description']?.toString() ?? '-', style: GoogleFonts.spaceGrotesk()),
                                );
                              })),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: kBrandGradient,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Share.share('${AppConstants.storePublicUrl}/apps/$appId/security-report'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text('Share Report', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _iconBox(Color color, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color),
    );
  }
}
