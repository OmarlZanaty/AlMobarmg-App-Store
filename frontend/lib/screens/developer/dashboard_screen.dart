import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../main.dart';
import '../../providers.dart';
import '../../widgets/security_badge.dart';

final developerAppsProvider =
    AsyncNotifierProvider<DeveloperAppsNotifier, List<Map<String, dynamic>>>(
  DeveloperAppsNotifier.new,
);

class DeveloperAppsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() {
    return ref.read(apiServiceProvider).getDeveloperApps();
  }

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
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await ref.read(apiServiceProvider).logout();
    } catch (_) {
      // Ignore remote logout errors and clear local session anyway.
    }

    if (!mounted) return;
    await ref.read(authStateProvider.notifier).clearSession();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final appsState = ref.watch(developerAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Apps'),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/developer/upload'),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload New App'),
      ),
      body: appsState.when(
        loading: _DashboardShimmer.new,
        error: (error, _) => _ErrorState(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.read(developerAppsProvider.notifier).refresh(),
        ),
        data: (apps) {
          if (apps.isEmpty) {
            return _EmptyState(onUpload: () => context.push('/developer/upload'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(developerAppsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: apps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _DeveloperAppCard(
                app: apps[index],
                pulseController: _pulseController,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeveloperAppCard extends StatelessWidget {
  const _DeveloperAppCard({
    required this.app,
    required this.pulseController,
  });

  final Map<String, dynamic> app;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final iconUrl = app['icon_url']?.toString() ?? '';
    final appName = app['name']?.toString() ?? 'Unknown app';
    final version = app['version']?.toString() ?? '—';
    final status = app['status']?.toString().toLowerCase() ?? 'pending';
    final score = (app['security_score'] as num?)?.toInt() ?? 0;
    final installs = (app['total_installs'] as num?)?.toInt() ?? 0;
    final platforms = (app['supported_platforms'] as List? ?? app['platforms'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: iconUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.apps, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text('Version $version', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                SecurityBadge(
                  score: score,
                  aiHint: app['security_summary']?.toString() ?? 'Security scan in progress',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatusChip(status: status, pulseController: pulseController),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: platforms
                  .map(
                    (platform) => Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(_platformIcon(platform), size: 16),
                      label: Text(platform.toUpperCase()),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text('Installs: $installs'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/apps/${app['id']}'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
      case 'iphone':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.window;
      case 'mac':
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.pulseController});

  final String status;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(status);
    if (status == 'scanning') {
      return FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(pulseController),
        child: Chip(
          visualDensity: VisualDensity.compact,
          backgroundColor: cfg.background,
          avatar: Icon(Icons.sync, color: cfg.foreground, size: 16),
          label: Text(cfg.label, style: TextStyle(color: cfg.foreground, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: cfg.background,
      avatar: Icon(Icons.circle, color: cfg.foreground, size: 10),
      label: Text(cfg.label, style: TextStyle(color: cfg.foreground, fontWeight: FontWeight.w600)),
    );
  }

  ({String label, Color background, Color foreground}) _statusConfig(String status) {
    switch (status) {
      case 'pending':
        return (
          label: 'Pending',
          background: Colors.grey.shade200,
          foreground: Colors.grey.shade800,
        );
      case 'scanning':
        return (
          label: 'Scanning',
          background: Colors.blue.shade100,
          foreground: Colors.blue.shade800,
        );
      case 'review':
        return (
          label: 'Review',
          background: Colors.amber.shade100,
          foreground: Colors.amber.shade900,
        );
      case 'approved':
        return (
          label: 'Approved',
          background: Colors.green.shade100,
          foreground: Colors.green.shade800,
        );
      case 'rejected':
        return (
          label: 'Rejected',
          background: Colors.red.shade100,
          foreground: Colors.red.shade700,
        );
      case 'removed':
      default:
        return (
          label: 'Removed',
          background: Colors.grey.shade300,
          foreground: Colors.grey.shade800,
        );
    }
  }
}

class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch, size: 72, color: Colors.blueGrey.shade300),
            const SizedBox(height: 12),
            Text('No apps yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text(
              'Upload your first app and kick off automated security scanning.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload),
              label: const Text('Upload your first app'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 58, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text('Could not load apps', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
