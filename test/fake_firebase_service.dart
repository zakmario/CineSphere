import 'dart:typed_data';

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

  @override
  Future<bool> toggleFavorite(String mediaId) async {
    _requireUser();
    calls.add('toggleFavorite $mediaId');
    return favorites.remove(mediaId) ? false : favorites.add(mediaId);
  }

  @override
  Future<bool> isWatched(String mediaId) async {
    calls.add('isWatched $mediaId');
    return watched.contains(mediaId);
  }

  @override
  Future<bool> toggleWatched(String mediaId) async {
    _requireUser();
    calls.add('toggleWatched $mediaId');
    return watched.remove(mediaId) ? false : watched.add(mediaId);
  }

  @override
  Future<void> uploadAvatar(Uint8List bytes) async {
    _requireUser();
    calls.add('uploadAvatar ${bytes.length}');
    avatar = bytes;
  }
}
