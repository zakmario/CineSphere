// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '/custom_code/actions/cine_models.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Vérifie que Firestore répond et que le catalogue CinéSphère est installé.
/// Action FlutterFlow (et point d'ancrage de la synchronisation du service).
Future<bool> firestoreService() async {
  try {
    await FirestoreService.instance.fetchGenres();
    return true;
  } on CineFailure catch (failure) {
    developer.log(failure.message, name: 'FirestoreService');
    return false;
  }
}

/// Nombre d'éléments par page (cahier des charges, section 6.4).
const int kPageSize = 20;

/// Bornes inclusives de la page [page] (0 = première).
({int from, int to}) pageRange(int page, {int pageSize = kPageSize}) {
  assert(page >= 0 && pageSize > 0);
  final from = page * pageSize;
  return (from: from, to: from + pageSize - 1);
}

/// Erreur typée, avec un message en français prêt à afficher.
class CineFailure implements Exception {
  const CineFailure(this.kind, this.message, [this.cause]);

  final CineFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CineFailure(${kind.name}): $message';
}

enum CineFailureKind {
  network,
  unauthenticated,
  forbidden,
  conflict,
  notFound,
  invalid,
  unknown,
}

/// SocketException (dart:io, absent sur le web) et ClientException (http)
/// sont reconnues par leur nom pour rester compatible avec toutes les cibles.
bool _isNetworkError(Object error) {
  final type = error.runtimeType.toString();
  return type.contains('SocketException') ||
      type.contains('ClientException') ||
      type.contains('HttpException');
}

/// Traduit une erreur Firestore / réseau en [CineFailure].
CineFailure mapFirestoreError(Object error) {
  if (error is CineFailure) {
    return error;
  }
  if (error is TimeoutException || _isNetworkError(error)) {
    return CineFailure(CineFailureKind.network,
        'Pas de connexion Internet. Réessayez plus tard.', error);
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return CineFailure(CineFailureKind.network,
            'Pas de connexion Internet. Réessayez plus tard.', error);
      case 'unauthenticated':
        return CineFailure(CineFailureKind.unauthenticated,
            'Votre session a expiré. Reconnectez-vous.', error);
      case 'permission-denied':
        return CineFailure(CineFailureKind.forbidden,
            'Vous n\'avez pas le droit d\'effectuer cette action.', error);
      case 'already-exists':
        return CineFailure(
            CineFailureKind.conflict, 'Cet élément existe déjà.', error);
      case 'not-found':
        return CineFailure(
            CineFailureKind.notFound, 'Élément introuvable.', error);
      case 'invalid-argument':
      case 'failed-precondition':
        return CineFailure(
            CineFailureKind.invalid, 'Données invalides.', error);
    }
  }
  return CineFailure(
      CineFailureKind.unknown, 'Une erreur inattendue est survenue.', error);
}

/// Pseudo : 3 à 24 caractères, lettres, chiffres, « _ », « . » ou « - ».
/// Renvoie un message d'erreur en français, ou null si valide.
String? validateUsername(String? value) {
  final username = value?.trim() ?? '';
  if (username.length < 3) {
    return 'Le pseudo doit contenir au moins 3 caractères.';
  }
  if (username.length > 24) {
    return 'Le pseudo ne doit pas dépasser 24 caractères.';
  }
  if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(username)) {
    return 'Utilisez seulement des lettres, chiffres, « _ », « . » ou « - ».';
  }
  return null;
}

/// Nom de liste : 1 à 60 caractères (règle Firestore de watchlists).
/// Renvoie un message d'erreur en français, ou null si valide.
String? validateWatchlistName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Donnez un nom à la liste.';
  }
  if (name.length > 60) {
    return 'Le nom ne doit pas dépasser 60 caractères.';
  }
  return null;
}

/// Taille maximale d'un avatar enregistré dans le profil (le document
/// Firestore est limité à 1 Mo ; l'image est compressée avant l'envoi).
const int kMaxAvatarBytes = 300 * 1024;

// Conversion des documents ---------------------------------------------------
//
// Les modèles (cine_models.dart) et les widgets lisent des lignes au format
// des anciennes tables : clés snake_case, dates ISO 8601, `id` inclus.
// Firestore stocke des champs camelCase et des Timestamp.

String _snake(String key) =>
    key.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

String _camel(String key) =>
    key.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase());

Object? _fromFirestore(Object? value) => switch (value) {
      Timestamp t => t.toDate().toUtc().toIso8601String(),
      List l => l.map(_fromFirestore).toList(),
      Map m => {
          for (final e in m.entries) _snake('${e.key}'): _fromFirestore(e.value)
        },
      _ => value,
    };

/// Document Firestore -> ligne `{id, cle_snake_case: valeur}`.
Map<String, dynamic> cineRow(DocumentSnapshot<Object?> doc) {
  final data = (doc.data() as Map<String, dynamic>?) ?? const {};
  return {
    for (final e in data.entries) _snake(e.key): _fromFirestore(e.value),
    'id': doc.id,
  };
}

const _dateKeys = {
  'created_at',
  'updated_at',
  'release_date',
  'release_at',
  'published_at',
  'watched_at',
  'added_at',
  'scheduled_at',
  'details_synced_at',
};

/// Ligne snake_case -> champs Firestore (camelCase, dates en Timestamp).
/// La clé `id` est ignorée : c'est l'identifiant du document.
Map<String, dynamic> toFirestoreFields(Map<String, dynamic> row) => {
      for (final e in row.entries)
        if (e.key != 'id')
          _camel(e.key): _dateKeys.contains(e.key) && e.value is String
              ? Timestamp.fromDate(DateTime.parse(e.value as String))
              : e.value,
    };

/// Identifiant déterministe d'un favori / d'un titre vu.
String userMediaDocId(String userId, String mediaId) => '${userId}_$mediaId';

/// Identifiant déterministe d'un titre dans une liste.
String watchlistItemDocId(String watchlistId, String mediaId) =>
    '${watchlistId}_$mediaId';

/// Accès aux données utilisateur et au catalogue dans Firestore.
///
/// Toutes les méthodes lèvent une [CineFailure] en cas d'erreur.
class FirestoreService {
  /// [currentUserId] remplace la session Firebase (tests).
  FirestoreService(this._db, {String? Function()? currentUserId})
      : _currentUserId = currentUserId;

  static final FirestoreService instance =
      FirestoreService(FirebaseFirestore.instance);

  final FirebaseFirestore _db;
  final String? Function()? _currentUserId;

  CollectionReference<Map<String, dynamic>> col(String name) =>
      _db.collection(name);

  String? get currentUserId {
    final override = _currentUserId;
    return override != null
        ? override()
        : fb.FirebaseAuth.instance.currentUser?.uid;
  }

  String get requireUserId {
    final id = currentUserId;
    if (id == null) {
      throw const CineFailure(
          CineFailureKind.unauthenticated, 'Connectez-vous pour continuer.');
    }
    return id;
  }

  Future<T> guard<T>(String operation, Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, stack) {
      final failure = mapFirestoreError(error);
      developer.log('$operation : ${failure.kind.name}',
          name: 'FirestoreService', error: error, stackTrace: stack);
      throw failure;
    }
  }

  // Profil -----------------------------------------------------------------

  Future<UserProfile?> fetchProfile([String? userId]) =>
      guard('fetchProfile', () async {
        final doc = await col('users').doc(userId ?? requireUserId).get();
        return doc.exists ? UserProfile.fromJson(cineRow(doc)) : null;
      });

  /// Vrai si le pseudo est libre (ou déjà celui de l'utilisateur).
  /// Utilisable avant l'inscription (collection `usernames` en lecture libre).
  Future<bool> isUsernameAvailable(String username) =>
      guard('isUsernameAvailable', () async {
        final doc =
            await col('usernames').doc(username.trim().toLowerCase()).get();
        return !doc.exists || doc.data()?['userId'] == currentUserId;
      });

  /// Crée le profil et réserve le pseudo (après la création du compte).
  /// Échoue avec [CineFailureKind.conflict] si le pseudo est déjà pris.
  Future<void> createProfile({
    required String userId,
    required String username,
    required String email,
  }) =>
      guard('createProfile', () async {
        final name = username.trim();
        final now = FieldValue.serverTimestamp();
        final batch = _db.batch()
          ..set(col('usernames').doc(name.toLowerCase()),
              {'userId': userId, 'username': name})
          ..set(col('users').doc(userId), {
            'id': userId,
            'username': name,
            'usernameLower': name.toLowerCase(),
            'email': email,
            'role': 'user',
            'createdAt': now,
            'updatedAt': now,
            ...toFirestoreFields(UserPreferences(userId: userId).toJson()
              ..remove('user_id')
              ..remove('updated_at')),
          });
        try {
          await batch.commit();
        } on FirebaseException catch (error) {
          // Un pseudo existant ne peut pas être réécrit (règle usernames).
          if (error.code == 'permission-denied') {
            throw CineFailure(
                CineFailureKind.conflict, 'Ce pseudo est déjà utilisé.', error);
          }
          rethrow;
        }
      });

  Future<UserProfile> updateProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) =>
      guard('updateProfile', () async {
        final userId = requireUserId;
        if (username != null) {
          final error = validateUsername(username);
          if (error != null) {
            throw CineFailure(CineFailureKind.invalid, error);
          }
        }
        final userRef = col('users').doc(userId);
        await _db.runTransaction((tx) async {
          final current = await tx.get(userRef);
          final oldName = current.data()?['username'] as String? ?? '';
          final changes = <String, dynamic>{
            'updatedAt': FieldValue.serverTimestamp(),
            if (bio != null) 'bio': bio.trim().isEmpty ? null : bio.trim(),
            if (avatarUrl != null) 'avatarUrl': avatarUrl,
          };
          final newName = username?.trim();
          if (newName != null &&
              newName.toLowerCase() != oldName.toLowerCase()) {
            final claim = col('usernames').doc(newName.toLowerCase());
            if ((await tx.get(claim)).exists) {
              throw const CineFailure(
                  CineFailureKind.conflict, 'Ce pseudo est déjà utilisé.');
            }
            tx.set(claim, {'userId': userId, 'username': newName});
            if (oldName.isNotEmpty) {
              tx.delete(col('usernames').doc(oldName.toLowerCase()));
            }
          }
          if (newName != null) {
            changes['username'] = newName;
            changes['usernameLower'] = newName.toLowerCase();
          }
          tx.update(userRef, changes);
        });
        return (await fetchProfile(userId))!;
      });

  /// Enregistre l'avatar (image déjà compressée) dans le profil, encodé en
  /// base64 : le forfait gratuit de Firebase n'inclut pas Storage.
  Future<void> uploadAvatar(Uint8List bytes) => guard('uploadAvatar', () async {
        if (bytes.length > kMaxAvatarBytes) {
          throw const CineFailure(
              CineFailureKind.invalid, 'Image trop volumineuse.');
        }
        await col('users').doc(requireUserId).update({
          'avatarData': base64Encode(bytes),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  Future<void> removeAvatar() => guard('removeAvatar', () async {
        await col('users').doc(requireUserId).update({
          'avatarData': FieldValue.delete(),
          'avatarUrl': FieldValue.delete(),
        });
      });

  /// Supprime toutes les données du membre connecté (profil, pseudo, favoris,
  /// vus, listes, notifications, historique). Le compte Firebase Auth est
  /// supprimé ensuite par [AuthService.deleteAccount].
  Future<void> deleteMyData() => guard('deleteMyData', () async {
        final userId = requireUserId;
        final refs = <DocumentReference>[];
        for (final name in const [
          'favorites',
          'watched',
          'watchlist_items',
          'watchlists',
          'notifications',
          'search_history',
        ]) {
          final snap =
              await col(name).where('userId', isEqualTo: userId).get();
          refs.addAll(snap.docs.map((d) => d.reference));
        }
        final profile = await col('users').doc(userId).get();
        final username = profile.data()?['usernameLower'] as String?;
        if (username != null && username.isNotEmpty) {
          refs.add(col('usernames').doc(username));
        }
        refs.add(profile.reference);
        // Les lots Firestore sont limités à 500 écritures.
        for (var i = 0; i < refs.length; i += 450) {
          final batch = _db.batch();
          for (final ref in refs.skip(i).take(450)) {
            batch.delete(ref);
          }
          await batch.commit();
        }
      });

  // Favoris et vus ---------------------------------------------------------

  Future<bool> isFavorite(String mediaId) => guard('isFavorite', () async {
        final userId = currentUserId;
        if (userId == null) {
          return false;
        }
        final doc =
            await col('favorites').doc(userMediaDocId(userId, mediaId)).get();
        return doc.exists;
      });

  /// Ajoute ou retire un favori ; renvoie le nouvel état.
  Future<bool> toggleFavorite(String mediaId) =>
      guard('toggleFavorite', () async {
        final userId = requireUserId;
        final ref = col('favorites').doc(userMediaDocId(userId, mediaId));
        if ((await ref.get()).exists) {
          await ref.delete();
          return false;
        }
        await ref.set({
          'userId': userId,
          'mediaId': mediaId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

  Future<bool> isWatched(String mediaId) => guard('isWatched', () async {
        final userId = currentUserId;
        if (userId == null) {
          return false;
        }
        final doc =
            await col('watched').doc(userMediaDocId(userId, mediaId)).get();
        return doc.exists;
      });

  /// Marque un titre comme vu ou le retire ; renvoie le nouvel état.
  Future<bool> toggleWatched(String mediaId) => guard('toggleWatched', () async {
        final userId = requireUserId;
        final ref = col('watched').doc(userMediaDocId(userId, mediaId));
        if ((await ref.get()).exists) {
          await ref.delete();
          return false;
        }
        await ref.set({
          'userId': userId,
          'mediaId': mediaId,
          'watchedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

  // Listes ---------------------------------------------------------------

  /// Listes du membre connecté, les plus récentes d'abord.
  Future<List<Watchlist>> fetchMyWatchlists() =>
      guard('fetchMyWatchlists', () async {
        final snap = await col('watchlists')
            .where('userId', isEqualTo: requireUserId)
            .orderBy('createdAt', descending: true)
            .get();
        return snap.docs.map((d) => Watchlist.fromJson(cineRow(d))).toList();
      });

  /// Identifiants des listes du membre qui contiennent déjà ce titre.
  Future<Set<String>> watchlistIdsWithMedia(String mediaId) =>
      guard('watchlistIdsWithMedia', () async {
        final snap = await col('watchlist_items')
            .where('userId', isEqualTo: requireUserId)
            .where('mediaId', isEqualTo: mediaId)
            .get();
        return {for (final d in snap.docs) d.data()['watchlistId'] as String};
      });

  Future<Watchlist> createWatchlist(String name, {String? description}) =>
      guard('createWatchlist', () async {
        final error = validateWatchlistName(name);
        if (error != null) {
          throw CineFailure(CineFailureKind.invalid, error);
        }
        // `id` = identifiant du document (pages FlutterFlow : requête sur id).
        final ref = col('watchlists').doc();
        await ref.set({
          'id': ref.id,
          'userId': requireUserId,
          'name': name.trim(),
          'isPublic': false,
          'createdAt': FieldValue.serverTimestamp(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        });
        return Watchlist.fromJson(cineRow(await ref.get()));
      });

  Future<Watchlist> renameWatchlist(String watchlistId, String name) =>
      guard('renameWatchlist', () async {
        final error = validateWatchlistName(name);
        if (error != null) {
          throw CineFailure(CineFailureKind.invalid, error);
        }
        requireUserId;
        final ref = col('watchlists').doc(watchlistId);
        await ref.update({'name': name.trim()});
        return Watchlist.fromJson(cineRow(await ref.get()));
      });

  /// Supprime la liste et ses titres.
  Future<void> deleteWatchlist(String watchlistId) =>
      guard('deleteWatchlist', () async {
        final items = await col('watchlist_items')
            .where('userId', isEqualTo: requireUserId)
            .where('watchlistId', isEqualTo: watchlistId)
            .get();
        final batch = _db.batch();
        for (final item in items.docs) {
          batch.delete(item.reference);
        }
        batch.delete(col('watchlists').doc(watchlistId));
        await batch.commit();
      });

  /// Ajoute un titre du catalogue (collection media) à une liste.
  Future<void> addMediaToWatchlist(String watchlistId, String mediaId) =>
      guard('addMediaToWatchlist', () async {
        final userId = requireUserId;
        final ref =
            col('watchlist_items').doc(watchlistItemDocId(watchlistId, mediaId));
        if ((await ref.get()).exists) {
          throw const CineFailure(
              CineFailureKind.conflict, 'Cet élément existe déjà.');
        }
        await ref.set({
          'id': ref.id,
          'watchlistId': watchlistId,
          'userId': userId,
          'mediaId': mediaId,
          'addedAt': FieldValue.serverTimestamp(),
        });
      });

  /// Retire un titre d'une liste (la règle Firestore vérifie le propriétaire).
  Future<void> removeWatchlistItem(String itemId) =>
      guard('removeWatchlistItem', () async {
        requireUserId;
        await col('watchlist_items').doc(itemId).delete();
      });

  // Préférences ----------------------------------------------------------

  Future<UserPreferences> fetchPreferences() =>
      guard('fetchPreferences', () async {
        final userId = requireUserId;
        final doc = await col('users').doc(userId).get();
        final row = cineRow(doc)..['user_id'] = userId;
        return doc.exists
            ? UserPreferences.fromJson(row)
            : UserPreferences(userId: userId);
      });

  Future<UserPreferences> savePreferences(UserPreferences preferences) =>
      guard('savePreferences', () async {
        final userId = requireUserId;
        final json = preferences.toJson()
          ..remove('user_id')
          ..remove('updated_at');
        await col('users').doc(userId).set(
            {...toFirestoreFields(json), 'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        return fetchPreferences();
      });

  // Catalogue ------------------------------------------------------------

  Future<List<Genre>> fetchGenres() => guard('fetchGenres', () async {
        final snap = await col('genres').orderBy('name').get();
        return snap.docs.map((d) => Genre.fromJson(cineRow(d))).toList();
      });

  Future<List<Platform>> fetchPlatforms() => guard('fetchPlatforms', () async {
        final snap = await col('platforms').orderBy('name').get();
        return snap.docs.map((d) => Platform.fromJson(cineRow(d))).toList();
      });

  Future<Map<String, dynamic>?> fetchMedia(String mediaId) =>
      guard('fetchMedia', () async {
        final doc = await col('media').doc(mediaId).get();
        return doc.exists ? cineRow(doc) : null;
      });

  /// Titres du catalogue par identifiants (requêtes `whereIn` par 30).
  Future<Map<String, Map<String, dynamic>>> fetchMediaByIds(
          Iterable<String> ids) =>
      guard('fetchMediaByIds', () async {
        final unique = ids.toSet().toList();
        final out = <String, Map<String, dynamic>>{};
        for (var i = 0; i < unique.length; i += 30) {
          final snap = await col('media')
              .where(FieldPath.documentId,
                  whereIn: unique.skip(i).take(30).toList())
              .get();
          for (final doc in snap.docs) {
            out[doc.id] = cineRow(doc);
          }
        }
        return out;
      });

  List<Map<String, dynamic>>? _catalog;
  DateTime? _catalogLoadedAt;

  /// Tout le catalogue (quelques centaines de titres), gardé en mémoire
  /// 10 minutes. Firestore n'offre ni recherche plein texte ni « ilike » :
  /// la recherche, les filtres, le tri et la pagination du catalogue se
  /// font sur cette copie locale.
  Future<List<Map<String, dynamic>>> catalog({bool refresh = false}) =>
      guard('catalog', () async {
        final fresh = _catalogLoadedAt != null &&
            DateTime.now().difference(_catalogLoadedAt!) <
                const Duration(minutes: 10);
        if (_catalog == null || refresh || !fresh) {
          final snap = await col('media').get();
          _catalog = snap.docs.map(cineRow).toList();
          _catalogLoadedAt = DateTime.now();
        }
        return _catalog!;
      });

  /// Oublie la copie locale (après un import TMDB).
  void invalidateCatalog() => _catalog = null;
}
