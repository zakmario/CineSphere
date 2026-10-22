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
/// prochaines sorties, séries en cours ; puis complète les fiches
/// incomplètes avec DetailFilm / DetailSerie (membre 1).
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

/// Un titre du catalogue : `kind` = 'movie' ou 'series' (comme media_type).
typedef TmdbTitle = ({String kind, int tmdbId});

/// Bande-annonce YouTube : française d'abord, puis bande-annonce dans une
/// autre langue, puis teaser.
String? pickTrailerUrl(Object? videos) {
  if (videos is! List) {
    return null;
  }
  int rank(Map<String, dynamic> v) =>
      (v['type'] == 'Trailer'
          ? 0
          : v['type'] == 'Teaser'
              ? 2
              : 4) +
      (v['iso_639_1'] == 'fr' ? 0 : 1);
  final candidates = videos
      .whereType<Map<String, dynamic>>()
      .where((v) => v['site'] == 'YouTube' && v['key'] is String && rank(v) < 4)
      .toList()
    ..sort((a, b) => rank(a).compareTo(rank(b)));
  return candidates.isEmpty
      ? null
      : 'https://www.youtube.com/watch?v=${candidates.first['key']}';
}

/// Réponse de DetailFilm / DetailSerie → ligne pour `enrich_tmdb_media`.
/// Plateformes : abonnements disponibles en France (hors offres avec pub).
Map<String, dynamic> tmdbDetailsPayload(
    TmdbTitle title, Map<String, dynamic> json) {
  final providers = json['watch/providers'];
  final results = providers is Map ? providers['results'] : null;
  final france = results is Map ? results['FR'] : null;
  final flatrate = france is Map ? france['flatrate'] : null;
  final videos = json['videos'];
  return {
    'media_type': title.kind,
    'tmdb_id': title.tmdbId,
    'runtime_minutes': json['runtime'],
    'seasons': json['number_of_seasons'],
    'episodes': json['number_of_episodes'],
    'ended': json['status'] == 'Ended' || json['status'] == 'Canceled',
    'trailer_url': pickTrailerUrl(videos is Map ? videos['results'] : null),
    'providers': [
      if (flatrate is List)
        for (final p in flatrate.whereType<Map<String, dynamic>>())
          // « Netflix Standard with Ads » … : doublon de l'offre principale.
          if (!'${p['provider_name']}'.endsWith('with Ads'))
            {'id': p['provider_id'], 'name': p['provider_name']},
    ],
  };
}

class TmdbCatalogImporter {
  TmdbCatalogImporter({
    List<TmdbSource>? sources,
    Future<int> Function(List<Map<String, dynamic>> items)? save,
    Future<List<TmdbTitle>> Function()? loadIncomplete,
    Future<ApiCallResponse> Function(TmdbTitle title)? fetchDetails,
    Future<int> Function(List<Map<String, dynamic>> items)? saveDetails,
  })  : _sources = sources ?? defaultSources,
        _save = save ?? _rpc('import_tmdb_media'),
        _loadIncomplete = loadIncomplete ?? _loadIncompleteFromSupabase,
        _fetchDetails = fetchDetails ?? _fetchDetailsFromTmdb,
        _saveDetails = saveDetails ?? _rpc('enrich_tmdb_media');

  final List<TmdbSource> _sources;
  final Future<int> Function(List<Map<String, dynamic>> items) _save;
  final Future<List<TmdbTitle>> Function() _loadIncomplete;
  final Future<ApiCallResponse> Function(TmdbTitle title) _fetchDetails;
  final Future<int> Function(List<Map<String, dynamic>> items) _saveDetails;

  /// Taille maximale d'un envoi à `import_tmdb_media`.
  static const batchSize = 200;

  /// Titres complétés par passage (un appel TMDB chacun).
  static const detailsPerRun = 40;

  /// Appels de détail TMDB lancés en même temps.
  static const detailsInParallel = 8;

  static List<TmdbSource> get defaultSources => [
        (type: null, fetch: () => TmdbGroup.tendancesCall.call()),
        (type: null, fetch: () => TmdbGroup.tendancesCall.call(page: 2)),
        (type: 'movie', fetch: () => TmdbGroup.filmsPopulairesCall.call()),
        (type: 'tv', fetch: () => TmdbGroup.seriesPopulairesCall.call()),
        (type: 'movie', fetch: () => TmdbGroup.prochainesSortiesCall.call()),
        (type: 'tv', fetch: () => TmdbGroup.seriesEnCoursCall.call()),
      ];

  static Future<int> Function(List<Map<String, dynamic>> items) _rpc(
          String function) =>
      (items) async {
        try {
          final count =
              await SupaFlow.client.rpc(function, params: {'items': items});
          return (count as num?)?.toInt() ?? 0;
        } catch (error) {
          throw mapSupabaseError(error);
        }
      };

  /// Titres TMDB du catalogue sans durée (films) ou sans saisons (séries),
  /// les plus populaires d'abord.
  static Future<List<TmdbTitle>> _loadIncompleteFromSupabase() async {
    try {
      final rows = await SupaFlow.client
          .from('media')
          .select('media_type, tmdb_id')
          .not('tmdb_id', 'is', null)
          .or('and(media_type.eq.movie,runtime_minutes.is.null),'
              'and(media_type.eq.series,seasons.is.null)')
          .order('popularity', ascending: false)
          .limit(detailsPerRun);
      return [
        for (final row in rows)
          (kind: row['media_type'] as String, tmdbId: row['tmdb_id'] as int),
      ];
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  static Future<ApiCallResponse> _fetchDetailsFromTmdb(TmdbTitle title) =>
      title.kind == 'movie'
          ? TmdbGroup.detailFilmCall.call(movieId: title.tmdbId)
          : TmdbGroup.detailSerieCall.call(seriesId: title.tmdbId);

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
    try {
      await completeDetails();
    } catch (error) {
      // Les listes sont enregistrées ; les détails seront repris au prochain
      // passage.
      developer.log('détails non complétés',
          name: 'TmdbCatalogImporter', error: error);
    }
    return saved;
  }

  /// Complète durée, saisons, statut, bande-annonce et plateformes des titres
  /// qui n'en ont pas encore ([detailsPerRun] au plus). Retourne le nombre de
  /// titres mis à jour.
  Future<int> completeDetails() async {
    final titles = await _loadIncomplete();
    final payloads = <Map<String, dynamic>>[];
    for (var i = 0; i < titles.length; i += detailsInParallel) {
      final batch =
          titles.sublist(i, min(i + detailsInParallel, titles.length));
      final responses = await Future.wait(batch.map(_fetchDetails));
      for (var j = 0; j < batch.length; j++) {
        final body = responses[j].jsonBody;
        if (responses[j].succeeded && body is Map<String, dynamic>) {
          payloads.add(tmdbDetailsPayload(batch[j], body));
        }
      }
    }
    if (payloads.isEmpty) {
      return 0;
    }
    return _saveDetails(payloads);
  }
}
