import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _created = DateTime.utc(2026, 10, 20, 9, 30);

final _profile = UserProfile(
  id: 'u1',
  username: 'zak',
  email: 'zak@example.com',
  avatarUrl: 'https://cdn/avatar.jpg',
  bio: 'Cinéphile',
  role: UserRole.admin,
  createdAt: _created,
  updatedAt: _created,
);

final _preferences = UserPreferences(
  userId: 'u1',
  favoriteGenres: const [28, 878],
  favoritePlatforms: const ['Netflix', 'Max'],
  contentTypes: const [MediaType.series],
  notificationsEnabled: false,
  notifyReleases: true,
  notifyFavoriteSeries: false,
  reminderTime: const TimeOfDay(hour: 9, minute: 5),
  themeMode: AppThemeMode.light,
  onboardingCompleted: true,
  updatedAt: _created,
);

final _movie = Movie(
  id: 'm1',
  tmdbId: 27205,
  title: 'Inception',
  description: 'Un voleur de rêves.',
  posterUrl: 'https://image.tmdb.org/p.jpg',
  backdropUrl: 'https://image.tmdb.org/b.jpg',
  releaseDate: DateTime(2010, 7, 16),
  duration: 148,
  rating: 8.4,
  trailerUrl: 'https://youtu.be/x',
  status: 'released',
  genreIds: const [28, 878],
  createdAt: _created,
);

final _series = Series(
  id: 's1',
  tmdbId: 70523,
  title: 'Dark',
  firstAirDate: DateTime(2017, 12, 1),
  numberOfSeasons: 3,
  numberOfEpisodes: 26,
  rating: 8.4,
  status: 'ended',
  genreIds: const [18, 9648],
  createdAt: _created,
);

/// Tous les modèles, avec leurs fabriques JSON et SQLite.
final _cases = <String, (CineModel, CineModel Function(Map<String, dynamic>),
    CineModel Function(Map<String, dynamic>))>{
  'UserProfile': (_profile, UserProfile.fromJson, UserProfile.fromMap),
  'UserPreferences': (
    _preferences,
    UserPreferences.fromJson,
    UserPreferences.fromMap
  ),
  'Genre': (const Genre(id: 28, name: 'Action'), Genre.fromJson, Genre.fromMap),
  'Platform': (
    const Platform(id: 8, name: 'Netflix', logoUrl: 'https://logo'),
    Platform.fromJson,
    Platform.fromMap
  ),
  'Movie': (_movie, Movie.fromJson, Movie.fromMap),
  'Series': (_series, Series.fromJson, Series.fromMap),
  'Favorite': (
    Favorite(id: 'f1', userId: 'u1', seriesId: 's1', createdAt: _created),
    Favorite.fromJson,
    Favorite.fromMap
  ),
  'Watchlist': (
    Watchlist(
        id: 'w1',
        userId: 'u1',
        name: 'Week-end',
        description: 'À voir',
        isPublic: true,
        createdAt: _created),
    Watchlist.fromJson,
    Watchlist.fromMap
  ),
  'WatchlistItem': (
    WatchlistItem(id: 'i1', watchlistId: 'w1', movieId: 'm1', addedAt: _created),
    WatchlistItem.fromJson,
    WatchlistItem.fromMap
  ),
  'WatchedEntry': (
    WatchedEntry(
        id: 'v1',
        userId: 'u1',
        seriesId: 's1',
        episodeId: 1234,
        watchedAt: _created),
    WatchedEntry.fromJson,
    WatchedEntry.fromMap
  ),
  'Review': (
    Review(
      id: 'r1',
      userId: 'u1',
      movieId: 'm1',
      rating: 9,
      content: 'Magistral',
      isPrivate: true,
      createdAt: _created,
      updatedAt: _created,
      likesCount: 4,
      authorUsername: 'zak',
    ),
    Review.fromJson,
    Review.fromMap
  ),
  'ReleaseEvent': (
    ReleaseEvent(
      id: 'e1',
      seriesId: 's1',
      title: 'S2E05',
      releaseAt: _created,
      platform: 'Netflix',
      seasonNumber: 2,
      episodeNumber: 5,
      description: 'Final',
    ),
    ReleaseEvent.fromJson,
    ReleaseEvent.fromMap
  ),
  'AppNotification': (
    AppNotification(
      id: 'n1',
      userId: 'u1',
      title: 'Dark',
      message: 'Sort demain',
      releaseEventId: 'e1',
      scheduledAt: _created,
      isRead: true,
      createdAt: _created,
    ),
    AppNotification.fromJson,
    AppNotification.fromMap
  ),
  'SearchHistoryEntry': (
    SearchHistoryEntry(id: 'h1', userId: 'u1', query: 'nolan', createdAt: _created),
    SearchHistoryEntry.fromJson,
    SearchHistoryEntry.fromMap
  ),
};

void main() {
  test('cineModels renvoie la version du schéma', () async {
    expect(await cineModels(), kCineSchemaVersion);
  });

  group('aller-retour', () {
    for (final entry in _cases.entries) {
      final (model, fromJson, fromMap) = entry.value;

      test('${entry.key} : fromJson(toJson())', () {
        expect(fromJson(model.toJson()), model);
      });

      test('${entry.key} : fromMap(toMap()) n\'utilise que des types SQLite', () {
        final row = model.toMap();
        expect(
          row.values.every((v) => v == null || v is num || v is String),
          isTrue,
          reason: '$row',
        );
        expect(fromMap(row), model);
      });

      test('${entry.key} : égalité par valeur et hashCode', () {
        final copy = fromJson(model.toJson());
        expect(copy, model);
        expect(copy.hashCode, model.hashCode);
        expect(identical(copy, model), isFalse);
      });
    }
  });

  group('JSON (lignes snake_case)', () {
    test('les colonnes date restent au format AAAA-MM-JJ', () {
      expect(_movie.toJson()['release_date'], '2010-07-16');
      expect(_series.toJson()['first_air_date'], '2017-12-01');
    });

    test('les nombres Postgres (numeric en texte, entiers) sont acceptés', () {
      final movie = Movie.fromJson({
        'tmdb_id': '27205',
        'title': 'Inception',
        'rating': '8.4',
        'duration': 148.0,
      });
      expect(movie.tmdbId, 27205);
      expect(movie.rating, 8.4);
      expect(movie.duration, 148);
    });

    test('les champs absents prennent les valeurs par défaut', () {
      final prefs = UserPreferences.fromJson({'user_id': 'u1'});
      expect(prefs, const UserPreferences(userId: 'u1'));
      expect(prefs.reminderTime, const TimeOfDay(hour: 18, minute: 0));
      expect(prefs.themeMode, AppThemeMode.dark);
    });

    test('toUpsertPayload retire les champs gérés par la base', () {
      final payload = _movie.toUpsertPayload();
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('created_at'), isFalse);
      expect(payload['genre_ids'], [28, 878]);
      expect(_series.toUpsertPayload().containsKey('id'), isFalse);
    });

    test('UserProfile.toUpdateJson n\'envoie jamais le rôle', () {
      expect(_profile.toUpdateJson().keys,
          unorderedEquals(['username', 'avatar_url', 'bio']));
    });

    test('Review lit le compteur de likes et l\'auteur imbriqués', () {
      final review = Review.fromJson({
        'id': 'r1',
        'user_id': 'u1',
        'movie_id': 'm1',
        'rating': 7,
        'created_at': '2026-10-20T09:30:00Z',
        'review_likes': [
          {'count': 12}
        ],
        'author': {'username': 'zak'},
      });
      expect(review.likesCount, 12);
      expect(review.authorUsername, 'zak');
      expect(review.toRowJson().containsKey('likes_count'), isFalse);
    });

    test('ReleaseEvent accepte release_date à défaut de release_at', () {
      final event = ReleaseEvent.fromJson(
          {'id': 'e1', 'title': 'Sortie', 'release_date': '2026-11-02'});
      expect(event.releaseAt, DateTime(2026, 11, 2));
      expect(event.isEpisode, isFalse);
    });
  });

  group('cible film / série', () {
    test('MediaTarget déduit le type et l\'identifiant', () {
      final movieFav =
          Favorite(id: 'f', userId: 'u', movieId: 'm1', createdAt: _created);
      final seriesFav =
          Favorite(id: 'f', userId: 'u', seriesId: 's1', createdAt: _created);
      expect(movieFav.mediaType, MediaType.movie);
      expect(movieFav.targetId, 'm1');
      expect(seriesFav.mediaType, MediaType.series);
      expect(seriesFav.targetId, 's1');
    });
  });

  group('enums', () {
    test('valeurs inconnues', () {
      expect(MediaType.fromValue('autre'), MediaType.movie);
      expect(UserRole.fromValue(null), UserRole.user);
      expect(AppThemeMode.fromValue('sepia'), AppThemeMode.dark);
    });
    test('valeurs connues', () {
      expect(MediaType.fromValue('series'), MediaType.series);
      expect(UserRole.fromValue('admin'), UserRole.admin);
      expect(AppThemeMode.fromValue('system'), AppThemeMode.system);
    });
  });

  group('heure de rappel', () {
    test('format Postgres time', () {
      expect(parseTimeOfDay('07:45:00'), const TimeOfDay(hour: 7, minute: 45));
      expect(formatTimeOfDay(const TimeOfDay(hour: 7, minute: 5)), '07:05:00');
    });
    test('valeurs invalides -> 18 h 00', () {
      for (final value in [null, '', 'abc', '25:00', '10:75']) {
        expect(parseTimeOfDay(value), const TimeOfDay(hour: 18, minute: 0));
      }
    });
  });

  group('copyWith', () {
    test('ne modifie que les champs fournis', () {
      final renamed = _profile.copyWith(username: 'zakaria');
      expect(renamed.username, 'zakaria');
      expect(renamed.email, _profile.email);
      expect(renamed, isNot(_profile));
      expect(_movie.copyWith(rating: 9).rating, 9);
      expect(_preferences.copyWith(themeMode: AppThemeMode.dark).themeMode,
          AppThemeMode.dark);
      expect(_preferences.copyWith().favoriteGenres, [28, 878]);
    });
  });

  group('SQLite', () {
    test('decodeSqliteRow restaure booléens et listes', () {
      final row = decodeSqliteRow(
        {'is_public': 1, 'genre_ids': '[1,2]', 'empty': ''},
        bools: ['is_public'],
        lists: ['genre_ids', 'empty'],
      );
      expect(row['is_public'], isTrue);
      expect(row['genre_ids'], [1, 2]);
      expect(row['empty'], isEmpty);
    });
  });
}
