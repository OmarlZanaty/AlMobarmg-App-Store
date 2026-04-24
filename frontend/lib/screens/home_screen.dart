import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/platform_chips.dart';

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
  Future<AppFeedState> build() => _loadFresh();

  Future<AppFeedState> _loadFresh() async {
    final apps = await ref.read(apiServiceProvider).getApps(page: 1);
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
      final apps = await ref.read(apiServiceProvider).getApps(
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
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final nextPage = current.page + 1;
      final next = await ref.read(apiServiceProvider).getApps(
            page: nextPage,
            query: current.query,
            platform: current.platform,
            category: current.category,
          );
      state = AsyncData(
        current.copyWith(
          apps: [...current.apps, ...next],
          page: nextPage,
          hasMore: next.isNotEmpty,
          loadingMore: false,
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
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 260) {
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
      appBar: GradientAppBar(
        title: 'Al Mobarmg',
        subtitle: 'Secure Apps · Every Platform',
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          ),
        ],
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
              SliverToBoxAdapter(child: _filters(data)),
              if (data.apps.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No apps found',
                    subtitle: 'Try adjusting your filters.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(14),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width >= 1100
                          ? 4
                          : MediaQuery.of(context).size.width >= 700
                              ? 3
                              : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.69,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _appCard(data.apps[index]),
                      childCount: data.apps.length,
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

  Widget _filters(AppFeedState state) {
    const platforms = ['all', 'android', 'ios', 'windows', 'mac', 'linux'];
    const categories = ['all', 'games', 'tools', 'business', 'education', 'health'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search secure apps...',
              prefixIcon: const Icon(Icons.search_rounded),
              fillColor: kSurface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kCyan.withOpacity(0.15), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kCyan, width: 2),
              ),
            ),
            onSubmitted: (value) => ref.read(appFeedProvider.notifier).updateFilters(query: value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platforms
                .map(
                  (p) => FilterChip(
                    label: Text(p.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    selected: state.platform == p,
                    selectedColor: kCyan,
                    checkmarkColor: Colors.white,
                    side: BorderSide(color: kCyan.withOpacity(0.25), width: 1.5),
                    backgroundColor: Colors.white,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: state.platform == p ? Colors.white : kNavyDeep,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => ref.read(appFeedProvider.notifier).updateFilters(platform: p),
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
                  (c) => FilterChip(
                    label: Text(c.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    selected: state.category == c,
                    selectedColor: kCyan,
                    checkmarkColor: Colors.white,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: kCyan.withOpacity(0.25), width: 1.5),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: state.category == c ? Colors.white : kNavyDeep,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => ref.read(appFeedProvider.notifier).updateFilters(category: c),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _appCard(Map<String, dynamic> app) {
    final score = (app['security_score'] as num?)?.toInt() ?? 0;
    final platforms = List<String>.from(app['supported_platforms'] ?? const []);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCyan.withOpacity(0.08)),
        boxShadow: const [BoxShadow(color: Color(0x141A237E), blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/apps/${app['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: app['icon_url']?.toString() ?? '',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            gradient: kBrandGradient,
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          child: const Icon(Icons.apps_rounded, color: Colors.white, size: 34),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  app['name']?.toString() ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: kNavyDeep, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  app['category']?.toString() ?? '',
                  style: GoogleFonts.spaceGrotesk(color: const Color(0xFF6B7280), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scoreColor(score).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${scoreLabel(score)} · $score',
                    style: GoogleFonts.plusJakartaSans(
                      color: scoreColor(score),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (score >= 85) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSafeGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 13, color: kSafeGreen),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: GoogleFonts.plusJakartaSans(
                            color: kSafeGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                PlatformChips(platforms: platforms, compact: true),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: kBrandGradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: kCyan.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.push('/apps/${app['id']}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Center(
                          child: Text(
                            'Install',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.69,
      ),
      itemBuilder: (_, __) => const SkeletonAppCard(),
    );
  }
}

class SkeletonAppCard extends StatelessWidget {
  const SkeletonAppCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x141A237E), blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFEAF3FF),
          highlightColor: const Color(0xFFF7FBFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 14, width: 120, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 12, width: 90, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 20, width: 80, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 34, width: double.infinity, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
