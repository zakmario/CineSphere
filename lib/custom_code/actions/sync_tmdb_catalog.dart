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

import 'package:shared_preferences/shared_preferences.dart';

import '/backend/api_requests/api_calls.dart';
import '/custom_code/actions/supabase_service.dart';

/// Met à jour le catalogue (table `media`) avec les listes TMDB du groupe
/// d'appels FlutterFlow « TMDB » : tendances, films et séries populaires,
/// prochaines sorties, séries en cours (membre 1).
///
/// [force] = false (connexion, ouverture des Paramètres) : au plus une fois
/// toutes les 12 h, en arrière-plan ; retourne "" tout de suite.
/// [force] = true (bouton « Actualiser le catalogue ») : attend la fin.
/// Retourne "" en cas de succès, sinon le message d'erreur à afficher.
Future<String> syncTmdbCatalog(bool force) async {
  final prefs = await SharedPreferences.getInstance();
  if (!force) {
    final last = prefs.getInt(kTmdbLastSyncKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    if (elapsed < kTmdbSyncInterval.inMilliseconds) {
      return '';
    }
  }
  final run = TmdbCatalogImporter().run().then((count) async {
    await prefs.setInt(kTmdbLastSyncKey, DateTime.now().millisecondsSinceEpoch);
    developer.log('$count titres importés', name: 'syncTmdbCatalog');
    return '';
  });
  if (!force) {
    unawaited(run.catchError((Object error) {
      developer.log('échec', name: 'syncTmdbCatalog', error: error);
      return '';
    }));
    return '';
  }
  try {
    return await run;
  } on CineFailure catch (failure) {
    return failure.message;
  }
}

const kTmdbLastSyncKey = 'tmdb_last_sync';
const kTmdbSyncInterval = Duration(hours: 12);
const kTmdbImageBase = 'https://image.tmdb.org/t/p/';

/// Une liste TMDB à importer ; [type] = 'movie' ou 'tv' quand la réponse
/// ne précise pas `media_type` (tout sauf les tendances).
typedef TmdbSource = ({String? type, Future<ApiCallResponse> Function() fetch});

/// Convertit un résultat de liste TMDB en ligne pour `import_tmdb_media`.
/// Retourne null pour une personne ou un résultat incomplet.
Map<String, dynamic>? tmdbToMediaPayload(Map<String, dynamic> json,
    {String? type}) {
  final kind = switch (json['media_type'] ?? type) {
    'movie' => 'movie',
    'tv' => 'series',
    _ => null,
  };
  final id = json['id'];
  final title = (json['title'] ?? json['name']) as String?;
  if (kind == null || id is! int || title == null || title.trim().isEmpty) {
    return null;
  }
  String? image(Object? path, String size) =>
      path is String && path.isNotEmpty ? '$kTmdbImageBase$size$path' : null;
  final date = (json['release_date'] ?? json['first_air_date']) as String?;
  return {
    'media_type': kind,
    'tmdb_id': id,
    'title': title.trim(),
    'overview': json['overview'],
    'poster_url': image(json['poster_path'], 'w500'),
    'backdrop_url': image(json['backdrop_path'], 'w1280'),
    'release_date': date == null || date.isEmpty ? null : date,
    'rating': json['vote_average'],
    'popularity': json['popularity'],
    'genre_ids': json['genre_ids'] ?? const <int>[],
  };
}

class TmdbCatalogImporter {
  TmdbCatalogImporter({
    List<TmdbSource>? sources,
    Future<int> Function(List<Map<String, dynamic>> items)? save,
  })  : _sources = sources ?? defaultSources,
        _save = save ?? _saveToSupabase;

  final List<TmdbSource> _sources;
  final Future<int> Function(List<Map<String, dynamic>> items) _save;

  /// Taille maximale d'un envoi à `import_tmdb_media`.
  static const batchSize = 200;

  static List<TmdbSource> get defaultSources => [
        (type: null, fetch: () => TmdbGroup.tendancesCall.call()),
        (type: null, fetch: () => TmdbGroup.tendancesCall.call(page: 2)),
        (type: 'movie', fetch: () => TmdbGroup.filmsPopulairesCall.call()),
        (type: 'tv', fetch: () => TmdbGroup.seriesPopulairesCall.call()),
        (type: 'movie', fetch: () => TmdbGroup.prochainesSortiesCall.call()),
        (type: 'tv', fetch: () => TmdbGroup.seriesEnCoursCall.call()),
      ];

  static Future<int> _saveToSupabase(List<Map<String, dynamic>> items) async {
    try {
      final count = await SupaFlow.client
          .rpc('import_tmdb_media', params: {'items': items});
      return (count as num?)?.toInt() ?? 0;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Récupère toutes les listes (sans doublon) puis les enregistre.
  /// Retourne le nombre de titres créés ou mis à jour.
  Future<int> run() async {
    final items = <String, Map<String, dynamic>>{};
    var failures = 0;
    for (final source in _sources) {
      final response = await source.fetch();
      final body = response.jsonBody;
      final results = body is Map ? body['results'] : null;
      if (!response.succeeded || results is! List) {
        failures++;
        continue;
      }
      for (final result in results.whereType<Map<String, dynamic>>()) {
        final payload = tmdbToMediaPayload(result, type: source.type);
        if (payload != null) {
          items.putIfAbsent(
              '${payload['media_type']}:${payload['tmdb_id']}', () => payload);
        }
      }
    }
    if (failures == _sources.length) {
      throw const CineFailure(CineFailureKind.network,
          'Impossible de joindre TMDB. Vérifiez votre connexion.');
    }
    final all = items.values.toList();
    var saved = 0;
    for (var i = 0; i < all.length; i += batchSize) {
      saved += await _save(all.sublist(i, min(i + batchSize, all.length)));
    }
    return saved;
  }
}
