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

/// Vérifie que Firestore répond et que les genres TMDB sont installés.
/// Action FlutterFlow (et point d'ancrage de la synchronisation du service).
Future<bool> firebaseService() async {
  try {
    return (await CineFirebaseService.instance.fetchGenres()).isNotEmpty;
  } on CineFailure catch (failure) {
    developer.log(failure.message, name: 'CineFirebaseService');
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

/// Avis : note de 1 à 10, texte de 2000 caractères au plus (section 5.4).
String? validateReview(int rating, String? content) {
  if (rating < 1 || rating > 10) {
    return 'La note doit être comprise entre 1 et 10.';
  }
  if ((content ?? '').length > 2000) {
    return 'L\'avis ne doit pas dépasser 2000 caractères.';
  }
  return null;
}

/// Taille maximale d'un avatar enregistré dans le profil. Le cahier des
/// charges prévoit Firebase Storage, mais le forfait gratuit (Spark) ne
/// permet plus d'en créer : l'image compressée est stockée en base64 dans
/// `users/{uid}.avatarData` (document limité à 1 Mo).
const int kMaxAvatarBytes = 300 * 1024;

// Identifiants ------------------------------------------------------------------

/// Identifiant d'un titre dans l'application : `movie_550`, `series_1399`.
/// C'est aussi l'identifiant des documents favoris, vus et éléments de liste
/// (unicité garantie par Firestore).
String mediaKey(String mediaType, int tmdbId) => '${mediaType}_$tmdbId';

/// `movie_550` -> (type: 'movie', tmdbId: 550), null si invalide.
({String type, int tmdbId})? parseMediaKey(String? key) {
  final match = RegExp(r'^(movie|series)_(\d+)$').firstMatch(key ?? '');
  return match == null
      ? null
      : (type: match[1]!, tmdbId: int.parse(match[2]!));
}

/// Collection du catalogue d'un type de titre.
String catalogCollection(String mediaType) =>
    mediaType == 'series' ? 'series' : 'movies';

// Conversion des documents ------------------------------------------------------
//
// Les modèles (cine_models.dart) et les widgets lisent des lignes au format
// historique : clés snake_case, dates ISO 8601, `id` inclus.

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
  'first_air_date',
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

/// Document `movies/{tmdbId}` ou `series/{tmdbId}` -> ligne de catalogue
/// commune aux films et aux séries (format lu par les widgets) :
/// id = `movie_550`, genres en noms, dates ISO.
Map<String, dynamic> catalogRow(
  String mediaType,
  DocumentSnapshot<Object?> doc, [
  Map<int, String> genreNames = const {},
]) {
  final d = (doc.data() as Map<String, dynamic>?) ?? const {};
  final tmdbId = (d['tmdbId'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0;
  final series = mediaType == 'series';
  return {
    'id': mediaKey(mediaType, tmdbId),
    'media_type': mediaType,
    'tmdb_id': tmdbId,
    'title': d['title'] ?? '',
    'overview': d['description'],
    'poster_url': d['posterUrl'],
    'backdrop_url': d['backdropUrl'],
    'release_date':
        _fromFirestore(series ? d['firstAirDate'] : d['releaseDate']),
    'runtime_minutes': series ? null : d['duration'],
    'seasons': series ? d['numberOfSeasons'] : null,
    'episodes': series ? d['numberOfEpisodes'] : null,
    'status': d['status'],
    'rating': (d['rating'] as num?)?.toDouble() ?? 0,
    'popularity': d['popularity'] ?? 0,
    'genre_ids': d['genreIds'] ?? const [],
    'genres': [
      for (final id in (d['genreIds'] as List? ?? const []))
        if (genreNames[id] != null) genreNames[id],
    ],
    'platforms': d['platforms'] ?? const [],
    'trailer_url': d['trailerUrl'],
    'details_synced_at': _fromFirestore(d['detailsSyncedAt']),
  };
}

/// Champs dénormalisés d'un titre pour les favoris, listes et vus.
Map<String, dynamic> mediaSummary(Map<String, dynamic> row) => {
      'mediaType': row['media_type'],
      'tmdbId': row['tmdb_id'],
      'title': row['title'] ?? '',
      'posterUrl': row['poster_url'],
    };

/// Accès aux données de Firebase (cahier des charges, section 5).
///
/// Données privées en sous-collections de `users/{uid}`, catalogue dans
/// `movies` et `series`. Toutes les méthodes lèvent une [CineFailure].
class CineFirebaseService {
  /// [currentUserId] remplace la session Firebase (tests).
  CineFirebaseService(this._db, {String? Function()? currentUserId})
      : _currentUserId = currentUserId;

  static CineFirebaseService? _instance;
  static CineFirebaseService? _override;

  static CineFirebaseService get instance =>
      _override ?? (_instance ??= CineFirebaseService(_configured()));

  /// Remplace le service partagé (tests). `null` rétablit Firestore.
  @visibleForTesting
  static set debugInstance(CineFirebaseService? service) => _override = service;

  /// Persistance hors ligne (section 5.6) : les écritures faites sans réseau
  /// sont mises en file par Firestore et envoyées au retour de la connexion.
  static FirebaseFirestore _configured() {
    final db = FirebaseFirestore.instance;
    try {
      db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024,
      );
    } catch (error) {
      // Réglage refusé si Firestore a déjà servi : on garde l'existant.
      developer.log('settings', name: 'CineFirebaseService', error: error);
    }
    return db;
  }

  final FirebaseFirestore _db;
  final String? Function()? _currentUserId;

  FirebaseFirestore get db => _db;

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

  DocumentReference<Map<String, dynamic>> get _me =>
      col('users').doc(requireUserId);

  /// Sous-collection privée du membre connecté (favorites, watched…).
  CollectionReference<Map<String, dynamic>> mine(String name) =>
      _me.collection(name);

  Future<T> guard<T>(String operation, Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, stack) {
      final failure = mapFirestoreError(error);
      developer.log('$operation : ${failure.kind.name}',
          name: 'CineFirebaseService', error: error, stackTrace: stack);
      throw failure;
    }
  }

  /// Écritures par lots de 500 au plus (limite Firestore).
  Future<void> commitInChunks(
      List<void Function(WriteBatch batch)> writes) async {
    for (var i = 0; i < writes.length; i += 500) {
      final batch = _db.batch();
      for (final write in writes.skip(i).take(500)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  // Profil -----------------------------------------------------------------

  Future<UserProfile?> fetchProfile([String? userId]) =>
      guard('fetchProfile', () async {
        final doc = await col('users').doc(userId ?? requireUserId).get();
        return doc.exists ? UserProfile.fromJson(cineRow(doc)) : null;
      });

  /// Vrai si le pseudo est libre ou déjà celui du membre. Les règles ne
  /// permettent cette lecture qu'aux membres connectés : sans session, la
  /// réponse est « libre » et la transaction d'inscription tranche.
  Future<bool> isUsernameAvailable(String username) =>
      guard('isUsernameAvailable', () async {
        if (currentUserId == null) {
          return true;
        }
        final doc =
            await col('usernames').doc(username.trim().toLowerCase()).get();
        return !doc.exists || doc.data()?['uid'] == currentUserId;
      });

  /// Inscription (section 5.2) : dans une transaction, vérifie que le pseudo
  /// est libre puis crée `usernames/{pseudo}` et `users/{uid}` avec les
  /// préférences par défaut.
  Future<void> createProfile({
    required String userId,
    required String username,
    required String email,
  }) =>
      guard('createProfile', () async {
        final name = username.trim();
        final claim = col('usernames').doc(name.toLowerCase());
        final prefs = UserPreferences(userId: userId).toJson()
          ..remove('user_id')
          ..remove('updated_at');
        await _db.runTransaction((tx) async {
          if ((await tx.get(claim)).exists) {
            throw const CineFailure(
                CineFailureKind.conflict, 'Ce pseudo est déjà utilisé.');
          }
          final now = FieldValue.serverTimestamp();
          tx
            ..set(claim, {'uid': userId})
            ..set(col('users').doc(userId), {
              'username': name,
              'email': email,
              'role': 'user',
              // uid et created_time : champs exigés par FlutterFlow pour la
              // collection des comptes.
              'uid': userId,
              'created_time': now,
              'createdAt': now,
              'updatedAt': now,
              'preferences': toFirestoreFields(prefs),
            });
        });
      });

  /// Pseudo, bio ou avatar ; un changement de pseudo libère l'ancien, et les
  /// champs dénormalisés des avis du membre sont mis à jour (section 5.2).
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
        var renamed = false;
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
            tx.set(claim, {'uid': userId});
            if (oldName.isNotEmpty) {
              tx.delete(col('usernames').doc(oldName.toLowerCase()));
            }
          }
          if (newName != null && newName != oldName) {
            changes['username'] = newName;
            renamed = true;
          }
          tx.update(userRef, changes);
        });
        if (renamed || avatarUrl != null) {
          await _refreshMyReviews();
        }
        return (await fetchProfile(userId))!;
      });

  /// Recopie pseudo et avatar du profil dans les avis du membre.
  Future<void> _refreshMyReviews() async {
    final profile = (await _me.get()).data() ?? const {};
    final reviews =
        await col('reviews').where('userId', isEqualTo: requireUserId).get();
    await commitInChunks([
      for (final review in reviews.docs)
        (batch) => batch.update(review.reference, {
              'username': profile['username'],
              'userAvatarUrl': profile['avatarUrl'],
            }),
    ]);
  }

  /// Enregistre l'avatar (image déjà compressée) en base64 dans le profil.
  Future<void> uploadAvatar(Uint8List bytes) => guard('uploadAvatar', () async {
        if (bytes.length > kMaxAvatarBytes) {
          throw const CineFailure(
              CineFailureKind.invalid, 'Image trop volumineuse.');
        }
        await _me.update({
          'avatarData': base64Encode(bytes),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  /// Supprime toutes les données du membre (section 5.2) : sous-collections,
  /// listes et leurs titres, avis (et leurs likes), pseudo, profil. Le compte
  /// Firebase Auth est supprimé ensuite par l'appelant.
  Future<void> deleteMyData() => guard('deleteMyData', () async {
        final me = _me;
        final refs = <DocumentReference>[];
        for (final name in const [
          'favorites',
          'watched',
          'notifications',
          'searchHistory',
        ]) {
          refs.addAll((await me.collection(name).get()).docs.map((d) => d.reference));
        }
        for (final list in (await me.collection('watchlists').get()).docs) {
          refs.addAll(
              (await list.reference.collection('items').get()).docs.map((d) => d.reference));
          refs.add(list.reference);
        }
        final reviews =
            await col('reviews').where('userId', isEqualTo: me.id).get();
        for (final review in reviews.docs) {
          refs.addAll((await review.reference.collection('likes').get())
              .docs
              .map((d) => d.reference));
          refs.add(review.reference);
        }
        final profile = await me.get();
        final username = profile.data()?['username'] as String?;
        if (username != null && username.isNotEmpty) {
          refs.add(col('usernames').doc(username.toLowerCase()));
        }
        refs.add(me);
        await commitInChunks([
          for (final ref in refs) (batch) => batch.delete(ref),
        ]);
      });

  // Préférences ----------------------------------------------------------

  Future<UserPreferences> fetchPreferences() =>
      guard('fetchPreferences', () async {
        final userId = requireUserId;
        final doc = await _me.get();
        final prefs = doc.data()?['preferences'];
        if (prefs is! Map) {
          return UserPreferences(userId: userId);
        }
        final row = _fromFirestore(prefs) as Map<String, dynamic>;
        return UserPreferences.fromJson(row..['user_id'] = userId);
      });

  Future<UserPreferences> savePreferences(UserPreferences preferences) =>
      guard('savePreferences', () async {
        final json = preferences.toJson()
          ..remove('user_id')
          ..remove('updated_at');
        await _me.update({
          'preferences': toFirestoreFields(json),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return fetchPreferences();
      });

  // Catalogue ------------------------------------------------------------

  Future<List<Genre>> fetchGenres() => guard('fetchGenres', () async {
        final snap = await col('genres').orderBy('name').get();
        return snap.docs.map((d) => Genre.fromJson(cineRow(d))).toList();
      });

  Future<List<Platform>> fetchPlatforms() => guard('fetchPlatforms', () async {
        final snap = await col('platforms').orderBy('name').get();
        return snap.docs
            .map((d) => Platform.fromJson(
                cineRow(d)..['id'] = int.tryParse(d.id) ?? 0))
            .toList();
      });

  Map<int, String>? _genreNames;

  Future<Map<int, String>> genreNames() async =>
      _genreNames ??= {for (final g in await fetchGenres()) g.id: g.name};

  /// Un titre du catalogue par sa clé `movie_550`, au format ligne.
  Future<Map<String, dynamic>?> fetchMedia(String key) =>
      guard('fetchMedia', () async {
        final parsed = parseMediaKey(key);
        if (parsed == null) {
          return null;
        }
        final doc = await col(catalogCollection(parsed.type))
            .doc('${parsed.tmdbId}')
            .get();
        return doc.exists
            ? catalogRow(parsed.type, doc, await genreNames())
            : null;
      });

  List<Map<String, dynamic>>? _catalog;
  DateTime? _catalogLoadedAt;

  /// Films et séries (quelques centaines de titres), gardés en mémoire
  /// 10 minutes. Firestore n'offre pas de recherche « contient » : la
  /// recherche, les filtres et le tri du catalogue se font sur cette copie.
  Future<List<Map<String, dynamic>>> catalog({bool refresh = false}) =>
      guard('catalog', () async {
        final fresh = _catalogLoadedAt != null &&
            DateTime.now().difference(_catalogLoadedAt!) <
                const Duration(minutes: 10);
        if (_catalog == null || refresh || !fresh) {
          final names = await genreNames();
          final results = await Future.wait(
              [col('movies').get(), col('series').get()]);
          _catalog = [
            for (final doc in results[0].docs) catalogRow('movie', doc, names),
            for (final doc in results[1].docs) catalogRow('series', doc, names),
          ];
          _catalogLoadedAt = DateTime.now();
        }
        return _catalog!;
      });

  /// Oublie la copie locale (après un import TMDB).
  void invalidateCatalog() => _catalog = null;

  Future<Map<String, dynamic>> _requireMedia(String key) async {
    final row = await fetchMedia(key);
    if (row == null) {
      throw const CineFailure(CineFailureKind.notFound, 'Titre introuvable.');
    }
    return row;
  }

  // Favoris et vus ---------------------------------------------------------

  Future<bool> isFavorite(String key) => guard('isFavorite', () async {
        if (currentUserId == null) {
          return false;
        }
        return (await mine('favorites').doc(key).get()).exists;
      });

  /// Ajoute ou retire un favori ; renvoie le nouvel état.
  Future<bool> toggleFavorite(String key) => guard('toggleFavorite', () async {
        final ref = mine('favorites').doc(key);
        if ((await ref.get()).exists) {
          await ref.delete();
          return false;
        }
        final media = await _requireMedia(key);
        await ref.set({
          ...mediaSummary(media),
          'rating': media['rating'],
          'releaseDate': media['release_date'] == null
              ? null
              : Timestamp.fromDate(DateTime.parse(media['release_date'])),
          'addedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

  Future<bool> isWatched(String key) => guard('isWatched', () async {
        if (currentUserId == null) {
          return false;
        }
        return (await mine('watched').doc(key).get()).exists;
      });

  /// Marque un titre entier comme vu ou le retire ; renvoie le nouvel état.
  Future<bool> toggleWatched(String key) => guard('toggleWatched', () async {
        final ref = mine('watched').doc(key);
        if ((await ref.get()).exists) {
          await ref.delete();
          return false;
        }
        final media = await _requireMedia(key);
        // posterUrl n'est pas dans le cahier des charges : dénormalisé pour
        // l'onglet Vus, comme pour les favoris.
        await ref.set({
          ...mediaSummary(media),
          'watchedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

  // Listes ---------------------------------------------------------------

  /// Listes du membre connecté, les plus récentes d'abord.
  Future<List<Watchlist>> fetchMyWatchlists() =>
      guard('fetchMyWatchlists', () async {
        final userId = requireUserId;
        final snap = await mine('watchlists')
            .orderBy('createdAt', descending: true)
            .get();
        return [
          for (final d in snap.docs)
            Watchlist.fromJson(cineRow(d)..['user_id'] = userId),
        ];
      });

  /// Identifiants des listes du membre qui contiennent déjà ce titre.
  Future<Set<String>> watchlistIdsWithMedia(String key) =>
      guard('watchlistIdsWithMedia', () async {
        final lists = await mine('watchlists').get();
        final hits = await Future.wait(lists.docs
            .map((l) => l.reference.collection('items').doc(key).get()));
        return {
          for (var i = 0; i < hits.length; i++)
            if (hits[i].exists) lists.docs[i].id,
        };
      });

  Future<Watchlist> createWatchlist(String name, {String? description}) =>
      guard('createWatchlist', () async {
        final error = validateWatchlistName(name);
        if (error != null) {
          throw CineFailure(CineFailureKind.invalid, error);
        }
        final now = FieldValue.serverTimestamp();
        final ref = await mine('watchlists').add({
          'name': name.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'isPublic': false,
          'itemCount': 0,
          'createdAt': now,
          'updatedAt': now,
        });
        return Watchlist.fromJson(cineRow(await ref.get())
          ..['user_id'] = requireUserId);
      });

  Future<void> renameWatchlist(String watchlistId, String name) =>
      guard('renameWatchlist', () async {
        final error = validateWatchlistName(name);
        if (error != null) {
          throw CineFailure(CineFailureKind.invalid, error);
        }
        await mine('watchlists').doc(watchlistId).update({
          'name': name.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  /// Supprime la liste et ses titres.
  Future<void> deleteWatchlist(String watchlistId) =>
      guard('deleteWatchlist', () async {
        final list = mine('watchlists').doc(watchlistId);
        final items = await list.collection('items').get();
        await commitInChunks([
          for (final item in items.docs) (batch) => batch.delete(item.reference),
          (batch) => batch.delete(list),
        ]);
      });

  /// Ajoute un titre à une liste : l'élément et `itemCount` changent dans le
  /// même lot (section 5.2).
  Future<void> addMediaToWatchlist(String watchlistId, String key) =>
      guard('addMediaToWatchlist', () async {
        final list = mine('watchlists').doc(watchlistId);
        final item = list.collection('items').doc(key);
        if ((await item.get()).exists) {
          throw const CineFailure(
              CineFailureKind.conflict, 'Cet élément existe déjà.');
        }
        final media = await _requireMedia(key);
        final batch = _db.batch()
          ..set(item, {
            ...mediaSummary(media),
            'addedAt': FieldValue.serverTimestamp(),
          })
          ..update(list, {
            'itemCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        await batch.commit();
      });

  /// Retire un titre d'une liste et décrémente `itemCount`.
  Future<void> removeWatchlistItem(String watchlistId, String key) =>
      guard('removeWatchlistItem', () async {
        final list = mine('watchlists').doc(watchlistId);
        final item = list.collection('items').doc(key);
        if (!(await item.get()).exists) {
          return;
        }
        final batch = _db.batch()
          ..delete(item)
          ..update(list, {
            'itemCount': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        await batch.commit();
      });

  // Avis -------------------------------------------------------------------

  /// Crée l'avis du membre sur un titre (pseudo et avatar dénormalisés).
  Future<String> createReview(String key,
          {required int rating, String? content, bool isPrivate = false}) =>
      guard('createReview', () async {
        final error = validateReview(rating, content);
        if (error != null) {
          throw CineFailure(CineFailureKind.invalid, error);
        }
        final parsed = parseMediaKey(key);
        if (parsed == null) {
          throw const CineFailure(CineFailureKind.invalid, 'Titre inconnu.');
        }
        final profile = (await _me.get()).data() ?? const {};
        final now = FieldValue.serverTimestamp();
        final ref = await col('reviews').add({
          'userId': requireUserId,
          'username': profile['username'],
          'userAvatarUrl': profile['avatarUrl'],
          'mediaType': parsed.type,
          'tmdbId': parsed.tmdbId,
          'rating': rating,
          'content': content?.trim(),
          'isPrivate': isPrivate,
          'likesCount': 0,
          'createdAt': now,
          'updatedAt': now,
        });
        return ref.id;
      });

  /// Like / unlike : `likes/{uid}` et `likesCount` dans le même lot.
  /// Renvoie le nouvel état.
  Future<bool> toggleReviewLike(String reviewId) =>
      guard('toggleReviewLike', () async {
        final review = col('reviews').doc(reviewId);
        final like = review.collection('likes').doc(requireUserId);
        final liked = (await like.get()).exists;
        final batch = _db.batch();
        if (liked) {
          batch.delete(like);
        } else {
          batch.set(like, {'createdAt': FieldValue.serverTimestamp()});
        }
        batch.update(review, {'likesCount': FieldValue.increment(liked ? -1 : 1)});
        await batch.commit();
        return !liked;
      });

  // Historique de recherche ----------------------------------------------

  Future<void> addSearch(String query) => guard('addSearch', () async {
        final text = query.trim();
        if (text.isEmpty || currentUserId == null) {
          return;
        }
        await mine('searchHistory').add({
          'query': text.length > 200 ? text.substring(0, 200) : text,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
}
