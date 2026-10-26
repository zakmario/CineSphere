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
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '/backend/api_requests/api_calls.dart';
import '/custom_code/actions/firestore_service.dart';

/// Met à jour le catalogue (collection `media`) avec les listes TMDB du groupe
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

/// Une liste TMDB à importer ; [type] = 'movie' ou 'tv' quand la réponse
/// ne précise pas `media_type` (tout sauf les tendances).
typedef TmdbSource = ({String? type, Future<ApiCallResponse> Function() fetch});

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
    Future<ApiCallResponse> Function(TmdbTitle title)? fetchDetails,
    Future<int> Function(List<Map<String, dynamic>> items)? saveDetails,
  })  : _sources = sources ?? defaultSources,
        _save = save ?? _importToFirestore,
        _loadIncomplete = loadIncomplete ?? _loadIncompleteFromFirestore,
        _fetchDetails = fetchDetails ?? _fetchDetailsFromTmdb,
        _saveDetails = saveDetails ?? _enrichInFirestore;

  final List<TmdbSource> _sources;
  final Future<int> Function(List<Map<String, dynamic>> items) _save;
  final Future<List<TmdbTitle>> Function() _loadIncomplete;
  final Future<ApiCallResponse> Function(TmdbTitle title) _fetchDetails;
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
        (type: null, fetch: () => TmdbGroup.tendancesCall.call()),
        (type: null, fetch: () => TmdbGroup.tendancesCall.call(page: 2)),
        (type: 'movie', fetch: () => TmdbGroup.filmsPopulairesCall.call()),
        (type: 'tv', fetch: () => TmdbGroup.seriesPopulairesCall.call()),
        (type: 'movie', fetch: () => TmdbGroup.prochainesSortiesCall.call()),
        (type: 'tv', fetch: () => TmdbGroup.seriesEnCoursCall.call()),
      ];

  /// Clé `media_type:tmdb_id` -> document du catalogue.
  static Future<Map<String, Map<String, dynamic>>> _catalogByTmdbId() async {
    final rows = await FirestoreService.instance.catalog(refresh: true);
    return {
      for (final row in rows)
        if (row['tmdb_id'] != null) '${row['media_type']}:${row['tmdb_id']}': row,
    };
  }

  /// Écritures Firestore par lots de 450 (limite : 500 par lot).
  static Future<void> _commit(
      List<void Function(WriteBatch batch)> writes) async {
    final db = FirebaseFirestore.instance;
    for (var i = 0; i < writes.length; i += 450) {
      final batch = db.batch();
      for (final write in writes.skip(i).take(450)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  static String _day(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Équivalent de l'ancienne fonction SQL `import_tmdb_media` : crée ou met
  /// à jour les titres (un titre existant garde ses champs non fournis et
  /// son statut « ended »), et ajoute la sortie au cinéma des films à venir
  /// au calendrier.
  static Future<int> _importToFirestore(
      List<Map<String, dynamic>> items) async {
    final service = FirestoreService.instance;
    try {
      service.requireUserId;
      final genres = {
        for (final g in await service.fetchGenres()) g.id: g.name,
      };
      final existing = await _catalogByTmdbId();
      final media = service.col('media');
      final events = service.col('release_events');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final writes = <void Function(WriteBatch)>[];
      var imported = 0;
      for (final item in items) {
        final kind = item['media_type'] as String?;
        final tmdbId = item['tmdb_id'];
        final title = '${item['title'] ?? ''}'.trim();
        if ((kind != 'movie' && kind != 'series') ||
            tmdbId is! int ||
            title.isEmpty) {
          continue;
        }
        final old = existing['$kind:$tmdbId'];
        final date = item['release_date'] as String?;
        final day = date == null ? null : DateTime.tryParse(date);
        final upcoming = day != null && day.isAfter(today);
        final names = [
          for (final id in (item['genre_ids'] as List? ?? const []))
            if (genres[id] != null) genres[id]!,
        ]..sort();
        final overview = '${item['overview'] ?? ''}'.trim();
        final fields = <String, dynamic>{
          'mediaType': kind,
          'tmdbId': tmdbId,
          'title': title.length > 300 ? title.substring(0, 300) : title,
          'titleLower': title.toLowerCase(),
          'status': old?['status'] == 'ended'
              ? 'ended'
              : upcoming
                  ? 'upcoming'
                  : kind == 'series'
                      ? 'ongoing'
                      : 'released',
          'rating': ((item['rating'] as num?)?.toDouble() ?? 0).clamp(0.0, 10.0),
          'popularity': max(0, ((item['popularity'] as num?) ?? 0).round()),
          if (overview.isNotEmpty) 'overview': overview,
          if (item['poster_url'] != null) 'posterUrl': item['poster_url'],
          if (item['backdrop_url'] != null) 'backdropUrl': item['backdrop_url'],
          if (day != null) 'releaseDate': Timestamp.fromDate(day),
          if (names.isNotEmpty) 'genres': names,
          if (old == null) 'createdAt': FieldValue.serverTimestamp(),
          if (old == null) 'platforms': const <String>[],
        };
        final ref = media.doc(old?['id'] as String? ?? '${kind}_$tmdbId');
        fields['id'] = ref.id;
        writes.add((batch) => batch.set(ref, fields, SetOptions(merge: true)));
        if (kind == 'movie' && upcoming) {
          // Identifiant déterministe : une seule sortie par titre et par jour.
          final event = events.doc('${ref.id}_${_day(day)}');
          writes.add((batch) => batch.set(event, {
                'mediaId': ref.id,
                'title': 'Sortie au cinéma',
                'releaseAt': Timestamp.fromDate(day),
                'releaseDate': Timestamp.fromDate(day),
                'platform': 'Cinéma',
              }));
        }
        imported++;
      }
      await _commit(writes);
      service.invalidateCatalog();
      return imported;
    } catch (error) {
      throw mapFirestoreError(error);
    }
  }

  /// Équivalent de l'ancienne fonction SQL `enrich_tmdb_media` : complète
  /// durée, saisons, épisodes, statut, bande-annonce et plateformes.
  static Future<int> _enrichInFirestore(
      List<Map<String, dynamic>> items) async {
    final service = FirestoreService.instance;
    try {
      service.requireUserId;
      final platforms = {
        for (final p in await service.fetchPlatforms()) p.id: p.name,
      };
      final existing = await _catalogByTmdbId();
      final writes = <void Function(WriteBatch)>[];
      for (final item in items) {
        final old = existing['${item['media_type']}:${item['tmdb_id']}'];
        if (old == null) {
          continue;
        }
        int? positive(Object? v) => v is int && v > 0 ? v : null;
        final providers = {
          for (final p in (item['providers'] as List? ?? const []))
            if (p is Map) platforms[p['id']] ?? p['name'] as String?,
        }.whereType<String>().toList();
        final trailer = item['trailer_url'] as String?;
        final fields = <String, dynamic>{
          if (positive(item['runtime_minutes']) != null)
            'runtimeMinutes': item['runtime_minutes'],
          if (positive(item['seasons']) != null) 'seasons': item['seasons'],
          if (positive(item['episodes']) != null) 'episodes': item['episodes'],
          if (old['media_type'] == 'series' && item['ended'] == true)
            'status': 'ended',
          if (trailer != null && trailer.isNotEmpty) 'trailerUrl': trailer,
          if (providers.isNotEmpty) 'platforms': providers,
          'detailsSyncedAt': FieldValue.serverTimestamp(),
        };
        final ref = service.col('media').doc(old['id'] as String);
        writes.add((batch) => batch.update(ref, fields));
      }
      await _commit(writes);
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
    final rows = await FirestoreService.instance.catalog();
    final todo = rows.where((row) {
      if (row['tmdb_id'] == null) {
        return false;
      }
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
