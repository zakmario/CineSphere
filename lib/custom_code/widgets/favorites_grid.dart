// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/firebase_service.dart';

/// Grille paginée des favoris de l'utilisateur connecté
/// (sous-collection `users/{uid}/favorites`, titre et affiche dénormalisés),
/// du plus récent au plus ancien.
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

  /// Dernier favori chargé : la page suivante commence après lui.
  DocumentSnapshot? _lastFavorite;

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
      _lastFavorite = null;
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
    if (CineFirebaseService.instance.currentUserId == null) {
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
      // Pagination par curseur (section 5.5).
      var query = CineFirebaseService.instance
          .mine('favorites')
          .orderBy('addedAt', descending: true)
          .limit(_pageSize);
      final last = _lastFavorite;
      if (last != null) {
        query = query.startAfterDocument(last);
      }
      final page = await query.get();
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        if (page.docs.isNotEmpty) {
          _lastFavorite = page.docs.last;
        }
        // L'identifiant du favori est la clé du titre (movie_550).
        _items.addAll(page.docs.map(cineRow));
        _hasMore = page.docs.length == _pageSize;
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
      body = const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: CineSkeleton(variant: 'grid', itemCount: 6),
      );
    } else if (_items.isEmpty && (_error != null || !_hasMore)) {
      final signedOut = CineFirebaseService.instance.currentUserId == null;
      body = _emptyState(
        theme,
        icon: signedOut
            ? Icons.lock_outline_rounded
            : _error != null
                ? Icons.wifi_off_rounded
                : Icons.favorite_rounded,
        title: signedOut
            ? 'Connexion requise'
            : _error != null
                ? 'Oups…'
                : 'Aucun favori pour l’instant',
        text: _error ??
            'Touchez le cœur sur un film ou une série pour le retrouver ici.',
      );
    } else {
      body = RefreshIndicator(
        color: theme.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded,
                        size: 18, color: theme.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      '${_items.length}${_hasMore ? '+' : ''} favori'
                      '${_items.length > 1 ? 's' : ''}',
                      style: theme.titleSmall
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      'Plus récents',
                      style: theme.labelMedium
                          .copyWith(color: theme.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.52,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                  childCount: _items.length,
                ),
              ),
            ),
            if (_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: theme.primary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return SizedBox(width: widget.width, height: widget.height, child: body);
  }

  Widget _emptyState(
    FlutterFlowTheme theme, {
    required IconData icon,
    required String title,
    required String text,
  }) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.tertiary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: theme.tertiary),
              ),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style:
                      theme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(text,
                  textAlign: TextAlign.center,
                  style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualiser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primary,
                  side: BorderSide(color: theme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
}
