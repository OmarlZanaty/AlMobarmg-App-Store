import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../main.dart';
import '../../providers.dart';
import '../../widgets/security_badge.dart';

class AdminQueueScreen extends ConsumerStatefulWidget {
  const AdminQueueScreen({super.key});

  @override
  ConsumerState<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends ConsumerState<AdminQueueScreen> {
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();

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
      if (_loadingMore || !_hasMore || _initialLoading) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 240) {
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
      _error = null;
      _initialLoading = true;
      _page = 1;
      _hasMore = true;
      _items.clear();
    });

    try {
      final data = await ref.read(apiServiceProvider).getAdminQueue(page: 1);
      if (!mounted) return;
      setState(() {
        _listKey = GlobalKey<AnimatedListState>();
        _items.addAll(data);
        _initialLoading = false;
        _hasMore = data.length >= 20;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    final nextPage = _page + 1;

    try {
      final nextItems = await ref.read(apiServiceProvider).getAdminQueue(page: nextPage);
      if (!mounted) return;

      final start = _items.length;
      setState(() {
        _page = nextPage;
        _items.addAll(nextItems);
        _loadingMore = false;
        _hasMore = nextItems.length >= 20;
      });

      for (var i = 0; i < nextItems.length; i++) {
        _listKey.currentState?.insertItem(start + i, duration: const Duration(milliseconds: 260));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
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

  Future<void> _approve(Map<String, dynamic> app, int index) async {
    final appId = app['id']?.toString() ?? '';
    if (appId.isEmpty) return;

    try {
      await ref.read(apiServiceProvider).approveApp(appId);
      _removeItemAt(index);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App approved successfully.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _reject(Map<String, dynamic> app, int index) async {
    final appId = app['id']?.toString() ?? '';
    if (appId.isEmpty) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );

    if (reason == null) return;

    try {
      await ref.read(apiServiceProvider).rejectApp(appId, reason: reason);
      _removeItemAt(index);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App rejected.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = _items.removeAt(index);

    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset.zero, end: const Offset(1.0, 0.0)).animate(animation),
          child: _QueueCard(
            app: removed,
            onApprove: () {},
            onReject: () {},
          ),
        ),
      ),
      duration: const Duration(milliseconds: 300),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return _QueueShimmer();
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadInitial,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Center(
            child: Text(
              'Queue is empty — all caught up!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        AnimatedList(
          key: _listKey,
          initialItemCount: _items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index, animation) {
            final app = _items[index];
            return SizeTransition(
              sizeFactor: animation,
              child: _QueueCard(
                app: app,
                onApprove: () => _approve(app, index),
                onReject: () => _reject(app, index),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_hasMore)
          OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('Load more'),
          ),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.app,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> app;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final iconUrl = app['icon_url']?.toString() ?? '';
    final name = app['name']?.toString() ?? 'Unknown app';
    final email = app['developer_email']?.toString() ?? 'Unknown developer';
    final submittedAt = app['submitted_at']?.toString() ?? app['created_at']?.toString() ?? '-';
    final score = (app['security_score'] as num?)?.toInt() ?? 0;
    final summary = app['security_summary']?.toString() ?? 'No AI summary yet.';
    final dangerousPermissions =
        (app['dangerous_permissions'] as List? ?? const []).map((e) => e.toString()).toList();
    final suspiciousApis =
        (app['suspicious_apis'] as List? ?? const []).map((e) => e.toString()).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: iconUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      width: 52,
                      height: 52,
                      child: const Icon(Icons.apps),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text('Submitted: $submittedAt', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                SecurityBadge(
                  size: SecurityBadgeSize.large,
                  score: score,
                  aiHint: summary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Risk level: ${_riskLabel(score)}',
              style: TextStyle(
                color: _riskColor(score),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(summary),
            const SizedBox(height: 12),
            Text('Dangerous permissions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            _buildChipRow(
              dangerousPermissions,
              bgColor: Colors.red.shade50,
              fgColor: Colors.red.shade800,
              emptyText: 'None detected',
            ),
            const SizedBox(height: 10),
            Text('Suspicious APIs', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            _buildChipRow(
              suspiciousApis,
              bgColor: Colors.amber.shade100,
              fgColor: Colors.amber.shade900,
              emptyText: 'None detected',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                    onPressed: onApprove,
                    child: const Text('APPROVE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                    onPressed: onReject,
                    child: const Text('REJECT'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipRow(
    List<String> items, {
    required Color bgColor,
    required Color fgColor,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Text(emptyText, style: TextStyle(color: fgColor));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (item) => Chip(
              visualDensity: VisualDensity.compact,
              backgroundColor: bgColor,
              label: Text(item, style: TextStyle(color: fgColor)),
            ),
          )
          .toList(),
    );
  }

  String _riskLabel(int score) {
    if (score >= 85) return 'SAFE';
    if (score >= 65) return 'LOW RISK';
    if (score >= 45) return 'CAUTION';
    if (score >= 25) return 'RISKY';
    return 'DANGEROUS';
  }

  Color _riskColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 65) return Colors.blue;
    if (score >= 45) return Colors.amber.shade800;
    if (score >= 25) return Colors.red;
    return Colors.red.shade900;
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final length = _reasonController.text.length;

    return AlertDialog(
      title: const Text('Reject app submission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reasonController,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Enter rejection reason (minimum 20 characters)',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$length/500', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final reason = _reasonController.text.trim();
            if (reason.length < 20) {
              setState(() => _error = 'Reason must be at least 20 characters.');
              return;
            }
            Navigator.of(context).pop(reason);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _QueueShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 260,
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
