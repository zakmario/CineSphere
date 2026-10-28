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

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '/custom_code/actions/firebase_service.dart';

/// Met à jour le catalogue (collections `movies` et `series`) avec les listes
/// TMDB (mêmes appels que le groupe FlutterFlow « TMDB ») : tendances, films
/// et séries populaires, prochaines sorties, séries en cours ; puis complète
/// les fiches incomplètes avec DetailFilm / DetailSerie (membre 1).
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
  final run = TmdbCatalogImporter().run().then((imported) async {
    await prefs.setInt(kTmdbLastSyncKey, DateTime.now().millisecondsSinceEpoch);
    developer.log('$imported titres importés', name: 'syncTmdbCatalog');
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

/// Réponse d'un appel TMDB : [jsonBody] décodé (null si illisible) et code
/// HTTP (-1 si TMDB est injoignable).
class TmdbResponse {
  const TmdbResponse(this.jsonBody, this.statusCode);

  final dynamic jsonBody;
  final int statusCode;

  bool get succeeded => statusCode >= 200 && statusCode < 300;
}

/// GET sur l'API TMDB, en français, avec la clé de l'environnement
/// FlutterFlow. Reprend les paramètres du groupe d'appels « TMDB » sans
/// passer par le fichier généré api_calls.dart, que l'analyseur de code
/// custom de FlutterFlow ne voit pas.
Future<TmdbResponse> tmdbGet(String path,
    [Map<String, String> params = const {}]) async {
  final uri = Uri.https('api.themoviedb.org', '/3$path', {
    'api_key': FFDevEnvironmentValues().tmdbApiKey,
    'language': 'fr-FR',
    ...params,
  });
  final http.Response response;
  try {
    response = await http.get(uri);
  } catch (_) {
    return const TmdbResponse(null, -1);
  }
  dynamic body;
  try {
    body = jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    body = null;
  }
  return TmdbResponse(body, response.statusCode);
}

/// Une liste TMDB à importer ; [type] = 'movie' ou 'tv' quand la réponse
/// ne précise pas `media_type` (tout sauf les tendances).
typedef TmdbSource = ({String? type, Future<TmdbResponse> Function() fetch});

/// Convertit un résultat de liste TMDB en ligne pour [TmdbCatalogImporter._importToFirestore].
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

/// Réponse de DetailFilm / DetailSerie → ligne pour [TmdbCatalogImporter._enrichInFirestore].
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
    Future<TmdbResponse> Function(TmdbTitle title)? fetchDetails,
    Future<int> Function(List<Map<String, dynamic>> items)? saveDetails,
  })  : _sources = sources ?? defaultSources,
        _save = save ?? _importToFirestore,
        _loadIncomplete = loadIncomplete ?? _loadIncompleteFromFirestore,
        _fetchDetails = fetchDetails ?? _fetchDetailsFromTmdb,
        _saveDetails = saveDetails ?? _enrichInFirestore;

  final List<TmdbSource> _sources;
  final Future<int> Function(List<Map<String, dynamic>> items) _save;
  final Future<List<TmdbTitle>> Function() _loadIncomplete;
  final Future<TmdbResponse> Function(TmdbTitle title) _fetchDetails;
  final Future<int> Function(List<Map<String, dynamic>> items) _saveDetails;

  /// Taille maximale d'un envoi à [_importToFirestore].
  static const batchSize = 200;

  /// Titres complétés par passage (un appel TMDB chacun).
  static const detailsPerRun = 60;

  /// Délai avant de redemander la bande-annonce d'un titre qui n'en a pas.
  static const detailsRetryAfter = Duration(days: 7);

  /// Appels de détail TMDB lancés en même temps.
  static const detailsInParallel = 8;

  static List<TmdbSource> get defaultSources => [
        (type: null, fetch: () => tmdbGet('/trending/all/week')),
        (type: null, fetch: () => tmdbGet('/trending/all/week', {'page': '2'})),
        (type: 'movie', fetch: () => tmdbGet('/movie/popular', {'region': 'FR'})),
        (type: 'tv', fetch: () => tmdbGet('/tv/popular')),
        (type: 'movie', fetch: () => tmdbGet('/movie/upcoming', {'region': 'FR'})),
        (type: 'tv', fetch: () => tmdbGet('/tv/on_the_air')),
      ];

  /// Clé `media_type:tmdb_id` -> ligne du catalogue.
  static Future<Map<String, Map<String, dynamic>>> _catalogByTmdbId() async {
    final rows = await CineFirebaseService.instance.catalog(refresh: true);
    return {
      for (final row in rows) '${row['media_type']}:${row['tmdb_id']}': row,
    };
  }

  static Timestamp? _date(String? value) {
    final day = value == null ? null : DateTime.tryParse(value);
    return day == null ? null : Timestamp.fromDate(day);
  }

  /// Cache TMDB (section 5.4) : crée ou met à jour `movies/{tmdbId}` et
  /// `series/{tmdbId}`. Un titre existant garde ses champs non fournis et
  /// son statut « ended ». Les sorties (`releaseEvents`) sont réservées aux
  /// admins par les règles : tool/seed_firestore.dart les génère.
  static Future<int> _importToFirestore(
      List<Map<String, dynamic>> items) async {
    final service = CineFirebaseService.instance;
    try {
      service.requireUserId;
      final existing = await _catalogByTmdbId();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final writes = <void Function(WriteBatch)>[];
      for (final item in items) {
        final kind = item['media_type'] as String? ?? '';
        final tmdbId = item['tmdb_id'];
        final title = '${item['title'] ?? ''}'.trim();
        if ((kind != 'movie' && kind != 'series') ||
            tmdbId is! int ||
            title.isEmpty) {
          continue;
        }
        final old = existing['$kind:$tmdbId'];
        final date = _date(item['release_date'] as String?);
        final upcoming = date != null && date.toDate().isAfter(today);
        final series = kind == 'series';
        final overview = '${item['overview'] ?? ''}'.trim();
        final genreIds = [
          for (final id in (item['genre_ids'] as List? ?? const []))
            if (id is int) id,
        ];
        final fields = <String, dynamic>{
          'tmdbId': tmdbId,
          'title': title.length > 300 ? title.substring(0, 300) : title,
          'status': old?['status'] == 'ended'
              ? 'ended'
              : upcoming
                  ? 'upcoming'
                  : series
                      ? 'ongoing'
                      : 'released',
          'rating': ((item['rating'] as num?)?.toDouble() ?? 0).clamp(0.0, 10.0),
          'popularity': max(0, ((item['popularity'] as num?) ?? 0).round()),
          if (overview.isNotEmpty) 'description': overview,
          if (item['poster_url'] != null) 'posterUrl': item['poster_url'],
          if (item['backdrop_url'] != null) 'backdropUrl': item['backdrop_url'],
          if (date != null) series ? 'firstAirDate' : 'releaseDate': date,
          if (genreIds.isNotEmpty) 'genreIds': genreIds,
          if (old == null) 'platforms': const <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final ref = service.col(catalogCollection(kind)).doc('$tmdbId');
        writes.add((batch) => batch.set(ref, fields, SetOptions(merge: true)));
      }
      await service.commitInChunks(writes);
      service.invalidateCatalog();
      return writes.length;
    } catch (error) {
      throw mapFirestoreError(error);
    }
  }

  /// Complète durée, saisons, épisodes, statut, bande-annonce et plateformes
  /// (ancienne fonction SQL `enrich_tmdb_media`).
  static Future<int> _enrichInFirestore(
      List<Map<String, dynamic>> items) async {
    final service = CineFirebaseService.instance;
    try {
      service.requireUserId;
      final platforms = {
        for (final p in await service.fetchPlatforms()) p.id: p.name,
      };
      final existing = await _catalogByTmdbId();
      final writes = <void Function(WriteBatch)>[];
      for (final item in items) {
        final kind = item['media_type'] as String;
        if (existing['$kind:${item['tmdb_id']}'] == null) {
          continue;
        }
        final series = kind == 'series';
        int? positive(Object? v) => v is int && v > 0 ? v : null;
        final providers = {
          for (final p in (item['providers'] as List? ?? const []))
            if (p is Map) platforms[p['id']] ?? p['name'] as String?,
        }.whereType<String>().toList();
        final trailer = item['trailer_url'] as String?;
        final fields = <String, dynamic>{
          if (!series && positive(item['runtime_minutes']) != null)
            'duration': item['runtime_minutes'],
          if (series && positive(item['seasons']) != null)
            'numberOfSeasons': item['seasons'],
          if (series && positive(item['episodes']) != null)
            'numberOfEpisodes': item['episodes'],
          if (series && item['ended'] == true) 'status': 'ended',
          if (trailer != null && trailer.isNotEmpty) 'trailerUrl': trailer,
          if (providers.isNotEmpty) 'platforms': providers,
          'detailsSyncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final ref =
            service.col(catalogCollection(kind)).doc('${item['tmdb_id']}');
        writes.add((batch) => batch.update(ref, fields));
      }
      await service.commitInChunks(writes);
      service.invalidateCatalog();
      return writes.length;
    } catch (error) {
      throw mapFirestoreError(error);
    }
  }

  /// Titres TMDB jamais complétés, ou toujours sans bande-annonce
  /// [detailsRetryAfter] après le dernier passage ; les plus populaires
  /// d'abord.
  static Future<List<TmdbTitle>> _loadIncompleteFromFirestore() async {
    final retryBefore = DateTime.now().toUtc().subtract(detailsRetryAfter);
    final rows = await CineFirebaseService.instance.catalog();
    final todo = rows.where((row) {
      final synced = row['details_synced_at'] == null
          ? null
          : DateTime.parse(row['details_synced_at'] as String);
      return synced == null ||
          (row['trailer_url'] == null && synced.isBefore(retryBefore));
    }).toList()
      ..sort((a, b) => ((b['popularity'] as num?) ?? 0)
          .compareTo((a['popularity'] as num?) ?? 0));
    return [
      for (final row in todo.take(detailsPerRun))
        (kind: row['media_type'] as String, tmdbId: row['tmdb_id'] as int),
    ];
  }

  /// DetailFilm / DetailSerie.
  static Future<TmdbResponse> _fetchDetailsFromTmdb(TmdbTitle title) =>
      tmdbGet(
          title.kind == 'movie'
              ? '/movie/${title.tmdbId}'
              : '/tv/${title.tmdbId}',
          const {
            'append_to_response': 'videos,watch/providers',
            'include_video_language': 'fr,en,null',
          });

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
  /// à reprendre ([detailsPerRun] au plus). Retourne le nombre de
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
