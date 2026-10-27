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

import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/firebase_service.dart';

/// Section « Avis » de la fiche d'un titre (membre 1, cahier des charges 6.6) :
/// note moyenne des avis publics, avis du membre (donner, modifier,
/// supprimer, option privé), avis des autres membres paginés et likes.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({
    super.key,
    this.width,
    this.height,
    required this.mediaId,
  });

  final double? width;
  final double? height;

  /// Clé du titre : `movie_550`, `series_1399`.
  final String mediaId;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

String _message(Object error, String fallback) =>
    error is CineFailure ? error.message : fallback;

/// Première erreur d'un chargement parallèle (`(a, b, c).wait`).
Object _firstError(Object error) {
  if (error is ParallelWaitError) {
    final errors = error.errors;
    if (errors is (AsyncError?, AsyncError?, AsyncError?)) {
      final first = errors.$1 ?? errors.$2 ?? errors.$3;
      if (first != null) {
        return first.error;
      }
    }
  }
  return error;
}

String _ratingText(num value) =>
    value.toStringAsFixed(value is int ? 0 : 1).replaceAll('.', ',');

class _ReviewsSectionState extends State<ReviewsSection> {
  CineFirebaseService get _service => CineFirebaseService.instance;

  ReviewStats? _stats;
  Review? _mine;
  final _reviews = <Review>[];
  final _liked = <String>{};
  final _likeBusy = <String>{};
  Object? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ReviewsSection oldWidget) {
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
      _moreError = null;
    });
    try {
      final (stats, mine, page) = await (
        _service.reviewStats(widget.mediaId),
        _service.fetchMyReview(widget.mediaId),
        _service.fetchReviews(widget.mediaId),
      ).wait;
      final liked =
          await _service.likedReviewIds(page.reviews.map((r) => r.id));
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
        _mine = mine;
        _reviews
          ..clear()
          ..addAll(page.reviews);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _liked
          ..clear()
          ..addAll(liked);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(_firstError(error), 'Impossible de charger les avis.');
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page =
          await _service.fetchReviews(widget.mediaId, after: _cursor);
      final liked =
          await _service.likedReviewIds(page.reviews.map((r) => r.id));
      if (!mounted) {
        return;
      }
      final known = _reviews.map((r) => r.id).toSet();
      setState(() {
        _reviews.addAll(page.reviews.where((r) => !known.contains(r.id)));
        _liked.addAll(liked);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _moreError =
            _message(error, 'Impossible de charger la suite des avis.'));
      }
    }
    if (mounted) {
      setState(() => _loadingMore = false);
    }
  }

  /// Le nouveau message remplace le précédent au lieu d'attendre sa fin.
  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _replace(Review review) {
    final index = _reviews.indexWhere((r) => r.id == review.id);
    if (index >= 0) {
      _reviews[index] = review;
    }
  }

  /// Mise à jour optimiste : le cœur et le compteur changent tout de suite,
  /// et reviennent en arrière si Firestore refuse.
  Future<void> _toggleLike(Review review) async {
    if (_service.currentUserId == null) {
      _snack('Connectez-vous pour aimer un avis.');
      return;
    }
    if (_likeBusy.contains(review.id)) {
      return;
    }
    final wasLiked = _liked.contains(review.id);
    setState(() {
      _likeBusy.add(review.id);
      wasLiked ? _liked.remove(review.id) : _liked.add(review.id);
      _replace(review.copyWith(
          likesCount: review.likesCount + (wasLiked ? -1 : 1)));
    });
    try {
      await _service.toggleReviewLike(review.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          wasLiked ? _liked.add(review.id) : _liked.remove(review.id);
          _replace(review);
        });
        _snack(_message(error, 'Impossible d\'enregistrer le like.'));
      }
    }
    if (mounted) {
      setState(() => _likeBusy.remove(review.id));
    }
  }

  Future<void> _openForm() async {
    if (_service.currentUserId == null) {
      _snack('Connectez-vous pour donner votre avis.');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewForm(mediaId: widget.mediaId, existing: _mine),
    );
    if (saved == true && mounted) {
      _snack(_mine == null ? 'Avis publié.' : 'Avis modifié.');
      await _load();
    }
  }

  Future<void> _deleteMine() async {
    final mine = _mine;
    if (mine == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer votre avis ?'),
        content: const Text('Votre note et votre texte seront effacés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _service.deleteReview(mine.id);
      if (mounted) {
        _snack('Avis supprimé.');
        await _load();
      }
    } catch (error) {
      if (mounted) {
        _snack(_message(error, 'Impossible de supprimer l\'avis.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Avis', style: theme.titleMedium)),
                if (!_loading && _error == null) _buildAverage(theme),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildBody(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildAverage(FlutterFlowTheme theme) {
    final stats = _stats;
    if (stats == null || stats.count == 0 || stats.average == null) {
      return Text('Aucune note', style: theme.bodySmall);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ratingColor(stats.average),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '★ ${_ratingText(stats.average!)}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 6),
        Text('${stats.count} avis',
            style: theme.bodySmall.copyWith(color: theme.secondaryText)),
      ],
    );
  }

  List<Widget> _buildBody(FlutterFlowTheme theme) {
    if (_loading) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        Text(_error!, style: theme.bodyMedium),
        TextButton(onPressed: _load, child: const Text('Réessayer')),
      ];
    }
    final me = _service.currentUserId;
    final others = _reviews.where((r) => r.userId != me).toList();
    return [
      if (_mine != null)
        _MyReviewCard(
          review: _mine!,
          onEdit: _openForm,
          onDelete: _deleteMine,
        )
      else
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.primary,
            side: BorderSide(color: theme.primary),
          ),
          onPressed: _openForm,
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Donner mon avis'),
        ),
      const SizedBox(height: 16),
      if (others.isEmpty)
        Text(
          _mine == null
              ? 'Aucun avis pour l\'instant. Soyez le premier !'
              : 'Aucun autre avis pour l\'instant.',
          style: theme.bodyMedium.copyWith(color: theme.secondaryText),
        ),
      for (final review in others)
        _ReviewTile(
          review: review,
          liked: _liked.contains(review.id),
          onLike: () => _toggleLike(review),
        ),
      if (_moreError != null)
        Row(
          children: [
            Expanded(child: Text(_moreError!, style: theme.bodySmall)),
            TextButton(onPressed: _loadMore, child: const Text('Réessayer')),
          ],
        )
      else if (_hasMore)
        Center(
          child: _loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _loadMore,
                  child: const Text('Voir plus d\'avis'),
                ),
        ),
    ];
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip(this.rating);

  final int rating;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: ratingColor(rating.toDouble()),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$rating/10',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
}

class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  final Review review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final content = review.content?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border.all(color: theme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Votre avis',
                  style: theme.bodyMedium
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              _RatingChip(review.rating),
              if (review.isPrivate) ...[
                const SizedBox(width: 8),
                Icon(Icons.lock_outline, size: 16, color: theme.secondaryText),
                const SizedBox(width: 2),
                Text('Privé', style: theme.bodySmall),
              ],
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(content, style: theme.bodyMedium),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onEdit, child: const Text('Modifier')),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: theme.error),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatefulWidget {
  const _ReviewTile({
    required this.review,
    required this.liked,
    required this.onLike,
  });

  final Review review;
  final bool liked;
  final VoidCallback onLike;

  @override
  State<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<_ReviewTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final review = widget.review;
    final name = review.authorUsername?.trim().isNotEmpty == true
        ? review.authorUsername!.trim()
        : 'Membre';
    final content = review.content?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.primary,
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium
                              .copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    _RatingChip(review.rating),
                  ],
                ),
                Text(formatReleaseDate(review.createdAt.toLocal()),
                    style: theme.bodySmall
                        .copyWith(color: theme.secondaryText)),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      content,
                      maxLines: _expanded ? null : 5,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: theme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: widget.liked ? 'Je n\'aime plus' : 'J\'aime',
                onPressed: widget.onLike,
                icon: Icon(
                  widget.liked ? Icons.favorite : Icons.favorite_border,
                  color: widget.liked ? theme.error : theme.secondaryText,
                ),
              ),
              Text('${review.likesCount}', style: theme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formulaire d'avis en bottom sheet : note de 1 à 10, texte facultatif et
/// option privé. Se ferme avec `true` une fois l'avis enregistré.
class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.mediaId, this.existing});

  final String mediaId;
  final Review? existing;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  late int _rating = widget.existing?.rating ?? 0;
  late bool _private = widget.existing?.isPrivate ?? false;
  late final _content =
      TextEditingController(text: widget.existing?.content ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = _rating == 0
        ? 'Choisissez une note.'
        : validateReview(_rating, _content.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final text = _content.text.trim();
    try {
      final existing = widget.existing;
      if (existing == null) {
        await CineFirebaseService.instance.createReview(widget.mediaId,
            rating: _rating,
            content: text.isEmpty ? null : text,
            isPrivate: _private);
      } else {
        await CineFirebaseService.instance.updateReview(existing.id,
            rating: _rating,
            content: text.isEmpty ? null : text,
            isPrivate: _private);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(error, 'Impossible d\'enregistrer l\'avis.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Votre avis' : 'Modifier votre avis',
              style: theme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Note', style: theme.bodyMedium),
                const Spacer(),
                Text(_rating == 0 ? '—/10' : '$_rating/10',
                    style: theme.titleSmall),
              ],
            ),
            Row(
              children: [
                for (var star = 1; star <= 10; star++)
                  Expanded(
                    child: InkResponse(
                      key: ValueKey('star$star'),
                      onTap:
                          _saving ? null : () => setState(() => _rating = star),
                      child: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 30,
                        color: star <= _rating
                            ? theme.warning
                            : theme.secondaryText,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Qu\'avez-vous pensé de ce titre ? (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _private,
              onChanged: _saving ? null : (v) => setState(() => _private = v),
              title: const Text('Avis privé'),
              subtitle: const Text('Visible par vous seulement'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: theme.bodySmall.copyWith(color: theme.error)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: theme.primary),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.existing == null ? 'Publier' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
