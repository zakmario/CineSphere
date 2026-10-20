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

/// Grille paginée des favoris de l'utilisateur connecté
/// (table `favorites` jointe à `media`), du plus récent au plus ancien.
class FavoritesGrid extends StatefulWidget {
  const FavoritesGrid({
    super.key,
    this.width,
    this.height,
    this.pageSize,
    this.onItemTap,
  });

  final double? width;
  final double? height;
  final int? pageSize;
  final Future Function(String tappedMediaId)? onItemTap;

  @override
  State<FavoritesGrid> createState() => _FavoritesGridState();
}

class _FavoritesGridState extends State<FavoritesGrid> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _requestId = 0;

  int get _pageSize => (widget.pageSize ?? 20).clamp(5, 100);

  @override
  void initState() {
    super.initState();
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
    _requestId++;
    setState(() {
      _items.clear();
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (!mounted || _loading || !_hasMore) {
      return;
    }
    final userId = SupaFlow.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _hasMore = false;
        _error = 'Connectez-vous pour voir vos favoris.';
      });
      return;
    }
    final requestId = _requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _items.length;
      final rows = await SupaFlow.client
          .from('favorites')
          .select(
              'created_at, media(id, media_type, title, poster_url, rating, release_date)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('media_id', ascending: true)
          .range(from, from + _pageSize - 1);
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _items.addAll(rows
            .map((r) => r['media'])
            .whereType<Map<String, dynamic>>());
        _hasMore = rows.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger vos favoris.';
        });
      }
    }
  }

  Future<void> _open(String id) async {
    await widget.onItemTap?.call(id);
    // Au retour de la page détail, le favori a peut-être été retiré.
    if (mounted) {
      await _refresh();
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 64, color: theme.secondaryText),
              const SizedBox(height: 12),
              Text(
                _error ??
                    'Aucun favori pour l’instant.\nTouchez le cœur sur un film '
                        'ou une série pour l’ajouter ici.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _refresh, child: const Text('Actualiser')),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.52,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            final id = item['id'] as String;
            return MediaCard(
              key: ValueKey(id),
              title: item['title'] as String? ?? '',
              posterUrl: item['poster_url'] as String?,
              mediaType: item['media_type'] as String?,
              rating: (item['rating'] as num?)?.toDouble(),
              releaseDate: item['release_date'] == null
                  ? null
                  : DateTime.tryParse(item['release_date'] as String),
              onTap: () => _open(id),
            );
          },
        ),
      );
    }
    return SizedBox(width: widget.width, height: widget.height, child: body);
  }
}
