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
import 'package:cached_network_image/cached_network_image.dart';
import '/custom_code/widgets/trailer_player.dart';

/// Contenu complet de la page détail d'un film ou d'une série :
/// image de couverture, infos, genres, plateformes, synopsis, favori,
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
      body = const Center(child: CircularProgressIndicator());
    } else if (_media == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? '', style: theme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Retour'),
            ),
          ],
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

    final facts = <String>[
      mediaTypeLabel(type),
      if (releaseDate != null) releaseDate.year.toString(),
      if (type == 'movie') formatRuntime(m['runtime_minutes'] as int?),
      if (type == 'series')
        seasonsLabel(m['seasons'] as int?, m['episodes'] as int?),
      statusLabel(m['status'] as String?),
    ].where((s) => s.isNotEmpty).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: theme.primaryBackground,
          foregroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: FavoriteButton(mediaId: widget.mediaId, iconSize: 22),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: backdrop == null
                ? Container(color: theme.alternate)
                : CachedNetworkImage(imageUrl: backdrop, fit: BoxFit.cover),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 100,
                        height: 150,
                        child: poster == null
                            ? Container(color: theme.alternate)
                            : CachedNetworkImage(
                                imageUrl: poster, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['title'] as String? ?? '',
                              style: theme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(facts.join(' • '),
                              style: theme.bodySmall
                                  .copyWith(color: theme.secondaryText)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ratingColor(rating),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '★ ${ratingLabel(rating)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (releaseDate != null)
                                Flexible(
                                  child: Text(
                                    daysUntil(releaseDate) > 0
                                        ? releaseCountdownLabel(releaseDate)
                                        : formatReleaseDate(releaseDate),
                                    style: theme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (genres.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: genres
                        .map((g) => Chip(
                              label: Text(g),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                if (platforms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.live_tv, size: 18, color: theme.secondaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Disponible sur : ${platforms.join(', ')}',
                            style: theme.bodyMedium),
                      ),
                    ],
                  ),
                ],
                if (trailer != null && trailer.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: theme.primary),
                    // Lecture dans l'application (TrailerPlayer, membre 1).
                    onPressed: () => showTrailerDialog(context, trailer,
                        title: m['title'] as String?),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Bande-annonce'),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: AddToWatchlistButton(mediaId: widget.mediaId)),
                    const SizedBox(width: 8),
                    Expanded(child: MarkWatchedButton(mediaId: widget.mediaId)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Synopsis', style: theme.titleMedium),
                const SizedBox(height: 8),
                Text(m['overview'] as String? ?? 'Pas de synopsis.',
                    style: theme.bodyMedium),
                const SizedBox(height: 24),
                Text('Prochaines diffusions', style: theme.titleMedium),
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
      ],
    );
  }
}
