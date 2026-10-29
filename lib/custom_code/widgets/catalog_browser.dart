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
      if (_genre != null &&
          !((row['genres'] as List?) ?? []).contains(_genre)) {
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.alternate,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filtres',
                          style: theme.headlineSmall
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.pop(context, false),
                        icon: Icon(Icons.close_rounded,
                            color: theme.secondaryText),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetTitle(theme, Icons.category_outlined, 'Genre'),
                        if (_genres.isEmpty)
                          Text('Aucun genre disponible.',
                              style: theme.bodySmall
                                  .copyWith(color: theme.secondaryText))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final g in _genres)
                                _choice(
                                    theme,
                                    g,
                                    genre == g,
                                    () => setSheetState(
                                        () => genre = genre == g ? null : g)),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _sheetTitle(theme,
                                  Icons.star_outline_rounded, 'Note minimale'),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                minRating > 0
                                    ? '★ ${minRating.toStringAsFixed(0)}+'
                                    : 'Toutes',
                                style: theme.titleSmall.copyWith(
                                  color: minRating > 0
                                      ? theme.primary
                                      : theme.secondaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: theme.primary,
                            inactiveTrackColor: theme.alternate,
                            thumbColor: theme.primary,
                            overlayColor: theme.primary.withValues(alpha: 0.12),
                            valueIndicatorColor: theme.primary,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: minRating,
                            min: 0,
                            max: 9,
                            divisions: 9,
                            label: minRating.toStringAsFixed(0),
                            onChanged: (v) =>
                                setSheetState(() => minRating = v),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sheetTitle(theme, Icons.event_outlined, 'Statut'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in _statusOptions)
                              _choice(
                                  theme,
                                  statusLabel(s),
                                  status == s,
                                  () => setSheetState(
                                      () => status = status == s ? null : s)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryText,
                            side: BorderSide(color: theme.alternate),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
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
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _sheetTitle(FlutterFlowTheme theme, IconData icon, String text) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.primary),
            const SizedBox(width: 8),
            Text(text,
                style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  /// Pastille de choix : contour discret, remplie en doré si sélectionnée.
  Widget _choice(FlutterFlowTheme theme, String label, bool selected,
          VoidCallback onTap) =>
      Material(
        color: selected ? theme.primary : theme.primaryBackground,
        shape: StadiumBorder(
          side: BorderSide(
              color: selected ? theme.primary : theme.alternate, width: 1),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: theme.bodyMedium.copyWith(
                color: selected ? Colors.white : theme.primaryText,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          _buildSearchBar(theme),
          _buildTypeSelector(theme),
          _buildSortRow(theme),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(FlutterFlowTheme theme) {
    final active = _activeFilterCount > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: theme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Rechercher un film, une série…',
                hintStyle:
                    theme.bodyMedium.copyWith(color: theme.secondaryText),
                prefixIcon:
                    Icon(Icons.search_rounded, color: theme.secondaryText),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (_, value, __) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: theme.secondaryText),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
                filled: true,
                fillColor: theme.secondaryBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.alternate),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: active,
            label: Text('$_activeFilterCount'),
            backgroundColor: theme.tertiary,
            child: Material(
              color: active ? theme.primary : theme.secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side:
                    BorderSide(color: active ? theme.primary : theme.alternate),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openFilters,
                child: Tooltip(
                  message: 'Filtres',
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.tune_rounded,
                        color: active ? Colors.white : theme.primaryText),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sélecteur segmenté Tous / Films / Séries.
  Widget _buildTypeSelector(FlutterFlowTheme theme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.alternate),
          ),
          child: Row(
            children: [
              for (final type in const [null, 'movie', 'series'])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_mediaType != type) {
                        _mediaType = type;
                        _reload();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _mediaType == type
                            ? theme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        switch (type) {
                          'movie' => 'Films',
                          'series' => 'Séries',
                          _ => 'Tous',
                        },
                        style: theme.bodyMedium.copyWith(
                          color: _mediaType == type
                              ? Colors.white
                              : theme.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildSortRow(FlutterFlowTheme theme) {
    final hasAnyFilter =
        _activeFilterCount > 0 || _query.isNotEmpty || _sort != 'popularity';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _items.isEmpty
                  ? ''
                  : '${_items.length}${_hasMore ? '+' : ''} titre'
                      '${_items.length > 1 ? 's' : ''}',
              style: theme.labelMedium.copyWith(color: theme.secondaryText),
            ),
          ),
          if (hasAnyFilter)
            TextButton(
              onPressed: _clearFilters,
              style: TextButton.styleFrom(foregroundColor: theme.tertiary),
              child: const Text('Effacer'),
            ),
          PopupMenuButton<String>(
            tooltip: 'Trier',
            initialValue: _sort,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded, size: 18, color: theme.primary),
                  const SizedBox(width: 4),
                  Text(
                    _sortOptions[_sort]!.label,
                    style: theme.labelLarge.copyWith(
                      color: theme.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.expand_more_rounded,
                      size: 18, color: theme.secondaryText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(FlutterFlowTheme theme) {
    if (_items.isEmpty && _loading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: CineSkeleton(variant: 'grid', itemCount: 9),
      );
    }
    if (_items.isEmpty && _error != null) {
      return _message(
        theme,
        Icons.wifi_off_rounded,
        _error!,
        'Vérifiez votre connexion puis réessayez.',
        retry: true,
      );
    }
    if (_items.isEmpty && !_hasMore) {
      return _message(
        theme,
        Icons.search_off_rounded,
        _query.isEmpty ? 'Aucun résultat' : 'Aucun résultat pour « $_query »',
        _query.isEmpty
            ? 'Aucun contenu ne correspond à ces filtres.'
            : 'Essayez un autre mot-clé ou retirez des filtres.',
      );
    }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () async => _reload(),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: theme.primary),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          style: TextButton.styleFrom(foregroundColor: theme.primary),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Erreur de chargement — réessayer'),
        ),
      );
    }
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Row(
          children: [
            Expanded(child: Divider(color: theme.alternate)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Vous avez tout vu',
                style: theme.bodySmall.copyWith(color: theme.secondaryText),
              ),
            ),
            Expanded(child: Divider(color: theme.alternate)),
          ],
        ),
      );
    }
    return const SizedBox(height: 48);
  }

  Widget _message(
    FlutterFlowTheme theme,
    IconData icon,
    String title,
    String text, {
    bool retry = false,
  }) =>
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: theme.primary),
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
              if (retry)
                FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Effacer les filtres'),
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
