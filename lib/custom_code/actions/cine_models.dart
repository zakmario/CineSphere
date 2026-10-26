// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';

import 'package:collection/collection.dart';

/// Modèles des collections Firestore de CinéSphère (firebase/firestore.rules).
///
/// FlutterFlow ne synchronise que les fichiers d'actions, de widgets et de
/// fonctions : ce fichier est donc une action dont la fonction ci-dessous
/// renvoie la version du schéma attendue par l'application. Les autres
/// fichiers de code personnalisé importent les modèles avec
/// `import '/custom_code/actions/cine_models.dart';`.
const int kCineSchemaVersion = 1;

Future<int> cineModels() async => kCineSchemaVersion;

// ---------------------------------------------------------------------------
// Base commune : égalité par valeur et conversion SQLite.
// ---------------------------------------------------------------------------

const _deepEquality = DeepCollectionEquality();

abstract class CineModel {
  const CineModel();

  /// Valeurs comparées par [==] et [hashCode].
  List<Object?> get props;

  /// Représentation JSON (clés snake_case ; voir cineRow dans firestore_service).
  Map<String, dynamic> toJson();

  /// Représentation SQLite : booléens en 0/1, listes en JSON.
  Map<String, dynamic> toMap() => encodeSqliteRow(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          _deepEquality.equals(props, (other as CineModel).props));

  @override
  int get hashCode => Object.hash(runtimeType, _deepEquality.hash(props));

  @override
  String toString() => '$runtimeType${toJson()}';
}

/// Convertit une ligne JSON en ligne SQLite (types natifs SQLite uniquement).
Map<String, dynamic> encodeSqliteRow(Map<String, dynamic> json) =>
    json.map((key, value) {
      if (value is bool) {
        return MapEntry(key, value ? 1 : 0);
      }
      if (value is List || value is Map) {
        return MapEntry(key, jsonEncode(value));
      }
      return MapEntry(key, value);
    });

/// Inverse de [encodeSqliteRow] pour les colonnes listées.
Map<String, dynamic> decodeSqliteRow(
  Map<String, dynamic> row, {
  List<String> bools = const [],
  List<String> lists = const [],
}) {
  final json = Map<String, dynamic>.from(row);
  for (final key in bools) {
    final value = json[key];
    if (value is int) {
      json[key] = value != 0;
    }
  }
  for (final key in lists) {
    final value = json[key];
    if (value is String) {
      json[key] = value.isEmpty ? <dynamic>[] : jsonDecode(value);
    }
  }
  return json;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

DateTime _dateOr(Object? value, DateTime fallback) => _date(value) ?? fallback;

double? _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}');

int? _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');

List<T> _list<T>(Object? value) =>
    value is List ? value.whereType<T>().toList() : <T>[];

List<int> _intList(Object? value) => value is List
    ? value.map(_int).whereType<int>().toList()
    : <int>[];

/// `2026-10-20` (colonnes `date`).
String? _dateOnly(DateTime? date) =>
    date?.toIso8601String().split('T').first;

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum MediaType {
  movie('movie'),
  series('series');

  const MediaType(this.value);
  final String value;

  static MediaType fromValue(String? value) =>
      MediaType.values.firstWhere((t) => t.value == value,
          orElse: () => MediaType.movie);
}

enum UserRole {
  user('user'),
  admin('admin');

  const UserRole(this.value);
  final String value;

  static UserRole fromValue(String? value) =>
      value == 'admin' ? UserRole.admin : UserRole.user;
}

enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.value);
  final String value;

  static AppThemeMode fromValue(String? value) =>
      AppThemeMode.values.firstWhere((m) => m.value == value,
          orElse: () => AppThemeMode.dark);
}

/// Cible d'une ligne liée à un contenu : exactement un film OU une série
/// (contraintes CHECK des tables favorites, watched, reviews...).
mixin MediaTarget {
  String? get movieId;
  String? get seriesId;

  MediaType get mediaType =>
      movieId != null ? MediaType.movie : MediaType.series;

  /// Identifiant Firestore du film ou de la série.
  String get targetId => movieId ?? seriesId ?? '';
}

// ---------------------------------------------------------------------------
// Profil et préférences
// ---------------------------------------------------------------------------

class UserProfile extends CineModel {
  const UserProfile({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    this.bio,
    this.role = UserRole.user,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAdmin => role == UserRole.admin;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        role: UserRole.fromValue(json['role'] as String?),
        createdAt: _date(json['created_at']),
        updatedAt: _date(json['updated_at']),
      );

  factory UserProfile.fromMap(Map<String, dynamic> map) =>
      UserProfile.fromJson(decodeSqliteRow(map));

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'bio': bio,
        'role': role.value,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Champs modifiables par l'utilisateur (le rôle est protégé côté base).
  Map<String, dynamic> toUpdateJson() => {
        'username': username,
        'avatar_url': avatarUrl,
        'bio': bio,
      };

  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? bio,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UserProfile(
        id: id ?? this.id,
        username: username ?? this.username,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        role: role ?? this.role,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, username, email, avatarUrl, bio, role, createdAt, updatedAt];
}

class UserPreferences extends CineModel {
  const UserPreferences({
    required this.userId,
    this.favoriteGenres = const [],
    this.favoritePlatforms = const [],
    this.contentTypes = const [MediaType.movie, MediaType.series],
    this.notificationsEnabled = true,
    this.notifyReleases = true,
    this.notifyFavoriteSeries = true,
    this.reminderTime = const TimeOfDay(hour: 18, minute: 0),
    this.themeMode = AppThemeMode.dark,
    this.onboardingCompleted = false,
    this.updatedAt,
  });

  final String userId;

  /// Identifiants de genres TMDB.
  final List<int> favoriteGenres;

  /// Noms des plateformes (table platforms).
  final List<String> favoritePlatforms;
  final List<MediaType> contentTypes;
  final bool notificationsEnabled;
  final bool notifyReleases;
  final bool notifyFavoriteSeries;
  final TimeOfDay reminderTime;
  final AppThemeMode themeMode;
  final bool onboardingCompleted;
  final DateTime? updatedAt;

  static const _bools = [
    'notifications_enabled',
    'notify_releases',
    'notify_favorite_series',
    'onboarding_completed',
  ];
  static const _lists = [
    'favorite_genres',
    'favorite_platforms',
    'content_types',
  ];

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        userId: json['user_id'] as String,
        favoriteGenres: _intList(json['favorite_genres']),
        favoritePlatforms: _list<String>(json['favorite_platforms']),
        contentTypes: json['content_types'] is List
            ? _list<String>(json['content_types'])
                .map(MediaType.fromValue)
                .toList()
            : const [MediaType.movie, MediaType.series],
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        notifyReleases: json['notify_releases'] as bool? ?? true,
        notifyFavoriteSeries: json['notify_favorite_series'] as bool? ?? true,
        reminderTime: parseTimeOfDay(json['reminder_time'] as String?),
        themeMode: AppThemeMode.fromValue(json['theme_mode'] as String?),
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
        updatedAt: _date(json['updated_at']),
      );

  factory UserPreferences.fromMap(Map<String, dynamic> map) =>
      UserPreferences.fromJson(
          decodeSqliteRow(map, bools: _bools, lists: _lists));

  @override
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'favorite_genres': favoriteGenres,
        'favorite_platforms': favoritePlatforms,
        'content_types': contentTypes.map((t) => t.value).toList(),
        'notifications_enabled': notificationsEnabled,
        'notify_releases': notifyReleases,
        'notify_favorite_series': notifyFavoriteSeries,
        'reminder_time': formatTimeOfDay(reminderTime),
        'theme_mode': themeMode.value,
        'onboarding_completed': onboardingCompleted,
        'updated_at': updatedAt?.toIso8601String(),
      };

  UserPreferences copyWith({
    List<int>? favoriteGenres,
    List<String>? favoritePlatforms,
    List<MediaType>? contentTypes,
    bool? notificationsEnabled,
    bool? notifyReleases,
    bool? notifyFavoriteSeries,
    TimeOfDay? reminderTime,
    AppThemeMode? themeMode,
    bool? onboardingCompleted,
    DateTime? updatedAt,
  }) =>
      UserPreferences(
        userId: userId,
        favoriteGenres: favoriteGenres ?? this.favoriteGenres,
        favoritePlatforms: favoritePlatforms ?? this.favoritePlatforms,
        contentTypes: contentTypes ?? this.contentTypes,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        notifyReleases: notifyReleases ?? this.notifyReleases,
        notifyFavoriteSeries: notifyFavoriteSeries ?? this.notifyFavoriteSeries,
        reminderTime: reminderTime ?? this.reminderTime,
        themeMode: themeMode ?? this.themeMode,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        userId,
        favoriteGenres,
        favoritePlatforms,
        contentTypes,
        notificationsEnabled,
        notifyReleases,
        notifyFavoriteSeries,
        reminderTime,
        themeMode,
        onboardingCompleted,
        updatedAt,
      ];
}

/// `18:30:00` (type Postgres `time`) -> TimeOfDay. 18 h 00 par défaut.
TimeOfDay parseTimeOfDay(String? value) {
  final parts = (value ?? '').split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return const TimeOfDay(hour: 18, minute: 0);
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}:00';

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

class Genre extends CineModel {
  const Genre({required this.id, required this.name});

  /// Identifiant TMDB.
  final int id;
  final String name;

  factory Genre.fromJson(Map<String, dynamic> json) =>
      Genre(id: _int(json['id']) ?? 0, name: json['name'] as String? ?? '');

  factory Genre.fromMap(Map<String, dynamic> map) => Genre.fromJson(map);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  Genre copyWith({int? id, String? name}) =>
      Genre(id: id ?? this.id, name: name ?? this.name);

  @override
  List<Object?> get props => [id, name];
}

class Platform extends CineModel {
  const Platform({required this.id, required this.name, this.logoUrl});

  /// Identifiant de fournisseur TMDB (0 = cinéma).
  final int id;
  final String name;
  final String? logoUrl;

  factory Platform.fromJson(Map<String, dynamic> json) => Platform(
        id: _int(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        logoUrl: json['logo_url'] as String?,
      );

  factory Platform.fromMap(Map<String, dynamic> map) => Platform.fromJson(map);

  @override
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'logo_url': logoUrl};

  Platform copyWith({int? id, String? name, String? logoUrl}) => Platform(
        id: id ?? this.id,
        name: name ?? this.name,
        logoUrl: logoUrl ?? this.logoUrl,
      );

  @override
  List<Object?> get props => [id, name, logoUrl];
}

class Movie extends CineModel {
  const Movie({
    this.id,
    required this.tmdbId,
    required this.title,
    this.description,
    this.posterUrl,
    this.backdropUrl,
    this.releaseDate,
    this.duration,
    this.rating,
    this.trailerUrl,
    this.status,
    this.genreIds = const [],
    this.createdAt,
  });

  /// Identifiant Firestore (null tant que le film n'est pas mis en cache).
  final String? id;
  final int tmdbId;
  final String title;
  final String? description;
  final String? posterUrl;
  final String? backdropUrl;
  final DateTime? releaseDate;

  /// Durée en minutes.
  final int? duration;

  /// Note sur 10.
  final double? rating;
  final String? trailerUrl;

  /// upcoming | released | canceled
  final String? status;
  final List<int> genreIds;
  final DateTime? createdAt;

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
        id: json['id'] as String?,
        tmdbId: _int(json['tmdb_id']) ?? 0,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        releaseDate: _date(json['release_date']),
        duration: _int(json['duration']),
        rating: _double(json['rating']),
        trailerUrl: json['trailer_url'] as String?,
        status: json['status'] as String?,
        genreIds: _intList(json['genre_ids']),
        createdAt: _date(json['created_at']),
      );

  factory Movie.fromMap(Map<String, dynamic> map) =>
      Movie.fromJson(decodeSqliteRow(map, lists: ['genre_ids']));

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'tmdb_id': tmdbId,
        'title': title,
        'description': description,
        'poster_url': posterUrl,
        'backdrop_url': backdropUrl,
        'release_date': _dateOnly(releaseDate),
        'duration': duration,
        'rating': rating,
        'trailer_url': trailerUrl,
        'status': status,
        'genre_ids': genreIds,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Charge utile de la fonction `upsert_movie_from_tmdb`.
  Map<String, dynamic> toUpsertPayload() => Map.of(toJson())
    ..remove('id')
    ..remove('created_at');

  Movie copyWith({
    String? id,
    int? tmdbId,
    String? title,
    String? description,
    String? posterUrl,
    String? backdropUrl,
    DateTime? releaseDate,
    int? duration,
    double? rating,
    String? trailerUrl,
    String? status,
    List<int>? genreIds,
    DateTime? createdAt,
  }) =>
      Movie(
        id: id ?? this.id,
        tmdbId: tmdbId ?? this.tmdbId,
        title: title ?? this.title,
        description: description ?? this.description,
        posterUrl: posterUrl ?? this.posterUrl,
        backdropUrl: backdropUrl ?? this.backdropUrl,
        releaseDate: releaseDate ?? this.releaseDate,
        duration: duration ?? this.duration,
        rating: rating ?? this.rating,
        trailerUrl: trailerUrl ?? this.trailerUrl,
        status: status ?? this.status,
        genreIds: genreIds ?? this.genreIds,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        tmdbId,
        title,
        description,
        posterUrl,
        backdropUrl,
        releaseDate,
        duration,
        rating,
        trailerUrl,
        status,
        genreIds,
        createdAt,
      ];
}

class Series extends CineModel {
  const Series({
    this.id,
    required this.tmdbId,
    required this.title,
    this.description,
    this.posterUrl,
    this.backdropUrl,
    this.firstAirDate,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.rating,
    this.status,
    this.genreIds = const [],
    this.createdAt,
  });

  final String? id;
  final int tmdbId;
  final String title;
  final String? description;
  final String? posterUrl;
  final String? backdropUrl;
  final DateTime? firstAirDate;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final double? rating;

  /// upcoming | ongoing | ended | canceled
  final String? status;
  final List<int> genreIds;
  final DateTime? createdAt;

  factory Series.fromJson(Map<String, dynamic> json) => Series(
        id: json['id'] as String?,
        tmdbId: _int(json['tmdb_id']) ?? 0,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        firstAirDate: _date(json['first_air_date']),
        numberOfSeasons: _int(json['number_of_seasons']),
        numberOfEpisodes: _int(json['number_of_episodes']),
        rating: _double(json['rating']),
        status: json['status'] as String?,
        genreIds: _intList(json['genre_ids']),
        createdAt: _date(json['created_at']),
      );

  factory Series.fromMap(Map<String, dynamic> map) =>
      Series.fromJson(decodeSqliteRow(map, lists: ['genre_ids']));

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'tmdb_id': tmdbId,
        'title': title,
        'description': description,
        'poster_url': posterUrl,
        'backdrop_url': backdropUrl,
        'first_air_date': _dateOnly(firstAirDate),
        'number_of_seasons': numberOfSeasons,
        'number_of_episodes': numberOfEpisodes,
        'rating': rating,
        'status': status,
        'genre_ids': genreIds,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Charge utile de la fonction `upsert_series_from_tmdb`.
  Map<String, dynamic> toUpsertPayload() => Map.of(toJson())
    ..remove('id')
    ..remove('created_at');

  Series copyWith({
    String? id,
    int? tmdbId,
    String? title,
    String? description,
    String? posterUrl,
    String? backdropUrl,
    DateTime? firstAirDate,
    int? numberOfSeasons,
    int? numberOfEpisodes,
    double? rating,
    String? status,
    List<int>? genreIds,
    DateTime? createdAt,
  }) =>
      Series(
        id: id ?? this.id,
        tmdbId: tmdbId ?? this.tmdbId,
        title: title ?? this.title,
        description: description ?? this.description,
        posterUrl: posterUrl ?? this.posterUrl,
        backdropUrl: backdropUrl ?? this.backdropUrl,
        firstAirDate: firstAirDate ?? this.firstAirDate,
        numberOfSeasons: numberOfSeasons ?? this.numberOfSeasons,
        numberOfEpisodes: numberOfEpisodes ?? this.numberOfEpisodes,
        rating: rating ?? this.rating,
        status: status ?? this.status,
        genreIds: genreIds ?? this.genreIds,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        tmdbId,
        title,
        description,
        posterUrl,
        backdropUrl,
        firstAirDate,
        numberOfSeasons,
        numberOfEpisodes,
        rating,
        status,
        genreIds,
        createdAt,
      ];
}

// ---------------------------------------------------------------------------
// Données utilisateur liées à un contenu
// ---------------------------------------------------------------------------

class Favorite extends CineModel with MediaTarget {
  const Favorite({
    required this.id,
    required this.userId,
    this.movieId,
    this.seriesId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  @override
  final String? movieId;
  @override
  final String? seriesId;
  final DateTime createdAt;

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        movieId: json['movie_id'] as String?,
        seriesId: json['series_id'] as String?,
        createdAt: _dateOr(json['created_at'], _epoch),
      );

  factory Favorite.fromMap(Map<String, dynamic> map) => Favorite.fromJson(map);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'movie_id': movieId,
        'series_id': seriesId,
        'created_at': createdAt.toIso8601String(),
      };

  Favorite copyWith({DateTime? createdAt}) => Favorite(
        id: id,
        userId: userId,
        movieId: movieId,
        seriesId: seriesId,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [id, userId, movieId, seriesId, createdAt];
}

class Watchlist extends CineModel {
  const Watchlist({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.isPublic = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final bool isPublic;
  final DateTime createdAt;

  factory Watchlist.fromJson(Map<String, dynamic> json) => Watchlist(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        isPublic: json['is_public'] as bool? ?? false,
        createdAt: _dateOr(json['created_at'], _epoch),
      );

  factory Watchlist.fromMap(Map<String, dynamic> map) =>
      Watchlist.fromJson(decodeSqliteRow(map, bools: ['is_public']));

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'is_public': isPublic,
        'created_at': createdAt.toIso8601String(),
      };

  Watchlist copyWith({String? name, String? description, bool? isPublic}) =>
      Watchlist(
        id: id,
        userId: userId,
        name: name ?? this.name,
        description: description ?? this.description,
        isPublic: isPublic ?? this.isPublic,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, userId, name, description, isPublic, createdAt];
}

class WatchlistItem extends CineModel with MediaTarget {
  const WatchlistItem({
    required this.id,
    required this.watchlistId,
    this.movieId,
    this.seriesId,
    required this.addedAt,
  });

  final String id;
  final String watchlistId;
  @override
  final String? movieId;
  @override
  final String? seriesId;
  final DateTime addedAt;

  factory WatchlistItem.fromJson(Map<String, dynamic> json) => WatchlistItem(
        id: json['id'] as String,
        watchlistId: json['watchlist_id'] as String,
        movieId: json['movie_id'] as String?,
        seriesId: json['series_id'] as String?,
        addedAt: _dateOr(json['added_at'], _epoch),
      );

  factory WatchlistItem.fromMap(Map<String, dynamic> map) =>
      WatchlistItem.fromJson(map);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'watchlist_id': watchlistId,
        'movie_id': movieId,
        'series_id': seriesId,
        'added_at': addedAt.toIso8601String(),
      };

  WatchlistItem copyWith({DateTime? addedAt}) => WatchlistItem(
        id: id,
        watchlistId: watchlistId,
        movieId: movieId,
        seriesId: seriesId,
        addedAt: addedAt ?? this.addedAt,
      );

  @override
  List<Object?> get props => [id, watchlistId, movieId, seriesId, addedAt];
}

class WatchedEntry extends CineModel with MediaTarget {
  const WatchedEntry({
    required this.id,
    required this.userId,
    this.movieId,
    this.seriesId,
    this.episodeId,
    required this.watchedAt,
  });

  final String id;
  final String userId;
  @override
  final String? movieId;
  @override
  final String? seriesId;

  /// Identifiant d'épisode TMDB.
  final int? episodeId;
  final DateTime watchedAt;

  factory WatchedEntry.fromJson(Map<String, dynamic> json) => WatchedEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        movieId: json['movie_id'] as String?,
        seriesId: json['series_id'] as String?,
        episodeId: _int(json['episode_id']),
        watchedAt: _dateOr(json['watched_at'], _epoch),
      );

  factory WatchedEntry.fromMap(Map<String, dynamic> map) =>
      WatchedEntry.fromJson(map);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'movie_id': movieId,
        'series_id': seriesId,
        'episode_id': episodeId,
        'watched_at': watchedAt.toIso8601String(),
      };

  WatchedEntry copyWith({DateTime? watchedAt}) => WatchedEntry(
        id: id,
        userId: userId,
        movieId: movieId,
        seriesId: seriesId,
        episodeId: episodeId,
        watchedAt: watchedAt ?? this.watchedAt,
      );

  @override
  List<Object?> get props =>
      [id, userId, movieId, seriesId, episodeId, watchedAt];
}

class Review extends CineModel with MediaTarget {
  const Review({
    required this.id,
    required this.userId,
    this.movieId,
    this.seriesId,
    required this.rating,
    this.content,
    this.isPrivate = false,
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.authorUsername,
  });

  final String id;
  final String userId;
  @override
  final String? movieId;
  @override
  final String? seriesId;

  /// Note de 1 à 10.
  final int rating;
  final String? content;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Calculés par la requête (non stockés dans reviews).
  final int likesCount;
  final String? authorUsername;

  factory Review.fromJson(Map<String, dynamic> json) {
    final likes = json['review_likes'];
    final author = json['author'];
    return Review(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as String?,
      seriesId: json['series_id'] as String?,
      rating: _int(json['rating']) ?? 1,
      content: json['content'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      createdAt: _dateOr(json['created_at'], _epoch),
      updatedAt: _date(json['updated_at']),
      likesCount: likes is List && likes.isNotEmpty && likes.first is Map
          ? _int((likes.first as Map)['count']) ?? 0
          : _int(json['likes_count']) ?? 0,
      authorUsername: author is Map
          ? author['username'] as String?
          : json['author_username'] as String?,
    );
  }

  factory Review.fromMap(Map<String, dynamic> map) =>
      Review.fromJson(decodeSqliteRow(map, bools: ['is_private']));

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'movie_id': movieId,
        'series_id': seriesId,
        'rating': rating,
        'content': content,
        'is_private': isPrivate,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'likes_count': likesCount,
        'author_username': authorUsername,
      };

  /// Colonnes de la table reviews (sans les champs calculés).
  Map<String, dynamic> toRowJson() => Map.of(toJson())
    ..remove('likes_count')
    ..remove('author_username');

  Review copyWith({
    int? rating,
    String? content,
    bool? isPrivate,
    DateTime? updatedAt,
    int? likesCount,
  }) =>
      Review(
        id: id,
        userId: userId,
        movieId: movieId,
        seriesId: seriesId,
        rating: rating ?? this.rating,
        content: content ?? this.content,
        isPrivate: isPrivate ?? this.isPrivate,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        likesCount: likesCount ?? this.likesCount,
        authorUsername: authorUsername,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        movieId,
        seriesId,
        rating,
        content,
        isPrivate,
        createdAt,
        updatedAt,
        likesCount,
        authorUsername,
      ];
}

// ---------------------------------------------------------------------------
// Sorties, notifications, recherches
// ---------------------------------------------------------------------------

class ReleaseEvent extends CineModel {
  const ReleaseEvent({
    required this.id,
    this.movieId,
    this.seriesId,
    required this.title,
    required this.releaseAt,
    this.platform,
    this.seasonNumber,
    this.episodeNumber,
    this.description,
  });

  final String id;
  final String? movieId;
  final String? seriesId;
  final String title;

  /// Date et heure de sortie (colonne release_at, release_date en dérive).
  final DateTime releaseAt;
  final String? platform;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? description;

  bool get isEpisode => seriesId != null && episodeNumber != null;

  factory ReleaseEvent.fromJson(Map<String, dynamic> json) => ReleaseEvent(
        id: json['id'] as String,
        movieId: json['movie_id'] as String?,
        seriesId: json['series_id'] as String?,
        title: json['title'] as String? ?? '',
        releaseAt: _dateOr(json['release_at'] ?? json['release_date'], _epoch),
        platform: json['platform'] as String?,
        seasonNumber: _int(json['season_number']),
        episodeNumber: _int(json['episode_number']),
        description: json['description'] as String?,
      );

  factory ReleaseEvent.fromMap(Map<String, dynamic> map) =>
      ReleaseEvent.fromJson(map);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'movie_id': movieId,
        'series_id': seriesId,
        'title': title,
        'release_at': releaseAt.toIso8601String(),
        'platform': platform,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'description': description,
      };

  ReleaseEvent copyWith({
    String? title,
    DateTime? releaseAt,
    String? platform,
    String? description,
  }) =>
      ReleaseEvent(
        id: id,
        movieId: movieId,
        seriesId: seriesId,
        title: title ?? this.title,
        releaseAt: releaseAt ?? this.releaseAt,
        platform: platform ?? this.platform,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        description: description ?? this.description,
      );

  @override
  List<Object?> get props => [
        id,
        movieId,
        seriesId,
        title,
        releaseAt,
        platform,
        seasonNumber,
        episodeNumber,
        description,
      ];
}

class AppNotification extends CineModel {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.releaseEventId,
    this.scheduledAt,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final String? releaseEventId;
  final DateTime? scheduledAt;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        releaseEventId: json['release_event_id'] as String?,
        scheduledAt: _date(json['scheduled_at']),
        isRead: json['is_read'] as bool? ?? false,
        createdAt: _dateOr(json['created_at'], _epoch),
      );

  factory AppNotification.fromMap(Map<String, dynamic> map) =>
      AppNotification.fromJson(decodeSqliteRow(map, bools: ['is_read']));

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'release_event_id': releaseEventId,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        userId: userId,
        title: title,
        message: message,
        releaseEventId: releaseEventId,
        scheduledAt: scheduledAt,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        message,
        releaseEventId,
        scheduledAt,
        isRead,
        createdAt,
      ];
}

class SearchHistoryEntry extends CineModel {
  const SearchHistoryEntry({
    required this.id,
    required this.userId,
    required this.query,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String query;
  final DateTime createdAt;

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntry(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        query: json['query'] as String? ?? '',
        createdAt: _dateOr(json['created_at'], _epoch),
      );

  factory SearchHistoryEntry.fromMap(Map<String, dynamic> map) =>
      SearchHistoryEntry.fromJson(map);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'query': query,
        'created_at': createdAt.toIso8601String(),
      };

  SearchHistoryEntry copyWith({String? query, DateTime? createdAt}) =>
      SearchHistoryEntry(
        id: id,
        userId: userId,
        query: query ?? this.query,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [id, userId, query, createdAt];
}
