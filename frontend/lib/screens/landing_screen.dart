import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 920;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hero(context, isWide),
                  const SizedBox(height: 24),
                  Text('Our Portfolio', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: kNavyDeep)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _FeatureCard(title: 'Mobile Engineering', description: 'Android, iOS and cross-platform delivery with security-first foundations.', icon: Icons.phone_android_rounded),
                      _FeatureCard(title: 'Backend Systems', description: 'Fast APIs, queue workers and resilient cloud-native operations for growth.', icon: Icons.hub_rounded),
                      _FeatureCard(title: 'AI Security', description: 'Automated malware analysis, risk scoring and review flows for every app.', icon: Icons.security_rounded),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Process', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: kNavyDeep)),
                  const SizedBox(height: 12),
                  const _StepTile(index: 1, title: 'Discovery & Planning', subtitle: 'Align goals, roadmap and technical architecture.'),
                  const _StepTile(index: 2, title: 'Build & Secure', subtitle: 'Develop, scan, test and validate each release pipeline.'),
                  const _StepTile(index: 3, title: 'Launch & Scale', subtitle: 'Publish with confidence and monitor growth metrics.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, bool isWide) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Al Mobarmg Store', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Secure Apps for Every Platform', style: GoogleFonts.spaceGrotesk(color: Colors.white.withOpacity(0.92), fontSize: 16)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _floatingBadge('Android'),
            _floatingBadge('iOS'),
            _floatingBadge('Windows'),
            _floatingBadge('Linux'),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('12,500+', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                  Text('Apps Scanned', style: GoogleFonts.spaceGrotesk(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kNavyDeep),
              onPressed: () => context.go('/register?role=developer'),
              child: Text('Start as Developer', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
              onPressed: () => context.go('/login'),
              child: Text('Sign In', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: kBrandGradient, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x261A237E), blurRadius: 28, offset: Offset(0, 12))]),
      child: isWide ? Row(children: [Expanded(child: content), const SizedBox(width: 20), const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 84)]) : content,
    );
  }

  Widget _floatingBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(100), border: Border.all(color: Colors.white24)),
      child: Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x1A1A237E), blurRadius: 18, offset: Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(gradient: kBrandGradient, borderRadius: BorderRadius.all(Radius.circular(12))),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.plusJakartaSans(color: kNavyDeep, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(description, style: GoogleFonts.spaceGrotesk(height: 1.5, color: const Color(0xFF475467))),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.title, required this.subtitle});

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: kCyan),
          child: Center(child: Text('$index', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800))),
        ),
        title: Text(title, style: GoogleFonts.plusJakartaSans(color: kNavyDeep, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: GoogleFonts.spaceGrotesk()),
      ),
    );
  }
}
