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
import 'dart:async';

/// Catalogue films + séries avec :
/// - recherche par contenu (titre et synopsis, avec délai de saisie),
/// - filtres (type, genre, note minimale, statut),
/// - tri (popularité, note, date, alphabétique),
/// - pagination avec chargement progressif (scroll infini) sur le catalogue
///   Firestore gardé en mémoire (CineFirebaseService.catalog).
///
/// Dans FlutterFlow, donnez-lui une hauteur (ou cochez "Expanded") car la
/// grille défile à l'intérieur du widget.
class CatalogBrowser extends StatefulWidget {
  const CatalogBrowser({
    super.key,
    this.width,
    this.height,
    this.pageSize,
    this.initialMediaType,
    this.onItemTap,
  });

  final double? width;
  final double? height;

  /// Nombre d'éléments chargés par page (20 par défaut).
  final int? pageSize;

  /// 'movie', 'series' ou vide pour tout afficher.
  final String? initialMediaType;
  final Future Function(String mediaId)? onItemTap;

  @override
  State<CatalogBrowser> createState() => _CatalogBrowserState();
}

class _SortOption {
  const _SortOption(this.label, this.column, this.ascending);
  final String label;
  final String column;
  final bool ascending;
}

const _sortOptions = <String, _SortOption>{
  'popularity': _SortOption('Plus populaires', 'popularity', false),
  'rating': _SortOption('Meilleure note', 'rating', false),
  'recent': _SortOption('Plus récents', 'release_date', false),
  'title': _SortOption('Ordre alphabétique', 'title', true),
};

const _statusOptions = <String>['released', 'ongoing', 'upcoming', 'ended'];

class _CatalogBrowserState extends State<CatalogBrowser> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  // Filtres actifs
  String _query = '';
  String? _mediaType;
  String? _genre;
  double _minRating = 0;
  String? _status;
  String _sort = 'popularity';

  // Pagination
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _requestId = 0;

  List<String> _genres = [];

  int get _pageSize => (widget.pageSize ?? 20).clamp(5, 100);

  int get _activeFilterCount =>
      (_genre != null ? 1 : 0) +
      (_minRating > 0 ? 1 : 0) +
      (_status != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    final type = widget.initialMediaType;
    _mediaType = (type == 'movie' || type == 'series') ? type : null;
    _scrollController.addListener(_onScroll);
    _loadGenres();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await CineFirebaseService.instance.fetchGenres();
      if (mounted) {
        setState(() {
          _genres = genres.map((g) => g.name).toList();
        });
      }
    } catch (_) {
      // La feuille de filtres affichera simplement aucun genre.
    }
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (value.trim() != _query) {
        _query = value.trim();
        _reload();
      }
    });
  }

  /// Repart de la première page (changement de recherche, filtre ou tri).
  void _reload() {
    _requestId++;
    setState(() {
      _items.clear();
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (!mounted || _loading || !_hasMore) {
      return;
    }
    final requestId = _requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final from = _items.length;
      final rows = await _fetchPage(from, from + _pageSize - 1);
      // Une recherche plus récente a été lancée : on ignore cette réponse.
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _items.addAll(rows);
        _hasMore = rows.length == _pageSize;
        _loading = false;
      });
      // Si la première page ne remplit pas l'écran, on charge la suivante.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent == 0) {
          _loadMore();
        }
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Impossible de charger le catalogue.';
      });
    }
  }

  /// Charge les lignes [from]..[to] du catalogue avec la recherche, les
  /// filtres et le tri en cours. Firestore n'a pas de recherche « contient »
  /// (ilike) : on filtre la copie du catalogue gardée en mémoire.
  Future<List<Map<String, dynamic>>> _fetchPage(int from, int to) async {
    final query = _query.toLowerCase();
    bool contains(Object? text) =>
        text is String && text.toLowerCase().contains(query);
    final rows = (await CineFirebaseService.instance.catalog()).where((row) {
      if (query.isNotEmpty &&
          !contains(row['title']) &&
          !contains(row['overview'])) {
        return false;
      }
      if (_mediaType != null && row['media_type'] != _mediaType) {
        return false;
      }
      if (_genre != null && !((row['genres'] as List?) ?? []).contains(_genre)) {
        return false;
      }
      if (_minRating > 0 && ((row['rating'] as num?) ?? 0) < _minRating) {
        return false;
      }
      return _status == null || row['status'] == _status;
    }).toList();

    final sort = _sortOptions[_sort]!;
    // Valeurs manquantes en dernier, puis id : pagination stable.
    rows.sort((a, b) {
      final va = a[sort.column] as Comparable?;
      final vb = b[sort.column] as Comparable?;
      if (va == null || vb == null) {
        if (va != vb) {
          return va == null ? 1 : -1;
        }
      } else {
        final c = sort.column == 'title'
            ? '$va'.toLowerCase().compareTo('$vb'.toLowerCase())
            : va.compareTo(vb);
        if (c != 0) {
          return sort.ascending ? c : -c;
        }
      }
      return '${a['id']}'.compareTo('${b['id']}');
    });
    return rows.sublist(min(from, rows.length), min(to + 1, rows.length));
  }

  void _clearFilters() {
    _searchController.clear();
    _query = '';
    _genre = null;
    _minRating = 0;
    _status = null;
    _sort = 'popularity';
    _reload();
  }

  Future<void> _openFilters() async {
    var genre = _genre;
    var minRating = _minRating;
    var status = _status;
    final theme = FlutterFlowTheme.of(context);

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filtres', style: theme.titleLarge),
                  const SizedBox(height: 16),
                  Text('Genre', style: theme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _genres
                        .map((g) => ChoiceChip(
                              label: Text(g),
                              selected: genre == g,
                              onSelected: (selected) => setSheetState(
                                  () => genre = selected ? g : null),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    minRating > 0
                        ? 'Note minimale : ${minRating.toStringAsFixed(0)}/10'
                        : 'Note minimale : aucune',
                    style: theme.titleSmall,
                  ),
                  Slider(
                    value: minRating,
                    min: 0,
                    max: 9,
                    divisions: 9,
                    label: minRating.toStringAsFixed(0),
                    onChanged: (v) => setSheetState(() => minRating = v),
                  ),
                  Text('Statut', style: theme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statusOptions
                        .map((s) => ChoiceChip(
                              label: Text(statusLabel(s)),
                              selected: status == s,
                              onSelected: (selected) => setSheetState(
                                  () => status = selected ? s : null),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(() {
                            genre = null;
                            minRating = 0;
                            status = null;
                          }),
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (apply == true) {
      _genre = genre;
      _minRating = minRating;
      _status = status;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          _buildSearchBar(theme),
          _buildTypeAndSortRow(theme),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(FlutterFlowTheme theme) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un film, une série…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (_, value, __) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                  filled: true,
                  fillColor: theme.secondaryBackground,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              backgroundColor: theme.primary,
              child: IconButton.filledTonal(
                tooltip: 'Filtres',
                onPressed: _openFilters,
                icon: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
      );

  Widget _buildTypeAndSortRow(FlutterFlowTheme theme) {
    final hasAnyFilter = _activeFilterCount > 0 ||
        _query.isNotEmpty ||
        _sort != 'popularity';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final type in const [null, 'movie', 'series'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(type == null ? 'Tous' : mediaTypeLabel(type)),
                selected: _mediaType == type,
                selectedColor: theme.primary.withValues(alpha: 0.2),
                onSelected: (_) {
                  if (_mediaType != type) {
                    _mediaType = type;
                    _reload();
                  }
                },
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Trier',
            initialValue: _sort,
            onSelected: (value) {
              if (value != _sort) {
                _sort = value;
                _reload();
              }
            },
            itemBuilder: (_) => _sortOptions.entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: Text(e.value.label),
                    ))
                .toList(),
            child: Chip(
              avatar: const Icon(Icons.sort, size: 18),
              label: Text(_sortOptions[_sort]!.label),
            ),
          ),
          if (hasAnyFilter)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Effacer les filtres'),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(FlutterFlowTheme theme) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return _message(theme, Icons.wifi_off, _error!, retry: true);
    }
    if (_items.isEmpty && !_hasMore) {
      return _message(
        theme,
        Icons.search_off,
        _query.isEmpty
            ? 'Aucun contenu ne correspond à ces filtres.'
            : 'Aucun résultat pour « $_query ».',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
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
                    onTap: widget.onItemTap == null
                        ? null
                        : () => widget.onItemTap!(id),
                  );
                },
                childCount: _items.length,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFooter(theme)),
        ],
      ),
    );
  }

  Widget _buildFooter(FlutterFlowTheme theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Erreur de chargement — réessayer'),
        ),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            '${_items.length} résultat${_items.length > 1 ? 's' : ''} — '
            'vous avez tout vu !',
            style: theme.bodySmall.copyWith(color: theme.secondaryText),
          ),
        ),
      );
    }
    return const SizedBox(height: 48);
  }

  Widget _message(
    FlutterFlowTheme theme,
    IconData icon,
    String text, {
    bool retry = false,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.secondaryText),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center, style: theme.bodyMedium),
              const SizedBox(height: 12),
              if (retry)
                FilledButton(onPressed: _reload, child: const Text('Réessayer'))
              else
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Effacer les filtres'),
                ),
            ],
          ),
        ),
      );
}
