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
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart'
    show
        ConflictAlgorithm,
        Database,
        DatabaseExecutor,
        DatabaseFactory,
        OpenDatabaseOptions,
        databaseFactory,
        onDatabaseDowngradeDelete;

import '/custom_code/actions/cine_models.dart';
import '/custom_code/actions/firebase_service.dart';

/// Base SQLite locale de CinéSphère (cahier des charges, section 6.10).
///
/// Action FlutterFlow d'ancrage (comme `cineModels`) : ouvre la base et
/// renvoie sa version, 0 sur le web où SQLite n'existe pas. Les autres
/// fichiers importent `CineLocalDb` avec
/// `import '/custom_code/actions/cine_local_db.dart';`.
Future<int> cineLocalDb() async {
  final local = CineLocalDb.instance;
  if (!local.isSupported) {
    return 0;
  }
  try {
    final rows = await (await local.database).rawQuery('PRAGMA user_version');
    return (rows.first.values.first as num).toInt();
  } catch (error) {
    developer.log('cineLocalDb', name: 'CineLocalDb', error: error);
    return 0;
  }
}

const String kLocalDbName = 'cinesphere.db';

/// Durée de fraîcheur du cache : au-delà, on recharge depuis Firestore
/// (les données périmées restent affichées hors connexion).
const Duration kCacheTtl = Duration(hours: 24);

/// Recherches récentes gardées par membre.
const int kMaxRecentSearches = 20;

/// Tables vidées par « Vider le cache » (données publiques, rechargeables).
const kCacheTables = [
  'cached_movies',
  'cached_series',
  'cached_home_sections',
  'calendar_events',
];

/// Tables des données du membre, vidées à la déconnexion.
const kPrivateTables = ['local_favorites', 'recent_searches', 'pending_sync'];

/// Migrations du schéma : l'élément i fait passer la base de la version i à
/// la version i + 1. Pour changer le schéma, AJOUTER un élément à la fin
/// (ne jamais modifier une migration déjà livrée) : `onUpgrade` exécute
/// seulement celles qui manquent sur l'appareil.
const List<List<String>> kLocalDbMigrations = [
  // Version 1
  [
    '''
    CREATE TABLE cached_movies (
      tmdb_id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      poster_url TEXT,
      release_date TEXT,
      rating REAL,
      popularity REAL,
      data TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE cached_series (
      tmdb_id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      poster_url TEXT,
      release_date TEXT,
      rating REAL,
      popularity REAL,
      data TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE cached_home_sections (
      section_key TEXT PRIMARY KEY,
      payload TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE local_favorites (
      user_id TEXT NOT NULL,
      media_key TEXT NOT NULL,
      media_type TEXT NOT NULL,
      tmdb_id INTEGER NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      poster_url TEXT,
      added_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, media_key)
    )''',
    '''
    CREATE TABLE recent_searches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      query TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE (user_id, query)
    )''',
    '''
    CREATE TABLE calendar_events (
      id TEXT PRIMARY KEY,
      media_key TEXT NOT NULL,
      media_type TEXT NOT NULL,
      tmdb_id INTEGER NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      poster_url TEXT,
      platform TEXT,
      release_at INTEGER NOT NULL,
      season_number INTEGER,
      episode_number INTEGER,
      data TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )''',
    'CREATE INDEX idx_calendar_events_release_at '
        'ON calendar_events (release_at)',
    '''
    CREATE TABLE pending_sync (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      operation TEXT NOT NULL CHECK (operation IN ('set', 'update', 'delete')),
      collection TEXT NOT NULL,
      doc_id TEXT NOT NULL,
      payload TEXT NOT NULL DEFAULT '{}',
      created_at INTEGER NOT NULL,
      retry_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT
    )''',
    'CREATE INDEX idx_pending_sync_doc '
        'ON pending_sync (user_id, collection, doc_id)',
  ],
];

/// Taille lisible en français : « 512 o », « 48 Ko », « 1,2 Mo ».
String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes o';
  }
  const units = ['Ko', 'Mo', 'Go'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value < 10 && value != value.roundToDouble()
      ? value.toStringAsFixed(1).replaceAll('.', ',')
      : value.round().toString();
  return '$text ${units[unit]}';
}

/// Document `releaseEvents/{id}` -> ligne [cineRow] (titre et affiche y sont
/// dénormalisés) avec la clé du titre (`media_key` : `movie_550`).
Map<String, dynamic> releaseEventRow(DocumentSnapshot<Object?> doc) {
  final row = cineRow(doc);
  final type = row['media_type'] as String? ?? 'movie';
  final tmdbId = (row['tmdb_id'] as num?)?.toInt() ?? 0;
  return row
    ..['media_type'] = type
    ..['media_key'] = mediaKey(type, tmdbId);
}

/// Date de sortie d'une ligne de [releaseEventRow] (UTC), null si absente.
DateTime? releaseDateOf(Map<String, dynamic> row) =>
    DateTime.tryParse('${row['release_date'] ?? row['release_at'] ?? ''}');

// Encodage JSON ---------------------------------------------------------------

/// JSON des colonnes `data` / `payload` : dates et Timestamp en ISO 8601.
String encodeLocalJson(Object? value) =>
    jsonEncode(value, toEncodable: (object) {
      if (object is DateTime) {
        return object.toUtc().toIso8601String();
      }
      if (object is Timestamp) {
        return object.toDate().toUtc().toIso8601String();
      }
      return object.toString();
    });

Map<String, dynamic> _decodeMap(Object? text) {
  if (text is! String || text.isEmpty) {
    return <String, dynamic>{};
  }
  final value = jsonDecode(text);
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

int _millis(DateTime date) => date.toUtc().millisecondsSinceEpoch;

DateTime _fromMillis(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch((value as num).toInt(), isUtc: true);

// Cache puis réseau ---------------------------------------------------------

/// Valeur lue dans le cache et date de son enregistrement.
class CachedValue<T> {
  const CachedValue(this.value, this.cachedAt);

  final T value;
  final DateTime cachedAt;
}

enum CacheSource { cache, network }

/// Résultat émis par [cacheThenNetwork].
class CacheResult<T> {
  const CacheResult(
    this.data,
    this.source, {
    required this.updatedAt,
    this.isStale = false,
    this.error,
  });

  final T data;
  final CacheSource source;

  /// Date des données (enregistrement en cache ou réponse du réseau).
  final DateTime updatedAt;

  /// Cache plus vieux que [kCacheTtl] (ou réseau indisponible).
  final bool isStale;

  /// Erreur du réseau quand les données affichées viennent du cache.
  final Object? error;

  bool get fromCache => source == CacheSource.cache;
}

/// Stratégie « cache puis réseau » (section 6.10) :
///
/// 1. le cache est émis tout de suite s'il existe (affichage immédiat, même
///    hors connexion) ;
/// 2. s'il a moins de [ttl] et que [forceRefresh] est faux, on s'arrête là
///    (pas de lecture Firestore inutile) ;
/// 3. sinon le réseau est interrogé, sa réponse est enregistrée puis émise ;
/// 4. si le réseau échoue, le cache est émis à nouveau, marqué périmé avec
///    l'erreur ; sans cache, l'erreur est transmise.
Stream<CacheResult<T>> cacheThenNetwork<T>({
  required Future<CachedValue<T>?> Function() readCache,
  required Future<T> Function() fetch,
  required Future<void> Function(T value) writeCache,
  bool forceRefresh = false,
  Duration ttl = kCacheTtl,
  DateTime Function() now = DateTime.now,
}) async* {
  CachedValue<T>? cached;
  try {
    cached = await readCache();
  } catch (error) {
    // Cache illisible : on passe directement au réseau.
    developer.log('readCache', name: 'CineLocalDb', error: error);
  }
  if (cached != null) {
    final fresh = now().difference(cached.cachedAt) < ttl;
    yield CacheResult(cached.value, CacheSource.cache,
        updatedAt: cached.cachedAt, isStale: !fresh);
    if (fresh && !forceRefresh) {
      return;
    }
  }

  final T value;
  try {
    value = await fetch();
  } catch (error) {
    if (cached == null) {
      rethrow;
    }
    yield CacheResult(cached.value, CacheSource.cache,
        updatedAt: cached.cachedAt, isStale: true, error: error);
    return;
  }
  try {
    await writeCache(value);
  } catch (error) {
    developer.log('writeCache', name: 'CineLocalDb', error: error);
  }
  yield CacheResult(value, CacheSource.network, updatedAt: now());
}

// File d'attente hors connexion -----------------------------------------

enum SyncOperation {
  set('set'),
  update('update'),
  delete('delete');

  const SyncOperation(this.value);
  final String value;

  static SyncOperation fromValue(String? value) => SyncOperation.values
      .firstWhere((o) => o.value == value, orElse: () => SyncOperation.set);
}

/// Écriture Firestore faite hors connexion, rejouée par le SyncService au
/// retour du réseau (table `pending_sync`).
class PendingSyncOperation extends CineModel {
  const PendingSyncOperation({
    this.id,
    required this.userId,
    required this.operation,
    required this.collection,
    required this.docId,
    this.payload = const {},
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  /// Rang dans la file (null avant l'enregistrement).
  final int? id;
  final String userId;
  final SyncOperation operation;

  /// Chemin de la collection, ex. `users/u1/favorites`.
  final String collection;
  final String docId;

  /// Champs écrits (clés snake_case, voir toFirestoreFields).
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  String get path => '$collection/$docId';

  factory PendingSyncOperation.fromMap(Map<String, dynamic> map) =>
      PendingSyncOperation(
        id: (map['id'] as num?)?.toInt(),
        userId: map['user_id'] as String,
        operation: SyncOperation.fromValue(map['operation'] as String?),
        collection: map['collection'] as String,
        docId: map['doc_id'] as String,
        payload: _decodeMap(map['payload']),
        createdAt: _fromMillis(map['created_at']),
        retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
        lastError: map['last_error'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'operation': operation.value,
        'collection': collection,
        'doc_id': docId,
        'payload': payload,
        'created_at': createdAt.toUtc().toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
      };

  @override
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'operation': operation.value,
        'collection': collection,
        'doc_id': docId,
        'payload': encodeLocalJson(payload),
        'created_at': _millis(createdAt),
        'retry_count': retryCount,
        'last_error': lastError,
      };

  PendingSyncOperation copyWith({
    SyncOperation? operation,
    Map<String, dynamic>? payload,
  }) =>
      PendingSyncOperation(
        id: id,
        userId: userId,
        operation: operation ?? this.operation,
        collection: collection,
        docId: docId,
        payload: payload ?? this.payload,
        createdAt: createdAt,
        retryCount: retryCount,
        lastError: lastError,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        operation,
        collection,
        docId,
        payload,
        createdAt,
        retryCount,
        lastError,
      ];
}

// Base locale -------------------------------------------------------------

/// Accès à `cinesphere.db`.
///
/// Sur le web (Test Mode FlutterFlow), SQLite n'existe pas : [isSupported]
/// est faux, les lectures renvoient null / vide et les écritures ne font
/// rien. Les écrans passent alors directement par Firestore.
class CineLocalDb {
  /// [factory] et [path] remplacent sqflite (tests : `databaseFactoryFfi`,
  /// `inMemoryDatabasePath`) ; [remote] remplace Firestore, [now] l'horloge.
  CineLocalDb({
    DatabaseFactory? factory,
    String? path,
    bool? supported,
    List<List<String>> migrations = kLocalDbMigrations,
    CineFirebaseService? remote,
    DateTime Function() now = DateTime.now,
  })  : _factory = factory,
        _path = path,
        isSupported = supported ?? (factory != null || !kIsWeb),
        _migrations = migrations,
        _remote = remote,
        _now = now;

  static CineLocalDb? _instance;
  static CineLocalDb? _override;

  static CineLocalDb get instance => _override ?? (_instance ??= CineLocalDb());

  /// Remplace la base partagée (tests). `null` rétablit la vraie base.
  @visibleForTesting
  static set debugInstance(CineLocalDb? db) => _override = db;

  final DatabaseFactory? _factory;
  final String? _path;
  final List<List<String>> _migrations;
  final CineFirebaseService? _remote;
  final DateTime Function() _now;

  /// Faux sur le web : aucune donnée n'est gardée sur l'appareil.
  final bool isSupported;

  int get version => _migrations.length;

  CineFirebaseService get remote => _remote ?? CineFirebaseService.instance;

  DateTime now() => _now();

  Future<Database>? _opening;

  /// Ouverte au premier appel, puis partagée.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? '${await factory.getDatabasesPath()}/$kLocalDbName';
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
        // Base plus récente que l'application (retour à une ancienne
        // version) : ce n'est qu'un cache, on la recrée.
        onDowngrade: onDatabaseDowngradeDelete,
      ),
    );
  }

  Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    for (var v = from; v < to; v++) {
      for (final statement in _migrations[v]) {
        batch.execute(statement);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) {
      await (await opening).close();
    }
  }

  /// Exécute [run] si SQLite est disponible, sinon renvoie [fallback].
  Future<T> _use<T>(T fallback, Future<T> Function(Database db) run) async {
    if (!isSupported) {
      return fallback;
    }
    return run(await database);
  }

  // Catalogue (cached_movies, cached_series) ------------------------------

  static String _catalogTable(String? mediaType) =>
      mediaType == 'series' ? 'cached_series' : 'cached_movies';

  Map<String, Object?>? _catalogEntry(Map<String, dynamic> row, int cachedAt) {
    final key = parseMediaKey(row['id'] as String?);
    if (key == null) {
      return null;
    }
    return {
      'tmdb_id': key.tmdbId,
      'title': row['title'] as String? ?? '',
      'poster_url': row['poster_url'],
      'release_date': row['release_date']?.toString(),
      'rating': (row['rating'] as num?)?.toDouble(),
      'popularity': (row['popularity'] as num?)?.toDouble(),
      'data': encodeLocalJson(row),
      'cached_at': cachedAt,
    };
  }

  /// Enregistre des lignes du catalogue ([catalogRow], id `movie_550`).
  /// [replaceAll] : catalogue complet, les anciens titres sont retirés.
  Future<void> saveCatalog(List<Map<String, dynamic>> rows,
          {bool replaceAll = false}) =>
      _use(null, (db) async {
        final cachedAt = _millis(now());
        await db.transaction((txn) async {
          final batch = txn.batch();
          if (replaceAll) {
            batch
              ..delete('cached_movies')
              ..delete('cached_series');
          }
          for (final row in rows) {
            final entry = _catalogEntry(row, cachedAt);
            if (entry != null) {
              batch.insert(
                  _catalogTable(row['media_type'] as String? ??
                      parseMediaKey(row['id'] as String?)?.type),
                  entry,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          await batch.commit(noResult: true);
        });
      });

  /// Tout le catalogue en cache, du plus populaire au moins populaire.
  /// La date retenue est celle du titre le plus ancien : un titre rafraîchi
  /// seul (fiche détail) ne rend pas tout le catalogue « frais ».
  Future<CachedValue<List<Map<String, dynamic>>>?> readCatalog() =>
      _use(null, (db) async {
        final rows = [
          ...await db.query('cached_movies', columns: ['data', 'cached_at']),
          ...await db.query('cached_series', columns: ['data', 'cached_at']),
        ];
        if (rows.isEmpty) {
          return null;
        }
        final oldest = rows
            .map((r) => (r['cached_at'] as num).toInt())
            .reduce((a, b) => a < b ? a : b);
        final media = rows.map((r) => _decodeMap(r['data'])).toList()
          ..sort((a, b) => ((b['popularity'] as num?) ?? 0)
              .compareTo((a['popularity'] as num?) ?? 0));
        return CachedValue(media, _fromMillis(oldest));
      });

  /// Un titre par sa clé `movie_550`.
  Future<CachedValue<Map<String, dynamic>>?> readMedia(String key) =>
      _use(null, (db) async {
        final parsed = parseMediaKey(key);
        if (parsed == null) {
          return null;
        }
        final rows = await db.query(_catalogTable(parsed.type),
            columns: ['data', 'cached_at'],
            where: 'tmdb_id = ?',
            whereArgs: [parsed.tmdbId]);
        return rows.isEmpty
            ? null
            : CachedValue(_decodeMap(rows.first['data']),
                _fromMillis(rows.first['cached_at']));
      });

  // Sections de l'accueil (cached_home_sections) ---------------------------

  Future<void> saveHomeSection(
          String sectionKey, List<Map<String, dynamic>> rows) =>
      _use(null, (db) async {
        await db.insert(
            'cached_home_sections',
            {
              'section_key': sectionKey,
              'payload': encodeLocalJson(rows),
              'cached_at': _millis(now()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      });

  Future<CachedValue<List<Map<String, dynamic>>>?> readHomeSection(
          String sectionKey) =>
      _use(null, (db) async {
        final rows = await db.query('cached_home_sections',
            where: 'section_key = ?', whereArgs: [sectionKey]);
        if (rows.isEmpty) {
          return null;
        }
        final payload = jsonDecode(rows.first['payload'] as String) as List;
        return CachedValue(
          [for (final item in payload) Map<String, dynamic>.from(item as Map)],
          _fromMillis(rows.first['cached_at']),
        );
      });

  // Calendrier (calendar_events) -------------------------------------------

  Map<String, Object?>? _calendarEntry(Map<String, dynamic> row, int cachedAt) {
    final type = row['media_type'] as String?;
    final tmdbId = (row['tmdb_id'] as num?)?.toInt();
    final date = releaseDateOf(row);
    if (row['id'] == null || type == null || tmdbId == null || date == null) {
      return null;
    }
    return {
      'id': row['id'],
      'media_key': mediaKey(type, tmdbId),
      'media_type': type,
      'tmdb_id': tmdbId,
      'title': row['title'] as String? ?? '',
      'poster_url': row['poster_url'],
      'platform': row['platform'],
      'release_at': _millis(date),
      'season_number': (row['season_number'] as num?)?.toInt(),
      'episode_number': (row['episode_number'] as num?)?.toInt(),
      'data': encodeLocalJson(row),
      'cached_at': cachedAt,
    };
  }

  /// Enregistre des sorties (lignes [releaseEventRow]).
  Future<void> saveCalendarEvents(List<Map<String, dynamic>> rows) =>
      _use(null, (db) async {
        final cachedAt = _millis(now());
        final batch = db.batch();
        for (final row in rows) {
          final entry = _calendarEntry(row, cachedAt);
          if (entry != null) {
            batch.insert('calendar_events', entry,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        await batch.commit(noResult: true);
      });

  /// Remplace les sorties de la période [from] - [to] par [rows] (réponse
  /// de Firestore pour cette période : les sorties supprimées disparaissent).
  Future<void> replaceCalendarRange(
          DateTime from, DateTime to, List<Map<String, dynamic>> rows) =>
      _use(null, (db) async {
        final cachedAt = _millis(now());
        await db.transaction((txn) async {
          final batch = txn.batch()
            ..delete('calendar_events',
                where: 'release_at >= ? AND release_at < ?',
                whereArgs: [_millis(from), _millis(to)]);
          for (final row in rows) {
            final entry = _calendarEntry(row, cachedAt);
            if (entry != null) {
              batch.insert('calendar_events', entry,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          await batch.commit(noResult: true);
        });
      });

  /// Sorties en cache de la période, avec la date de la plus ancienne
  /// (null si la période n'a jamais été chargée ou ne contient rien).
  Future<CachedValue<List<Map<String, dynamic>>>?> readCalendarRange(
          DateTime from, DateTime to) =>
      _use(null, (db) async {
        final rows = await db.query('calendar_events',
            columns: ['data', 'cached_at'],
            where: 'release_at >= ? AND release_at < ?',
            whereArgs: [_millis(from), _millis(to)],
            orderBy: 'release_at, id');
        if (rows.isEmpty) {
          return null;
        }
        final oldest = rows
            .map((r) => (r['cached_at'] as num).toInt())
            .reduce((a, b) => a < b ? a : b);
        return CachedValue(
            [for (final r in rows) _decodeMap(r['data'])], _fromMillis(oldest));
      });

  /// Sorties Firestore (`releaseEvents`) entre [from] (inclus) et [to]
  /// (exclu), par date.
  Future<List<Map<String, dynamic>>> fetchReleaseEvents(
          DateTime from, DateTime to) =>
      remote.guard('fetchReleaseEvents', () async {
        final snap = await remote
            .col('releaseEvents')
            .where('releaseDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .where('releaseDate', isLessThan: Timestamp.fromDate(to))
            .orderBy('releaseDate')
            .get();
        return snap.docs.map(releaseEventRow).toList();
      });

  /// Sorties entre [from] (inclus) et [to] (exclu), par date. [platforms] et
  /// [mediaKeys] (ex. favoris du membre) filtrent si non vides.
  Future<List<Map<String, dynamic>>> readCalendarEvents({
    DateTime? from,
    DateTime? to,
    Iterable<String> platforms = const [],
    Iterable<String> mediaKeys = const [],
    int? limit,
  }) =>
      _use(const [], (db) async {
        final where = <String>[];
        final args = <Object?>[];
        if (from != null) {
          where.add('release_at >= ?');
          args.add(_millis(from));
        }
        if (to != null) {
          where.add('release_at < ?');
          args.add(_millis(to));
        }
        void inList(String column, Iterable<String> values) {
          if (values.isNotEmpty) {
            where.add(
                '$column IN (${List.filled(values.length, '?').join(', ')})');
            args.addAll(values);
          }
        }

        inList('platform', platforms);
        inList('media_key', mediaKeys);
        final rows = await db.query('calendar_events',
            columns: ['data'],
            where: where.isEmpty ? null : where.join(' AND '),
            whereArgs: args,
            orderBy: 'release_at, id',
            limit: limit);
        return [for (final r in rows) _decodeMap(r['data'])];
      });

  /// Oublie les sorties passées avant [before].
  Future<int> deleteCalendarEventsBefore(DateTime before) => _use(
      0,
      (db) => db.delete('calendar_events',
          where: 'release_at < ?', whereArgs: [_millis(before)]));

  // Favoris (local_favorites) ---------------------------------------------

  /// Remplace les favoris locaux de [userId] (lignes [cineRow] de
  /// `users/{uid}/favorites`, id `movie_550`).
  Future<void> replaceLocalFavorites(
          String userId, List<Map<String, dynamic>> rows) =>
      _use(null, (db) async {
        await db.transaction((txn) async {
          await txn.delete('local_favorites',
              where: 'user_id = ?', whereArgs: [userId]);
          for (final row in rows) {
            await _insertFavorite(txn, userId, row);
          }
        });
      });

  /// Ajoute ou retire un favori local.
  Future<void> setLocalFavorite(
          String userId, Map<String, dynamic> row, bool favorite) =>
      _use(null, (db) async {
        if (favorite) {
          await _insertFavorite(db, userId, row);
        } else {
          await db.delete('local_favorites',
              where: 'user_id = ? AND media_key = ?',
              whereArgs: [userId, row['id']]);
        }
      });

  Future<void> _insertFavorite(
      DatabaseExecutor db, String userId, Map<String, dynamic> row) async {
    final key = parseMediaKey(row['id'] as String?);
    if (key == null) {
      return;
    }
    final addedAt = DateTime.tryParse('${row['added_at'] ?? ''}') ?? now();
    await db.insert(
        'local_favorites',
        {
          'user_id': userId,
          'media_key': row['id'],
          'media_type': key.type,
          'tmdb_id': key.tmdbId,
          'title': row['title'] as String? ?? '',
          'poster_url': row['poster_url'],
          'added_at': _millis(addedAt),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Favoris locaux de [userId], les plus récents d'abord (format [cineRow]).
  Future<List<Map<String, dynamic>>> localFavorites(String userId) =>
      _use(const [], (db) async {
        final rows = await db.query('local_favorites',
            where: 'user_id = ?',
            whereArgs: [userId],
            orderBy: 'added_at DESC');
        return [
          for (final r in rows)
            {
              'id': r['media_key'],
              'media_type': r['media_type'],
              'tmdb_id': r['tmdb_id'],
              'title': r['title'],
              'poster_url': r['poster_url'],
              'added_at': _fromMillis(r['added_at']).toIso8601String(),
            },
        ];
      });

  // Recherches récentes (recent_searches) -----------------------------------

  /// Note une recherche ; une recherche répétée remonte en tête. Seules les
  /// [kMaxRecentSearches] dernières sont gardées.
  Future<void> addRecentSearch(String userId, String query) =>
      _use(null, (db) async {
        final text = query.trim();
        if (text.isEmpty) {
          return;
        }
        await db.transaction((txn) async {
          await txn.insert(
              'recent_searches',
              {
                'user_id': userId,
                'query': text,
                'created_at': _millis(now()),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
          await txn.rawDelete(
            'DELETE FROM recent_searches WHERE user_id = ? AND id NOT IN '
            '(SELECT id FROM recent_searches WHERE user_id = ? '
            'ORDER BY created_at DESC, id DESC LIMIT ?)',
            [userId, userId, kMaxRecentSearches],
          );
        });
      });

  Future<List<String>> recentSearches(String userId, {int limit = 10}) =>
      _use(const [], (db) async {
        final rows = await db.query('recent_searches',
            columns: ['query'],
            where: 'user_id = ?',
            whereArgs: [userId],
            orderBy: 'created_at DESC, id DESC',
            limit: limit);
        return [for (final r in rows) r['query'] as String];
      });

  // File pending_sync ---------------------------------------------------

  /// Met une écriture en file. Dernière écriture gagnante : les opérations
  /// déjà en attente sur le même document sont remplacées par celle-ci
  /// (un `update` après un `set` / `update` fusionne les champs ; un
  /// `update` après un `delete` est ignoré, le document n'existant plus).
  /// Renvoie le rang de l'opération gardée (0 sur le web).
  Future<int> enqueuePending(PendingSyncOperation operation) => _use(
      0,
      (db) => db.transaction((txn) async {
            final previous = (await txn.query('pending_sync',
                    where: 'user_id = ? AND collection = ? AND doc_id = ?',
                    whereArgs: [
                      operation.userId,
                      operation.collection,
                      operation.docId,
                    ],
                    orderBy: 'id'))
                .map(PendingSyncOperation.fromMap)
                .toList();
            var kept = operation;
            if (operation.operation == SyncOperation.update &&
                previous.isNotEmpty) {
              final last = previous.last;
              if (last.operation == SyncOperation.delete) {
                return last.id!;
              }
              kept = operation.copyWith(
                operation: last.operation,
                payload: {...last.payload, ...operation.payload},
              );
            }
            for (final old in previous) {
              await txn
                  .delete('pending_sync', where: 'id = ?', whereArgs: [old.id]);
            }
            return txn.insert('pending_sync', kept.toMap()..remove('id'));
          }));

  /// Opérations en attente, dans l'ordre où elles doivent être rejouées.
  Future<List<PendingSyncOperation>> pendingOperations({String? userId}) =>
      _use(const [], (db) async {
        final rows = await db.query('pending_sync',
            where: userId == null ? null : 'user_id = ?',
            whereArgs: userId == null ? null : [userId],
            orderBy: 'id');
        return rows.map(PendingSyncOperation.fromMap).toList();
      });

  Future<int> pendingCount({String? userId}) => _use(0, (db) async {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM pending_sync'
          '${userId == null ? '' : ' WHERE user_id = ?'}',
          [if (userId != null) userId],
        );
        return (rows.first['n'] as num).toInt();
      });

  /// Opération envoyée à Firestore : retirée de la file.
  Future<void> removePending(int id) => _use(null, (db) async {
        await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
      });

  /// Échec d'envoi : l'opération reste en file, `retry_count` augmente.
  Future<void> markPendingFailed(int id, Object error) =>
      _use(null, (db) async {
        await db.rawUpdate(
          'UPDATE pending_sync SET retry_count = retry_count + 1, '
          'last_error = ? WHERE id = ?',
          ['$error', id],
        );
      });

  // Nettoyage ------------------------------------------------------------

  /// Taille approximative (octets) des données en cache : colonnes JSON des
  /// tables de [kCacheTables].
  Future<int> cacheSizeBytes() => _use(0, (db) async {
        final rows = await db.rawQuery('''
          SELECT
            (SELECT IFNULL(SUM(LENGTH(CAST(data AS BLOB))), 0) FROM cached_movies)
          + (SELECT IFNULL(SUM(LENGTH(CAST(data AS BLOB))), 0) FROM cached_series)
          + (SELECT IFNULL(SUM(LENGTH(CAST(payload AS BLOB))), 0) FROM cached_home_sections)
          + (SELECT IFNULL(SUM(LENGTH(CAST(data AS BLOB))), 0) FROM calendar_events)
          AS size''');
        return (rows.first['size'] as num?)?.toInt() ?? 0;
      });

  /// Vide le cache public (catalogue, accueil, calendrier). Les favoris,
  /// recherches et écritures en attente sont gardés. Renvoie la taille
  /// libérée.
  Future<int> clearCache() => _use(0, (db) async {
        final size = await cacheSizeBytes();
        final batch = db.batch();
        for (final table in kCacheTables) {
          batch.delete(table);
        }
        await batch.commit(noResult: true);
        try {
          await db.execute('VACUUM');
        } catch (error) {
          developer.log('VACUUM', name: 'CineLocalDb', error: error);
        }
        return size;
      });

  /// Vide les sections d'accueil enregistrées : « Pour vous » dépend des
  /// genres du membre connecté.
  Future<void> clearPersonalCache() =>
      _use(null, (db) => db.delete('cached_home_sections'));

  /// Efface les données privées (favoris, recherches, file d'attente) de
  /// [userId], ou de tous les membres si null (déconnexion).
  Future<void> clearPrivateData({String? userId}) => _use(null, (db) async {
        final batch = db.batch();
        for (final table in kPrivateTables) {
          batch.delete(table,
              where: userId == null ? null : 'user_id = ?',
              whereArgs: userId == null ? null : [userId]);
        }
        await batch.commit(noResult: true);
      });

  // Lecture cache puis réseau -------------------------------------------

  /// Catalogue complet (films + séries) : SQLite puis Firestore.
  Stream<CacheResult<List<Map<String, dynamic>>>> watchCatalog(
          {bool forceRefresh = false}) =>
      cacheThenNetwork(
        readCache: readCatalog,
        fetch: () => remote.catalog(refresh: forceRefresh),
        writeCache: (rows) => saveCatalog(rows, replaceAll: true),
        forceRefresh: forceRefresh,
        now: now,
      );

  /// Un titre (`movie_550`) : SQLite puis Firestore ; null s'il n'existe pas.
  Stream<CacheResult<Map<String, dynamic>?>> watchMedia(String key,
          {bool forceRefresh = false}) =>
      cacheThenNetwork<Map<String, dynamic>?>(
        readCache: () => readMedia(key),
        fetch: () => remote.fetchMedia(key),
        writeCache: (row) async {
          if (row != null) {
            await saveCatalog([row]);
          }
        },
        forceRefresh: forceRefresh,
        now: now,
      );

  /// Sorties de la période [from] - [to] : SQLite puis Firestore.
  Stream<CacheResult<List<Map<String, dynamic>>>> watchCalendar(
    DateTime from,
    DateTime to, {
    bool forceRefresh = false,
  }) =>
      cacheThenNetwork(
        readCache: () => readCalendarRange(from, to),
        fetch: () => fetchReleaseEvents(from, to),
        writeCache: (rows) => replaceCalendarRange(from, to, rows),
        forceRefresh: forceRefresh,
        now: now,
      );

  /// Une section de l'accueil ([sectionKey] : `trending`, `upcoming`…)
  /// calculée par [fetch] à partir de Firestore.
  Stream<CacheResult<List<Map<String, dynamic>>>> watchHomeSection(
    String sectionKey,
    Future<List<Map<String, dynamic>>> Function() fetch, {
    bool forceRefresh = false,
  }) =>
      cacheThenNetwork(
        readCache: () => readHomeSection(sectionKey),
        fetch: fetch,
        writeCache: (rows) => saveHomeSection(sectionKey, rows),
        forceRefresh: forceRefresh,
        now: now,
      );
}
