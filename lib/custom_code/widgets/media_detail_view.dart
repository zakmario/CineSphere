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

import 'dart:async';

import '/custom_code/actions/firebase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/custom_code/widgets/trailer_player.dart';

/// Contenu complet de la page détail d'un film ou d'une série :
/// grande image en fondu avec affiche, chiffres clés (note, sortie, durée),
/// genres, plateformes, synopsis dépliable, favori,
/// bande-annonce et prochaines diffusions (avec rappels).
/// Placez-le seul dans une page SANS app bar : il a son propre bouton retour.
class MediaDetailView extends StatefulWidget {
  const MediaDetailView({
    super.key,
    this.width,
    this.height,
    required this.mediaId,
  });

  final double? width;
  final double? height;
  final String mediaId;

  @override
  State<MediaDetailView> createState() => _MediaDetailViewState();
}

class _MediaDetailViewState extends State<MediaDetailView> {
  Map<String, dynamic>? _media;
  bool _loading = true;
  String? _error;
  bool _synopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MediaDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await CineFirebaseService.instance.fetchMedia(widget.mediaId);
      if (!mounted) {
        return;
      }
      setState(() {
        _media = row;
        _loading = false;
        _error = row == null ? 'Contenu introuvable.' : null;
      });
      // Onglet Historique de Favoris (membre 1).
      if (row != null) {
        unawaited(CineFirebaseService.instance.recordView(row));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger ce contenu.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget body;
    if (_loading) {
      body = const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: CineSkeleton(variant: 'detail', itemCount: 5),
      );
    } else if (_media == null) {
      body = Center(
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
                child: Icon(Icons.movie_filter_outlined,
                    size: 40, color: theme.primary),
              ),
              const SizedBox(height: 20),
              Text(_error ?? '',
                  textAlign: TextAlign.center,
                  style:
                      theme.titleMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style:
                    TextButton.styleFrom(foregroundColor: theme.secondaryText),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = _buildContent(theme, _media!);
    }
    return SizedBox(width: widget.width, height: widget.height, child: body);
  }

  Widget _buildContent(FlutterFlowTheme theme, Map<String, dynamic> m) {
    final type = m['media_type'] as String?;
    final rating = (m['rating'] as num?)?.toDouble();
    final releaseDate = m['release_date'] == null
        ? null
        : DateTime.tryParse(m['release_date'] as String);
    final genres = List<String>.from(m['genres'] as List? ?? const []);
    final platforms = List<String>.from(m['platforms'] as List? ?? const []);
    final trailer = m['trailer_url'] as String?;
    final backdrop = m['backdrop_url'] as String?;
    final poster = m['poster_url'] as String?;
    final overview = m['overview'] as String?;
    final upcoming = releaseDate != null && daysUntil(releaseDate) > 0;

    final facts = <String>[
      mediaTypeLabel(type),
      statusLabel(m['status'] as String?),
    ].where((s) => s.isNotEmpty).toList();
    final length = type == 'movie'
        ? formatRuntime(m['runtime_minutes'] as int?)
        : type == 'series'
            ? seasonsLabel(m['seasons'] as int?, m['episodes'] as int?)
            : '';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 360,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: theme.primaryBackground,
          foregroundColor: theme.primaryText,
          leading: _roundButton(
            IconButton(
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          actions: [
            _roundButton(FavoriteButton(mediaId: widget.mediaId, iconSize: 22)),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  bottom: 90,
                  child: backdrop == null || backdrop.isEmpty
                      ? _imageFallback(theme)
                      : CachedNetworkImage(
                          imageUrl: backdrop,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _imageFallback(theme),
                          errorWidget: (_, __, ___) => _imageFallback(theme),
                        ),
                ),
                // Fondu de l'image vers le fond de la page.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                        theme.primaryBackground.withValues(alpha: 0.85),
                        theme.primaryBackground,
                      ],
                      stops: const [0, 0.3, 0.68, 0.78],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 112,
                        height: 168,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: poster == null || poster.isEmpty
                              ? _imageFallback(theme)
                              : CachedNetworkImage(
                                  imageUrl: poster,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _imageFallback(theme),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final f in facts)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      f.toUpperCase(),
                                      style: theme.labelSmall.copyWith(
                                        color: theme.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              m['title'] as String? ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.headlineSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trois chiffres clés.
                Row(
                  children: [
                    _statTile(
                      theme,
                      icon: Icons.star_rounded,
                      iconColor: ratingColor(rating),
                      value: ratingLabel(rating),
                      label: 'Note',
                    ),
                    const SizedBox(width: 10),
                    _statTile(
                      theme,
                      icon: upcoming
                          ? Icons.hourglass_top_rounded
                          : Icons.calendar_today_rounded,
                      iconColor: theme.primary,
                      value: releaseDate == null
                          ? '—'
                          : upcoming
                              ? releaseCountdownLabel(releaseDate)
                              : releaseDate.year.toString(),
                      label: upcoming ? 'Sortie' : 'Année',
                    ),
                    const SizedBox(width: 10),
                    _statTile(
                      theme,
                      icon: type == 'series'
                          ? Icons.video_library_outlined
                          : Icons.schedule_rounded,
                      iconColor: theme.secondary,
                      value: length.isEmpty ? '—' : length,
                      label: type == 'series' ? 'Saisons' : 'Durée',
                    ),
                  ],
                ),
                if (releaseDate != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Sortie : ${formatReleaseDate(releaseDate)}',
                    style: theme.bodySmall.copyWith(color: theme.secondaryText),
                  ),
                ],
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in genres)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.alternate),
                          ),
                          child: Text(g,
                              style: theme.bodySmall
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                if (trailer != null && trailer.isNotEmpty) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: theme.titleSmall
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    // Lecture dans l'application (TrailerPlayer, membre 1).
                    onPressed: () => showTrailerDialog(context, trailer,
                        title: m['title'] as String?),
                    icon: const Icon(Icons.play_arrow_rounded, size: 26),
                    label: const Text('Bande-annonce'),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                        child: AddToWatchlistButton(mediaId: widget.mediaId)),
                    const SizedBox(width: 10),
                    Expanded(child: MarkWatchedButton(mediaId: widget.mediaId)),
                  ],
                ),
                if (platforms.isNotEmpty) ...[
                  _sectionTitle(theme, 'Où regarder'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in platforms)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.secondaryBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.alternate),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.live_tv_rounded,
                                  size: 16, color: theme.primary),
                              const SizedBox(width: 6),
                              Text(p,
                                  style: theme.bodySmall
                                      .copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                _sectionTitle(theme, 'Synopsis'),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: Text(
                    overview == null || overview.isEmpty
                        ? 'Pas de synopsis.'
                        : overview,
                    maxLines: _synopsisExpanded ? null : 4,
                    overflow: _synopsisExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: theme.bodyMedium.copyWith(
                      height: 1.55,
                      color: theme.primaryText.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if ((overview?.length ?? 0) > 180)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primary,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () =>
                        setState(() => _synopsisExpanded = !_synopsisExpanded),
                    child:
                        Text(_synopsisExpanded ? 'Réduire' : 'Lire la suite'),
                  ),
                _sectionTitle(theme, 'Prochaines diffusions'),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: UpcomingReleasesList(
            height: 280,
            mediaId: widget.mediaId,
          ),
        ),
        // Avis (ReviewsSection, membre 1).
        SliverToBoxAdapter(child: ReviewsSection(mediaId: widget.mediaId)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _roundButton(Widget child) => Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Center(child: child),
        ),
      );

  Widget _imageFallback(FlutterFlowTheme theme) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.alternate, theme.accent4],
          ),
        ),
        child: Center(
          child:
              Icon(Icons.movie_outlined, color: theme.secondaryText, size: 40),
        ),
      );

  Widget _statTile(
    FlutterFlowTheme theme, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.alternate),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: theme.labelSmall.copyWith(color: theme.secondaryText)),
            ],
          ),
        ),
      );

  /// Titre de section avec petit trait doré.
  Widget _sectionTitle(FlutterFlowTheme theme, String text) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleLarge
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 19)),
            ),
          ],
        ),
      );
}
