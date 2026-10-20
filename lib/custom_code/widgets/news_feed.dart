// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Fil d'actualités paginé (table `news`), du plus récent au plus ancien.
/// Toucher une actualité liée à un contenu appelle [onItemTap] avec son id.
class NewsFeed extends StatefulWidget {
  const NewsFeed({
    super.key,
    this.width,
    this.height,
    this.pageSize,
    this.onItemTap,
  });

  final double? width;
  final double? height;
  final int? pageSize;
  final Future Function(String linkedMediaId)? onItemTap;

  @override
  State<NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends State<NewsFeed> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  int get _pageSize => (widget.pageSize ?? 10).clamp(5, 50);

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _scrollController.addListener(() {
      final p = _scrollController.position;
      if (p.pixels >= p.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (!mounted || _loading || !_hasMore) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _items.length;
      final rows = await SupaFlow.client
          .from('news')
          .select('id, media_id, title, summary, image_url, published_at')
          .order('published_at', ascending: false)
          .order('id', ascending: true)
          .range(from, from + _pageSize - 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(rows);
        _hasMore = rows.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger les actualités.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty && (_error != null || !_hasMore)) {
      body = Center(
        child: TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: Text(_error ?? 'Aucune actualité pour le moment.'),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == _items.length) {
              return _buildFooter(theme);
            }
            return _buildCard(theme, _items[index]);
          },
        ),
      );
    }
    return SizedBox(width: widget.width, height: widget.height, child: body);
  }

  Widget _buildCard(FlutterFlowTheme theme, Map<String, dynamic> news) {
    final image = news['image_url'] as String?;
    final mediaId = news['media_id'] as String?;
    final published = DateTime.tryParse(news['published_at'] as String? ?? '');
    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: mediaId == null || widget.onItemTap == null
            ? null
            : () => widget.onItemTap!(mediaId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(news['title'] as String? ?? '',
                      style: theme.titleMedium),
                  if (news['summary'] != null) ...[
                    const SizedBox(height: 6),
                    Text(news['summary'] as String,
                        style: theme.bodyMedium
                            .copyWith(color: theme.secondaryText)),
                  ],
                  if (published != null) ...[
                    const SizedBox(height: 8),
                    Text(timeago.format(published, locale: 'fr'),
                        style: theme.bodySmall
                            .copyWith(color: theme.secondaryText)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(FlutterFlowTheme theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(
        child: TextButton(
            onPressed: _loadMore, child: const Text('Erreur — réessayer')),
      );
    }
    return const SizedBox(height: 24);
  }
}
