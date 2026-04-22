import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/platform_chips.dart';
import '../widgets/security_badge.dart';

final apiServiceProvider = Provider<ApiService>((_) => ApiService());

final appFeedProvider = AsyncNotifierProvider<AppFeedNotifier, AppFeedState>(
  AppFeedNotifier.new,
);

class AppFeedState {
  const AppFeedState({
    this.apps = const [],
    this.loadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.query = '',
    this.platform = 'all',
    this.category = 'all',
  });

  final List<Map<String, dynamic>> apps;
  final bool loadingMore;
  final bool hasMore;
  final int page;
  final String query;
  final String platform;
  final String category;

  AppFeedState copyWith({
    List<Map<String, dynamic>>? apps,
    bool? loadingMore,
    bool? hasMore,
    int? page,
    String? query,
    String? platform,
    String? category,
  }) {
    return AppFeedState(
      apps: apps ?? this.apps,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      query: query ?? this.query,
      platform: platform ?? this.platform,
      category: category ?? this.category,
    );
  }
}

class AppFeedNotifier extends AsyncNotifier<AppFeedState> {
  @override
  Future<AppFeedState> build() async {
    return _loadFresh();
  }

  Future<AppFeedState> _loadFresh() async {
    final api = ref.read(apiServiceProvider);
    final apps = await api.getApps(page: 1);
    return AppFeedState(apps: apps, hasMore: apps.length >= 20);
  }

  Future<void> refreshFeed() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFresh);
  }

  Future<void> updateFilters({String? query, String? platform, String? category}) async {
    final current = state.valueOrNull ?? const AppFeedState();
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final api = ref.read(apiServiceProvider);
      final apps = await api.getApps(
        query: query ?? current.query,
        platform: platform ?? current.platform,
        category: category ?? current.category,
      );
      state = AsyncData(
        current.copyWith(
          apps: apps,
          page: 1,
          hasMore: apps.length >= 20,
          query: query ?? current.query,
          platform: platform ?? current.platform,
          category: category ?? current.category,
          loadingMore: false,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    final api = ref.read(apiServiceProvider);
    final nextPage = current.page + 1;

    try {
      final next = await api.getApps(
        page: nextPage,
        query: current.query,
        platform: current.platform,
        category: current.category,
      );
      state = AsyncData(
        current.copyWith(
          apps: [...current.apps, ...next],
          page: nextPage,
          loadingMore: false,
          hasMore: next.isNotEmpty,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(appFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(appFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Al Mobarmg Store'),
      ),
      body: feed.when(
        loading: _buildLoading,
        error: (error, _) => ErrorState(
          message: 'Failed to load apps. ${error.toString()}',
          onRetry: ref.read(appFeedProvider.notifier).refreshFeed,
        ),
        data: (data) => RefreshIndicator(
          onRefresh: ref.read(appFeedProvider.notifier).refreshFeed,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _filters(context, data)),
              if (data.apps.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No apps found',
                    subtitle: 'Try adjusting your filters or search term.',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _appCard(context, data.apps[index]),
                      childCount: data.apps.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width >= 1100
                          ? 4
                          : MediaQuery.of(context).size.width >= 700
                              ? 3
                              : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: data.loadingMore
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(BuildContext context, AppFeedState state) {
    const platforms = ['all', 'android', 'ios', 'windows', 'mac', 'linux'];
    const platformLabels = {
      'all': 'ALL',
      'android': 'ANDROID',
      'ios': 'IPHONE',
      'windows': 'WINDOWS',
      'mac': 'MAC',
      'linux': 'LINUX',
    };
    const categories = ['all', 'games', 'tools', 'business', 'education', 'health'];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search apps',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Apply filters',
                onPressed: () {
                  ref.read(appFeedProvider.notifier).updateFilters(
                        query: _searchController.text,
                      );
                },
              ),
            ),
            onSubmitted: (value) {
              ref.read(appFeedProvider.notifier).updateFilters(query: value);
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platforms
                .map(
                  (platform) => FilterChip(
                    label: Text(platformLabels[platform] ?? platform.toUpperCase()),
                    selected: state.platform == platform,
                    onSelected: (_) {
                      ref.read(appFeedProvider.notifier).updateFilters(platform: platform);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (category) => FilterChip(
                    label: Text(category.toUpperCase()),
                    selected: state.category == category,
                    onSelected: (_) {
                      ref.read(appFeedProvider.notifier).updateFilters(category: category);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _appCard(BuildContext context, Map<String, dynamic> app) {
    final score = (app['security_score'] as num?)?.toInt() ?? 0;
    final appPlatforms = List<String>.from(app['supported_platforms'] ?? const <String>[]);
    final riskBadge = app['risk_badge']?.toString() ?? 'unknown';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/apps/${app['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: app['icon_url'] ?? '',
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(Icons.apps_rounded, size: 60),
                  ),
                ),
              ),
              Text(
                app['name'] ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                app['category']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              SecurityBadge(
                score: score,
                aiHint: 'Risk level: $riskBadge',
              ),
              if (score >= 85) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              PlatformChips(platforms: appPlatforms, compact: true),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/apps/${app['id']}'),
                  child: const Text('Install'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (_, __) => const SkeletonAppCard(),
    );
  }
}

class SkeletonAppCard extends StatelessWidget {
  const SkeletonAppCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
          highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF2F2F2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 14, width: double.infinity, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 12, width: 110, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 20, width: double.infinity, color: Colors.white),
              const SizedBox(height: 6),
              Row(
                children: List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(height: 24, width: 24, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 48, width: double.infinity, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
