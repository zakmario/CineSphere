// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '/custom_code/actions/cine_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Vérifie que Supabase répond et que le schéma CinéSphère est installé.
/// Action FlutterFlow (et point d'ancrage de la synchronisation du service).
Future<bool> supabaseService() async {
  try {
    await SupabaseService.instance.fetchGenres();
    return true;
  } on CineFailure catch (failure) {
    developer.log(failure.message, name: 'SupabaseService');
    return false;
  }
}

/// Nombre d'éléments par page (cahier des charges, section 6.4).
const int kPageSize = 20;

/// Bornes inclusives `.range(from, to)` de la page [page] (0 = première).
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

/// Traduit une erreur Supabase / réseau en [CineFailure].
CineFailure mapSupabaseError(Object error) {
  if (error is CineFailure) {
    return error;
  }
  if (error is TimeoutException || _isNetworkError(error)) {
    return CineFailure(CineFailureKind.network,
        'Pas de connexion Internet. Réessayez plus tard.', error);
  }
  if (error is supa.AuthException) {
    return CineFailure(CineFailureKind.unauthenticated,
        'Votre session a expiré. Reconnectez-vous.', error);
  }
  if (error is supa.StorageException) {
    final status = error.statusCode ?? '';
    if (status == '413') {
      return CineFailure(CineFailureKind.invalid,
          'Image trop volumineuse (2 Mo maximum).', error);
    }
    if (status == '403' || status == '401') {
      return CineFailure(CineFailureKind.forbidden,
          'Vous ne pouvez pas modifier ce fichier.', error);
    }
    return CineFailure(
        CineFailureKind.unknown, 'L\'envoi de l\'image a échoué.', error);
  }
  if (error is supa.PostgrestException) {
    switch (error.code) {
      case '23505':
        final detail = '${error.message} ${error.details ?? ''}';
        return CineFailure(
          CineFailureKind.conflict,
          detail.contains('username')
              ? 'Ce pseudo est déjà utilisé.'
              : 'Cet élément existe déjà.',
          error,
        );
      case '42501':
        return CineFailure(CineFailureKind.forbidden,
            'Vous n\'avez pas le droit d\'effectuer cette action.', error);
      case '23514':
      case '22023':
      case '22P02':
        return CineFailure(
            CineFailureKind.invalid, 'Données invalides.', error);
      case 'PGRST116':
        return CineFailure(
            CineFailureKind.notFound, 'Élément introuvable.', error);
    }
    if (error.code == 'PGRST301' || error.code == '401') {
      return CineFailure(CineFailureKind.unauthenticated,
          'Votre session a expiré. Reconnectez-vous.', error);
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

/// Nom de liste : 1 à 60 caractères (contrainte de la table watchlists).
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

/// Chemin Storage de l'avatar : `{user_id}/avatar.{ext}` (politique RLS).
String avatarStoragePath(String userId, String extension) {
  final ext = extension.toLowerCase().replaceAll('.', '');
  final safeExt = const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)
      ? (ext == 'jpeg' ? 'jpg' : ext)
      : 'jpg';
  return '$userId/avatar.$safeExt';
}

String _contentType(String path) => switch (path.split('.').last) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

/// Accès aux données utilisateur et au cache catalogue dans Supabase.
///
/// Toutes les méthodes lèvent une [CineFailure] en cas d'erreur.
class SupabaseService {
  /// [currentUserId] remplace la session Supabase (tests).
  SupabaseService(this._client, {String? Function()? currentUserId})
      : _currentUserId = currentUserId;

  static final SupabaseService instance = SupabaseService(SupaFlow.client);

  final SupabaseClient _client;
  final String? Function()? _currentUserId;

  String? get currentUserId {
    final override = _currentUserId;
    return override != null ? override() : _client.auth.currentUser?.id;
  }

  String get _requireUserId {
    final id = currentUserId;
    if (id == null) {
      throw const CineFailure(
          CineFailureKind.unauthenticated, 'Connectez-vous pour continuer.');
    }
    return id;
  }

  Future<T> _guard<T>(String operation, Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, stack) {
      final failure = mapSupabaseError(error);
      developer.log('$operation : ${failure.kind.name}',
          name: 'SupabaseService', error: error, stackTrace: stack);
      throw failure;
    }
  }

  // Profil -----------------------------------------------------------------

  Future<UserProfile?> fetchProfile([String? userId]) =>
      _guard('fetchProfile', () async {
        final row = await _client
            .from('profiles')
            .select()
            .eq('id', userId ?? _requireUserId)
            .maybeSingle();
        return row == null ? null : UserProfile.fromJson(row);
      });

  /// Profil public d'un autre membre (sans e-mail).
  Future<UserProfile?> fetchPublicProfile(String userId) =>
      _guard('fetchPublicProfile', () async {
        final rows = await _client
            .rpc('get_public_profile', params: {'profile_id': userId});
        final list = (rows as List).cast<Map<String, dynamic>>();
        return list.isEmpty ? null : UserProfile.fromJson(list.first);
      });

  /// Vrai si le pseudo est libre (ou déjà celui de l'utilisateur).
  /// Utilisable avant l'inscription (fonction accessible à anon).
  Future<bool> isUsernameAvailable(String username) =>
      _guard('isUsernameAvailable', () async {
        final available = await _client
            .rpc('username_available', params: {'candidate': username.trim()});
        return available == true;
      });

  Future<UserProfile> updateProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) =>
      _guard('updateProfile', () async {
        if (username != null) {
          final error = validateUsername(username);
          if (error != null) {
            throw CineFailure(CineFailureKind.invalid, error);
          }
        }
        final changes = <String, dynamic>{
          if (username != null) 'username': username.trim(),
          if (bio != null) 'bio': bio.trim().isEmpty ? null : bio.trim(),
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        };
        final row = await _client
            .from('profiles')
            .update(changes)
            .eq('id', _requireUserId)
            .select()
            .single();
        return UserProfile.fromJson(row);
      });

  /// Envoie l'avatar dans `avatars/{user_id}/` et met à jour le profil.
  /// Renvoie l'URL publique (avec un paramètre anti-cache).
  Future<String> uploadAvatar(Uint8List bytes, {String extension = 'jpg'}) =>
      _guard('uploadAvatar', () async {
        final userId = _requireUserId;
        final path = avatarStoragePath(userId, extension);
        await _client.storage.from('avatars').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: _contentType(path),
                upsert: true,
              ),
            );
        final url = '${_client.storage.from('avatars').getPublicUrl(path)}'
            '?v=${DateTime.now().millisecondsSinceEpoch}';
        await updateProfile(avatarUrl: url);
        return url;
      });

  /// Supprime définitivement le compte du membre connecté : fichiers de
  /// `avatars/{user_id}/`, puis le compte (fonction SQL `delete_my_account`,
  /// qui efface toutes ses données en cascade), puis la session locale.
  Future<void> deleteMyAccount() => _guard('deleteMyAccount', () async {
        final userId = _requireUserId;
        final bucket = _client.storage.from('avatars');
        final files = await bucket.list(path: userId);
        if (files.isNotEmpty) {
          await bucket.remove([for (final f in files) '$userId/${f.name}']);
        }
        await _client.rpc('delete_my_account');
        await _client.auth.signOut(scope: SignOutScope.local);
      });

  // Listes ---------------------------------------------------------------

  /// Listes du membre connecté, les plus récentes d'abord.
  Future<List<Watchlist>> fetchMyWatchlists() =>
      _guard('fetchMyWatchlists', () async {
        final rows = await _client
            .from('watchlists')
            .select()
            .eq('user_id', _requireUserId)
            .order('created_at', ascending: false);
        return rows.map(Watchlist.fromJson).toList();
      });

  /// Identifiants des listes (visibles) qui contiennent déjà ce titre.
  Future<Set<String>> watchlistIdsWithMedia(String mediaId) =>
      _guard('watchlistIdsWithMedia', () async {
        _requireUserId;
        final rows = await _client
            .from('watchlist_items')
            .select('watchlist_id')
            .eq('media_id', mediaId);
        return {for (final row in rows) row['watchlist_id'] as String};
      });

  Future<Watchlist> createWatchlist(String name, {String? description}) =>
      _guard('createWatchlist', () async {
        final error = validateWatchlistName(name);
        if (error != null) {
          throw CineFailure(CineFailureKind.invalid, error);
        }
        final row = await _client
            .from('watchlists')
            .insert({
              'user_id': _requireUserId,
              'name': name.trim(),
              if (description != null && description.trim().isNotEmpty)
                'description': description.trim(),
            })
            .select()
            .single();
        return Watchlist.fromJson(row);
      });

  Future<Watchlist> renameWatchlist(String watchlistId, String name) =>
      _guard('renameWatchlist', () async {
        final error = validateWatchlistName(name);
        if (error != null) {
          throw CineFailure(CineFailureKind.invalid, error);
        }
        final row = await _client
            .from('watchlists')
            .update({'name': name.trim()})
            .eq('id', watchlistId)
            .eq('user_id', _requireUserId)
            .select()
            .single();
        return Watchlist.fromJson(row);
      });

  /// Supprime la liste et ses titres (cascade).
  Future<void> deleteWatchlist(String watchlistId) =>
      _guard('deleteWatchlist', () async {
        await _client
            .from('watchlists')
            .delete()
            .eq('id', watchlistId)
            .eq('user_id', _requireUserId);
      });

  /// Ajoute un titre du catalogue (table media) à une liste.
  Future<void> addMediaToWatchlist(String watchlistId, String mediaId) =>
      _guard('addMediaToWatchlist', () async {
        _requireUserId;
        await _client
            .from('watchlist_items')
            .insert({'watchlist_id': watchlistId, 'media_id': mediaId});
      });

  /// Retire un titre d'une liste (la RLS vérifie le propriétaire).
  Future<void> removeWatchlistItem(String itemId) =>
      _guard('removeWatchlistItem', () async {
        _requireUserId;
        await _client.from('watchlist_items').delete().eq('id', itemId);
      });

  // Préférences ----------------------------------------------------------

  Future<UserPreferences> fetchPreferences() =>
      _guard('fetchPreferences', () async {
        final userId = _requireUserId;
        final row = await _client
            .from('user_preferences')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        // Le trigger crée la ligne à l'inscription ; valeurs par défaut sinon.
        return row == null
            ? UserPreferences(userId: userId)
            : UserPreferences.fromJson(row);
      });

  Future<UserPreferences> savePreferences(UserPreferences preferences) =>
      _guard('savePreferences', () async {
        final json = preferences.toJson()
          ..['user_id'] = _requireUserId
          ..remove('updated_at');
        final row = await _client
            .from('user_preferences')
            .upsert(json)
            .select()
            .single();
        return UserPreferences.fromJson(row);
      });

  // Catalogue ------------------------------------------------------------

  Future<List<Genre>> fetchGenres() => _guard('fetchGenres', () async {
        final rows = await _client.from('genres').select().order('name');
        return rows.map(Genre.fromJson).toList();
      });

  Future<List<Platform>> fetchPlatforms() => _guard('fetchPlatforms', () async {
        final rows = await _client.from('platforms').select().order('name');
        return rows.map(Platform.fromJson).toList();
      });

  /// Enregistre (ou met à jour) un film TMDB et renvoie son id Supabase.
  Future<String> cacheMovie(Movie movie) => _guard('cacheMovie', () async {
        final id = await _client.rpc('upsert_movie_from_tmdb',
            params: {'payload': movie.toUpsertPayload()});
        return id as String;
      });

  /// Enregistre (ou met à jour) une série TMDB et renvoie son id Supabase.
  Future<String> cacheSeries(Series series) => _guard('cacheSeries', () async {
        final id = await _client.rpc('upsert_series_from_tmdb',
            params: {'payload': series.toUpsertPayload()});
        return id as String;
      });
}
