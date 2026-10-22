import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

const _kPrivateApiFunctionName = 'ffPrivateApiCall';

/// Start TMDB Group Code

class TmdbGroup {
  static String getBaseUrl({
    String? apiKey,
    String? language = 'fr-FR',
  }) {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    return 'https://api.themoviedb.org/3';
  }

  static Map<String, String> headers = {};
  static TendancesCall tendancesCall = TendancesCall();
  static RechercheCall rechercheCall = RechercheCall();
  static FilmsPopulairesCall filmsPopulairesCall = FilmsPopulairesCall();
  static SeriesPopulairesCall seriesPopulairesCall = SeriesPopulairesCall();
  static ProchainesSortiesCall prochainesSortiesCall = ProchainesSortiesCall();
  static SeriesEnCoursCall seriesEnCoursCall = SeriesEnCoursCall();
  static DetailFilmCall detailFilmCall = DetailFilmCall();
  static DetailSerieCall detailSerieCall = DetailSerieCall();
  static GenresFilmsCall genresFilmsCall = GenresFilmsCall();
}

class TendancesCall {
  Future<ApiCallResponse> call({
    int? page = 1,
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'Tendances',
      apiUrl: '${baseUrl}/trending/all/week',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'page': page,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  List? resultats(dynamic response) => getJsonField(
        response,
        r'''$.results''',
        true,
      ) as List?;
  List<int>? ids(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].id''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<int>(x))
          .withoutNulls
          .toList();
  List<String>? titres(dynamic response) => (getJsonField(
        response,
        r'''$.results[:]['title','name']''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<String>? affiches(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].poster_path''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<double>? notes(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].vote_average''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<double>(x))
          .withoutNulls
          .toList();
  int? totalPages(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.total_pages''',
      ));
}

class RechercheCall {
  Future<ApiCallResponse> call({
    int? page = 1,
    String? query = '',
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'Recherche',
      apiUrl: '${baseUrl}/search/multi',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'page': page,
        'query': query,
        'include_adult': "false",
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  List? resultats(dynamic response) => getJsonField(
        response,
        r'''$.results''',
        true,
      ) as List?;
  List<int>? ids(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].id''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<int>(x))
          .withoutNulls
          .toList();
  List<String>? titres(dynamic response) => (getJsonField(
        response,
        r'''$.results[:]['title','name']''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<String>? affiches(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].poster_path''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<double>? notes(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].vote_average''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<double>(x))
          .withoutNulls
          .toList();
  int? totalPages(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.total_pages''',
      ));
}

class FilmsPopulairesCall {
  Future<ApiCallResponse> call({
    int? page = 1,
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'FilmsPopulaires',
      apiUrl: '${baseUrl}/movie/popular',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'page': page,
        'region': "FR",
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  List? resultats(dynamic response) => getJsonField(
        response,
        r'''$.results''',
        true,
      ) as List?;
  List<int>? ids(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].id''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<int>(x))
          .withoutNulls
          .toList();
  List<String>? titres(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].title''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<String>? affiches(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].poster_path''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<double>? notes(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].vote_average''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<double>(x))
          .withoutNulls
          .toList();
  int? totalPages(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.total_pages''',
      ));
}

class SeriesPopulairesCall {
  Future<ApiCallResponse> call({
    int? page = 1,
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'SeriesPopulaires',
      apiUrl: '${baseUrl}/tv/popular',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'page': page,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  List? resultats(dynamic response) => getJsonField(
        response,
        r'''$.results''',
        true,
      ) as List?;
  List<int>? ids(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].id''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<int>(x))
          .withoutNulls
          .toList();
  List<String>? titres(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].name''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<String>? affiches(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].poster_path''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<double>? notes(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].vote_average''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<double>(x))
          .withoutNulls
          .toList();
  int? totalPages(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.total_pages''',
      ));
}

class ProchainesSortiesCall {
  Future<ApiCallResponse> call({
    int? page = 1,
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'ProchainesSorties',
      apiUrl: '${baseUrl}/movie/upcoming',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'page': page,
        'region': "FR",
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  List? resultats(dynamic response) => getJsonField(
        response,
        r'''$.results''',
        true,
      ) as List?;
  List<int>? ids(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].id''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<int>(x))
          .withoutNulls
          .toList();
  List<String>? titres(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].title''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<String>? affiches(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].poster_path''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<double>? notes(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].vote_average''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<double>(x))
          .withoutNulls
          .toList();
  int? totalPages(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.total_pages''',
      ));
}

class SeriesEnCoursCall {
  Future<ApiCallResponse> call({
    int? page = 1,
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'SeriesEnCours',
      apiUrl: '${baseUrl}/tv/on_the_air',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'page': page,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  List? resultats(dynamic response) => getJsonField(
        response,
        r'''$.results''',
        true,
      ) as List?;
  List<int>? ids(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].id''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<int>(x))
          .withoutNulls
          .toList();
  List<String>? titres(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].name''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<String>? affiches(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].poster_path''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List<double>? notes(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].vote_average''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<double>(x))
          .withoutNulls
          .toList();
  int? totalPages(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.total_pages''',
      ));
}

class DetailFilmCall {
  Future<ApiCallResponse> call({
    int? movieId,
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'DetailFilm',
      apiUrl: '${baseUrl}/movie/${movieId}',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'append_to_response': "videos,watch/providers",
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  String? titre(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.title''',
      ));
  String? synopsis(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.overview''',
      ));
  String? affiche(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.poster_path''',
      ));
  String? fond(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.backdrop_path''',
      ));
  String? dateSortie(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.release_date''',
      ));
  int? duree(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.runtime''',
      ));
  double? note(dynamic response) => castToType<double>(getJsonField(
        response,
        r'''$.vote_average''',
      ));
  List<String>? genres(dynamic response) => (getJsonField(
        response,
        r'''$.genres[:].name''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  List? videos(dynamic response) => getJsonField(
        response,
        r'''$.videos.results''',
        true,
      ) as List?;
}

class DetailSerieCall {
  Future<ApiCallResponse> call({
    int? seriesId,
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'DetailSerie',
      apiUrl: '${baseUrl}/tv/${seriesId}',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
        'append_to_response': "videos,watch/providers",
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  String? titre(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.name''',
      ));
  String? synopsis(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.overview''',
      ));
  String? affiche(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.poster_path''',
      ));
  String? fond(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.backdrop_path''',
      ));
  String? premiereDiffusion(dynamic response) =>
      castToType<String>(getJsonField(
        response,
        r'''$.first_air_date''',
      ));
  int? saisons(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.number_of_seasons''',
      ));
  int? episodes(dynamic response) => castToType<int>(getJsonField(
        response,
        r'''$.number_of_episodes''',
      ));
  double? note(dynamic response) => castToType<double>(getJsonField(
        response,
        r'''$.vote_average''',
      ));
  List<String>? genres(dynamic response) => (getJsonField(
        response,
        r'''$.genres[:].name''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  dynamic? prochainEpisode(dynamic response) => getJsonField(
        response,
        r'''$.next_episode_to_air''',
      );
}

class GenresFilmsCall {
  Future<ApiCallResponse> call({
    String? apiKey,
    String? language = 'fr-FR',
  }) async {
    apiKey ??= FFDevEnvironmentValues().tmdbApiKey;
    final baseUrl = TmdbGroup.getBaseUrl(
      apiKey: apiKey,
      language: language,
    );

    return ApiManager.instance.makeApiCall(
      callName: 'GenresFilms',
      apiUrl: '${baseUrl}/genre/movie/list',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'api_key': apiKey,
        'language': language,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: true,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }

  List? genres(dynamic response) => getJsonField(
        response,
        r'''$.genres''',
        true,
      ) as List?;
  List<String>? noms(dynamic response) => (getJsonField(
        response,
        r'''$.genres[:].name''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
}

/// End TMDB Group Code

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String _toEncodable(dynamic item) {
  return item;
}

String _serializeList(List? list) {
  list ??= <String>[];
  try {
    return json.encode(list, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("List serialization failed. Returning empty list.");
    }
    return '[]';
  }
}

String _serializeJson(dynamic jsonVar, [bool isList = false]) {
  jsonVar ??= (isList ? [] : {});
  try {
    return json.encode(jsonVar, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("Json serialization failed. Returning empty json.");
    }
    return isList ? '[]' : '{}';
  }
}
