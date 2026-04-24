import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../main.dart';
import '../../providers.dart';
import '../../theme.dart';

class AdminQueueScreen extends ConsumerStatefulWidget {
  const AdminQueueScreen({super.key});

  @override
  ConsumerState<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends ConsumerState<AdminQueueScreen> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 220) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _items.clear();
    });
    try {
      final data = await ref.read(apiServiceProvider).getAdminQueue(page: 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        _initialLoading = false;
        _hasMore = data.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final more = await ref.read(apiServiceProvider).getAdminQueue(page: nextPage);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _items.addAll(more);
        _hasMore = more.length >= 20;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
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

  Future<void> _approve(Map<String, dynamic> app) async {
    final id = app['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await ref.read(apiServiceProvider).approveApp(id);
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e['id'].toString() == id));
  }

  Future<void> _reject(Map<String, dynamic> app) async {
    final id = app['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final reason = await showDialog<String>(context: context, builder: (_) => const _RejectDialog());
    if (reason == null || reason.isEmpty) return;
    await ref.read(apiServiceProvider).rejectApp(id, reason: reason);
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e['id'].toString() == id));
  }

  @override
  Widget build(BuildContext context) {
    final safeCount = _items.where((e) => ((e['security_score'] as num?)?.toInt() ?? 0) >= 85).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavyDeep,
        title: Text('Admin Queue', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _initialLoading
            ? const _QueueShimmer()
            : _error != null
                ? ListView(children: [const SizedBox(height: 140), Center(child: Text(_error!))])
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    children: [
                      Row(
                        children: [
                          Expanded(child: _statCard('Pending', _items.length, kCyan)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('Safe', safeCount, kSafeGreen)),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('Review', _items.length - safeCount, kCautionAmb)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._items.map((item) => _queueCard(item)),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
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
          const SizedBox(height: 5),
          Text('$value', style: GoogleFonts.plusJakartaSans(color: color, fontWeight: FontWeight.w800, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _queueCard(Map<String, dynamic> app) {
    final score = (app['security_score'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x141A237E), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: app['icon_url']?.toString() ?? '',
                  width: 52,
                  height: 52,
                  errorWidget: (_, __, ___) => Container(
                    width: 52,
                    height: 52,
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
                    Text(app['developer_email']?.toString() ?? '-', style: GoogleFonts.spaceGrotesk(fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: scoreColor(score).withOpacity(0.15), borderRadius: BorderRadius.circular(100)),
                child: Text('${scoreLabel(score)} $score', style: GoogleFonts.plusJakartaSans(color: scoreColor(score), fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(app['security_summary']?.toString() ?? 'No AI summary available.', style: GoogleFonts.spaceGrotesk()),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kSafeGreen, Color(0xFF00B07A)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _approve(app),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(child: Text('Approve', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: kDangerRed.withOpacity(0.08),
                    side: BorderSide(color: kDangerRed.withOpacity(0.5)),
                  ),
                  onPressed: () => _reject(app),
                  child: Text('Reject', style: GoogleFonts.plusJakartaSans(color: kDangerRed, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject App', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      content: TextField(controller: _controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Reject')),
      ],
    );
  }
}

class _QueueShimmer extends StatelessWidget {
  const _QueueShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFEAF3FF),
          highlightColor: const Color(0xFFF7FBFF),
          child: Container(height: 148, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
        ),
      ),
    );
  }
}
