import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../main.dart';
import '../../providers.dart';
import '../../theme.dart';

final developerAppsProvider = AsyncNotifierProvider<DeveloperAppsNotifier, List<Map<String, dynamic>>>(
  DeveloperAppsNotifier.new,
);

class DeveloperAppsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() => ref.read(apiServiceProvider).getDeveloperApps();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

class DeveloperDashboardScreen extends ConsumerStatefulWidget {
  const DeveloperDashboardScreen({super.key});

  @override
  ConsumerState<DeveloperDashboardScreen> createState() => _DeveloperDashboardScreenState();
}

class _DeveloperDashboardScreenState extends ConsumerState<DeveloperDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await ref.read(apiServiceProvider).logout();
    } catch (_) {}
    if (!mounted) return;
    await ref.read(authStateProvider.notifier).clearSession();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final appsState = ref.watch(developerAppsProvider);
    final authState = ref.watch(authStateProvider);
    final name = authState.role == 'developer' ? 'Developer Portal' : 'Developer';

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Developer Dashboard',
        subtitle: name,
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded, color: Colors.white))],
      ),
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          gradient: kBrandGradient,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () => context.push('/developer/upload'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, color: Colors.white), SizedBox(width: 6), Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
            ),
          ),
        ),
      ),
      body: appsState.when(
        loading: () => const _DashboardShimmer(),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (apps) {
          final live = apps.where((a) => a['status']?.toString().toLowerCase() == 'approved').length;
          final scanning = apps.where((a) => a['status']?.toString().toLowerCase() == 'scanning').length;
          return RefreshIndicator(
            onRefresh: () => ref.read(developerAppsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                Row(
                  children: [
                    Expanded(child: _statCard('Total Apps', apps.length, kNavyDeep)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Live', live, kSafeGreen)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Scanning', scanning, kCyanDark)),
                  ],
                ),
                const SizedBox(height: 12),
                ...apps.map((app) => _appCard(app)).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1A1A237E), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text(title, style: GoogleFonts.spaceGrotesk(color: const Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(height: 6),
          Text('$value', style: GoogleFonts.plusJakartaSans(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _appCard(Map<String, dynamic> app) {
    final status = app['status']?.toString().toLowerCase() ?? 'review';
    final color = status == 'approved'
        ? kSafeGreen
        : status == 'scanning'
            ? kCyan
            : status == 'review'
                ? kCautionAmb
                : kDangerRed;

    Widget statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(100)),
      child: Text(status.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );

    if (status == 'scanning') {
      statusChip = FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1).animate(_pulse),
        child: statusChip,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x1A1A237E), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: app['icon_url']?.toString() ?? '',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(gradient: kBrandGradient),
                child: const Icon(Icons.apps_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app['name']?.toString() ?? '-', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: kNavyDeep)),
                const SizedBox(height: 2),
                Text('Version ${app['version']?.toString() ?? '-'}', style: GoogleFonts.spaceGrotesk(fontSize: 12)),
                const SizedBox(height: 8),
                statusChip,
              ],
            ),
          ),
          IconButton(onPressed: () => context.push('/apps/${app['id']}'), icon: const Icon(Icons.open_in_new_rounded, color: kCyanDark)),
        ],
      ),
    );
  }
}

class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFEAF3FF),
          highlightColor: const Color(0xFFF7FBFF),
          child: Container(height: 86, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        ),
      ),
    );
  }
}
