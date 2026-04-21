import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../services/api_service.dart';
import '../widgets/security_badge.dart';

final apiServiceProvider = Provider<ApiService>((_) => ApiService());

final appFeedProvider = AsyncNotifierProvider<AppFeedNotifier, AppFeedState>(AppFeedNotifier.new);

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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final apps = await api.getApps(
        query: query ?? current.query,
        platform: platform ?? current.platform,
        category: category ?? current.category,
      );
      return current.copyWith(
        apps: apps,
        page: 1,
        hasMore: apps.length >= 20,
        query: query ?? current.query,
        platform: platform ?? current.platform,
        category: category ?? current.category,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;

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
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        ref.read(appFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(appFeedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Al Mobarmg Store')),
      body: feed.when(
        loading: _buildLoading,
        error: (e, _) => Center(child: Text('Failed to load apps: $e')),
        data: (data) => RefreshIndicator(
          onRefresh: ref.read(appFeedProvider.notifier).refreshFeed,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _filters(context, data)),
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
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(BuildContext context, AppFeedState state) {
    const platforms = ['all', 'android', 'iphone', 'windows', 'mac', 'linux'];
    const categories = ['all', 'games', 'tools', 'business', 'education', 'health'];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search apps',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => ref.read(appFeedProvider.notifier).updateFilters(query: _searchController.text),
              ),
            ),
            onSubmitted: (value) => ref.read(appFeedProvider.notifier).updateFilters(query: value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: platforms
                .map((p) => FilterChip(
                      label: Text(p.toUpperCase()),
                      selected: state.platform == p,
                      onSelected: (_) => ref.read(appFeedProvider.notifier).updateFilters(platform: p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: categories
                .map((c) => FilterChip(
                      label: Text(c.toUpperCase()),
                      selected: state.category == c,
                      onSelected: (_) => ref.read(appFeedProvider.notifier).updateFilters(category: c),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _appCard(BuildContext context, Map<String, dynamic> app) {
    final score = (app['security_score'] ?? 0) as int;
    final supports = List<String>.from(app['platforms'] ?? const []);
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
                    errorWidget: (_, __, ___) => const Icon(Icons.apps, size: 60),
                  ),
                ),
              ),
              Text(app['name'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(app['developer_name'] ?? '-', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              SecurityBadge(score: score, aiHint: app['security_summary'] ?? 'Security scan completed'),
              const SizedBox(height: 6),
              Wrap(spacing: 4, children: supports.map((e) => Icon(_platformIcon(e), size: 16)).toList()),
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
      default:
        return Icons.computer;
    }
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(color: Colors.white),
      ),
    );
  }
}
