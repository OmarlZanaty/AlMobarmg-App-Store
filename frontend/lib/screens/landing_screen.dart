import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroSection(isWide: isWide),
                  const SizedBox(height: 28),
                  const Text(
                    'Our Portfolio',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _PortfolioCard(
                        title: 'Custom Mobile Apps',
                        description:
                            'We build secure Android and iOS products with scalable architecture and smooth UX.',
                        icon: Icons.phone_android_rounded,
                      ),
                      _PortfolioCard(
                        title: 'Business Platforms',
                        description:
                            'End-to-end systems for operations, analytics dashboards, and automation workflows.',
                        icon: Icons.dashboard_customize_rounded,
                      ),
                      _PortfolioCard(
                        title: 'AI & Cloud Integrations',
                        description:
                            'Smart integrations that connect your apps with AI services and cloud-native APIs.',
                        icon: Icons.cloud_sync_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Our Work Process',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const _ChecklistTile(
                    title: 'Discovery & Product Strategy',
                    subtitle: 'We define scope, user journeys, and delivery milestones.',
                  ),
                  const _ChecklistTile(
                    title: 'Design & Development',
                    subtitle: 'UI/UX design, app engineering, backend implementation, and QA.',
                  ),
                  const _ChecklistTile(
                    title: 'Launch & Maintenance',
                    subtitle: 'Deployment support, monitoring, and continuous improvements.',
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact AlMobarmg',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 12),
                        Text('Email: contact@almobarmg.com'),
                        SizedBox(height: 6),
                        Text('Phone: +966 50 000 0000'),
                        SizedBox(height: 6),
                        Text('Location: Saudi Arabia'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/register?role=developer'),
                        icon: const Icon(Icons.engineering_rounded),
                        label: const Text('Create Developer Account'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/register?role=user'),
                        icon: const Icon(Icons.person_add_alt_rounded),
                        label: const Text('Create User Account'),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Open AlMobarmg App Store login',
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.storefront_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    const textSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to AlMobarmg',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 12),
        Text(
          'We craft powerful digital products and publish trusted applications through the AlMobarmg App Store.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );

    final badge = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 42),
          SizedBox(height: 8),
          Text(
            'AlMobarmg Portfolio',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: textSection),
                const SizedBox(width: 18),
                badge,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textSection,
                const SizedBox(height: 16),
                badge,
              ],
            ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(description),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle_rounded, color: Colors.green),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}
