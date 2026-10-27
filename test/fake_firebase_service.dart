import 'dart:async';
import 'dart:typed_data';

import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

class _UnusedFirestore extends Mock implements FirebaseFirestore {}

/// Service Firestore en mémoire pour les tests de widgets : favoris, vus et
/// avatar du membre [userId] (null = déconnecté). Chaque appel est noté dans
/// [calls].
class FakeCineFirebaseService extends CineFirebaseService {
  FakeCineFirebaseService({this.userId = 'u1'})
      : super(_UnusedFirestore(), currentUserId: null);

  String? userId;
  final favorites = <String>{};
  final watched = <String>{};
  final calls = <String>[];
  Uint8List? avatar;

  @override
  String? get currentUserId => userId;

  String _requireUser() {
    if (userId == null) {
      throw const CineFailure(
          CineFailureKind.unauthenticated, 'Connectez-vous pour continuer.');
    }
    return userId!;
  }

  @override
  Future<bool> isFavorite(String mediaId) async {
    calls.add('isFavorite $mediaId');
    return favorites.contains(mediaId);
  }

  /// Les écritures de favoris / vus échouent (réseau) tant que c'est vrai.
  bool failWrites = false;

  /// Écritures en attente (hors connexion) : complétées par [flushWrites].
  bool holdWrites = false;
  final _held = <Completer<void>>[];

  Future<void> flushWrites() async {
    for (final write in _held) {
      write.complete();
    }
    _held.clear();
  }

  Future<void> _write(String call, Set<String> target, String id, bool on) async {
    calls.add(call);
    if (failWrites) {
      throw const CineFailure(
          CineFailureKind.network, 'Pas de connexion Internet.');
    }
    on ? target.add(id) : target.remove(id);
    if (holdWrites) {
      final pending = Completer<void>();
      _held.add(pending);
      await pending.future;
    }
  }

  @override
  Future<void> writeFavorite(String key, bool favorite) =>
      _write('setFavorite $key $favorite', favorites, key, favorite);

  @override
  Future<void> writeWatched(String key, bool watched) =>
      _write('setWatched $key $watched', this.watched, key, watched);

  @override
  Future<bool> toggleFavorite(String mediaId) async {
    final value = !favorites.contains(mediaId);
    await setFavorite(mediaId, value);
    return value;
  }

  @override
  Future<bool> isWatched(String mediaId) async {
    calls.add('isWatched $mediaId');
    return watched.contains(mediaId);
  }

  @override
  Future<bool> toggleWatched(String mediaId) async {
    final value = !watched.contains(mediaId);
    await setWatched(mediaId, value);
    return value;
  }

  @override
  Future<void> uploadAvatar(Uint8List bytes) async {
    _requireUser();
    calls.add('uploadAvatar ${bytes.length}');
    avatar = bytes;
  }

  /// Statistiques renvoyées par [fetchMyStats] (null = calculées à partir
  /// de [favorites] et [watched] sans catalogue).
  UserStats? stats;

  @override
  Future<UserStats> fetchMyStats() async {
    calls.add('fetchMyStats');
    return stats ??
        computeUserStats(
            watchedKeys: watched, favoriteKeys: favorites, catalogByKey: {});
  }

  // Avis : reviews[] du plus récent au plus ancien, likes = ids likés.
  final reviews = <Review>[];
  final likedReviews = <String>{};
  bool failLikes = false;
  var _reviewSeq = 0;

  Review addReview(String userId, int rating,
      {String? content, String? username, bool isPrivate = false}) {
    final review = Review(
      id: 'r${++_reviewSeq}',
      userId: userId,
      movieId: 'movie_550',
      rating: rating,
      content: content,
      isPrivate: isPrivate,
      createdAt: DateTime.utc(2026, 10, 27),
      authorUsername: username ?? userId,
    );
    reviews.insert(0, review);
    return review;
  }

  Iterable<Review> get _public => reviews.where((r) => !r.isPrivate);

  @override
  Future<ReviewStats> reviewStats(String key) async {
    final public = _public.toList();
    return ReviewStats(
      count: public.length,
      average: public.isEmpty
          ? null
          : public.map((r) => r.rating).reduce((a, b) => a + b) /
              public.length,
    );
  }

  @override
  Future<ReviewPage> fetchReviews(String key,
      {Object? after, int pageSize = kPageSize}) async {
    calls.add('fetchReviews ${after ?? 0}');
    final start = (after as int?) ?? 0;
    final page = _public.skip(start).take(pageSize).toList();
    return ReviewPage(
      reviews: page,
      cursor: start + page.length,
      hasMore: page.length == pageSize,
    );
  }

  @override
  Future<Review?> fetchMyReview(String key) async =>
      reviews.where((r) => r.userId == userId).firstOrNull;

  @override
  Future<Set<String>> likedReviewIds(Iterable<String> reviewIds) async =>
      reviewIds.where(likedReviews.contains).toSet();

  @override
  Future<String> createReview(String key,
      {required int rating, String? content, bool isPrivate = false}) async {
    final user = _requireUser();
    calls.add('createReview $rating ${content ?? '-'} $isPrivate');
    return addReview(user, rating,
            content: content, username: 'moi', isPrivate: isPrivate)
        .id;
  }

  @override
  Future<void> updateReview(String reviewId,
      {required int rating, String? content, required bool isPrivate}) async {
    calls.add('updateReview $reviewId $rating ${content ?? '-'} $isPrivate');
    final index = reviews.indexWhere((r) => r.id == reviewId);
    reviews[index] = reviews[index]
        .copyWith(rating: rating, content: content, isPrivate: isPrivate);
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    calls.add('deleteReview $reviewId');
    reviews.removeWhere((r) => r.id == reviewId);
  }

  @override
  Future<bool> toggleReviewLike(String reviewId) async {
    _requireUser();
    calls.add('toggleReviewLike $reviewId');
    if (failLikes) {
      throw const CineFailure(
          CineFailureKind.network, 'Pas de connexion Internet.');
    }
    return likedReviews.remove(reviewId) ? false : likedReviews.add(reviewId);
  }
}
